const util = require('util');
const config = require('./config');
const commons = require('./commons');

async function httpAnalyze(req, res, next) {

    try {
        var params = req.query;

        console.log('*******************START analyze request******************************************************');
        var result = await analyze();
        console.log('********************Complete analyze request*****************************************************');
        res.send(result);
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to analyze \n' + ex);
        res.send(ex);
    }

}

async function analyze() {
    return new Promise(async (resolve, reject) => {
        var result = '';
        try {

            var spawn = require('child_process').spawn,
                py = spawn(config.python.path + 'python', [require.resolve("../collab/get_routes_ratings_per_cluster.py")]);

            py.stdout.on('data', function (data) {
                //console.log("update cluster --- " + data.toString());
                result = data.toString();
            });
            py.stdout.on('end', async function () {
                console.log("send back " + result);
                resolve(result);
            });
            py.stdin.end();
        } catch (ex) {
            console.error('Unexpected exception occurred when trying to cluster registered users \n' + ex);
            reject(ex);
        }
    });
}

module.exports.httpAnalyze = httpAnalyze;