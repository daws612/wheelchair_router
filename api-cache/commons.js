const util = require('util');
const config = require('./config');
const mysql = require('mysql');
var restify_clients = require('restify-clients');

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

client = restify_clients.createJsonClient({
    url: config.google.directions.url,
    //version: '~1.0'
    retry: false,
    connectTimeout: 3000,
    requestTimeout: 3000,
});

client.on('error', function (err) {
    console.log("Error " + err);
});

function fetchFromGoogle(origin, destination, googleUrl, tableName, fieldName) {
    return new Promise(async (resolve, reject) => {

        try {

            client.get(googleUrl, async function (cerr, creq, cres, cobj) {

                if (cobj == undefined) {
                    console.error('Google Directions API call did not return successfully. Something is wrong');
                    resolve('');
                }

                console.log(util.format('Successfully returned from google api %s \n', googleUrl));

                await saveCacheData(origin, destination, cobj, tableName, fieldName);
                resolve(JSON.stringify(cobj));
            });

        } catch (ex) {
            console.error('Unexpected exception occurred when trying to fetch from google api \n' + ex);
            return ex;
        }
    });
}

function fetchDataFromCache(origin, destination, tableName, fieldName, googleUrl) {
    try {
        const mysqlConn = makeDb({
            host: config.schema.host,
            user: config.schema.user,
            password: config.schema.password,
            database: config.schema.db
        });
        return new Promise(async (resolve, reject) => {
            var sqlQuery = util.format('SELECT id, %s FROM %s WHERE origin = "%s" AND destination = "%s"', fieldName, tableName, origin, destination);
            var queryResult = await mysqlConn.query(sqlQuery);
            if (queryResult.length === 0) {
                resolve(fetchFromGoogle(origin, destination, googleUrl, tableName, fieldName));
            } else {
                if(fieldName === "polyline_json")
                    resolve(queryResult[0].polyline_json);
                else if(fieldName === "elevation_json")
                    resolve(queryResult[0].elevation_json)
                else
                    resolve(queryResult);
                mysqlConn.close();
            }
        });

    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get directions \n' + ex);
    }
}

async function saveCacheData(origin, destination, cobj, tableName, fieldName) {

    const mysqlConn = makeDb({
        host: config.schema.host,
        user: config.schema.user,
        password: config.schema.password,
        database: config.schema.db
    });
    //util.format('?origin=%s&destination=%s&mode=driving&key=%s', origin, destination, config.google.apikey);
    var sqlQuery = util.format('INSERT INTO %s(origin,destination,%s) VALUES(?,?,?)', tableName, fieldName);
    await mysqlConn.query(sqlQuery, [origin, destination, JSON.stringify(cobj)]);
    mysqlConn.close();
}

module.exports.makeDb = makeDb;
module.exports.fetchFromGoogle = fetchFromGoogle;
module.exports.fetchDataFromCache = fetchDataFromCache;