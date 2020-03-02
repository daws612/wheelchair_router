const config = require('./config');
const Pool = require('pg').Pool;
const getElevation = require('./getElevation');

const pool = new Pool({
  user: config.schema.user,
  host: config.schema.host,
  database: config.schema.db,
  password: config.schema.password,
  port: 5432,
});

async function getSidewalkDirections(originlat, originlon, destlat, destlon) {
  return new Promise(async (resolve, reject) => {
    var result = await fetchSidewalkFromDB(originlat, originlon, destlat, destlon);

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

    pool.query(query, [originlon, originlat, destlon, destlat], async (error, results) => {
      if (error) {
        reject(error);
        return;
      }

      await saveRouteInfo(originlat, originlon, destlat, destlon, results);

      var response = formatResult(results.rows);
      if (response.pathData.length > 0)
        result.push(response);
      resolve(result);
    });

  });
}

async function saveRouteInfo(originlat, originlon, destlat, destlon, results) {
  if(results.rows.length < 1)
    return;
  else
    results = results.rows;
  //Save to db if first time queried
  //insert route details
  var route = "INSERT INTO izmit.routes(orig_lat, orig_lon, dest_lat, dest_lon, distance) values( " +
    "$1, $2, " +
    "$3, $4, " +
    "ST_Distance( " +
    " ST_SetSRID(ST_MakePoint($2, $1), 4326), " +
    "ST_SetSRID(ST_MakePoint($4, $3), 4326), " +
    "true " +
    ") " +
    ") ON CONFLICT (orig_lat, orig_lon, dest_lat, dest_lon) DO NOTHING RETURNING route_id ;";

  var routeid = await pool.query(route, [originlat, originlon, destlat, destlon]);
  if(routeid.rows.length < 1) {
    route = "SELECT route_id FROM izmit.routes " +
    " WHERE orig_lon = $1 AND orig_lat = $2 " +
    " AND dest_lon = $3 AND dest_lat = $4;"
    routeid = await pool.query(route, [originlon, originlat, destlon, destlat]);
  }

  routeid = routeid.rows[0].route_id;

  //insert each row segment
  for (var i = 0; i < results.length; i++) {

    calc = await getElevation.calculateSlope(results[i].y1, results[i].x1, results[i].y2, results[i].x2);

    var proc = `CALL izmit.saveRouteInfo($1, $2, $3, $4, $5, $6, $7, $8)`;

    console.log("Add segment -- "+ i +" :: " + results[i].y1 + results[i].x1 + results[i].y2 + results[i].x2);
    pool.query(proc, [results[i].y1, results[i].x1, results[i].y2, results[i].x2, calc.slope, i, results[i].accessible, routeid], (error, segments) => {
      if (error) {
        console.log(error);
      }
    });

  }
}

async function fetchSidewalkFromDB(originlat, originlon, destlat, destlon) {

  var result = [];

  var route = "SELECT route_id FROM izmit.routes " +
    " WHERE orig_lon = $1 AND orig_lat = $2 " +
    " AND dest_lon = $3 AND dest_lat = $4;"
  var routeid = await pool.query(route, [originlon, originlat, destlon, destlat]);
  
  if(routeid.rowCount == 0)
    return result;

  routeid = routeid.rows[0].route_id;

  var segmentsQu = "SELECT start_lat as y1, start_lon as x1, end_lat as y2, end_lon as x2, incline, length FROM izmit.route_segments rs "+
  " JOIN izmit.segments seg ON seg.segment_id = rs.segment_id "+
  " WHERE route_id = $1 "+
  " order by sequence;";

  var segments = await pool.query(segmentsQu, [routeid]);

  var response = formatResult(segments.rows);
  if (response.pathData.length > 0)
    result.push(response);
  
  return result;
}

function formatResult(results) {

  var path = [];
  for (i = 0; i < results.length; i++) {
    var origin = { lat: results[i].y1, lng: results[i].x1 };
    var destination = { lat: results[i].y2, lng: results[i].x2 };
    var startElv = { location: origin, elevation: "", resolution: "" };
    var endElv = { location: destination, elevation: "", resolution: "" };

    var pathData = { origin: origin.lat + "," + origin.lng, destination: destination.lat + "," + destination.lng, elevation: [startElv, endElv], slope: results[i].incline };

    path.push(pathData);
  }

  var response = { polyline: "", pathData: path, distance: 0, duration: 0 };
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