const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const googleMapsClient = require('@google/maps').createClient({
    key: 'AIzaSyByv2kxHAnj0FaZHUdqe6cb2MJbaZEeQsc'
});

// // Create and Deploy Your First Cloud Functions
// // https://firebase.google.com/docs/functions/write-firebase-functions
//
exports.helloWorld = functions.https.onRequest((request, response) => {
    response.send("Hello from Firebase!");
});

exports.getDirections = functions.https.onRequest((request, response) => {

    //var directionsService = googleMapsClient.DirectionsService();
    var start = '40.763221, 29.925132'; //(40.821088, 29.926643);//(40.823665,29.925366);
    //var end = new google.maps.LatLng(38.334818, -181.884886);
    var end = '40.765618, 29.925497';//(40.820627, 29.923613); //(40.820791, 29.920961); //(40.820783,29.921082);
    var req = {
        origin: start,
        destination: end,
        mode: "walking",
        alternatives: true
    };

    googleMapsClient.directions(req, function (request, resp) {
        if (resp.status === 200) {
            calculateSlope(resp);
            response.send("got directions");

        } else {
            console.log("Directions Request from " + start.toUrlValue(6) + " to " + end.toUrlValue(6) + " failed: " + status);
            response.send("problem in got directions");
        }
    });
});

function calculateSlope(response, map) {

    for (var i = 0; i < response.json.routes.length; i++) {
        var path = [];
        var points = response.json.routes[i].overview_polyline.points;
        path = decode(points);
        for (var p = 0; p < path.length - 1; p++) {
            //get slope between these two points.
            displayLocationElevation(path[p], path[p + 1], p, i, function (slope, index, pathIndex) {


                //create path with the 2 points used to get elevation only
                var newPath = [];
                var pathOnPoint = response.routes[pathIndex].overview_path;
                for (var r = 0; r <= pathOnPoint.length; r++) {
                    if (r == index || r == index + 1) {
                        newPath.push(pathOnPoint[r]);
                        bounds.extend(pathOnPoint[r]);
                    }
                }
                var polylineOptions = {
                    path: newPath,
                    strokeColor: colorToUse,
                    strokeOpacity: 1,
                    strokeWeight: 4,
                    width: 15,
                    geodesic: true,
                    icons: [{
                        icon: lineSymbols[pathIndex],
                        offset: '0',
                        repeat: '20px'
                    }],
                };

                var stepPolyline = new google.maps.Polyline(polylineOptions);
                polylines.push(stepPolyline);
            });

        }//end path loop
    }//end routes loop

}


function displayLocationElevation(location1, location2, index, pathIndex, callback) {
    googleMapsClient.elevationAlongPath({
        locations: [location1, location2], function(err, response) {
            if (!err && response.status === 200) {
                return response.json.results
            }
        },
    });
    // elevator.getElevationForLocations({
    //     'locations': [location1, location2]
    // }, function (results, status) {
    //     if (status === 'OK') {
    //         // Retrieve the first result
    //         if (results[0]) {
    //             var run = google.maps.geometry.spherical.computeDistanceBetween(location1, location2);
    //             var rise = results[1].elevation - results[0].elevation; // if negative, down slope
    //             var slope = (rise / run) * 100.0;
    //             console.log(slope);
    //             callback(slope, index, pathIndex);
    //         } else {
    //             console.log('No results found');
    //             callback(-9999, index, pathIndex);
    //         }
    //     } else {
    //         console.log('Elevation service failed due to: ' + status);
    //         callback(-9999, index, pathIndex);
    //     }
    // });

}
// googleMapsClient.elevation({
//     locations: [{
//       lat: 40.71189,
//       lng: -111.96794
//     }, {
//       lat: 40.71189,
//       lng: -112.9679
//     }], (err, response) => {
//       if (!err && response.status === 200) {
//         return response.json.results
//       }
//   })

//   // returns:

//   [{ 
//     elevation: 1294.016723632812,
//     location: { lat: 40.71189, lng: -111.96794 },
//     resolution: 4.771975994110107
//   },
//   { 
//     elevation: 1551.623901367188,
//     location: { lat: 40.71189, lng: -112.9679 },
//     resolution: 9.543951988220215 
//   }]


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


        var dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;
        shift = 0;
        result = 0;
        do {
            b = encoded.charAt(index++).charCodeAt(0) - 63;
            result |= (b & 0x1f) << shift;
            shift += 5;
        } while (b >= 0x20);
        var dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        points.push({ latitude: (lat / 1E5), longitude: (lng / 1E5) })

    }
    return points
}