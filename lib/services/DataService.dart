import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:routing/models/AllRoutesJSON.dart';
import 'package:routing/models/LocationJSON.dart';
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
    var url = 'https://***REMOVED***/wheelchair/getbusstops$params';
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

  Future<AllRoutesJSON> fetchRoutes(LatLng origin, LatLng destination) async {
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
    var url = 'https://***REMOVED***/wheelchair/getbusroutes$params';

    print("Fetching routes from - " + url);

    Map<String, dynamic> routesJSON;
    AllRoutesJSON allRoutes;
    try {
      Response response = await Dio().get(url);
      if (response.statusCode == 200) {
        routesJSON = response.data; //jsonDecode(response.data);

        if (routesJSON.isNotEmpty) {
          print("Routes received :: " + routesJSON.length.toString());
          allRoutes = AllRoutesJSON.fromJson(routesJSON);
        }
      } else {
        print("No bus routes found");
      }
    } catch (exception) {
      print(exception);
    }
    return allRoutes;
  }

  Future<WalkPathJSON> fetchPGRoutes(List<Marker> pgMarkers) async {
    //https://missfarukh.com/server_functions/getRoutes.php?originlat=40.76012279512181&originlon=29.922576919198036&destlat=40.824600&destlon=29.919007
    //http://192.168.43.238:9595/getbusroutes?originlat=40.8191533&originlon=29.923916099999985&destlat=40.7656144&destlon=29.925500199999988
    var url = "https://***REMOVED***/wheelchair/pgroute";

    print("Fetching routes from - " + url);

    List<dynamic> routesJSON;
    WalkPathJSON w;
    try {
      Response response = await Dio().get(url);
      if (response.statusCode == 200) {
        routesJSON = response.data; //jsonDecode(response.data);

        if (routesJSON.isNotEmpty) {
          print("PGRoutes received :: " + routesJSON.length.toString());

          List<PolylineJSON> path = [];
          routesJSON.forEach((dynamic route) {
            List<LocationJSON> loc = [];
            loc.add(new LocationJSON(
                latitude: route['y1'], longitude: route['x1']));
            loc.add(new LocationJSON(
                latitude: route['y2'], longitude: route['x2']));
            PolylineJSON p =
                new PolylineJSON(pathIndex: 0, slope: 0, location: loc);
            path.add(p);
          });
          w = new WalkPathJSON(
              routeIndex: 0, distanceM: 0, durationSec: 0, pathData: path);
        }
      } else {
        print("No pg routes found");
      }
    } catch (exception) {
      print(exception);
    }
    return w;
  }
}
