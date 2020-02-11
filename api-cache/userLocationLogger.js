const commons = require('./commons');

async function logCurrentLocation(req, res, next) {

    try {

        var params = req.query;
        userId = params.userId; 
        currentLocation = params.currentLocation; 
        origin = params.origin; 
        destination = params.destination; 

        var initSql = "CREATE TABLE IF NOT EXISTS user_location_history (" + 
            " id INT(6) UNSIGNED AUTO_INCREMENT PRIMARY KEY, " +
            " userId, VARCHAR(100), " + 
            " currentLocation VARCHAR(100), " + 
            " origin VARCHAR(100), " + 
            " destination VARCHAR(100), " + 
            " timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP " +
            ");";
            
        commons.pool.query(initSql);
        
        var insertSQL = `INSERT INTO user_location_history (userId, currentLocation, origin, destination) VALUES (` + 
            `'${userId}', ` +
            `'${currentLocation}', ` +
            `'${origin}', ` +
            `'${destination}');`; 

        commons.query(insertSQL);

        res.send('OK');
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to log user location \n' + ex);
        res.send(ex);
    }

}

module.exports.logCurrentLocation = logCurrentLocation