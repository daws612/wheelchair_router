const util = require('util');
const config = require('./config');
const commons = require('./commons');

async function httpFetchPolylinePath(req, res, next) {
    try {
        var params = req.query;
        var origin = params.origin;
        var destination = params.destination;
        var googleUrl = config.google.directions.url + util.format('?origin=%s&destination=%s&mode=driving&key=%s', origin, destination, config.google.apikey);
        var result = await commons.fetchDataFromCache(origin, destination, "polyline_path", "polyline_json", googleUrl);
        res.send(JSON.parse(result));
    } catch (ex) {
        console.error('Unexpected exception occurred when trying to get directions \n' + ex);
    }
}

module.exports.httpFetchPolylinePath = httpFetchPolylinePath

/*
CREATE TABLE `wheelchair_routing`.`polyline_path` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `origin` VARCHAR(255) NOT NULL,
  `destination` VARCHAR(255) NOT NULL,
  `polyline_json` JSON NOT NULL,
  PRIMARY KEY (`id`));
*/