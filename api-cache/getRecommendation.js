const util = require('util');
const config = require('./config');
const commons = require('./commons');

async function httpGetRecommendation(req, res, next) {

    try {
        var params = req.query;
        var originHttp = params.origin;
        var destinationHttp = params.destination;

        console.log('*************************************************************************');
        console.log('\START recommendation request');

        var result = await getRecommendation(originHttp, destinationHttp);
        console.log('\nComplete recommendation request');
        console.log('*************************************************************************');
        res.send(result);
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get recommendation \n' + ex);
        res.send(ex);
    }

}

async function getRecommendation(originHttp, destinationHttp, allOptions, firebaseId) {
    return new Promise(async (resolve, reject) => {
        var result = [];

        var spawn = require('child_process').spawn,
            py = spawn('python', ['../collab/kmeans-recommend.py']),
            userid = 9990,
            cluster_userids = [];

        py.stdout.on('data', function (data) {
            cluster_userids = data.toString();
        });
        py.stdout.on('end', function () {
            console.log('Sum of numbers=', cluster_userids.length);
        });
        py.stdin.write(JSON.stringify(userid));
        py.stdin.end();

        resolve(result);
    });
}

module.exports.httpGetRecommendation = httpGetRecommendation;