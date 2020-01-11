import 'package:routing/models/StopsJSON.dart';

class BusRoutesJSON {
  final StopsJSON origin;
  final StopsJSON destination;
  final List<RoutesJSON> routes;

  BusRoutesJSON({this.origin, this.destination, this.routes});

  factory BusRoutesJSON.fromJson(Map<String, dynamic> json) {
    if(json == null)
      return null;
    var list = json['routes'] as List;
    return new BusRoutesJSON(
      origin: StopsJSON.fromJson(json['origin']),
      destination: StopsJSON.fromJson(json['destination']),
      routes: list
          .map((i) => RoutesJSON.fromJson(i))
          .toList(),
    );
  }
}

class RoutesJSON {
  final String routeId;
  final String routeShortName;
  final String routeLongName;
  final String tripId;
  final String departureTime;
  final String arrivalTime;
  final List<StopsJSON> stops;
  final List<String> polylines;

  RoutesJSON({this.routeId, this.routeShortName, this.routeLongName, this.tripId, this.departureTime, this.arrivalTime, this.stops, this.polylines});

  factory RoutesJSON.fromJson(Map<String, dynamic> json) {
    if(json == null)
      return null;
    var list = json['stops'] as List;
    var polys = json['polylines'] as List;
    return new RoutesJSON(
      routeId: json['route_id'],
      routeShortName: json['route_short_name'],
      routeLongName: json['route_long_name'],
      tripId: json['trip_id'],
      departureTime: json['departure_time'],
      arrivalTime: json['arrival_time'],
      stops: list
          .map((i) => StopsJSON.fromJson(i))
          .toList(),
      polylines: List.from(polys)
    );
  }
}