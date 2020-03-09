
const util = require('util');
const config = require('./config');
const commons = require('./commons');

async function httpGetElevation(req, res, next) {

    try {
        var params = req.query;
        var originHttp = params.origin;
        var destinationHttp = params.destination;


        var result = await getWalkingDirections(originHttp, destinationHttp, true);
        console.log('\nComplete elevation request');
        console.log('*************************************************************************');
        res.send(result);
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get elevation \n' + ex);
        res.send(ex);
    }

}

async function getWalkingDirections(originHttp, destinationHttp, allOptions) {
    return new Promise(async (resolve, reject) => {
        var result = [];

        var googleUrlDirections = config.google.directions.url + util.format('?origin=%s&destination=%s&mode=walking&alternatives=true&key=%s', originHttp, destinationHttp, config.google.apikey);

        var polyResults = await commons.fetchDataFromCache(originHttp, destinationHttp, "polyline_path", "polyline_json", googleUrlDirections, "walking");
        var polyline = JSON.parse(polyResults);
        if (polyline.routes.length === 0)
            resolve(result);

        console.log("Alternate walking routes found: " + polyline.routes.length);

        if (allOptions) {
            for (var poly = 0; poly < polyline.routes.length; poly++) {
                var dirs = await getElevation(originHttp, destinationHttp, polyline.routes[poly]);
                result = result.concat(dirs);
            }
        } else {
            var dirs = await getElevation(originHttp, destinationHttp, polyline.routes[0]);
            result = result.concat(dirs);
        }
        resolve(result);
    });
}

async function getElevation(originHttp, destinationHttp, route) {
    return new Promise(async (resolve, reject) => {
        var result = await commons.fetchRouteSegmentsFromDB(originHttp.split(',')[0], originHttp.split(',')[1], destinationHttp.split(',')[0], destinationHttp.split(',')[1], "walk");

        if (result.length > 0) {
            resolve(result);
            return;
        }

        result = { polyline: "", pathData: "", distance: "", duration: "", rating: 0, dbRouteId: "" };

        try {
            var legs = route.legs;
            var polyline = route.overview_polyline.points;

            //get the route from origin to destination
            //var polyline = await getPath.fetchPolylinePath(originHttp, destinationHttp);
            if (!polyline)
                reject({ error: "No polyline found" });

            //Calculate distance and duration in all legs of route
            var distance = 0;
            var duration = 0;
            for (var lg = 0; lg < legs.length; lg++) {
                distance += legs[lg].distance.value;
                duration += legs[lg].duration.value;
            }

            //decode the polyline to get the points on the route
            var path = decode(polyline);
            var routeid = await commons.saveRouteInfo(originHttp.split(',')[0], originHttp.split(',')[1], destinationHttp.split(',')[0], destinationHttp.split(',')[1], "walk");

            //get elevation between each 2 consecutive points on a path
            var pathData = [];
            console.log("Fetch elevation data for " + path.length + " points between " + originHttp + " and " + destinationHttp);
            for (var p = 0; p < path.length - 1; p++) {
                //console.log(" Get elevation for index " + p);
                var origin = path[p].latitude + "," + path[p].longitude;
                var destination = path[p + 1].latitude + "," + path[p + 1].longitude;

                // var googleUrlElevation = config.google.elevation.url + util.format('?path=%s|%s&samples=2&mode=walking&key=%s', origin, destination, config.google.apikey);
                // var elevResult = await commons.fetchDataFromCache(origin, destination, "elevation_path", "elevation_json", googleUrlElevation, "walking");
                // var elevation = JSON.parse(elevResult);

                // var run = getDistance(path[p], path[p + 1]);
                // var rise = elevation.results[1].elevation - elevation.results[0].elevation; // if negative, down slope
                // var slope = (rise / run) * 100.0;
                // if (slope === 0)
                //     slope = 0.01;

                var calc = await calculateSlope(path[p].latitude, path[p].longitude, path[p + 1].latitude, path[p + 1].longitude);

                var proc = `CALL izmit.saveRouteInfo($1, $2, $3, $4, $5, $6, $7, $8)`;

                console.log("Add segment -- " + i + " :: " + path[p].latitude + path[p].longitude + path[p + 1].latitude + path[p + 1].longitude);
                commons.pgPool.query(proc, [path[p].latitude, path[p].longitude, path[p + 1].latitude, path[p + 1].longitude, calc.slope, i, 0, routeid], (error, segments) => {
                    if (error) {
                        console.log(error);
                    }
                });

                elevation = calc.elevation.results;
                var slope = calc.slope;
                pathData.push({ origin, destination, elevation, slope });
            }

            result.polyline = polyline;
            result.pathData = pathData;
            result.distance = distance;
            result.duration = duration;
            result.routeid = routeid;

            //result.push({ polyline, pathData });

            resolve(result);
        } catch (ex) {
            console.error('Unexpected exception occurred when trying to get elevation \n' + ex);
            return ex;
        }
    });

}

async function calculateSlope(originlat, originlon, destinationlat, destinationlon) {
    try {
        var origin = originlat + "," + originlon;
        var destination = destinationlat + "," + destinationlon;

        var googleUrlElevation = config.google.elevation.url + util.format('?path=%s|%s&samples=2&mode=walking&key=%s', origin, destination, config.google.apikey);
        var elevResult = await commons.fetchDataFromCache(origin, destination, "elevation_path", "elevation_json", googleUrlElevation, "walking");
        var elevation = JSON.parse(elevResult);

        var run = getDistance(originlat, originlon, destinationlat, destinationlon);
        var rise = elevation.results[1].elevation - elevation.results[0].elevation; // if negative, down slope
        var slope = (rise / run) * 100.0;
        if (slope === 0)
            slope = 0.01;

        return { slope: slope, elevation: elevation };
    } catch (e) {
        console.log(e);
        return -1;
    }
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

var getDistance = function (p1Lat, p1Lon, p2Lat, p2Lon) {
    var R = 6378137; // Earth’s mean radius in meter
    var dLat = rad(p2Lat - p1Lat);
    var dLong = rad(p2Lon - p1Lon);
    var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(rad(p1Lat)) * Math.cos(rad(p2Lat)) *
        Math.sin(dLong / 2) * Math.sin(dLong / 2);
    var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    var d = R * c;
    return d; // returns the distance in meter
};

module.exports.httpGetElevation = httpGetElevation;
module.exports.getWalkingDirections = getWalkingDirections;
module.exports.calculateSlope = calculateSlope;

/*
CREATE TABLE `wheelchair_routing`.`elevation_path` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `origin` VARCHAR(255) NOT NULL,
  `destination` VARCHAR(255) NOT NULL,
  `elevation_json` JSON NOT NULL,
  PRIMARY KEY (`id`));
*/