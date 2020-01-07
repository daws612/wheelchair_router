var geoHash = require('geo-hash');
var restify_clients = require('restify-clients');
const util = require('util');
const config = require('./config');
const saveSnappedToRedis = require('./saveSnappedToRedis');

var redis = require('redis'),
    client = redis.createClient(config.redis.port,config.redis.host)

// if an error occurs, print it to the console
client.on('error', function (err) {
    console.log("Error " + err);
});

var geoSnappedCoordinates = require('georedis').initialize(client, {
  zset: config.schema.name,
});

var geo_redis_options = {
  withCoordinates: true, // Will provide coordinates with locations, default false
  withDistances: true, // Will provide distance from query, default false
  order: 'ASC', // or 'DESC' or true (same as 'ASC'), default false
  units: 'm', // or 'km', 'mi', 'ft', default 'm'
  count: 1, // Number of results to return, default undefined
  accurate: true // Useful if in emulated mode and accuracy is important, default false
}

function redisSnapToRoads(req, res, next) {
    console.log('~~~~~~~~~~~~~~~~~~~START redisSnapToRoads~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    
    var data = getJsonData(req.body);
    
    var query = data;
    
    var lat = query.lat;
    var lng = query.lng;
      
    if(lat == undefined || lng == undefined){
        console.error('Error trying to snapToRoads. Latitude or Longitude must not be null');
        returnResultToClient(res);
    } else {
        makeDbCall(res, lat, lng, returnResultToClient);
    }
    
    next();
}

function getJsonData(body){
    var data;
    try {
        data = JSON.parse(body);
    } catch (e) {
        data = body; // if incoming request is a json, don't parse it
    }
    //console.log(data.query);
    return data;
}

function makeDbCall(res, lat, lng, callback){

    //Get geo hash of passed LatLng
    var hash = geoHash.encode(lat, lng);
    console.log('generated hash for lat,lng: ' + lat + ',' + lng + ' is :: ' + hash);

    //Search for the LatLng entry of this geohash in redis db
    geoSnappedCoordinates.nearby(hash, 10, geo_redis_options, function(err, locations){
        if(err) {
            
            //invoke Roads API and save the entry in redis db
            console.error("Error encountered while searching for nearby locations " + err)
            snapToRoads(lat, lng, callback, res);
            
        } else {
            
            //return the snapped values found in redis db
            console.log(util.format('nearby locations found:', locations))
            callback(res,locations);
            
      }
    });
    
}

function returnResultToClient(res,result,triggerGoogleAPI){
    
    var sendToClient;
    if(!result)
        sendToClient = {"success": false,
                        "triggerGoogleAPI": triggerGoogleAPI};
    else {
            sendToClient = {"success": true,
            "snappedLatitude": result[0].latitude,
            "snappedLongitude": result[0].longitude,
            "triggerGoogleAPI": triggerGoogleAPI
            }
        }
    console.log('~~~~~~~~~~~~~~~~~~~END redisSnapToRoads~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    //console.log(sendToClient);
    return res.send(sendToClient);
    
}

    client = restify_clients.createJsonClient({
        url: config.google.url,
        //version: '~1.0'
        retry: false,
        connectTimeout: 3000,
        requestTimeout: 3000,
    });

function snapToRoads(lat, lng, callback, res) {
    
    try {
        var url = util.format('?path=%s,%s&interpolate=true&key=%s', lat, lng, config.google.apikey);
        
        client.get(config.google.url + url, function(cerr, creq, cres, cobj) {
            //assert.ifError(cerr);
            if(cobj == undefined || cobj.snappedPoints == undefined) {
                console.error('API call did not return successfully. Something is wrong');
                callback(res, false, true);
                return;
            }

            //console.log('Server returned: %j \n', cobj); //cres.body
            var snappedLat= cobj.snappedPoints[0].location.latitude;
            var snappedLng= cobj.snappedPoints[0].location.longitude;
            console.log(util.format('API call returned Snapped Latitude %s and Longitude %s \n', snappedLat, snappedLng));
            
            saveSnappedToRedis.addLocationToRedis(res, lat, lng, snappedLat, snappedLng, null);
            
            //return the snapped coordinates without waiting for save
            var result = new Array();
            var point = new Object();
            point.latitude = snappedLat;
            point.longitude = snappedLng;
            result.push(point);
            callback(res, result);
        });
        
    } catch(ex) {
        console.error('Unexpected exception occurred when trying to snap coordinates\n' + ex);
    }
}

module.exports.redisSnapToRoads = redisSnapToRoads 