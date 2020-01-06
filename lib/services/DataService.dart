import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:routing/models/BusRoutesJSON.dart';
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

  Future<List<BusRoutesJSON>> fetchRoutes(LatLng origin, LatLng destination) async {
    String params = "?originlat=" +
        origin.latitude.toString() +
        '&originlon=' +
        origin.longitude.toString() +
        '&destlat=' +
        destination.latitude.toString() +
        '&destlon=' +
        destination.longitude.toString();

    //https://missfarukh.com/server_functions/getRoutes.php?originlat=40.76012279512181&originlon=29.922576919198036&destlat=40.824600&destlon=29.919007
    var url = 'https://missfarukh.com/server_functions/getRoutes.php$params';
              
    print("Fetching routes from - " + url);

    List<dynamic> routesJSON;
    List<BusRoutesJSON> busRoutes = [];
    try {
      Response response = await Dio().get(url);
      if (response.statusCode == 200) {
        routesJSON = jsonDecode(response.data);

        if (routesJSON.isNotEmpty) {
          print("Routes received :: " + routesJSON.length.toString());
          busRoutes = routesJSON.map((i) => BusRoutesJSON.fromJson(i)).toList();
        }
      } else {
        print("No bus routes found");
      }
    } catch (exception) {
      print(exception);
    }
    return busRoutes;
  }
}
