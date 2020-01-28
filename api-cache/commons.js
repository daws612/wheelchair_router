const util = require('util');
const config = require('./config');
const mysql = require('mysql');
var restify_clients = require('restify-clients');

var pool = mysql.createPool({
    connectionLimit: 100,
    host: config.schema.host,
    user: config.schema.user,
    password: config.schema.password,
    database: config.schema.db
});


// Ping database to check for common exception errors.
pool.getConnection((err, connection) => {
    if (err) {
        if (err.code === 'PROTOCOL_CONNECTION_LOST') {
            console.error('Database connection was closed.')
        }
        if (err.code === 'ER_CON_COUNT_ERROR') {
            console.error('Database has too many connections.')
        }
        if (err.code === 'ECONNREFUSED') {
            console.error('Database connection was refused.')
        }
    }

    if (connection) connection.release()

    return
});

// Promisify for Node.js async/await.
pool.query = util.promisify(pool.query);

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

function fetchFromGoogle(origin, destination, googleUrl, tableName, fieldName, directionsMode) {
    return new Promise(async (resolve, reject) => {

        try {

            client.get(googleUrl, async function (cerr, creq, cres, cobj) {

                if (cobj == undefined) {
                    console.error('Google Directions API call did not return successfully. Something is wrong');
                    resolve('');
                }

                console.log(util.format('Successfully returned from google api %s \n', googleUrl));

                await saveCacheData(origin, destination, cobj, tableName, fieldName, directionsMode);
                resolve(JSON.stringify(cobj));
            });

        } catch (ex) {
            console.error('Unexpected exception occurred when trying to fetch from google api \n' + ex);
            reject(ex);
        }
    });
}

function fetchDataFromCache(origin, destination, tableName, fieldName, googleUrl, directionsMode) {
    try {

        return new Promise(async (resolve, reject) => {
            var sqlQuery;
            if (fieldName === "polyline_json")
                sqlQuery = util.format('SELECT id, %s FROM %s WHERE origin = "%s" AND destination = "%s" and mode = "%s"', fieldName, tableName, origin, destination, directionsMode);
            else
                sqlQuery = util.format('SELECT id, %s FROM %s WHERE origin = "%s" AND destination = "%s"', fieldName, tableName, origin, destination);
            var queryResult = await pool.query(sqlQuery);
            if (queryResult.length === 0) {
                resolve(fetchFromGoogle(origin, destination, googleUrl, tableName, fieldName, directionsMode));
            } else {
                if (fieldName === "polyline_json")
                    resolve(queryResult[0].polyline_json);
                else if (fieldName === "elevation_json")
                    resolve(queryResult[0].elevation_json)
                else
                    resolve(queryResult);
                    
            }
        });

    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get directions \n' + ex);
    }
}

async function saveCacheData(origin, destination, cobj, tableName, fieldName, directionsMode) {

    //util.format('?origin=%s&destination=%s&mode=driving&key=%s', origin, destination, config.google.apikey);
    var sqlQuery;
    if (fieldName === "polyline_json")
        sqlQuery = util.format('INSERT INTO %s(origin,destination,%s,mode) VALUES(?,?,?,"%s")', tableName, fieldName, directionsMode);
    else
        sqlQuery = util.format('INSERT INTO %s(origin,destination,%s) VALUES(?,?,?)', tableName, fieldName);
    await pool.query(sqlQuery, [origin, destination, JSON.stringify(cobj)]);
    
}

module.exports.pool = pool;
module.exports.fetchFromGoogle = fetchFromGoogle;
module.exports.fetchDataFromCache = fetchDataFromCache;