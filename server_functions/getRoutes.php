<?php 

    include("connection.php");
    
    $originlat = $_GET['originlat']; //a
    $originlon = $_GET['originlon']; //b
    $destlat = $_GET['destlat']; //c
    $destlon = $_GET['destlon']; //d
    
    //get nearest stops to the origin and destination
    $sql_origin = "SELECT *, 'origin' as stoptype,
            ST_Distance_Sphere(
                point($originlat, $originlon),
                point(stop_lat, stop_lon)
                ) as 'dist_m'
            FROM stops
            WHERE ST_Distance_Sphere(
                point($originlat, $originlon),
                point(stop_lat, stop_lon)
                ) < 200
            ORDER BY `dist_m`";
            
    $sql_dest = "SELECT *, 'destination' as stoptype,
            ST_Distance_Sphere(
                point($destlat, $destlon),
                point(stop_lat, stop_lon)
                ) as 'dist_m'
            FROM stops
            WHERE ST_Distance_Sphere(
                point($destlat, $destlon),
                point(stop_lat, stop_lon)
                ) < 200
            ORDER BY `dist_m`";
 
    $result_origin = $conn->query($sql_origin);
    $result_dest = $conn->query($sql_dest);
    
    $originArray;
    $destinationArray;
    $routeArray = [];
    if ($result_origin->num_rows >0 && $result_dest->num_rows > 0) {
        
        while($row[] = $result_origin->fetch_assoc()) {
        
        }
        $originArray=$row;
        
        while($destrow[] = $result_dest->fetch_assoc()) {
        
        }
        $destinationArray=$destrow;
        
        
        //For each origin, get routes to each destination
        foreach($originArray as $origin) {
            foreach($destinationArray as $destination) {
                if($origin === null || $destination === null)
                    continue;
                $stop1 = $origin['stop_id'];
                $stop2 = $destination['stop_id'];
                
                $sql_route = "SELECT t.route_id, t.trip_id, a.departure_time, b.arrival_time, t.*
                                from stop_times a, stop_times b 
                                left join trips t on t.trip_id=b.trip_id
                                where 
                                a.stop_id = $stop1
                                and b.stop_id = $stop2
                                and a.trip_id = b.trip_id
                                and a.departure_time between '07:00' and TIME(DATE_ADD('2019-01-06 07:00', INTERVAL 15 MINUTE))
                                and t.service_id = (case 
                                when dayofweek(current_date()) between 2 and 6 then 1
                                when dayofweek(current_date()) = 1 then 3
                                else 2 end)
                                group by t.trip_id
                                order by a.departure_time ";
                $result_route = $conn->query($sql_route);
                
                $routerow = [];
                $routeinfo = [];
                $routerow['origin'] = $stop1;
                $routerow['destination'] = $stop2;
                //array_push($routerow, array('origin' => $stop1, 'destination' => $stop2));
                if ($result_route->num_rows >0) {
                    $index = 0;
                    while($routeinfo[] = $result_route->fetch_assoc()) {
                        $tripId = $routeinfo[$index]['trip_id'];
                        //$sql_stops = "SELECT * FROM stops WHERE stop_id IN (SELECT DISTINCT stop_id FROM stop_times WHERE trip_id = $tripId ORDER BY stop_sequence asc);";
                        //The and clause is to get the stops in the route that are between origin and destination only
                        $sql_stops = "SELECT st.stop_sequence, s.* FROM stops s
                                        left join stop_times st on st.stop_id = s.stop_id
                                        WHERE trip_id = $tripId 
                                        AND st.stop_sequence between (SELECT st.stop_sequence FROM stops s
                                        left join stop_times st on st.stop_id = s.stop_id
                                        WHERE st.stop_id = $stop1 and trip_id = $tripId ) and (SELECT st.stop_sequence FROM stops s
                                        left join stop_times st on st.stop_id = s.stop_id
                                        WHERE st.stop_id = $stop2 and trip_id = $tripId)
                                        ORDER BY stop_sequence asc";
                        $result_stops = $conn->query($sql_stops);
                        $tripStops = [];
                        if ($result_stops->num_rows >0) {
                            while($tripStops[] = $result_stops->fetch_assoc()) {
                            }
                        }
                        $routeinfo[$index]['stops'] = $tripStops;
                        //array_push($routerow, array('stops' => $tripStops));
                        $index++;
                    }
                }
                $routerow['route'] = $routeinfo;
                array_push($routeArray, $routerow);
            }
        }
        
    
    } else {
        //echo "No Data Found.";
        $routeArray = [];
    }
    //header('Content-Type: application/json');
    echo json_encode($routeArray);
    $conn->close();
 ?>
