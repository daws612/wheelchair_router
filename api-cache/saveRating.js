const commons = require('./commons');

async function saveRating(req, res, next) {

    try{

        var body = req.body;
        var firebaseId = body.firebaseId;
        var ratingList = body.rating;

        for(var i=0; i<ratingList.length; i++) {
            var sql = "INSERT INTO izmit.route_ratings (user_id, route_id, rating, route_sections, orig_lat, orig_lon, dest_lat, dest_lon) "+
            " VALUES((SELECT user_id FROM izmit.users WHERE firebase_id=$1), $2, $3, $4, $5, $6, $7, $8) ";
            var result = await commons.pgPool.query(sql, [firebaseId, ratingList[i].dbRouteId, ratingList[i].rating, 
                ratingList[i].routeSections, ratingList[i].origin.latitude, ratingList[i].origin.longitude, 
                ratingList[i].destination.latitude, ratingList[i].destination.longitude]);
        }
        
        console.log(body);
        res.send("done");

    } catch (e) {
        console.log("Exception occurred when saving rating", e);
        res.send(e);
    }

}


module.exports.saveRating = saveRating;