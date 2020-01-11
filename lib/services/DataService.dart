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
    var url = 'http://192.168.43.238:9595/getbusstops$params';
    print("Fetching stops - " + url);

    List<dynamic> stopsJSON;
    List<StopsJSON> stops = [];
    try {
      Response response = await Dio().get(url);
      if (response.statusCode == 200) {
        stopsJSON = response.data;

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

  Future<List<RoutesJSON>> fetchRoutes(LatLng origin, LatLng destination) async {
    String params = "?originlat=" +
        origin.latitude.toString() +
        '&originlon=' +
        origin.longitude.toString() +
        '&destlat=' +
        destination.latitude.toString() +
        '&destlon=' +
        destination.longitude.toString();

    //https://missfarukh.com/server_functions/getRoutes.php?originlat=40.76012279512181&originlon=29.922576919198036&destlat=40.824600&destlon=29.919007
    //http://192.168.43.238:9595/getbusroutes?originlat=40.8191533&originlon=29.923916099999985&destlat=40.7656144&destlon=29.925500199999988
    var url = 'http://192.168.43.238:9595/getbusroutes$params';
              
    print("Fetching routes from - " + url);

    List<dynamic> routesJSON;
    List<RoutesJSON> busRoutes = [];
    try {
      Response response = await Dio().get(url);
      if (response.statusCode == 200) {
        routesJSON = response.data; //jsonDecode(response.data);

        if (routesJSON.isNotEmpty) {
          print("Routes received :: " + routesJSON.length.toString());
          int index = 0;
          busRoutes = routesJSON.map((i) => RoutesJSON.fromJson(i, index++)).toList();
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
