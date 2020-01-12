import 'package:routing/models/LocationJSON.dart';
import 'package:routing/models/StopsJSON.dart';

class BusRoutesJSON {
  final StopsJSON origin;
  final StopsJSON destination;
  final List<RoutesJSON> routes;

  BusRoutesJSON({this.origin, this.destination, this.routes});

  factory BusRoutesJSON.fromJson(Map<String, dynamic> json) {
    if (json == null) return null;
    var list = json['routes'] as List;
    var index = 0;
    return new BusRoutesJSON(
      origin: StopsJSON.fromJson(json['origin']),
      destination: StopsJSON.fromJson(json['destination']),
      routes: list.map((i) => RoutesJSON.fromJson(i, index++)).toList(),
    );
  }
}

class RoutesJSON {
  final int routeIndex;
  final String routeId;
  final String routeShortName;
  final String routeLongName;
  final String tripId;
  final String departureTime;
  final String arrivalTime;
  final List<StopsJSON> stops;
  final List<String> polylines;
  final WalkPathJSON toFirstStop;
  final WalkPathJSON fromLastStop;

  RoutesJSON(
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
      this.fromLastStop});

  factory RoutesJSON.fromJson(Map<String, dynamic> json, int index) {
    if (json == null) return null;
    var list = json['stops'] as List;
    var polys = json['polylines'] as List;
    return new RoutesJSON(
      routeIndex: index,
      routeId: json['route_id'],
      routeShortName: json['route_short_name'],
      routeLongName: json['route_long_name'],
      tripId: json['trip_id'],
      departureTime: json['departure_time'],
      arrivalTime: json['arrival_time'],
      stops: list.map((i) => StopsJSON.fromJson(i)).toList(),
      polylines: List.from(polys),
      toFirstStop: WalkPathJSON.fromJson(json['toFirstStop']),
      fromLastStop: WalkPathJSON.fromJson(json['fromLastStop']),
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
      location: list.map((i) => LocationJSON.fromJson(i['location'])).toList(),
      slope: json['slope'],
      pathIndex: index
    );
  }
}

class WalkPathJSON {
  final List<PolylineJSON> pathData;
  final int distanceM;
  final int durationSec;
  final StopsJSON stop;

  WalkPathJSON({this.pathData, this.distanceM, this.durationSec, this.stop});

  factory WalkPathJSON.fromJson(Map<String, dynamic> json) {
    var list = json['pathData'] as List;
    int index= 0;
    return new WalkPathJSON(
      pathData: list.map((i) => PolylineJSON.fromJson(i, index)).toList(),
      distanceM: json['distance'],
      durationSec: json['duration'],
      stop: StopsJSON.fromJson(json['stopData'])
    );
  }
}
