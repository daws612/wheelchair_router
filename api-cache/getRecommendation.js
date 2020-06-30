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

            resolve(result);
        });
        py.stdin.write(JSON.stringify(userid));
        py.stdin.end();
    });
}

async function getTopRatedRoutes(originlat, originlon, destlat, destlon, cluster_userids) {
    var routeSql = ``;

    commons.pgPool.query(routeSql, (error, results)=> {

    });
}

module.exports.httpGetRecommendation = httpGetRecommendation;