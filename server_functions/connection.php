<?php

    $conn = new mysqli("localhost", "wheelchair_routing", "em6Wgu<S;^J*xP?g%.", "wheelchair_routing");

    if ($conn->connect_error) {
 
        die("Connection failed: " . $conn->connect_error);
    } else {
        mysqli_set_charset($conn, 'utf8');
    }
?> 
