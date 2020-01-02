import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FirestoreService {
  final db = Firestore.instance;

  void getNearbyStops(LatLngBounds bounds) {
    var north = new GeoPoint(bounds.northeast.latitude, bounds.northeast.longitude);
    var south = new GeoPoint(bounds.southwest.latitude, bounds.southwest.longitude);

    print("Fetching nearby stops");
    db
      .collection('stops')
      .where('location', isLessThanOrEqualTo: north)
      .where('location', isGreaterThanOrEqualTo: south)
      .getDocuments()
        .then((QuerySnapshot snapshot) {
          print("Returned " + snapshot.documents.length.toString() + " stops.");
      //snapshot.documents.forEach((f) => print('${f.data}}'));
    });
  }
}