<?php 

    include("connection.php");
    
    $swlat = $_GET['swlat']; //a
    $swlon = $_GET['swlon']; //b
    $nelat = $_GET['nelat']; //c
    $nelon = $_GET['nelon']; //d

    //$sql = "SELECT * FROM wheelchair_routing.stops LIMIT 10";
    /*$sql = "SELECT * FROM stops WHERE
                ($swlat < $nelat AND lat BETWEEN $swlat AND $nelat) OR ($nelat < $swlat AND lat BETWEEN $nelat AND $swlat)
                AND 
                ($swlon < $nelon AND lng BETWEEN $swlon AND $nelon) OR ($nelon < $swlon AND lng BETWEEN $nelon AND $swlon)*/
    
    $sql = "SELECT * FROM stops WHERE
            (CASE WHEN $swlat < $nelat
                    THEN stop_lat BETWEEN $swlat AND $nelat
                    ELSE stop_lat BETWEEN $nelat AND $swlat
            END) 
            AND
            (CASE WHEN $swlon < $nelon
                    THEN stop_lon BETWEEN $swlon AND $nelon
                    ELSE stop_lon BETWEEN $nelon AND $swlon
            END)";
 
    $result = $conn->query($sql);
    
    if ($result->num_rows >0) {
    
        while($row[] = $result->fetch_assoc()) {
        
            $item = $row;
            
            $json = json_encode($item);
        
        }
    
    } else {
        //echo "No Data Found.";
        $json= json_encode([]);
    }
    //header('Content-Type: application/json');
    echo $json;
    $conn->close();
 ?>
