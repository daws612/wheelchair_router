class LocationJSON {
  double latitude;
  double longitude;

  LocationJSON({this.latitude, this.longitude});

  factory LocationJSON.fromJson(Map<String, dynamic> json) {
    return new LocationJSON(
      latitude: json['latitude'] == null ? json['lat'] : json['latitude'],
      longitude: json['longitude'] == null ? json['lng'] : json['longitude'],
    );
  }

  Map<String, dynamic> toJson() => {
          'latitude': latitude,
          'longitude': longitude,
  };
}