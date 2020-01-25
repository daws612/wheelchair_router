const config = require('./config');
const Pool = require('pg').Pool

const pool = new Pool({
  user: config.schema.user,
  host: config.schema.host,
  database: config.schema.db,
  password: config.schema.password,
  port: 5432,
});

async function pgRoute(req, res, next) {
    
    try{

        var query = "SELECT seq, node, edge, cost as cost, agg_cost, geom, x1, y1, x2, y2  " +
        "FROM pgr_astar( " +
        "'SELECT id, source, target, st_length(geom, true) as cost, x1, y1, x2, y2  FROM public.uni_noded', " +
        "44, 31, false) as pt " +
        "JOIN public.uni_noded rd ON pt.edge = rd.id";

        pool.query(query, (error, results) => {
            if (error) {
              throw error
            }
            res.send(results.rows)
          });
        
    }catch (ex) {
        console.error('Unexpected exception occurred when trying to get directions \n' + ex);
        res.send(ex);
    } 

}

module.exports.pgRoute = pgRoute;