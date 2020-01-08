const config = require('./config');
const commons = require('./commons');
const util = require('util');

async function getBusRoutes(req, res, next) {

    const db = commons.makeDb({
        host: config.schema.host,
        user: config.schema.user,
        password: config.schema.password,
        database: config.schema.db
    });
    var result = [];

    try {

        var params = req.query;
        var originlat = params.originlat;
        var originlon = params.originlon;
        var destlat = params.destlat;
        var destlon = params.destlon;

        var nearestStopQuery = "SELECT *, 'destination' as stoptype, " +
            "ST_Distance_Sphere( " +
            "point(?, ?), " +
            "point(stop_lat, stop_lon) " +
            ") as 'dist_m' " +
            "FROM stops " +
            "WHERE ST_Distance_Sphere( " +
            "point(?, ?), " +
            "point(stop_lat, stop_lon) " +
            ") < 1000 " +
            "ORDER BY `dist_m` limit 0, 2";

        var nearestDest = await db.query(nearestStopQuery, [destlat, destlon, destlat, destlon]);
        var nearestOrigin = await db.query(nearestStopQuery, [originlat, originlon, originlat, originlon]);

        for (var i = 0; i < nearestOrigin.length; i++) {
            for (var j = 0; j < nearestDest.length; j++) {
                var origin = nearestOrigin[i];
                var destination = nearestDest[j];
                var row = [];

                if (origin === null || destination === null)
                    return;

                var stop1 = origin.stop_id;
                var stop2 = destination.stop_id;

                console.log("Get route from " + stop1 + " to " + stop2);

                var routeQuery = "SELECT t.route_id, t.trip_id, a.departure_time, b.arrival_time, t.* " +
                    "from stop_times a, stop_times b  " +
                    "left join trips t on t.trip_id=b.trip_id " +
                    "where  " +
                    "a.stop_id = ? " +
                    "and b.stop_id = ? " +
                    "and a.trip_id = b.trip_id " +
                    "and a.departure_time between '07:00' and TIME(DATE_ADD('2019-01-07 07:00', INTERVAL 15 MINUTE)) " +
                    "and t.service_id = (case  " +
                    "when dayofweek(current_date()) between 2 and 6 then 1 " +
                    "when dayofweek(current_date()) = 1 then 3 " +
                    "else 2 end) " +
                    "group by t.trip_id " +
                    "order by a.departure_time ";

                var routes = await db.query(routeQuery, [stop1, stop2]);

                console.log("Get route from " + stop1 + " to " + stop2 + " :: Found routes :: " + routes.length);

                if (routes.length > 0) {
                    for (var k = 0; k < routes.length; k++) {
                        var tripId = routes[k].trip_id;
                        var routeStopsQuery = "SELECT st.stop_sequence, s.* FROM stops s " +
                            "left join stop_times st on st.stop_id = s.stop_id " +
                            "WHERE trip_id = ?  " +
                            "AND st.stop_sequence between (SELECT st.stop_sequence FROM stops s " +
                            "left join stop_times st on st.stop_id = s.stop_id " +
                            "WHERE st.stop_id = ? and trip_id = ? ) and (SELECT st.stop_sequence FROM stops s " +
                            "left join stop_times st on st.stop_id = s.stop_id " +
                            "WHERE st.stop_id = ? and trip_id = ?) " +
                            "ORDER BY stop_sequence asc";
                        var routeStops = await db.query(routeStopsQuery, [tripId, stop1, tripId, stop2, tripId]);
                        routes[k]['stops'] = routeStops;

                        var routePolylines=[];
                        for(var l = 0; l < routeStops.length - 1; l++) {
                            var originStop = routeStops[l].stop_lat + "," + routeStops[l].stop_lon;
                            var destStop = routeStops[l+1].stop_lat + "," + routeStops[l+1].stop_lon;
                            
                            var googleUrl = config.google.directions.url + util.format('?origin=%s&destination=%s&mode=driving&key=%s', originStop, destStop, config.google.apikey);
                            var polylineResult = await commons.fetchDataFromCache(originStop, destStop, "polyline_path", "polyline_json", googleUrl);
                            var polyline = JSON.parse(polylineResult);
                            polyline = polyline.routes[0].overview_polyline.points;
                            
                            //var polyline = await getPath.fetchPolylinePath(originStop, destStop);
                            if(polyline)
                                routePolylines.push(polyline);
                        }
                        routes[k]['polylines'] = routePolylines;
                    } //for routes
                }//if routes
                
                result.push({origin, destination, routes});
                
            } //for dest
        }// for origin
        
        res.send(result);
        
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get directions \n' + ex);
        res.send(ex);
    } finally {
        await db.close();
    }

}

module.exports.getBusRoutes = getBusRoutes