var restify_clients = require('restify-clients');
const util = require('util');
const config = require('./config');
var mysql = require('mysql');

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

function makeDb(config) {
    const connection = mysql.createConnection(config);

    return {
        query(sql, args) {
            return util.promisify(connection.query)
                .call(connection, sql, args);
        },
        close() {
            return util.promisify(connection.end).call(connection);
        }
    };
}

function fetchPolylineGoogle(origin, destination) {
    return new Promise(async (resolve, reject) => {

        try {

            //localhost:9595/getPath?origin=40.8187666,29.924751600000008&destination=40.76720229999999,29.93954629999999
            //https://maps.googleapis.com/maps/api/directions/json?origin=Disneyland&destination=Universal+Studios+Hollywood&key=YOUR_API_KEY
            var url = util.format('?origin=%s&destination=%s&mode=driving&key=%s', origin, destination, config.google.apikey);
    
            client.get(config.google.directions.url + url, function (cerr, creq, cres, cobj) {
                //assert.ifError(cerr);
                if (cobj == undefined || cobj.routes == undefined) {
                    console.error('API call did not return successfully. Something is wrong');
                    resolve('');
                }
    
                //console.log('Server returned: %j \n', cobj); //cres.body
                var points = cobj.routes[0].overview_polyline.points;
                console.log(util.format('API call returned routes %s \n', cobj.routes.length));
    
                //store data in mysql
                saveDirectionsData(origin, destination, cobj);
                resolve(cobj.routes[0].overview_polyline.points);
            });
    
        } catch (ex) {
            console.error('Unexpected exception occurred when trying to get directions \n' + ex);
            return ex;
        }
    });
}

function fetchPolylinePath(origin, destination) {
    try {
        const mysqlConn = makeDb({
            host: config.schema.host,
            user: config.schema.user,
            password: config.schema.password,
            database: config.schema.db
        });
        return new Promise(async (resolve, reject) => {
            var sqlQuery = util.format('SELECT id, polyline_json FROM polyline_path WHERE origin = "%s" AND destination = "%s"', (origin), (destination));
            var queryResult = await mysqlConn.query(sqlQuery);
            if (queryResult.length === 0) {
                resolve(fetchPolylineGoogle(origin, destination));
            } else {
                var line = JSON.parse(queryResult[0].polyline_json);
                resolve(line.routes[0].overview_polyline.points);
                mysqlConn.close();
            }
        });
        
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get directions \n' + ex);
    }
}

function httpFetchPolylinePath(req, res, next) {
    try {
        var params = req.query;
        var origin = params.origin;
        var destination = params.destination;
        var result = fetchPolylinePath(origin, destination);
        res.send(JSON.parse(result));
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get directions \n' + ex);
    }
}

function saveDirectionsData(origin, destination, cobj) {

    const mysqlConn = makeDb({
        host: config.schema.host,
        user: config.schema.user,
        password: config.schema.password,
        database: config.schema.db
    });
    var sqlQuery = 'INSERT INTO polyline_path(origin,destination,polyline_json) VALUES(?,?,?)';
    mysqlConn.query(sqlQuery, [origin, destination, JSON.stringify(cobj)], function (err, result, fields) {
        if (err) { mysqlConn.end(); throw err; };
        console.log("Successfully saved directions :: " + result);
    });
}

var rad = function (x) {
    return x * Math.PI / 180;
};

var getDistance = function (p1, p2) {
    var R = 6378137; // Earth’s mean radius in meter
    var dLat = rad(p2.latitude - p1.latitude);
    var dLong = rad(p2.longitude - p1.longitude);
    var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(rad(p1.latitude)) * Math.cos(rad(p2.latitude)) *
        Math.sin(dLong / 2) * Math.sin(dLong / 2);
    var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    var d = R * c;
    return d; // returns the distance in meter
};

// source: http://doublespringlabs.blogspot.com.br/2012/11/decoding-polylines-from-google-maps.html
function decode(encoded) {

    // array that holds the points

    var points = []
    var index = 0, len = encoded.length;
    var lat = 0, lng = 0;
    while (index < len) {
        var b, shift = 0, result = 0;
        do {

            b = encoded.charAt(index++).charCodeAt(0) - 63;//finds ascii                                                                                    //and substract it by 63
            result |= (b & 0x1f) << shift;
            shift += 5;
        } while (b >= 0x20);


        var dlat = ((result & 1) !== 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;
        shift = 0;
        result = 0;
        do {
            b = encoded.charAt(index++).charCodeAt(0) - 63;
            result |= (b & 0x1f) << shift;
            shift += 5;
        } while (b >= 0x20);
        var dlng = ((result & 1) !== 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        points.push({ latitude: (lat / 1E5), longitude: (lng / 1E5) })

    }
    return points
}

module.exports.httpFetchPolylinePath = httpFetchPolylinePath
module.exports.fetchPolylinePath = fetchPolylinePath

/*
CREATE TABLE `wheelchair_routing`.`polyline_path` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `origin` VARCHAR(255) NOT NULL,
  `destination` VARCHAR(255) NOT NULL,
  `polyline_json` JSON NOT NULL,
  PRIMARY KEY (`id`));
*/