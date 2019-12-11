import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:routing/screens/PlacesSearchScreen.dart';
import 'package:routing/services/PermissionsService.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_webservice/directions.dart' as DirectionsAPI;

const kGoogleApiKey = "AIzaSyByv2kxHAnj0FaZHUdqe6cb2MJbaZEeQsc";
DirectionsAPI.GoogleMapsDirections directions =
    DirectionsAPI.GoogleMapsDirections(apiKey: kGoogleApiKey);

class MainScreen extends StatefulWidget {
  MainScreen({this.title});

  final String title;

  @override
  State<StatefulWidget> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  GoogleMapController _controller;
  Geolocator _geolocator = Geolocator();
  bool _isLoading = false,
      _destinationSet = false,
      _originVisible = true,
      _originSet = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  final Map<String, Marker> _markers = {};

  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];

  @override
  void initState() {
    super.initState();
    _isLoading = false;
    WidgetsBinding.instance.addObserver(this);
    PermissionsService()
        .hasPermission(
            PermissionGroup.locationAlways) //check permission returns a Future
        .then((result) {
      if (result) {
        print("Permission Granted");
        showCurrentLocation();
      } else {
        PermissionsService()
            .requestPermission(PermissionGroup.locationAlways)
            .then((result) {
          if (!result) {
            setState(() {
              _isLoading = false;
            });
            print("Not yet granted or denied");
            final snackBar = SnackBar(
                content: Text('Please enable location permissions'),
                action: SnackBarAction(
                  label: 'Accept',
                  onPressed: () {
                    PermissionsService().openAppSettings();
                  },
                ));
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scaffoldKey.currentState.showSnackBar(snackBar));
            Scaffold.of(context).showSnackBar(snackBar);
          } else {
            //show current location/ set center to current location
            showCurrentLocation();
          }
        });
      }
    }); // handling in callback to prevent blocking UI
  }

  LatLng _center = const LatLng(40.763221, 29.925132);

  void showCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });
    print("Permission now Granted");
    //_geolocator.forceAndroidLocationManager = true;
    Position position = await _geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    _controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15.0,
        ),
      ),
    );

    setState(() {
      _isLoading = false;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        body: Stack(
          children: <Widget>[
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(target: _center, zoom: 15),
              markers: _markers.values.toSet(),
              polylines: Set<Polyline>.of(polylines.values),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              padding: EdgeInsets.only(
                top: 100.0,
              ),
              mapType: MapType.normal,
            ),
            Positioned(
                // To take AppBar Size only
                top: 50.0,
                left: 20.0,
                right: 20.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(),
                    borderRadius: new BorderRadius.circular(15.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0, top: 16.0),
                          child: Icon(
                            Icons.menu,
                            color: Theme.of(context).accentColor,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: <Widget>[
                                //Origin text field
                                Visibility(
                                  visible: _originVisible,
                                  child: TextField(
                                    decoration: InputDecoration(
                                        hintText: "Search your origin...",
                                        border: InputBorder.none,
                                        hintStyle:
                                            TextStyle(color: Colors.grey)),
                                    onTap: () {
                                      _navigateAndDisplaySelection(
                                          context, true);
                                    },
                                  ),
                                ),
                                //Destination text field
                                TextField(
                                  decoration: InputDecoration(
                                      hintText: "Search your destination...",
                                      border: InputBorder.none,
                                      hintStyle: TextStyle(color: Colors.grey)),
                                  onTap: () {
                                    _navigateAndDisplaySelection(
                                        context, false);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.search,
                              color: Theme.of(context).accentColor),
                          onPressed: () {},
                        ),
                        IconButton(
                          padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                          icon: CircleAvatar(
                            backgroundImage:
                                AssetImage('assets/images/kocaeli_logo.jpg'),
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                )),
            showCircularProgress(),
            showGetDirectionsButton(),
          ],
        ));
  }

  Widget showCircularProgress() {
    if (_isLoading) {
      //return Center(child: CircularProgressIndicator(backgroundColor: Theme.of(context).primaryColor,));
      return new Stack(
        children: [
          // new Opacity(
          //   opacity: 0.2,
          //   child: const ModalBarrier(dismissible: true, color: Colors.black),
          // ),
          new Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator(),
                Text('Loading your location'),
              ],
            ),
          ),
        ],
      );
    }
    return Container(
      width: 0,
      height: 0,
    );
  }

  Widget showGetDirectionsButton() {
    if (_destinationSet) {
      return new Stack(
        children: [
          Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 180,
                child: RaisedButton(
                  onPressed: () {
                    _getDirections();
                  },
                  child: const Text('Get Directions'),
                  color: Theme.of(context).primaryColor,
                  textColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: new BorderRadius.circular(18.0),
                      side: BorderSide(color: Theme.of(context).accentColor)),
                ),
              ))
        ],
      );
    } else
      return Container(
        width: 0,
        height: 0,
      );
  }

  _navigateAndDisplaySelection(BuildContext context, bool origin) async {
    // Navigator.push returns a Future that completes after calling
    // Navigator.pop on the Selection Screen.
    final PlacesDetailsResponse result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PlacesSearchScreen(
                mapController: _controller,
                hintText: origin
                    ? "Search your origin..."
                    : "Search your destination...",
              )),
    );
    if (result != null) {
      final location = result.result.geometry.location;
      final m = Marker(
          markerId: MarkerId(location.lat.toString() + location.lng.toString()),
          position: LatLng(location.lat, location.lng),
          infoWindow: InfoWindow(title: origin ? "Origin" : "Destination"));
      origin ? _markers["Origin"] = m : _markers["Destination"] = m;

      _controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(location.lat, location.lng),
            zoom: 15.0,
          ),
        ),
      );

      setState(() {
        origin ? _originSet = true : _destinationSet = true;
      });
    }
  }

  _getDirections() async {
    polylineCoordinates.clear();
    polylines.clear();
    _originVisible = true;

    LatLng destination = _markers["Destination"].position;
    Position lastKnownPosition = await _geolocator.getLastKnownPosition(
        locationPermissionLevel: GeolocationPermission.locationAlways);
    LatLng origin = _originSet
        ? _markers["Origin"].position
        : LatLng(lastKnownPosition.latitude, lastKnownPosition.longitude);

    //Use static origin and destination to map 3 different routes
    DirectionsAPI.DirectionsResponse res =
        await directions.directionsWithLocation(
            //Location(origin.latitude, origin.longitude),
            Location(40.763221, 29.925132),
            //Location(destination.latitude, destination.longitude),
            Location(40.765618, 29.925497),
            alternatives: true,
            travelMode: TravelMode.walking);

    List<DirectionsAPI.Route> rota = res.routes;

    PolylinePoints polylinePoints = PolylinePoints();

    int index = -1;
    rota.forEach((DirectionsAPI.Route route) {
      index++;
      List<PointLatLng> result =
          polylinePoints.decodePolyline(route.overviewPolyline.points);
      print(result);

      if (result.isNotEmpty) {
        result.forEach((PointLatLng point) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        });
      }
      _addPolyLine(index);
    });
  }

  _addPolyLine(int index) {
    List<MaterialColor> colors = [Colors.red, Colors.blue, Colors.green, Colors.yellow];
    PolylineId id = PolylineId("poly" + index.toString());
    Polyline polyline = Polyline(
        polylineId: id,
        color: colors[index],
        points: polylineCoordinates,
        width: 2);
    polylines[id] = polyline;
    setState(() {});
  }
}
