const commons = require('./commons');

async function logCurrentLocation(req, res, next) {

    try {

        var params = req.query;
        userId = params.userId;
        currentLocation = params.currentLocation;
        origin = params.origin;
        destination = params.destination;


        // var initSql = "CREATE TABLE IF NOT EXISTS user_location_history (" + 
        //     " id INT(6) UNSIGNED AUTO_INCREMENT PRIMARY KEY, " +
        //     " userId VARCHAR(100), " + 
        //     " currentLocation VARCHAR(100), " + 
        //     " origin VARCHAR(100), " + 
        //     " destination VARCHAR(100), " + 
        //     " timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP " +
        //     ");";
        var initSql = `CREATE TABLE IF NOT EXISTS izmit.user_location_history
                        (
                        id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
                        user_id bigint,
                        current_location  character varying(255),
                        origin double precision NOT NULL,
                        destination double precision NOT NULL,
                        polyline_json json NOT NULL,
                        CONSTRAINT user_location_history_pkey PRIMARY KEY (id)
                        )
                        WITH (
                            OIDS = FALSE
                        )
                        TABLESPACE pg_default;`;

        commons.pgPool.query(initSql);

        var insertSQL = `INSERT INTO izmit.user_location_history (user_id, current_location, origin, destination) VALUES (` +
            `'${userId}', ` +
            `'${currentLocation}', ` +
            `'${origin}', ` +
            `'${destination}');`;

        commons.pgPool.query(insertSQL);

        res.send('OK');
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to log user location \n' + ex);
        res.send(ex);
    }

}

module.exports.logCurrentLocation = logCurrentLocation