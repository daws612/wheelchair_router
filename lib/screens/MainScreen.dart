import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:routing/screens/PlacesSearchScreen.dart';
import 'package:routing/services/PermissionsService.dart';
import 'package:google_maps_webservice/places.dart';
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
      _originSet = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  final Map<String, Marker> _markers = {};

  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  Map<PolylineId, Polyline> polylines = {};

  String _progressText = 'Loading';

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

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
      _progressText = 'Loading your location';
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
            showOriginTextField(),
            Positioned(
                // To take AppBar Size only
                top: _destinationSet ? 115.0 : 50.0,
                left: 20.0,
                right: 20.0,
                child: AppBar(
                    backgroundColor: Colors.white,
                    primary: false,
                    title: TextField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                          hintText: "Search your destination...",
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey)),
                      onTap: () {
                        _navigateAndDisplaySelection(context, false);
                      },
                    ),
                    actions: <Widget>[
                      IconButton(
                        icon: Icon(Icons.search,
                            color: Theme.of(context).accentColor),
                        onPressed: () {},
                      ),
                      IconButton(
                        padding: const EdgeInsets.only(right: 8.0),
                        icon: CircleAvatar(
                          backgroundImage:
                              AssetImage('assets/images/kocaeli_logo.jpg'),
                        ),
                        onPressed: () {},
                      ),
                    ])),
            showCircularProgress(),
            showGetDirectionsButton(),
          ],
        ));
  }

  Widget showOriginTextField() {
    if (_destinationSet) {
      return Positioned(
          // To take AppBar Size only
          top: 50.0,
          left: 20.0,
          right: 20.0,
          child: AppBar(
              backgroundColor: Colors.white,
              primary: false,
              title: TextField(
                controller: _originController,
                decoration: InputDecoration(
                    hintText: "Search your origin...",
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey)),
                onTap: () {
                  _navigateAndDisplaySelection(context, true);
                },
              ),
              actions: <Widget>[
                IconButton(
                  icon:
                      Icon(Icons.search, color: Theme.of(context).accentColor),
                  onPressed: () {},
                ),
                IconButton(
                  padding: const EdgeInsets.only(right: 8.0),
                  icon: CircleAvatar(
                    backgroundImage:
                        AssetImage('assets/images/kocaeli_logo.jpg'),
                  ),
                  onPressed: () {},
                ),
              ]));
    }

    return Container(
      width: 0,
      height: 0,
    );
  }

  Widget showCircularProgress() {
    if (_isLoading) {
      return new Stack(
        children: [
          new Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator(),
                Text(_progressText),
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
                    _getFirebaseDirections();
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
    final Map<String, Object> result = await Navigator.push(
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
      PlacesDetailsResponse selectedAddress = result["selectedAddress"];
      final location = selectedAddress.result.geometry.location;
      final m = Marker(
          markerId: MarkerId(location.lat.toString() + location.lng.toString()),
          position: LatLng(location.lat, location.lng),
          infoWindow: InfoWindow(title: origin ? "Origin" : "Destination"),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              origin ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed));
      origin ? _markers["Origin"] = m : _markers["Destination"] = m;

      //Add origin marker when destination is being set
      if (!origin && result["currentPosition"] != null && _markers["Origin"] == null) {
        Placemark origin = result["currentPosition"];
        final m = Marker(
            markerId: MarkerId(origin.position.latitude.toString() +
                origin.position.longitude.toString()),
            position:
                LatLng(origin.position.latitude, origin.position.longitude),
            infoWindow: InfoWindow(title: "Origin"),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen));
        _markers["Origin"] = m;
      }

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
        String originAddress = _originSet
            ? selectedAddress.result.formattedAddress
            : result["currentLoc"];
        _originController.text = originAddress;
        if (!origin)
          _destinationController.text = selectedAddress.result.formattedAddress;
      });
    }
  }

  _getFirebaseDirections() async {
    setState(() {
      _isLoading = true;
      _progressText = 'Getting directions...';
    });

    polylines.clear();

    LatLng destination = _markers["Destination"].position;
    Position lastKnownPosition = await _geolocator.getLastKnownPosition(
        locationPermissionLevel: GeolocationPermission.locationAlways);
    LatLng origin = _originSet
        ? _markers["Origin"].position
        : LatLng(lastKnownPosition.latitude, lastKnownPosition.longitude);

    String params = "?origin=" +
        origin.latitude.toString() +
        ',' +
        origin.longitude.toString() +
        '&destination=' +
        destination.latitude.toString() +
        ',' +
        destination.longitude.toString();

    var url =
        'https://us-central1-wheelchair-router.cloudfunctions.net/getDirections$params';

    List<dynamic> polylinesJSON;
    try {
      Response response = await Dio().get(url);
      if (response.statusCode == 200) {
        polylinesJSON = jsonDecode(response.data);

        int index = -1;
        if (polylinesJSON.isNotEmpty) {
          List<PolylineJSON> lines =
              polylinesJSON.map((i) => PolylineJSON.fromJson(i)).toList();

          lines.forEach((PolylineJSON point) {
            index++;
            List<LatLng> polylineCoordinates = [];
            polylineCoordinates
                .add(LatLng(point.origin.latitude, point.origin.longitude));
            polylineCoordinates.add(LatLng(
                point.destination.latitude, point.destination.longitude));
            _addPolyLine(index, polylineCoordinates, point.slope, point.routeIndex);
          });
        }
      }
    } catch (exception) {
      print(exception);
    }

    // If the widget was removed from the tree while the message was in flight,
    // we want to discard the reply rather than calling setState to update our
    // non-existent appearance.
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  _addPolyLine(int index, List<LatLng> polylineCoordinates, double slope, int routeIndex) {
    MaterialColor slopeColor;
    if (slope > 7)
      slopeColor = Colors.red;
    else if (slope >= -7 && slope <= 7)
      slopeColor = Colors.green;
    else if (slope < -7) slopeColor = Colors.blue;

    List<List<PatternItem>> patterns = [
      [PatternItem.dot],
      [PatternItem.dash(5)],
      [PatternItem.gap(5)]
    ];
    PolylineId id = PolylineId("poly" + index.toString());
    Polyline polyline = Polyline(
      polylineId: id,
      color: slopeColor,
      points: polylineCoordinates,
      width: 2,
      geodesic: true,
      startCap: Cap.buttCap,
      endCap: Cap.roundCap,
      patterns: patterns[routeIndex]
    );
    polylines[id] = polyline;
    setState(() {});
  }
}

//Model to get data from firebase cloud function
class PolylineJSON {
  final double slope;
  final LocationJSON origin;
  final LocationJSON destination;
  final int routeIndex;

  PolylineJSON({
    this.slope,
    this.origin,
    this.destination,
    this.routeIndex,
  });

  factory PolylineJSON.fromJson(Map<String, dynamic> json) {
    return new PolylineJSON(
      slope: json['slope'],
      origin: LocationJSON.fromJson(json['loc1']),
      destination: LocationJSON.fromJson(json['loc2']),
      routeIndex: json['pathIndex'],
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
