const getElevation = require('./getElevation');
const commons = require('./commons');

async function getSidewalkDirections(originlat, originlon, destlat, destlon, firebaseId) {
  return new Promise(async (resolve, reject) => {
    var result = await commons.fetchRouteSegmentsFromDB(originlat, originlon, destlat, destlon, "sidewalk", firebaseId);

    if(result.length > 0){
      resolve(result);
      return;
    }

    result = [];
    var query = " SELECT seq, node, edge, cost as cost, agg_cost, rd.wkb_geometry, accessible, x1, y1, x2, y2, coalesce(incline, 0) as incline " +
      "FROM pgr_dijkstra( " +
      "'SELECT  edges.id, " +
      "edges.source::bigint, edges.target::bigint, " +
      //"cost_len AS cost " +
      "st_length(wkb_geometry, true) AS cost " +
      "FROM izmit.izmit_noded as edges', " +
      // "JOIN izmit.izmit AS original ON original.id = edges.old_id " +
      //"WHERE cost_len = 0', " +
      "(SELECT source " +
      "FROM izmit.izmit_noded " +
      "WHERE ST_Distance( " +
      "wkb_geometry, " +
      "ST_SetSRID(ST_MakePoint($1, $2), 4326), " +
      "true " +
      ") < 500 ORDER BY wkb_geometry <-> ST_SetSRID(ST_Point($1, $2),4326) ASC " +
      "LIMIT 1),  " +
      "(SELECT source " +
      "FROM izmit.izmit_noded  " +
      "WHERE ST_Distance( " +
      "wkb_geometry, " +
      "ST_SetSRID(ST_MakePoint($3, $4), 4326), " +
      "true " +
      ") < 500 ORDER BY wkb_geometry <-> ST_SetSRID(ST_Point($3, $4),4326) ASC LIMIT 1), false " +
      ") as pt " +
      "JOIN izmit.izmit_noded rd ON pt.edge = rd.id " +
      "JOIN izmit.izmit AS original ON original.id = rd.old_id;";

    commons.pgPool.query(query, [originlon, originlat, destlon, destlat], async (error, results) => {
      if (error) {
        reject(error);
        return;
      }

      await saveRouteInfo(originlat, originlon, destlat, destlon, results);

      var response = await commons.fetchRouteSegmentsFromDB(originlat, originlon, destlat, destlon, "sidewalk", firebaseId);
      if(response.length > 0){
        resolve(response);
        return;
      }
      resolve(result);
    });

  });
}

async function saveRouteInfo(originlat, originlon, destlat, destlon, results) {
  if(results.rows.length < 1)
    return;
  else
    results = results.rows;
  
  var routeid = await commons.saveRouteInfo(originlat, originlon, destlat, destlon, "sidewalk", null);

  //insert each row segment
  for (var i = 0; i < results.length; i++) {

    calc = await getElevation.calculateSlope(results[i].y1, results[i].x1, results[i].y2, results[i].x2);

    var proc = `CALL izmit.saveRouteInfo($1, $2, $3, $4, $5, $6, $7, $8)`;

    console.log("Add segment -- "+ i +" :: " + results[i].y1 + results[i].x1 + results[i].y2 + results[i].x2);
    await commons.pgPool.query(proc, [results[i].y1, results[i].x1, results[i].y2, results[i].x2, calc.slope, i, results[i].accessible, routeid]);
  }
}

async function pgRoute(req, res, next) {

  try {
    var params = req.query;
    var originlat = +params.originlat;
    var originlon = +params.originlon;
    var destlat = +params.destlat;
    var destlon = +params.destlon;

    var result = await getSidewalkDirections(originlat, originlon, destlat, destlon);
    console.log('\nComplete sidewalk directions request');
    console.log('*************************************************************************');
    res.send(result);

  } catch (ex) {
    console.error('Unexpected exception occurred when trying to get sidewalk directions \n' + ex);
    res.send(ex);
  }

}

module.exports.pgRoute = pgRoute;
module.exports.getSidewalkDirections = getSidewalkDirections;