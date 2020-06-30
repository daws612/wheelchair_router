const util = require('util');
const commons = require('./commons');

async function getBusStops(req, res, next) {

    try {

        var params = req.query;
        swlat = params.swlat; //a
        swlon = params.swlon; //b
        nelat = params.nelat; //c
        nelon = params.nelon; //d

        var sql = "SELECT * FROM stops WHERE " +
            "(CASE WHEN $1 < $2 " +
            "THEN stop_lat BETWEEN $3 AND $4 " +
            "ELSE stop_lat BETWEEN $5 AND $6 " +
            "END)  " +
            "AND " +
            "(CASE WHEN $7 < $8 " +
            "THEN stop_lon BETWEEN $9 AND $10 " +
            "ELSE stop_lon BETWEEN $11 AND $12 " +
            "END)";

        var busStops = await commons.pgPool.query(sql, [swlat, nelat, swlat, nelat, nelat, swlat, swlon, nelon, swlon, nelon, nelon, swlon]);

        res.send(busStops.rows);

    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get directions \n' + ex);
        res.send(ex);
    }

}

module.exports.getBusStops = getBusStops