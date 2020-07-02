const util = require('util');
const config = require('./config');
const commons = require('./commons');

async function httpGetRecommendation(req, res, next) {

    try {
        var params = req.query;
        var originlat = +params.originlat;
        var originlon = +params.originlon;
        var destlat = +params.destlat;
        var destlon = +params.destlon;

        console.log('*************************************************************************');
        console.log('\START recommendation request');

        var result = await getRecommendation(originlat, originlon, destlat, destlon);
        console.log('\nComplete recommendation request');
        console.log('*************************************************************************');
        res.send(result);
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get recommendation \n' + ex);
        res.send(ex);
    }

}

async function getRecommendation(originlat, originlon, destlat, destlon) {
    return new Promise(async (resolve, reject) => {
        var result = [];

        var spawn = require('child_process').spawn,
            py = spawn('python', [require.resolve("../collab/kmeans-recommend.py")]),
            userid = 9990,
            cluster_userids = '';

        py.stdout.on('data', function (data) {
            console.log(data.toString());
            cluster_userids = data.toString();
        });
        py.stdout.on('end', async function () {
            console.log('No of users =', cluster_userids.split(',').length);
            result = await getTopRatedRoutes(originlat, originlon, destlat, destlon, cluster_userids);
            console.log("send back " + result);
            resolve(result);
        });
        py.stdin.write(JSON.stringify(userid));
        py.stdin.end();
    });
}

async function getTopRatedRoutes(originlat, originlon, destlat, destlon, cluster_userids) {
    var response = [];
    var radius = 100;
    var min_score = 2.3;
    var recommendations = [];
    var routeSql = `call izmit.getRecommendedRoutes($1, $2, $3, $4, $5, $6, $7);`;

    var results = await commons.pgPool.query(routeSql, [40.8227515, 29.9283604, 40.8243215, 29.9185689, radius, min_score, recommendations]);

    if (results.rows && results.rows.length > 0) {
        console.log(results.rows);
        recommendations = results.rows[0].rec;
        response = reconstructRoutes(recommendations);
    }
    return response;

}

async function reconstructRoutes(routeIds) {
    var response = { busRoutes: "", walkingDirections: "" };
    var busRoutes = [];
    var direct = []

    for (var i = 0; i < routeIds.length; i++) {
        //convert comma separated string to int array
        var dbRouteIds = routeIds[i].split(",").filter(x => x.trim().length && !isNaN(x)).map(Number);
        console.log("Reconstruct " + dbRouteIds);
        if (dbRouteIds.length == 3) {//is bus route. Bus, To, From
            busRoutes = await getBusRoute(dbRouteIds, busRoutes);
        } else {
            direct = await commons.constructDirectRoute(dbRouteIds[0]);
        }
    }

    response.busRoutes = busRoutes;
    response.walkingDirections = direct;
    return response;
}

async function getBusRoute(dbRouteIds, result) {
    try {
        //find start and end stop ids of this route
        var stopIdSQL = `SELECT *, ST_DistanceSphere( 
		st_point((select %s from izmit.routes where route_id=$1), (select %s from izmit.routes where route_id=$1)), 
		st_point(stop_lon,stop_lat) ) as dist_m
            FROM stops
            WHERE ST_DistanceSphere( 
		st_point((select %s from izmit.routes where route_id=$1), (select %s from izmit.routes where route_id=$1)), 
		st_point(stop_lon,stop_lat) ) < 10
            ORDER BY dist_m`;

        var firstStop = await commons.pgPool.query(util.format(stopIdSQL, 'orig_lon', 'orig_lat', 'orig_lon', 'orig_lat'), [dbRouteIds[0]]);
        var lastStop = await commons.pgPool.query(util.format(stopIdSQL, 'dest_lon', 'dest_lat', 'dest_lon', 'dest_lat'), [dbRouteIds[0]]);

        console.log("First Stop " + firstStop.rows[0].stop_id + " Last stop " + lastStop.rows[0].stop_id);
        result = await commons.constructBusRoute(dbRouteIds, firstStop.rows[0], lastStop.rows[0], result);

        return result;
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to reconstruct bus route \n' + ex);
        return;
    }
}

module.exports.httpGetRecommendation = httpGetRecommendation;