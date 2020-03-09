const commons = require('./commons');

async function saveRating(req, res, next) {

    try{

        var body = req.body;
        var firebaseId = body.firebaseId;
        var ratingList = body.rating;

        for(var i=0; i<ratingList.length; i++) {
            var sql = "INSERT INTO izmit.route_ratings (user_id, route_id, rating) "+
            " VALUES((SELECT user_id FROM izmit.users WHERE firebase_id=$1), $2, $3) ";
            var result = await commons.pgPool.query(sql, [firebaseId, ratingList[i].dbRouteId, ratingList[i].rating]);
        }
        
        console.log(body);
        res.send("done");

    } catch (e) {
        console.log("Exception occurred when saving rating", e);
        res.send(e);
    }

}


module.exports.saveRating = saveRating;