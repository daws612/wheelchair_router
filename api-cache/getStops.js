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
            "(CASE WHEN ? < ? " +
            "THEN stop_lat BETWEEN ? AND ? " +
            "ELSE stop_lat BETWEEN ? AND ? " +
            "END)  " +
            "AND " +
            "(CASE WHEN ? < ? " +
            "THEN stop_lon BETWEEN ? AND ? " +
            "ELSE stop_lon BETWEEN ? AND ? " +
            "END)";

        var busStops = await commons.pool.query(sql, [swlat, nelat, swlat, nelat, nelat, swlat, swlon, nelon, swlon, nelon, nelon, swlon]);

        res.send(busStops);

    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get directions \n' + ex);
        res.send(ex);
    }

}

module.exports.getBusStops = getBusStops