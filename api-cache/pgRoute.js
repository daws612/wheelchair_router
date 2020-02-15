const config = require('./config');
const Pool = require('pg').Pool

const pool = new Pool({
  user: config.schema.user,
  host: config.schema.host,
  database: config.schema.db,
  password: config.schema.password,
  port: 5432,
});

async function getSidewalkDirections(originlat, originlon, destlat, destlon) {
  return new Promise(async (resolve, reject) => {
    var result = [];
    var query = " SELECT seq, node, edge, cost as cost, agg_cost, rd.wkb_geometry, x1, y1, x2, y2, coalesce(incline, 0) as incline " +
      "FROM pgr_dijkstra( " +
      "'SELECT  edges.id, " +
      "edges.source::bigint, edges.target::bigint, " +
      "cost_len AS cost " +
      "FROM izmit.izmit_noded as edges JOIN izmit.izmit AS original ON original.id = edges.old_id " +
      "WHERE cost_len = 0', " +
      "(SELECT source " +
      "FROM izmit.izmit_noded " +
      "ORDER BY ST_Distance( " +
      "ST_StartPoint(ST_geometryn(wkb_geometry,1)), " +
      "ST_SetSRID(ST_MakePoint($1, $2), 4326), " +
      "true " +
      ") ASC " +
      "LIMIT 1),  " +
      "(SELECT source " +
      "FROM izmit.izmit_noded  " +
      "ORDER BY ST_Distance( " +
      "ST_StartPoint(ST_geometryn(wkb_geometry,1)), " +
      "ST_SetSRID(ST_MakePoint($3, $4), 4326), " +
      "true " +
      ") ASC LIMIT 1), false " +
      ") as pt " +
      "JOIN izmit.izmit_noded rd ON pt.edge = rd.id " +
      "JOIN izmit.izmit AS original ON original.id = rd.old_id;";

    pool.query(query, [originlon, originlat, destlon, destlat], (error, results) => {
      if (error) {
        reject(error);
      }
      var response = formatResult(results.rows);
      if(response.pathData.length > 0)
        result.push(response);
      resolve(result);
    });

  });
}

function formatResult(results){

  var path = [];
  for(i=0; i<results.length; i++) {
    var origin = {lat:results[i].y1 , lng:results[i].x1 };
    var destination = {lat:results[i].y2 , lng:results[i].x2 };
    var startElv = {location: origin, elevation:"", resolution:""};
    var endElv = {location: destination, elevation:"", resolution:""};
    
    var pathData = {origin: origin.lat+","+origin.lng, destination:destination.lat+","+destination.lng, elevation: [startElv, endElv], slope:results[i].incline};
    
    path.push(pathData);
  }
  
  var response = {polyline: "", pathData: path, distance:0, duration:0};
  return response;
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