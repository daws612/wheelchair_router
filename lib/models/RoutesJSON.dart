class RoutesJSON {
  final int routeIndex;
  final String routeTotalDistance;
  //final double routeHighestSlope;
  final List<PolylineJSON> polylineJSON;

  RoutesJSON({this.routeIndex, this.routeTotalDistance, this.polylineJSON});

  factory RoutesJSON.fromJson(Map<String, dynamic> json) {
    var list = json['slopeOfRoute'] as List;
    return new RoutesJSON(
      routeIndex: json['routeIndex'],
      routeTotalDistance: json['routeTotalDistance'],
      polylineJSON: list
          .map((i) => PolylineJSON.fromJson(i))
          .toList(), //new List<PolylineJSON>.from(json['slopeOfRoute']),
    );
  }
}

//Model to get data from firebase cloud function
class PolylineJSON {
  final double slope;
  final LocationJSON origin;
  final LocationJSON destination;
  final int pathIndex;
  final int routeIndex;
  final double elevation1;
  final double elevation2;

  PolylineJSON({
    this.slope,
    this.origin,
    this.destination,
    this.pathIndex,
    this.routeIndex,
    this.elevation1,
    this.elevation2
  });

  factory PolylineJSON.fromJson(Map<String, dynamic> json) {
    return new PolylineJSON(
      slope: json['slope'] as double,
      origin: LocationJSON.fromJson(json['loc1']),
      destination: LocationJSON.fromJson(json['loc2']),
      pathIndex: json['pathIndex'],
      routeIndex: json['routeIndex'],
      elevation1: json['elv1'],
      elevation2: json['elv2']
    );
  }
}

class LocationJSON {
  double latitude;
  double longitude;

  LocationJSON({this.latitude, this.longitude});

  factory LocationJSON.fromJson(Map<String, dynamic> json) {
    return new LocationJSON(
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }
}
