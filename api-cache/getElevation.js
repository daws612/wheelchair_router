
const util = require('util');
const config = require('./config');
const commons = require('./commons');

async function httpGetElevation(req, res, next) {

    var result = [];

    try {
        var params = req.query;
        var originHttp = params.origin;
        var destinationHttp = params.destination;

        var result = await getElevation(originHttp, destinationHttp);
        res.send(result);
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get elevation \n' + ex);
        res.send(ex);
    }

}

async function getElevation(originHttp, destinationHttp) {
    return new Promise(async (resolve, reject) => {

        const db = commons.makeDb({
            host: config.schema.host,
            user: config.schema.user,
            password: config.schema.password,
            database: config.schema.db
        });
        var result = {polyline: "", pathData: ""};

        try {

            var googleUrlDirections = config.google.directions.url + util.format('?origin=%s&destination=%s&mode=walking&key=%s', originHttp, destinationHttp, config.google.apikey);

            var polyResults = await commons.fetchDataFromCache(originHttp, destinationHttp, "polyline_path", "polyline_json", googleUrlDirections, "walking");
            var polyline = JSON.parse(polyResults);
            if (polyline.routes.length === 0)
                resolve(result);
            polyline = polyline.routes[0].overview_polyline.points;

            //get the route from origin to destination
            //var polyline = await getPath.fetchPolylinePath(originHttp, destinationHttp);
            if (!polyline)
                res.send({ error: "No polyline found" });

            //decode the polyline to get the points on the route
            var path = decode(polyline);

            //get elevation between each 2 consecutive points on a path
            var pathData = [];
            console.log("Fetch elevation data for " + path.length + " points between " + originHttp + " and " + destinationHttp);
            for (var p = 0; p < path.length - 1; p++) {
                console.log(" Get elevation for index " + p);
                var origin = path[p].latitude + "," + path[p].longitude;
                var destination = path[p + 1].latitude + "," + path[p + 1].longitude;

                var googleUrlElevation = config.google.elevation.url + util.format('?path=%s|%s&samples=2&mode=walking&key=%s', origin, destination, config.google.apikey);
                var elevResult = await commons.fetchDataFromCache(origin, destination, "elevation_path", "elevation_json", googleUrlElevation, "walking");
                var elevation = JSON.parse(elevResult);

                var run = getDistance(path[p], path[p+1]);
                var rise = elevation.results[1].elevation - elevation.results[0].elevation; // if negative, down slope
                var slope = (rise / run) * 100.0;

                elevation = elevation.results;
                pathData.push({ origin, destination, elevation, slope });
            }

            result.polyline = polyline;
            result.pathData = pathData;

            //result.push({ polyline, pathData });

            resolve(result);
        } catch (ex) {
            console.error('Unexpected exception occurred when trying to get elevation \n' + ex);
            return ex;
        } finally {
            await db.close();
        }
    });

}
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

module.exports.httpGetElevation = httpGetElevation;
module.exports.getElevation = getElevation;

/*
CREATE TABLE `wheelchair_routing`.`elevation_path` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `origin` VARCHAR(255) NOT NULL,
  `destination` VARCHAR(255) NOT NULL,
  `elevation_json` JSON NOT NULL,
  PRIMARY KEY (`id`));
*/