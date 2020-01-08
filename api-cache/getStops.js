const util = require('util');
const mysql = require('mysql');
const config = require('./config');

function makeDb(config) {
    const connection = mysql.createConnection(config);

    return {
        query(sql, args) {
            return util.promisify(connection.query)
                .call(connection, sql, args);
        },
        close() {
            return util.promisify(connection.end).call(connection);
        }
    };
}

async function getBusStops(req, res, next) {

    const db = makeDb({
        host: config.schema.host,
        user: config.schema.user,
        password: config.schema.password,
        database: config.schema.db
    });
    var result = [];

    try {

        var params = req.query;
        swlat = params.swlat; //a
        swlon = params.swlon; //b
        nelat = params.nelat; //c
        nelon = params.nelon; //d

        var sql = "SELECT * FROM stops WHERE "+
            "(CASE WHEN ? < ? "+
                    "THEN stop_lat BETWEEN ? AND ? "+
                    "ELSE stop_lat BETWEEN ? AND ? "+
            "END)  "+
            "AND "+
            "(CASE WHEN ? < ? "+
                    "THEN stop_lon BETWEEN ? AND ? "+
                    "ELSE stop_lon BETWEEN ? AND ? "+
            "END)";

        var busStops = await db.query(sql, [swlat, nelat, swlat, nelat, nelat, swlat, swlon, nelon, swlon, nelon, nelon, swlon]);
        
        res.send(busStops);
        
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get directions \n' + ex);
        res.send(ex);
    } finally {
        await db.close();
    }

}

module.exports.getBusStops = getBusStops