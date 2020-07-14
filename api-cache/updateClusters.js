const util = require('util');
const config = require('./config');
const commons = require('./commons');

async function httpUpdateClusters(req, res, next) {

    try {
        var params = req.query;

        console.log('*******************START clustering request******************************************************');
        var result = await updateClusters();
        console.log('********************Complete clustering request*****************************************************');
        res.send(result);
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to cluster registered users \n' + ex);
        res.send(ex);
    }

}

async function updateClusters() {
    return new Promise(async (resolve, reject) => {
        var result = '';
        try {

            var spawn = require('child_process').spawn,
                py = spawn('python', [require.resolve("../collab/cluster_registered.py")]);

            py.stdout.on('data', function (data) {
                //console.log(data.toString());
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

module.exports.httpUpdateClusters = httpUpdateClusters;