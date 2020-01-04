class StopsJSON {
  final String stopId;
  final String stopCode;
  final String stopName;
  final double stopLatitude;
  final double stopLongitude;

  StopsJSON({this.stopId, this.stopCode, this.stopName, this.stopLatitude, this.stopLongitude});

  factory StopsJSON.fromJson(Map<String, dynamic> json) {
    return new StopsJSON(
      stopId: json['stop_id'],
      stopCode: json['stop_code'],
      stopName: json['stop_name'],
      stopLatitude: double.parse(json['stop_lat']),
      stopLongitude: double.parse(json['stop_lon'])
    );
  }
}