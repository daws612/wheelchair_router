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
        var firebaseId = params.userid;

        console.log('*************************************************************************');
        console.log('\START recommendation request');
        // http://192.168.43.238:9595/getbusroutes?originlat=40.822751499999995&originlon=29.928360400000003&destlat=40.8242364&destlon=29.918173300000007&userid=2DFDoUKhDcZ5msfoLf2fPggYL1j1
        var result = await getRecommendation(originlat, originlon, destlat, destlon, firebaseId);
        console.log('\nComplete recommendation request');
        console.log('*************************************************************************');
        res.send(result);
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get recommendation \n' + ex);
        res.send(ex);
    }

}

async function getRecommendation(originlat, originlon, destlat, destlon, firebaseId) {
    return new Promise(async (resolve, reject) => {
        try {
            var result = { busRoutes: [], walkingDirections: [] };

            var spawn = require('child_process').spawn,
                py = spawn('python', [require.resolve("../collab/get_cluster_users.py")]),
                userid = (!firebaseId) ? '' : firebaseId,
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
        } catch (ex) {
            console.error('Unexpected exception occurred when trying to cluster registered users \n' + ex);
            reject(ex);
        }
    });
}

async function getTopRatedRoutes(originlat, originlon, destlat, destlon, cluster_userids) {
    var response = { busRoutes: [], walkingDirections: [] };
    var radius = 100;
    var min_score = 3;
    var recommendations = [];
    console.log('------------cluster users: ' + cluster_userids);
    var routeSql = `call izmit.getRecommendedRoutes($1, $2, $3, $4, $5, $6, $7, $8);`;

    //http://localhost:9595/getbusroutes?originlat=40.8227515&originlon=29.9283604&destlat=40.8243215&destlon=29.9185689&userid=2DFDoUKhDcZ5msfoLf2fPggYL1j1
    
    //http://localhost:9595/getrecommendation?originlat=40.8227515&originlon=29.9283604&destlat=40.8243215&destlon=29.9185689&userid=2DFDoUKhDcZ5msfoLf2fPggYL1j1
    
    //call izmit.getRecommendedRoutes(40.8227515, 29.9283604, 40.8243215, 29.9185689, 100, 1, '82,83 ', null);
    var results = await commons.pgPool.query(routeSql, [originlat, originlon, destlat, destlon, radius, min_score, cluster_userids, recommendations]);

    if (results.rows && results.rows.length > 0) {
        console.log(results.rows);
        recommendations = results.rows[0].rec;
        response = reconstructRoutes(recommendations);
    }
    return response;

}

async function reconstructRoutes(routeIds) {
    var response = { busRoutes: [], walkingDirections: [] };

    if (!routeIds || routeIds.length < 1)
        return response;

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
        return result;
    }
}

module.exports.httpGetRecommendation = httpGetRecommendation;
module.exports.getRecommendation = getRecommendation;