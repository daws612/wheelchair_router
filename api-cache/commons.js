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
                    console.error('Google Directions API call did not return successfully. Something is wrong',  + cerr);
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

//module.exports.pool = pool;
module.exports.fetchFromGoogle = fetchFromGoogle;
module.exports.fetchDataFromCache = fetchDataFromCache;
module.exports.getSidewalkOrWalkingDirections = getSidewalkOrWalkingDirections;
module.exports.saveRouteInfo = saveRouteInfo;
module.exports.pgPool = pgPool;
module.exports.fetchRouteSegmentsFromDB = fetchRouteSegmentsFromDB;
module.exports.formatResult = formatResult;