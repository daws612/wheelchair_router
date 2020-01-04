import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:routing/models/StopsJSON.dart';

class DataService {
  Future<List<StopsJSON>> fetchData(LatLngBounds bounds) async {
    String params = "?swlat=" +
        bounds.southwest.latitude.toString() +
        '&swlon=' +
        bounds.southwest.longitude.toString() +
        '&nelat=' +
        bounds.northeast.latitude.toString() +
        '&nelon=' +
        bounds.northeast.longitude.toString();

    //https://missfarukh.com/server_functions/getStops.php?swlat=40.81536520463702&swlon=29.921189546585083&nelat=40.84009957890793&nelon=29.940704964101315
    var url = 'https://missfarukh.com/server_functions/getStops.php$params';
    print("Fetching stops - " + url);

    List<dynamic> stopsJSON;
    List<StopsJSON> stops = [];
    try {
      Response response = await Dio().get(url);
      if (response.statusCode == 200) {
        stopsJSON = jsonDecode(response.data);

        if (stopsJSON.isNotEmpty) {
          print("Stops received :: " + stopsJSON.length.toString());
          stops = stopsJSON.map((i) => StopsJSON.fromJson(i)).toList();
        }
      }
    } catch (exception) {
      print(exception);
    }
    return stops;
  }
}
