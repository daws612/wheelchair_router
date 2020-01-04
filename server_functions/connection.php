<?php

    $conn = new mysqli("localhost", "wheelchair_routing", "***REMOVED***", "wheelchair_routing");

    if ($conn->connect_error) {
 
        die("Connection failed: " . $conn->connect_error);
    } else {
        mysqli_set_charset($conn, 'utf8');
    }
?> 
