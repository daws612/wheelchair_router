const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();
const FieldValue = require('firebase-admin').firestore.FieldValue;

const googleMapsClient = require('@google/maps').createClient({
    key: 'AIzaSyByv2kxHAnj0FaZHUdqe6cb2MJbaZEeQsc'
});

// // Create and Deploy Your First Cloud Functions
// // https://firebase.google.com/docs/functions/write-firebase-functions
exports.helloWorld = functions.https.onRequest((request, response) => {
    response.send("Hello from Firebase!");
});

//localhost:8010/eventlogger-597d7/us-central1/getDirections?origin=40.763221,29.925132&destination=40.765618,29.925497
exports.getDirections = functions.https.onRequest((request, response) => {

    if (!request.query.origin || !request.query.destination)
        response.sendStatus(404);//("Invalid arguments")
    else
        app(request, response);
});

async function app(request, response) {
    var start = request.query.origin; //'40.763221, 29.925132'; //(40.821088, 29.926643);//(40.823665,29.925366);

    var end = request.query.destination; //'40.765618, 29.925497';//(40.820627, 29.923613); //(40.820791, 29.920961); //(40.820783,29.921082);

    var req = {
        origin: start,
        destination: end,
        mode: "walking",
        alternatives: true
    };

    googleMapsClient.directions(req, function (request, resp) {
        if (resp.status === 200) {
            var a = calculateSlope(req, resp).then((a) => {
                response.send(JSON.stringify(a));
                return true;
            }, err => {
                throw err;
            }).catch((reason) => {
                response.send("problem in got directions " + reason);
            });

        } else {
            console.log("Directions Request from " + start.toUrlValue(6) + " to " + end.toUrlValue(6) + " failed: " + status);
            response.send("problem in got directions");
        }
    });
}

async function calculateSlope(req, response) {
    return new Promise(function (resolve, reject) {

        var totalPoints = 0;
        for (var i = 0; i < response.json.routes.length; i++) {
            var polypoints = response.json.routes[i].overview_polyline.points;
            path = decode(polypoints);
            totalPoints = totalPoints + path.length - 1;
        }

        var receivedPath = 0;
        var slopes = [];
        for (var j = 0; j < response.json.routes.length; j++) {
            var path = [];
            var points = response.json.routes[j].overview_polyline.points;
            path = decode(points);
            for (var p = 0; p < path.length - 1; p++) {
                //get slope between these two points.
                displayLocationElevation(path[p], path[p + 1], p, j, function (err, slope, loc1, loc2, pathIndex, routeIndex, elv1, elv2) {
                    if (err) {
                        return reject(err);
                    }
                    receivedPath++;
                    if (slope === 0)
                        slope = 1;
                    if (slope === parseInt(slope, 10))
                        slope = Number((slope / 100).toFixed(2));
                    slopes.push({ loc1, loc2, slope, pathIndex, routeIndex, elv1, elv2 })
                    if (receivedPath >= totalPoints) {
                        resolve(createResponse(response.json.routes, slopes));
                    }
                });

            }//end path loop
        }//end routes loop
    });

}

function createResponse(routes, slopes) {
    var response = [];
    for (var routeIndex = 0; routeIndex < routes.length; routeIndex++) {
        var route = routes[routeIndex];
        var slopeOfRoute = [];
        for (var slopeIndex = 0; slopeIndex < slopes.length; slopeIndex++) {
            if (slopes[slopeIndex].routeIndex === routeIndex) {
                slopeOfRoute.push(slopes[slopeIndex]);
            }
        }
        var routeTotalDistance = 0;
        for (var j = 0; j < route.legs.length; j++) {
            routeTotalDistance = route.legs[j].distance.value + routeTotalDistance;
        }
        slopeOfRoute.sort((a, b) => (a.pathIndex > b.pathIndex) ? 1 : -1)
        routeTotalDistance = (routeTotalDistance / 1000).toString() + " km";
        response.push({ routeIndex, routeTotalDistance, slopeOfRoute });
    }
    return response;

}

function displayLocationElevation(location1, location2, pathIndex, routeIndex, callback) {
    googleMapsClient.elevationAlongPath({
        samples: 2,
        path: [location1, location2/*{ lat: location1.latitude, lng: location1.longitude }, 
        { lat: location2.latitude, lng: location2.longitude }*/]
    },
        function (err, elevationResponse) {
            if (elevationResponse.status === 200) {
                if (err) {
                    callback("error reported :: " + err);
                    return;
                }

                var run = getDistance(location1, location2);
                var rise = elevationResponse.json.results[1].elevation - elevationResponse.json.results[0].elevation; // if negative, down slope
                var slope = (rise / run) * 100.0;
                console.log(slope);
                callback(err, slope, location1, location2, pathIndex, routeIndex, elevationResponse.json.results[0].elevation, elevationResponse.json.results[1].elevation);
                return true;
                //req.send(JSON.stringify(elevationResponse));
            }

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

const firestore = admin.firestore();
const executeOnce = (change, context, task) => {
    const eventRef = firestore.collection('events').doc(context.eventId);

    return firestore.runTransaction(t =>
        t
            .get(eventRef)
            .then(docSnap => (docSnap.exists ? null : task(t)))
            .then(() => t.set(eventRef, { processed: true }))
    );
};

const documentCounter = collectionName => (change, context) =>
    executeOnce(change, context, t => {
        // on create
        if (!change.before.exists && change.after.exists) {
            return t
                .get(firestore.collection('metadatas')
                    .doc(collectionName))
                .then(docSnap =>
                    t.set(docSnap.ref, {
                        count: ((docSnap.data() && docSnap.data().count) || 0) + 1
                    }));
            // on delete
        } else if (change.before.exists && !change.after.exists) {
            return t
                .get(firestore.collection('metadatas')
                    .doc(collectionName))
                .then(docSnap =>
                    t.set(docSnap.ref, {
                        count: docSnap.data().count - 1
                    }));
        } else if(change.before.exists && change.after.exists){ //on update -- use to count all docs at once
            return firestore.collection(collectionName).get().then(function(querySnapshot) {
                return t
                    .get(firestore.collection('metadatas')
                        .doc(collectionName))
                    .then(docSnap =>
                        t.set(docSnap.ref, {
                            count: querySnapshot.docs.length
                        }));
            });
        }

        return null;
    });

/**
 * Count documents in customers collection.
 */
exports.stopsCounter = functions.firestore
    .document('stops/{stop_id}')
    .onWrite(documentCounter('stops'));