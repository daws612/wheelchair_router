import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DataService {
  void fetchData(LatLngBounds bounds) async {

    String params = "?swlat=" +
        bounds.southwest.latitude.toString() +
        '&swlon=' +
        bounds.southwest.longitude.toString() +
        '&nelat=' +
        bounds.northeast.latitude.toString() +
        '&nelon=' +
        bounds.northeast.longitude.toString();

    //https://missfarukh.com/server_functions/getStops.php?swlat=40.81536520463702&swlon=29.921189546585083&nelat=40.84009957890793&nelon=29.940704964101315
    var url ='https://missfarukh.com/server_functions/getStops.php$params';
    print("Fetching stops - " + url);

    List<dynamic> stopsJSON;
    try {
      Response response = await Dio().get(url);
      if (response.statusCode == 200) {
        stopsJSON = jsonDecode(response.data);

        if (stopsJSON.isNotEmpty) {
          print("Stops received :: " + stopsJSON.length.toString());
        }
      }
    } catch (exception) {
      print(exception);
    }
  }
}