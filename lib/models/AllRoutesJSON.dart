import 'package:routing/models/LocationJSON.dart';
import 'package:routing/models/StopsJSON.dart';

class RoutesWithRecommended {
  final List<WalkPathJSON> walkingDirections;
  final List<BusRoutesJSON> busRoutes;
  final AllRoutesJSON recommendations;

  RoutesWithRecommended({this.walkingDirections, this.busRoutes, this.recommendations});

  factory RoutesWithRecommended.fromJson(Map<String, dynamic> json) {
    if (json == null) return null;
    var walks = json['walkingDirections'] as List;
    var bus = json['busRoutes'] as List;
    int index = 0;
    return new RoutesWithRecommended(
      walkingDirections:
          walks.map((i) => WalkPathJSON.fromJson(i, index++)).toList(),
      busRoutes: bus.map((i) => BusRoutesJSON.fromJson(i, index++)).toList(),
      recommendations: AllRoutesJSON.fromJson(json['recommendations'], index),
    );
  }
}

class AllRoutesJSON {
  final List<WalkPathJSON> walkingDirections;
  final List<BusRoutesJSON> busRoutes;

  AllRoutesJSON({this.walkingDirections, this.busRoutes});

  factory AllRoutesJSON.fromJson(Map<String, dynamic> json, int index) {
    if (json == null) return null;
    var walks = json['walkingDirections'] as List;
    var bus = json['busRoutes'] as List;
    //int index = 0;
    return new AllRoutesJSON(
      walkingDirections:
          walks.map((i) => WalkPathJSON.fromJson(i, index++)).toList(),
      busRoutes: bus.map((i) => BusRoutesJSON.fromJson(i, index++)).toList(),
    );
  }
}

class BusRoutesJSON {
  final int routeIndex;
  final String routeId;
  final String routeShortName;
  final String routeLongName;
  final String tripId;
  final String departureTime;
  final String arrivalTime;
  final List<StopsJSON> stops;
  final List<String> polylines;
  final List<WalkPathJSON> toFirstStop;
  final List<WalkPathJSON> fromLastStop;
  double rating;
  final String dbRouteId;

  BusRoutesJSON(
      {this.routeIndex,
      this.routeId,
      this.routeShortName,
      this.routeLongName,
      this.tripId,
      this.departureTime,
      this.arrivalTime,
      this.stops,
      this.polylines,
      this.toFirstStop,
      this.fromLastStop,
      this.rating,
      this.dbRouteId});

  factory BusRoutesJSON.fromJson(Map<String, dynamic> json, int index) {
    if (json == null) return null;
    var stopsList = json['stops'] as List;
    var polys = json['polylines'] as List;
    var stop1List = json['toFirstStop'] as List;
    var stop2List = json['fromLastStop'] as List;
    int index1 = 0, index2 = 0;
    if(json['rating'] == null) 
      json['rating'] = 0;
    return new BusRoutesJSON(
      routeIndex: index,
      routeId: json['route_id'],
      routeShortName: json['route_short_name'],
      routeLongName: json['route_long_name'],
      tripId: json['trip_id'],
      departureTime: json['departure_time'],
      arrivalTime: json['arrival_time'],
      stops: stopsList.map((i) => StopsJSON.fromJson(i)).toList(),
      polylines: List.from(polys),
      toFirstStop:
          stop1List.map((i) => WalkPathJSON.fromJson(i, index1++)).toList(),
      fromLastStop:
          stop2List.map((i) => WalkPathJSON.fromJson(i, index2++)).toList(),
      rating: json['rating'] is double ? json['rating'] : (json['rating'] / 10) * 10,
      dbRouteId: json['dbRouteId']
    );
  }
}

class PolylineJSON {
  List<LocationJSON> location;
  double slope;
  int pathIndex;

  PolylineJSON({this.location, this.slope, this.pathIndex});

  factory PolylineJSON.fromJson(Map<String, dynamic> json, int index) {
    var list = json['elevation'] as List;
    return new PolylineJSON(
        location:
            list.map((i) => LocationJSON.fromJson(i['location'])).toList(),
        slope: json['slope'] is double ? json['slope'] : json['slope']/10,
        pathIndex: index);
  }
}

class WalkPathJSON {
  final int routeIndex;
  final List<PolylineJSON> pathData;
  final int distanceM;
  final int durationSec;
  double rating;
  final String dbRouteId;

  WalkPathJSON(
      {this.routeIndex, this.pathData, this.distanceM, this.durationSec, this.rating, this.dbRouteId});

  factory WalkPathJSON.fromJson(Map<String, dynamic> json, routeIndex) {
    var list = json['pathData'] as List;
    int index = 0;
    if(json['rating'] == null) 
      json['rating'] = 0;
    return new WalkPathJSON(
      routeIndex: routeIndex,
      pathData: list.map((i) => PolylineJSON.fromJson(i, index++)).toList(),
      distanceM: json['distance'],
      durationSec: json['duration'],
      rating: json['rating'] is double ? json['rating'] : (json['rating'] / 10) * 10,
      dbRouteId: json['dbRouteId']
    );
  }
}
