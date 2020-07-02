const util = require('util');
const config = require('./config');
const mysql = require('mysql');
var restify_clients = require('restify-clients');
const getElevation = require('./getElevation');
const pgRoute = require('./pgRoute');
const PGPool = require('pg').Pool;

const pgPool = new PGPool({
    user: config.schema.user,
    host: config.schema.host,
    database: config.schema.db,
    password: config.schema.password,
    port: 5432,
});

// var pool = mysql.createPool({
//     connectionLimit: 100,
//     host: config.schema.host,
//     user: config.schema.user,
//     password: config.schema.password,
//     database: config.schema.db
// });


// Ping database to check for common exception errors.
// pgPool.getConnection((err, connection) => {
//     if (err) {
//         if (err.code === 'PROTOCOL_CONNECTION_LOST') {
//             console.error('Database connection was closed.')
//         }
//         if (err.code === 'ER_CON_COUNT_ERROR') {
//             console.error('Database has too many connections.')
//         }
//         if (err.code === 'ECONNREFUSED') {
//             console.error('Database connection was refused.')
//         }
//     }

//     if (connection) connection.release()

//     return
// });

// Promisify for Node.js async/await.
pgPool.query = util.promisify(pgPool.query);

client = restify_clients.createJsonClient({
    url: config.google.directions.url,
    //version: '~1.0'
    retry: false,
    connectTimeout: 3000,
    requestTimeout: 3000,
});

client.on('error', function (err) {
    console.log("Error " + err);
});

function fetchFromGoogle(origin, destination, googleUrl, tableName, fieldName, directionsMode) {
    return new Promise(async (resolve, reject) => {

        try {

            client.get(googleUrl, async function (cerr, creq, cres, cobj) {

                if (cobj == undefined) {
                    console.error('Google Directions API call did not return successfully. Something is wrong', + cerr);
                    resolve('');
                    return;
                }

                console.log(util.format('Successfully returned from google api %s \n', googleUrl));

                await saveCacheData(origin, destination, cobj, tableName, fieldName, directionsMode);
                //resolve(JSON.stringify(cobj));
                resolve(cobj);
            });

        } catch (ex) {
            console.error('Unexpected exception occurred when trying to fetch from google api \n' + ex);
            reject(ex);
        }
    });
}

function fetchDataFromCache(origin, destination, tableName, fieldName, googleUrl, directionsMode) {
    try {

        return new Promise(async (resolve, reject) => {
            var sqlQuery;
            if (fieldName === "polyline_json")
                sqlQuery = util.format("SELECT id, %s FROM %s WHERE origin = '%s' AND destination = '%s' and mode = '%s'", fieldName, "izmit." + tableName, origin, destination, directionsMode);
            else
                sqlQuery = util.format("SELECT id, %s FROM %s WHERE origin = '%s' AND destination = '%s'", fieldName, "izmit." + tableName, origin, destination);
            var queryResult = await pgPool.query(sqlQuery);
            if (queryResult.rowCount === 0) {
                resolve(fetchFromGoogle(origin, destination, googleUrl, "izmit." + tableName, fieldName, directionsMode));
            } else {
                if (fieldName === "polyline_json")
                    resolve(queryResult.rows[0].polyline_json);
                else if (fieldName === "elevation_json") {
                    if (queryResult.rows[0].elevation_json == "null") {
                        await pgPool.query(util.format("DELETE FROM %s WHERE origin = '%s' AND destination = '%s'", "izmit." + tableName, origin, destination));
                        resolve(fetchFromGoogle(origin, destination, googleUrl, "izmit." + tableName, fieldName, directionsMode));
                    } else
                        resolve(queryResult.rows[0].elevation_json)
                }
                else
                    resolve(queryResult.rows);

            }
        });

    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get directions \n' + ex);
    }
}

async function saveCacheData(origin, destination, cobj, tableName, fieldName, directionsMode) {

    //util.format('?origin=%s&destination=%s&mode=driving&key=%s', origin, destination, config.google.apikey);
    var sqlQuery;
    if (fieldName === "polyline_json")
        sqlQuery = util.format("INSERT INTO %s(origin,destination,%s,mode) VALUES($1,$2,$3,'%s')", tableName, fieldName, directionsMode);
    else {
        if (cobj.status === "OK")
            sqlQuery = util.format("INSERT INTO %s(origin,destination,%s) VALUES($1,$2,$3)", tableName, fieldName);
        else
            return;
    }
    await pgPool.query(sqlQuery, [origin, destination, cobj]);

}

async function getSidewalkOrWalkingDirections(originlat, originlon, destlat, destlon, firebaseId) {

    var originHttp = originlat + "," + originlon;
    var destinationHttp = destlat + "," + destlon;

    //console.log("Get sidewalk directions.");
    var sidewalkDirs = await pgRoute.getSidewalkDirections(originlat, originlon, destlat, destlon, firebaseId);
    if (sidewalkDirs === 'undefined' || sidewalkDirs.length == 0) {
        console.log("No sidewalk route found.");
        var walkingDirections = await getElevation.getWalkingDirections(originHttp, destinationHttp, false, firebaseId);
        if (walkingDirections === 'undefined' || walkingDirections.length == 0)
            console.log("No walking directions found");
        else
            console.log("Return walking route");
        return walkingDirections;
    } else {
        console.log("Return sidewalk route");
        return sidewalkDirs;
    }
}

async function saveRouteInfo(originlat, originlon, destlat, destlon, routeName, trip_id) {
    //Save to db if first time queried
    //insert route details
    var route = "INSERT INTO izmit.routes(orig_lat, orig_lon, dest_lat, dest_lon, route_name, distance, trip_id) values( " +
        "$1, $2, " +
        "$3, $4, $5, " +
        "ST_Distance( " +
        " ST_SetSRID(ST_MakePoint($2, $1), 4326), " +
        "ST_SetSRID(ST_MakePoint($4, $3), 4326), " +
        "true " +
        "), $6 " +
        ") ON CONFLICT (orig_lat, orig_lon, dest_lat, dest_lon, route_name) DO NOTHING RETURNING route_id ;";

    var routeid = await pgPool.query(route, [+originlat, +originlon, +destlat, +destlon, routeName, +trip_id]);
    if (routeid.rows.length < 1) {
        route = "SELECT route_id FROM izmit.routes " +
            " WHERE orig_lon = $1 AND orig_lat = $2 " +
            " AND dest_lon = $3 AND dest_lat = $4 AND route_name = $5"
        if (!trip_id) {
            route += " AND trip_id=$6"
            routeid = await pgPool.query(route, [originlon, originlat, destlon, destlat, routeName, trip_id]);
        }
        else
            routeid = await pgPool.query(route, [originlon, originlat, destlon, destlat, routeName]);

    }

    if (routeid.rowCount > 1)
        console.log("******More than one route returned**********");

    routeid = routeid.rows[0].route_id;

    return routeid;
}

async function fetchRouteSegmentsFromDB(originlat, originlon, destlat, destlon, routeName, firebaseId) {

    var result = [];
    if (!firebaseId) firebaseId = "test";

    var route = "SELECT r.route_id, coalesce(round(avg(rating),2),0) as rating FROM izmit.routes r " +
        " LEFT JOIN izmit.route_ratings rr ON r.route_id = rr.route_id " +
        " WHERE r.orig_lon = $1 AND r.orig_lat = $2 " +
        " AND r.dest_lon = $3 AND r.dest_lat = $4 AND route_name=$5  GROUP BY r.route_id;"
    var routeid = await pgPool.query(route, [originlon, originlat, destlon, destlat, routeName]);

    if (routeid.rowCount == 0)
        return result;

    var rating = +routeid.rows[0].rating;
    routeid = routeid.rows[0].route_id;

    var segmentsQu = "SELECT start_lat as y1, start_lon as x1, end_lat as y2, end_lon as x2, incline, length FROM izmit.route_segments rs " +
        " JOIN izmit.segments seg ON seg.segment_id = rs.segment_id " +
        " WHERE route_id = $1 " +
        " order by sequence;";

    var segments = await pgPool.query(segmentsQu, [routeid]);

    if (segments.rowCount == 0)
        return result;

    var response = formatResult(segments.rows, rating, routeid);
    if (response.pathData.length > 0)
        result.push(response);

    return result;
}

function formatResult(results, rating, routeid) {

    var path = [];
    var distance = 0;
    for (i = 0; i < results.length; i++) {
        var origin = { lat: results[i].y1, lng: results[i].x1 };
        var destination = { lat: results[i].y2, lng: results[i].x2 };
        var startElv = { location: origin, elevation: "", resolution: "" };
        var endElv = { location: destination, elevation: "", resolution: "" };

        var pathData = { origin: origin.lat + "," + origin.lng, destination: destination.lat + "," + destination.lng, elevation: [startElv, endElv], slope: results[i].incline };

        path.push(pathData);
        distance = distance + results[i]['length'];
    }

    //assuming speed is 1.4meters/sec
    var duration = distance / 1.4;

    var response = { polyline: "", pathData: path, distance: Math.ceil(distance), duration: Math.ceil(duration), rating: rating, dbRouteId: routeid };
    return response;
}

async function constructDirectRoute(dbRouteId) {

    var result = [];

    var route = "SELECT r.route_id, coalesce(round(avg(rating),2),0) as rating FROM izmit.routes r " +
        " LEFT JOIN izmit.route_ratings rr ON r.route_id = rr.route_id " +
        " WHERE r.route_id = $1 " +
        " GROUP BY r.route_id;"
    var routeid = await pgPool.query(route, [dbRouteId]);

    if (routeid.rowCount == 0)
        return result;

    var rating = +routeid.rows[0].rating;
    routeid = routeid.rows[0].route_id;

    var segmentsQu = "SELECT start_lat as y1, start_lon as x1, end_lat as y2, end_lon as x2, incline, length FROM izmit.route_segments rs " +
        " JOIN izmit.segments seg ON seg.segment_id = rs.segment_id " +
        " WHERE route_id = $1 " +
        " order by sequence;";

    var segments = await pgPool.query(segmentsQu, [routeid]);

    if (segments.rowCount == 0)
        return result;

    var response = formatResult(segments.rows, rating, routeid);
    if (response.pathData.length > 0)
        result.push(response);

    return result;
}

async function constructBusRoute(dbRouteIds, startStop, endStop, result) {
    var timeZone = "SET TIME ZONE 'Europe/Istanbul';"

    var routeQuery = `SELECT a.departure_time, b.arrival_time, r.*, t.*
    from trips t 
    left join routes r on t.route_id = r.route_id
    left join stop_times a on t.trip_id = a.trip_id and a.stop_id = $1 
    left join stop_times b on t.trip_id = b.trip_id and  b.stop_id = $2
    where t.route_id=(select route_id from trips where trip_id = (select trip_id::text from izmit.routes where route_id=$3))
    and t.service_id = (case when extract(dow from current_date) between 1 and 5 then '1'
                            when extract(dow from current_date) = 0 then '3' else '2' end)
    and a.departure_time > to_char(current_timestamp, 'HH24:MI:SS') 
    and a.departure_time < to_char(now()::time + INTERVAL '30 min', 'HH24:MI:SS') `

    await pgPool.query(timeZone);
    var routes = await pgPool.query(routeQuery, [startStop.stop_id, endStop.stop_id, dbRouteIds[0]]);
    routes = routes.rows;

    console.log("Get route from " + startStop.stop_id + " - " + startStop.stop_name + " to " + endStop.stop_id + " - " + endStop.stop_name + " :: Found routes :: " + routes.length);

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
            var routeStops = await pgPool.query(routeStopsQuery, [tripId, startStop.stop_id, tripId, endStop.stop_id, tripId]);
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
                var polylineResult = await fetchDataFromCache(originStop, destStop, "polyline_path", "polyline_json", googleUrl, "driving");
                var polyline = polylineResult; //JSON.parse(polylineResult);
                polyline = polyline.routes[0].overview_polyline.points;

                //var polyline = await getPath.fetchPolylinePath(originStop, destStop);
                if (polyline)
                    routePolylines.push(polyline);
            }
            routes[k]['polylines'] = routePolylines;

            //if stops are more than 1
            if (routeStops.length > 1) {

                var tofirstStop = await constructDirectRoute(dbRouteIds[1]);
                var fromLastStop = await constructDirectRoute(dbRouteIds[2]);
                console.log("Get walking route to first stop: " + routeStops[0].stop_name);
                routes[k]["toFirstStop"] = tofirstStop;


                console.log("Get walking route from last stop: " + routeStops[routeStops.length - 1].stop_name);
                routes[k]["fromLastStop"] = fromLastStop;
            }

            //get routing rate
            var route = "SELECT r.route_id,  coalesce(round(avg(rating),2),0) as rating FROM izmit.routes r " +
                " LEFT JOIN izmit.route_ratings rr ON r.route_id = rr.route_id " +
                " WHERE r.orig_lon = $1 AND r.orig_lat = $2 " +
                " AND r.dest_lon = $3 AND r.dest_lat = $4 AND route_name=$5 GROUP BY r.route_id;"
            var routeid = await pgPool.query(route, [startStop.stop_lon, startStop.stop_lat, endStop.stop_lon, endStop.stop_lat, "bus-" + routes[k].route_short_name]);

            var rating = 0;
            if (routeid.rowCount > 0)
                rating = +routeid.rows[0].rating;

            routes[k]["rating"] = rating;

            //save route in db for later rating reference
            routeid = await saveRouteInfo(startStop.stop_lat, startStop.stop_lon, endStop.stop_lat, endStop.stop_lon, "bus-" + routes[k].route_short_name, tripId);
            routes[k]["dbRouteId"] = routeid;
        } //for routes
    }//if routes
    if (routes.length > 0)
        result = result.concat(routes);

    return result;
}

//module.exports.pool = pool;
module.exports.fetchFromGoogle = fetchFromGoogle;
module.exports.fetchDataFromCache = fetchDataFromCache;
module.exports.getSidewalkOrWalkingDirections = getSidewalkOrWalkingDirections;
module.exports.saveRouteInfo = saveRouteInfo;
module.exports.pgPool = pgPool;
module.exports.fetchRouteSegmentsFromDB = fetchRouteSegmentsFromDB;
module.exports.formatResult = formatResult;
module.exports.constructBusRoute = constructBusRoute;
module.exports.constructDirectRoute = constructDirectRoute;