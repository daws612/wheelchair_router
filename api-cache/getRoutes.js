const config = require('./config');
const commons = require('./commons');
const util = require('util');
const getElevation = require('./getElevation');

async function performRouting(req, res, next) {
    var response = { busRoutes: "", walkingDirections: "", recommendations: "" };

    try {

        var params = req.query;
        var originlat = +params.originlat;
        var originlon = +params.originlon;
        var destlat = +params.destlat;
        var destlon = +params.destlon;
        var originHttp = originlat + "," + originlon;
        var destinationHttp = destlat + "," + destlon;

        var firebaseId = params.id;

        var walkingDirections = await commons.getSidewalkOrWalkingDirections(originlat, originlon, destlat, destlon, firebaseId); //await getWalkingRoutes(originHttp, destinationHttp);
        var busRoutes = await getBusRoutes(originlat, originlon, destlat, destlon, originHttp, destinationHttp, firebaseId);

        response.walkingDirections = walkingDirections;
        response.busRoutes = busRoutes;

        res.send(response);
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get directions \n' + ex);
        res.send(ex);
    }

}

async function getWalkingRoutes(origin, destination) {
    console.log("Get walking route of whole path.");
    var walkingDirections = await getElevation.getWalkingDirections(origin, destination, false);
    return walkingDirections;
}

async function getBusRoutes(originlat, originlon, destlat, destlon, firebaseId) {

    var result = [];
    var maxNumberOfOptions = 3;
    var timeToCheck = null;
    var timeInterval = 15;

    try {

        var nearestStopQuery = "SELECT *, 'destination' as stoptype, " +
            "ST_DistanceSphere( " +
            "st_point($2, $1), " +
            "st_point(stop_lon,stop_lat) " +
            ") as dist_m " +
            "FROM stops " +
            "WHERE ST_DistanceSphere( " +
            "st_point($4, $3), " +
            "st_point(stop_lon, stop_lat) " +
            ") < 1000 " +
            "ORDER BY dist_m";

        var nearestDest = await commons.pgPool.query(nearestStopQuery, [destlat, destlon, destlat, destlon]);
        var nearestOrigin = await commons.pgPool.query(nearestStopQuery, [originlat, originlon, originlat, originlon]);

        nearestDest = nearestDest.rows;
        nearestOrigin = nearestOrigin.rows;

        var pageSize = 2;
        var pageStart = 0;
        var pageEnd = pageStart + pageSize;
        while (result.length < maxNumberOfOptions && pageStart < nearestOrigin.length) {

            result = await createRouteDetails(originlat, originlon, destlat, destlon, pageStart, pageEnd, nearestOrigin, nearestDest, result, maxNumberOfOptions, firebaseId);

            if (result.length < maxNumberOfOptions) {
                pageStart = pageEnd;
                pageEnd = pageEnd + pageSize;
            } else
                break;
        }

        console.log('\nSuccessfully complete routing request');
        console.log('*************************************************************************');
        return result;

    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get directions \n' + ex);
        throw ex;
    }

}

async function createRouteDetails(originlat, originlon, destlat, destlon, pageStart, pageEnd, nearestOrigin, nearestDest, result, maxNumberOfOptions, firebaseId) {
    for (var i = pageStart; i < nearestOrigin.length && i < pageEnd; i++) {
        for (var j = 0; j < nearestDest.length && j < pageEnd; j++) {
            if (result.length >= maxNumberOfOptions) {
                i = nearestOrigin.length;
                j = nearestDest.length;
                break;
            }
            result = await fetchDBRoutes(originlat, originlon, destlat, destlon, i, j, nearestOrigin, nearestDest, result, maxNumberOfOptions, firebaseId)


        } //for dest
    }// for origin

    //all origins have been checked against destinations, if still no route found, 
    //go through all origins with the remaining unchecked destinations.
    //This will complete the stop pairs in the retrieved arrays
    if (result.length < maxNumberOfOptions && pageEnd >= nearestOrigin.length && pageEnd < nearestDest.length) {
        for (var orgn = 0; orgn < nearestOrigin.length; orgn++) {
            for (var dstn = pageEnd; dstn < nearestDest.length; dstn++) {
                if (result.length >= maxNumberOfOptions) {
                    orgn = nearestOrigin.length;
                    dstn = nearestDest.length;
                    break;
                }

                result = await fetchDBRoutes(originlat, originlon, destlat, destlon, orgn, dstn, nearestOrigin, nearestDest, result, maxNumberOfOptions, firebaseId)

            }
        }
    }

    return result;
}

async function fetchDBRoutes(originlat, originlon, destlat, destlon, i, j, nearestOrigin, nearestDest, result, maxNumberOfOptions, firebaseId) {

    console.log("Search for origin " + i + " and destination " + j);
    var origin = nearestOrigin[i];
    var destination = nearestDest[j];
    var row = [];

    if (origin === null || destination === null)
        return;

    var stop1 = origin.stop_id;
    var stop2 = destination.stop_id;

    var timeZone = "SET TIME ZONE 'Europe/Istanbul';"

    var routeQuery = "SELECT r.*, t.trip_id, a.departure_time, b.arrival_time, t.* " +
        "from stop_times a, stop_times b  " +
        "left join trips t on t.trip_id=b.trip_id " +
        "left join routes r on r.route_id = t.route_id " +
        "where  " +
        "a.stop_id = $1 " +
        "and b.stop_id = $2 " +
        "and a.trip_id = b.trip_id " +
        //"and a.departure_time between '09:00' and TIME(DATE_ADD('2019-01-07 09:00', INTERVAL 15 MINUTE)) " +
        " and a.departure_time > to_char(current_timestamp, 'HH24:MI:SS') and a.departure_time < to_char(now()::time + INTERVAL '30 min', 'HH24:MI:SS') "+
        "and t.service_id = (case  " +
        "when extract(dow from  current_date) between 1 and 5 then '1' " +
        "when extract(dow from  current_date) = 0 then '3' " +
        "else '2' end) " +
        "group by r.route_id,t.trip_id, a.departure_time, b.arrival_time " +
        "order by a.departure_time ";

    await commons.pgPool.query(timeZone);
    var routes = await commons.pgPool.query(routeQuery, [stop1, stop2]);
    routes = routes.rows;

    console.log("Get route from " + stop1 + " - " + origin.stop_name + " to " + stop2 + " - " + destination.stop_name + " :: Found routes :: " + routes.length);

    if (routes.length > 0) {
        for (var k = 0; k < routes.length; k++) {
            var tripId = routes[k].trip_id;
            var routeStopsQuery = "SELECT st.stop_sequence, s.* FROM stops s " +
                "left join stop_times st on st.stop_id = s.stop_id " +
                "WHERE trip_id = $1  " +
                "AND st.stop_sequence between (SELECT st.stop_sequence FROM stops s " +
                "left join stop_times st on st.stop_id = s.stop_id " +
                "WHERE st.stop_id = $2 and trip_id = $3 ) and (SELECT st.stop_sequence FROM stops s " +
                "left join stop_times st on st.stop_id = s.stop_id " +
                "WHERE st.stop_id = $4 and trip_id = $5) " +
                "ORDER BY stop_sequence asc";
            //howcan this query be made to include the origin and destination stops?
            var routeStops = await commons.pgPool.query(routeStopsQuery, [tripId, stop1, tripId, stop2, tripId]);
            routeStops = routeStops.rows;
            routes[k]['stops'] = routeStops;
            console.log("Trip - " + tripId + " Route index: " + k + " - " + routes[k].route_short_name + " -- Number of stops found: " + routeStops.length);

            if (routes[k].stops.length < 2) {
                routes.splice(k, 1); //remove kth element
                k--;
                continue;
            }

            var routePolylines = [];
            for (var l = 0; l < routeStops.length - 1; l++) {
                var originStop = routeStops[l].stop_lat + "," + routeStops[l].stop_lon;
                var destStop = routeStops[l + 1].stop_lat + "," + routeStops[l + 1].stop_lon;
                //console.log("Get polyline from stop " + l + " to " + (l + 1));

                var googleUrl = config.google.directions.url + util.format('?origin=%s&destination=%s&mode=driving&alternatives=true&key=%s', originStop, destStop, config.google.apikey);
                var polylineResult = await commons.fetchDataFromCache(originStop, destStop, "polyline_path", "polyline_json", googleUrl, "driving");
                var polyline = polylineResult; //JSON.parse(polylineResult);
                polyline = polyline.routes[0].overview_polyline.points;

                //var polyline = await getPath.fetchPolylinePath(originStop, destStop);
                if (polyline)
                    routePolylines.push(polyline);
            }
            routes[k]['polylines'] = routePolylines;

            //if stops are more than 1
            if (routeStops.length > 1) {
                var firstStop = routeStops[0].stop_lat + "," + routeStops[0].stop_lon;
                console.log("Get walking route to first stop: " + routeStops[0].stop_name);
                //var tofirstStop = await getElevation.getWalkingDirections(originlat + "," + originlon, firstStop, true);
                var tofirstStop = await commons.getSidewalkOrWalkingDirections(originlat, originlon, routeStops[0].stop_lat, routeStops[0].stop_lon);
                routes[k]["toFirstStop"] = tofirstStop;


                var lastStop = routeStops[routeStops.length - 1].stop_lat + "," + routeStops[routeStops.length - 1].stop_lon;
                console.log("Get walking route from last stop: " + routeStops[routeStops.length - 1].stop_name);
                //var fromLastStop = await getElevation.getWalkingDirections(lastStop, destlat + "," + destlon, true);
                var fromLastStop = await commons.getSidewalkOrWalkingDirections(routeStops[routeStops.length - 1].stop_lat, routeStops[routeStops.length - 1].stop_lon, destlat, destlon);
                routes[k]["fromLastStop"] = fromLastStop;
            }

            //get routing rate
            var route = "SELECT r.route_id,  coalesce(round(avg(rating),2),0) as rating FROM izmit.routes r " +
                " LEFT JOIN izmit.route_ratings rr ON r.route_id = rr.route_id " +
                " WHERE rr.orig_lon = $1 AND rr.orig_lat = $2 " +
                " AND rr.dest_lon = $3 AND rr.dest_lat = $4 AND route_name=$5 GROUP BY r.route_id;"
            var routeid = await commons.pgPool.query(route, [origin.stop_lon, origin.stop_lat, destination.stop_lon, destination.stop_lat, "bus-" + routes[k].route_short_name]);

            var rating = 0;
            if (routeid.rowCount > 0)
                rating = +routeid.rows[0].rating;

            routes[k]["rating"] = rating;

            //save route in db for later rating reference
            routeid = await commons.saveRouteInfo(origin.stop_lat, origin.stop_lon, destination.stop_lat, destination.stop_lon, "bus-" + routes[k].route_short_name, tripId);
            routes[k]["dbRouteId"] = routeid;
        } //for routes
    }//if routes
    if (routes.length > 0)
        result = result.concat(routes);

    return result;
}

module.exports.performRouting = performRouting