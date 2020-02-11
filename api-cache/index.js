var restify = require('restify');
var fs = require('fs');
const util = require('util');
const config = require('./config');
const getPath = require('./getPath');
const getRoutes = require('./getRoutes');
const getStops = require('./getStops');
const getElevation = require('./getElevation');
const userLocationLogger = require('./userLocationLogger');
const pgRoute = require('./pgRoute');
var logFileName = __dirname + '/api-cache.log';

var server = restify.createServer();
//server.use(restify.plugins.bodyParser()); //---Used for post
server.use(restify.plugins.queryParser());
server.get('/getpath', getPath.httpFetchPolylinePath);
server.get('/getbusroutes', getRoutes.performRouting);
server.get('/getbusstops', getStops.getBusStops);
server.get('/getelevation', getElevation.httpGetElevation);
server.get('/pgroute', pgRoute.pgRoute);
server.get('/userLocationLogger', userLocationLogger.logCurrentLocation);

//log to file
var logFile = fs.createWriteStream(logFileName, { flags: 'a' });
var logProxy = console.log;
console.log = function (d) {
    logFile.write((new Date().toLocaleString() + ' :: ' + d || '') + '\n');
    logProxy.apply(this, arguments);
};

console.error = console.log;

process.on('uncaughtException', function (err) {
    console.log(err.stack);
    throw err;
});

var cluster = require('cluster');

if (cluster.isMaster) {
    console.log('*************************************************************************');
    console.log('Starting up Server');
    console.log('*************************************************************************');
    console.log('Server is active. Forking workers now.');
    var cpuCount = 2; //use 2 workers for now. require('os').cpus().length;
    for (var i = 0; i < cpuCount; i++) {
        cluster.fork();
    }
    cluster.on('exit', function (worker) {
        console.error(util.format('Worker %s has died!', worker.id));
        console.log('Number of workers :: ' + Object.keys(cluster.workers).length);
    });
    cluster.on('disconnect', function (worker) {
        console.error(util.format('Worker %s has disconnected! Creating a new one.', worker.id));
        cluster.fork();
    });
}
else {

    server.listen(config.web.port, config.web.host, function (err) {
        if (err) {
            console.error('~~~~~~~~~~~~~~~~~');
            console.error(err);
            console.error('~~~~~~~~~~~~~~~~~');
        }
        else {
            console.log(util.format('%s listening at %s', server.name, server.url));
        }
    });

    console.log(`Worker ${process.pid} started`);

    
} 
