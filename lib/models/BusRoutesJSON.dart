import 'package:routing/models/StopsJSON.dart';

class BusRoutesJSON {
  final String origin;
  final String destination;
  final List<RoutesJSON> route;

  BusRoutesJSON({this.origin, this.destination, this.route});

  factory BusRoutesJSON.fromJson(Map<String, dynamic> json) {
    if(json == null)
      return null;
    var list = json['route'] as List;
    return new BusRoutesJSON(
      origin: json['origin'],
      destination: json['destination'],
      route: list
          .map((i) => RoutesJSON.fromJson(i))
          .toList(),
    );
  }
}

class RoutesJSON {
  final String routeId;
  final String tripId;
  final String departureTime;
  final String arrivalTime;
  final List<StopsJSON> stops;

  RoutesJSON({this.routeId, this.tripId, this.departureTime, this.arrivalTime, this.stops});

  factory RoutesJSON.fromJson(Map<String, dynamic> json) {
    if(json == null)
      return null;
    var list = json['stops'] as List;
    return new RoutesJSON(
      routeId: json['route_id'],
      tripId: json['trip_id'],
      departureTime: json['departure_time'],
      arrivalTime: json['arrival_time'],
      stops: list
          .map((i) => StopsJSON.fromJson(i))
          .toList(),
    );
  }
}