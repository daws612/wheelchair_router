import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:routing/Constants.dart' as Const;
import 'package:routing/models/AllRoutesJSON.dart' as AllRoutes;
import 'package:routing/models/LocationJSON.dart';
import 'package:routing/models/RoutesJSON.dart';
import 'package:routing/models/StopsJSON.dart';
import 'package:routing/models/User.dart';
import 'package:routing/screens/ImageViewer.dart';
import 'package:routing/screens/PathDetails.dart';
import 'package:routing/screens/PlacesSearchScreen.dart';
import 'package:routing/screens/RateDialog.dart';
import 'package:routing/screens/UserProfile.dart';
import 'package:routing/services/DataService.dart';
import 'package:routing/services/PermissionsService.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:google_maps_webservice/directions.dart' as DirectionsAPI;
import 'package:routing/services/UserLocationLoggerService.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'RouteDetails.dart';
import 'package:geojson/geojson.dart';
import 'package:flutter/services.dart' show SystemChannels, rootBundle;
import 'package:latlong/latlong.dart' as flutterLatLng;

DirectionsAPI.GoogleMapsDirections directions =
    DirectionsAPI.GoogleMapsDirections(apiKey: Const.Constants.kGoogleApiKey);

class MainScreen extends StatefulWidget {
  MainScreen({this.title, this.firebaseUserId});

  final String title;
  final String firebaseUserId;

  @override
  State<StatefulWidget> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  GoogleMapController _controller;
  Geolocator _geolocator = Geolocator();
  bool _isLoading = false, _destinationSet = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  final Map<String, Marker> _markers = {};

  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  Map<PolylineId, Polyline> polylines = {};
  List<RoutesJSON> routes = [];
  AllRoutes.AllRoutesJSON allRoutes;
  int selectedRoute = 0;

  String _progressText = 'Loading';

  final double _initFabHeight = 120.0;
  double _fabHeight;
  double _panelHeightOpen = 375.0;
  double _panelHeightClosed = 65.0;
  PanelController _panelController = new PanelController();

  BitmapDescriptor busStopIcon;
  bool showStops = true;

  List<String> imageFileList = [];
  bool showCarousel = false;
  bool allPermissionsGranted = false;

  double rating = 0;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  _checkPermissions() {
    var storagePermission =
        Platform.isAndroid ? PermissionGroup.storage : PermissionGroup.photos;

    PermissionsService().getPermissionsToAsk([
      storagePermission,
      PermissionGroup.location
    ]) //check permission returns a Future
        .then((result) {
      if (result.length == 0) {
        print("Permission Granted");
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _goToUserProfilePage(true));
        showCurrentLocation();
        if (!mounted) return;
        setState(() {
          allPermissionsGranted = true;
        });
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _panelController.hide());
      } else {
        PermissionsService().requestPermission(result).then((result) {
          if (!result) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
            print("Not yet granted or denied");
            final snackBar = SnackBar(
                duration: Duration(minutes: 5),
                content: Text(
                    'Please enable both location and storage permissions.'),
                action: SnackBarAction(
                  label: 'Accept',
                  onPressed: () {
                    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                    PermissionsService().openAppSettings();
                  },
                ));
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scaffoldKey.currentState.showSnackBar(snackBar));
          } else {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _goToUserProfilePage(true));

            //show current location/ set center to current location
            showCurrentLocation();
            if (!mounted) return;
            setState(() {
              allPermissionsGranted = true;
            });
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _panelController.hide());
          }
        });
      }
    });
    // handling in callback to prevent blocking UI
  }

  void _setupLocationLoggingTimer() {
    Timer.periodic(Duration(seconds: 10), (timer) {
      String origin = _markers.containsKey("Origin")
          ? _markers["Origin"].position.toString()
          : "";
      String destination = _markers.containsKey("Destination")
          ? _markers["Destination"].position.toString()
          : "";

      UserLocationLoggerService.logCurrentLocation(
          _geolocator, origin, destination);
    });
  }

  @override
  void initState() {
    super.initState();
    _isLoading = false;
    WidgetsBinding.instance.addObserver(this);
    _fabHeight = _initFabHeight;

    _checkPermissions();

    _setupLocationLoggingTimer();

    BitmapDescriptor.fromAssetImage(ImageConfiguration(size: Size(48, 48)),
            'assets/images/bus_stop_32.png')
        .then((onValue) {
      busStopIcon = onValue;
    });
  }

  LatLng _center = const LatLng(40.763221, 29.925132);

  void showCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _progressText = 'Loading your location';
    });
    print("Permission now Granted");
    //_geolocator.forceAndroidLocationManager = true;
    Position position = await _geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation);

    _controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15.0,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
  }

  void _onCameraIdle() async {
    if (_controller == null) return;
    LatLngBounds visibleRegion = await _controller.getVisibleRegion();
    print("Camera Idle! VisibleRegion: " + visibleRegion.toString());
    getStopsWithinArea(visibleRegion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: allPermissionsGranted
          ? Stack(alignment: Alignment.topCenter, children: <Widget>[
              GoogleMap(
                onLongPress: (latlng) {
                  //_addDraggableMarker(latlng);
                },
                onMapCreated: _onMapCreated,
                onCameraIdle: _onCameraIdle,
                initialCameraPosition:
                    CameraPosition(target: _center, zoom: 15),
                markers: _markers.values.toSet(),
                polylines: Set<Polyline>.of(polylines.values),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                padding: EdgeInsets.only(
                  top: _destinationSet ? 170 : 100.0,
                ),
                mapType: MapType.normal,
              ),
              showImageCarousel(),
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
                        readOnly: true,
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
                          onPressed: () {
                            _navigateAndDisplaySelection(context, false);
                          },
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
              //showGetPGRouteButton(),
              toggleStopsButton(),
              //toggleGeoJSONDataButton(),
              preferencesButton(),
              SlidingUpPanel(
                //color: Theme.of(context).primaryColor.withOpacity(0.5),
                controller: _panelController,
                maxHeight: MediaQuery.of(context).size.height,
                minHeight: _panelHeightClosed,
                parallaxEnabled: true,
                parallaxOffset: .5,
                panelSnapping: false,
                body: Container(),
                panel: _busRoutesPanel(), //_googleWalkingDirectionsPanel(),
                //color: Colors.white70,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18.0),
                    topRight: Radius.circular(18.0)),
                onPanelSlide: (double pos) => setState(() {
                  _fabHeight = pos * (_panelHeightOpen - _panelHeightClosed) +
                      _initFabHeight;
                }),
              ),
            ])
          : Container(),
    );
  }

  Widget _googleWalkingDirectionsPanel() {
    //if (routes.isNotEmpty) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 12.0,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.all(Radius.circular(12.0))),
            ),
          ],
        ),
        SizedBox(
          height: 18.0,
        ),
        Row(
          //mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              flex: 9,
              child: Text(
                "Route Details",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 24.0,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: GestureDetector(
                onTap: () async {
                  final Const.ConfirmAction action = await _asyncConfirmDialog(
                      context,
                      'Reset Map?',
                      'This will remove the displayed routes and their details.',
                      true);
                  if (action == Const.ConfirmAction.ACCEPT) _closeRouting();
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CircleAvatar(
                    radius: 14.0,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 36.0,
        ),
        Expanded(
          child: ListView.builder(
              itemCount: routes.length, // records.length
              itemBuilder: (BuildContext context, int i) {
                return PathDetails(
                  route: routes[i],
                  index: i,
                  radioValue: selectedRoute,
                  onClicked: () {
                    selectedRoute = i;
                    _renderPolylines(routes);
                    if (!mounted) return;
                    setState(() {});
                  },
                );
              }),
        ),
      ],
    );
    // } else {
    //   //_panelController.hide();
    //   return Container();
    // }
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
                readOnly: true,
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
                  onPressed: () {
                    _navigateAndDisplaySelection(context, true);
                  },
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
    if (!(routes.isNotEmpty || allRoutes != null) && _destinationSet) {
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

  Widget preferencesButton() {
    return new Positioned(
        top: _destinationSet ? 270.0 : 200.0,
        right: 10.0,
        width: 40,
        child: SizedBox(
          height: 40,
          child: RaisedButton(
            padding: EdgeInsets.all(0),
            //shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            color: Colors.white,
            child: Icon(
              Icons.settings,
              color: Colors.black54,
            ),
            onPressed: () {
              _goToUserProfilePage(false);
            },
          ),
        ));
  }

  _goToUserProfilePage(bool isAutomatic) {
    FirebaseAuth.instance.currentUser().then((onValue) {
      Firestore.instance
          .collection('/users')
          .document(onValue.uid)
          .get()
          .then((doc) {
        User user = User.fromDocument(doc);
        if (isAutomatic &&
            user != null &&
            user.wheelchairtype != null &&
            user.age > 0 &&
            user.gender != "Unspecified") {
          print("User already set. Do not redirect to profile page");
        } else {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => UserProfile(
                        user: user,
                      )));
        }
      });
    });
  }

  Widget toggleStopsButton() {
    return new Positioned(
        //alignment: Alignment.bottomRight,
        top: _destinationSet ? 225.0 : 155.0,
        right: 10.0,
        width: 40,
        child: SizedBox(
          height: 40,
          child: RaisedButton(
            padding: EdgeInsets.all(0),
            //shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            color: showStops ? Colors.white : Colors.grey,
            child: ImageIcon(
              AssetImage('assets/images/bus_stop_64.png'),
              color: Colors.black54,
            ),
            onPressed: () {
              showStops = !showStops;
              if (showStops)
                getStopsWithinArea(null);
              else
                _toggleVisible();
            },
          ),
        ));
  }

  Widget toggleGeoJSONDataButton() {
    return new Positioned(
        //alignment: Alignment.bottomRight,
        top: _destinationSet ? 315.0 : 245.0,
        right: 10.0,
        width: 40,
        child: SizedBox(
          height: 40,
          child: RaisedButton(
            padding: EdgeInsets.all(0),
            //shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            color: Colors.white,
            child: Icon(
              Icons.link,
              color: Colors.black54,
            ),
            onPressed: () {
              showGeoJsonLines();
            },
          ),
        ));
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
      if (!origin &&
          result["currentPosition"] != null &&
          _markers["Origin"] == null) {
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

      if (!mounted) return;
      setState(() {
        _resetMap();
        _originController.text = _originController.text.isEmpty
            ? result["currentLoc"]
            : _originController.text;
        if (!origin) {
          _destinationController.text = result["description"];
          _destinationSet = true;
        } else {
          String originAddress =
              origin ? result["description"] : result["currentLoc"];
          _originController.text = originAddress;
        }
      });
    }
  }

  _closeRouting() {
    _destinationSet = false;
    _destinationController.clear();
    _originController.clear();
    _markers.remove('Origin');
    _markers.remove('Destination');
    routes.clear();
    allRoutes = null;
    polylines.clear();
    if (_panelController.isPanelShown()) _panelController.hide();
    selectedRoute = 0;
    if (!mounted) return;
    setState(() {});
  }

  _resetMap() {
    routes.clear();
    allRoutes = null;
    polylines.clear();
    if (_panelController.isPanelShown()) _panelController.hide();
    selectedRoute = 0;
  }

  _getDirections() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _progressText = 'Getting directions...';
    });

    polylines.clear();

    LatLng destination = _markers["Destination"].position;
    Position lastKnownPosition = await _geolocator.getLastKnownPosition(
        locationPermissionLevel: GeolocationPermission.locationAlways);
    if (lastKnownPosition == null && !_markers.containsKey("Origin")) {
      _asyncConfirmDialog(
          context,
          'Address Not Set',
          'Please choose the address you want to route from since we cannot get your current location. Thank you',
          false);
      return;
    }
    LatLng origin = _markers.containsKey("Origin")
        ? _markers["Origin"].position
        : LatLng(lastKnownPosition.latitude, lastKnownPosition.longitude);

    await _getBusRoutes(origin, destination);

    //await _fetchGoogleMapDirections(origin, destination);

    // If the widget was removed from the tree while the message was in flight,
    // we want to discard the reply rather than calling setState to update our
    // non-existent appearance.
    if (!mounted) return;

    if (routes.isNotEmpty && !_panelController.isPanelShown())
      _panelController.show();
    setState(() {
      _isLoading = false;
    });
  }

  _fetchGoogleMapDirections(LatLng origin, LatLng destination) async {
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

    List<dynamic> routesJSON;
    try {
      Response response = await Dio().get(url);
      if (response.statusCode == 200) {
        routesJSON = jsonDecode(response.data);

        if (routesJSON.isNotEmpty) {
          routes = routesJSON.map((i) => RoutesJSON.fromJson(i)).toList();

          _renderPolylines(routes);
        }
      }
    } catch (exception) {
      print(exception);
    }
  }

  _renderPolylines(List<RoutesJSON> routes) {
    polylines.clear();
    int index = -1;
    routes.forEach((RoutesJSON route) {
      route.polylineJSON.forEach((PolylineJSON point) {
        index++;
        List<LatLng> polylineCoordinates = [];
        polylineCoordinates
            .add(LatLng(point.origin.latitude, point.origin.longitude));
        polylineCoordinates.add(
            LatLng(point.destination.latitude, point.destination.longitude));
        _addPolyLine("poly-" + index.toString(), polylineCoordinates,
            point.slope, route.routeIndex, true);
      });
    });
  }

  Future<Const.ConfirmAction> _asyncConfirmDialog(BuildContext context,
      String title, String message, bool showCancel) async {
    return showDialog<Const.ConfirmAction>(
      context: context,
      barrierDismissible: false, // user must tap button for close dialog!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reset Map?'),
          content: Text(message),
          actions: <Widget>[
            showCancel
                ? FlatButton(
                    child: const Text('CANCEL'),
                    onPressed: () {
                      Navigator.of(context).pop(Const.ConfirmAction.CANCEL);
                    },
                  )
                : Container(
                    width: 0,
                    height: 0,
                  ),
            FlatButton(
              child: const Text('ACCEPT'),
              onPressed: () {
                Navigator.of(context).pop(Const.ConfirmAction.ACCEPT);
              },
            )
          ],
        );
      },
    );
  }

  //Load stops for visible area
  void getStopsWithinArea(LatLngBounds visibleRegion) async {
    if (visibleRegion == null && _controller != null) {
      visibleRegion = await _controller.getVisibleRegion();
      print("Toggle Show Stops! VisibleRegion: " + visibleRegion.toString());
    }

    //If we cant get the visible area and controller is also null, the map hasnt initialized yet
    if (visibleRegion == null || _controller == null) return;

    if (showStops) {
      _toggleVisible(); //show already fetched stops then fetch

      List<StopsJSON> stops = await DataService().fetchData(visibleRegion);

      if (stops.isNotEmpty) {
        stops.forEach((StopsJSON stop) {
          Marker m = Marker(
              visible: showStops,
              markerId: MarkerId("stop-" + stop.stopId.toString()),
              position: LatLng(stop.stopLatitude, stop.stopLongitude),
              infoWindow: InfoWindow(
                  title: stop.stopCode.toString() + " - " + stop.stopName),
              icon: busStopIcon);
          _markers[stop.stopId.toString()] = m;
        });
        if (!mounted) return;
        setState(() {});
      } else {
        if (!mounted) return;
        setState(() {});
      }
      print("Completed stops loops");
    }
  }

  Future<void> _toggleVisible() async {
    //find stop markers only and toggle their visibility
    _markers.forEach((key, value) {
      String id = value.markerId.value;
      if (id.startsWith("stop-")) {
        if (!mounted) return;
        setState(() {
          _markers[key] = value.copyWith(
            visibleParam: showStops, //!value.visible as per docs
          );
        });
      }
    });
  }

  _getBusRoutes(LatLng origin, LatLng destination) async {
    //https://stackoverflow.com/questions/13407468/how-can-i-list-all-the-stops-associated-with-a-route-using-gtfs
    allRoutes = await DataService().fetchRoutes(origin, destination);
    _controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: origin,
          zoom: 15.0,
        ),
      ),
    );

    if (allRoutes != null) _renderRoutes();
  }

  _renderBusRoute(AllRoutes.BusRoutesJSON route) {
    List<LatLng> polylineCoordinates = [];

    int index = 0;
    route.polylines.forEach((String line) {
      if (line == null) return;

      List<PointLatLng> result = PolylinePoints().decodePolyline(line);
      polylineCoordinates = [];

      if (result.isNotEmpty) {
        result.forEach((PointLatLng point) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        });

        _addPolyLine(route.tripId + "-" + index.toString(), polylineCoordinates,
            null, route.routeIndex, true);
      }

      index++;
    }); //finish bus route polylines

    //plot from current location to first bus stop
    route.toFirstStop.forEach((AllRoutes.WalkPathJSON walkRoute) {
      index = 0;
      walkRoute.pathData.forEach((AllRoutes.PolylineJSON elevation) {
        polylineCoordinates = [];
        elevation.location.forEach((LocationJSON coords) {
          polylineCoordinates.add(LatLng(coords.latitude, coords.longitude));
        });
        _addPolyLine(
            walkRoute.routeIndex.toString() +
                "-toFirstStop-" +
                index.toString(),
            polylineCoordinates,
            elevation.slope,
            route.routeIndex,
            walkRoute.routeIndex == 0 ? true : false);
        index++;
      });
    }); //finish path to first stop

    //plot from current location to first bus stop
    route.fromLastStop.forEach((AllRoutes.WalkPathJSON walkRoute) {
      index = 0;
      walkRoute.pathData.forEach((AllRoutes.PolylineJSON elevation) {
        polylineCoordinates = [];
        elevation.location.forEach((LocationJSON coords) {
          polylineCoordinates.add(LatLng(coords.latitude, coords.longitude));
        });
        _addPolyLine(
            walkRoute.routeIndex.toString() +
                "-fromLastStop-" +
                index.toString(),
            polylineCoordinates,
            elevation.slope,
            route.routeIndex,
            walkRoute.routeIndex == 0 ? true : false);
        index++;
      });
    }); //finish path to first stop
  }

  _addPolyLine(String polyId, List<LatLng> polylineCoordinates, double slope,
      int routeIndex, bool highlightRoute) {
    MaterialColor slopeColor;
    if (slope != null) {
      if (slope > 7)
        slopeColor = Colors.red;
      else if (slope >= -7 && slope <= 7)
        slopeColor = Colors.green;
      else if (slope < -7) slopeColor = Colors.blue;
    } else {
      slopeColor = Colors.grey;
    }

    PolylineId id = PolylineId(polyId);
    Polyline polyline = Polyline(
      polylineId: id,
      color: highlightRoute ? slopeColor : slopeColor.withOpacity(0.3),
      points: polylineCoordinates,
      width: 2,
      geodesic: true,
      startCap: Cap.buttCap,
      endCap: Cap.roundCap,
      consumeTapEvents: true,
    );
    polylines[id] = polyline;
    if (!mounted) return;
    setState(() {});
  }

  _renderWalkRoute(AllRoutes.WalkPathJSON route) {
    List<LatLng> polylineCoordinates = [];

    int index = 0;
    route.pathData.forEach((AllRoutes.PolylineJSON line) {
      if (line == null) return;

      polylineCoordinates = [];
      line.location.forEach((LocationJSON coords) {
        polylineCoordinates.add(LatLng(coords.latitude, coords.longitude));
      });
      _addPolyLine(
          route.routeIndex.toString() + "-walk-" + index.toString(),
          polylineCoordinates,
          line.slope,
          route.routeIndex,
          route.routeIndex == selectedRoute ? true : false);
      index++;
    });
  }

  _renderRoutes() {
    polylines.clear();
    bool clearWalkRoutes = true;
    allRoutes.walkingDirections.forEach((AllRoutes.WalkPathJSON route) {
      _renderWalkRoute(route);
      if (route != null && selectedRoute == route.routeIndex) {
        clearWalkRoutes = false; //selected route is walk route, dont clear
      }
    });

    if (clearWalkRoutes) {
      polylines.clear(); //if we are showing bus routes, dont show walk routes

      allRoutes.busRoutes.forEach((AllRoutes.BusRoutesJSON route) {
        if (route != null && selectedRoute == route.routeIndex)
          _renderBusRoute(route);
      });
    }

    if (!mounted) return;
    if (allRoutes != null &&
        (allRoutes.busRoutes.isNotEmpty ||
            allRoutes.walkingDirections.isNotEmpty) &&
        !_panelController.isPanelShown()) _panelController.show();
    setState(() {
      _isLoading = false;
    });
  }

  Widget _busRoutesPanel() {
    if (allRoutes != null &&
        (allRoutes.busRoutes.isNotEmpty ||
            allRoutes.walkingDirections.isNotEmpty)) {
      return Column(
        children: <Widget>[
          SizedBox(
            height: 12.0,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.all(Radius.circular(12.0))),
              ),
            ],
          ),
          SizedBox(
            height: 9.0,
          ),
          Row(
            //mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                flex: 10,
                child: Text(
                  "Route Details",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 18.0,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () {
                    _panelController.hide();
                    _getDirections();
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CircleAvatar(
                      radius: 12.0,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Icon(
                        Icons.refresh,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () async {
                    final Const.ConfirmAction action = await _asyncConfirmDialog(
                        context,
                        'Reset Map?',
                        'This will remove the displayed routes and their details.',
                        true);
                    if (action == Const.ConfirmAction.ACCEPT) _closeRouting();
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CircleAvatar(
                      radius: 12.0,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 16.0,
          ),
          Expanded(
              child: RouteDetails(
                  allRoutes: allRoutes,
                  radioValue: selectedRoute,
                  onClicked: (value) {
                    selectedRoute = value;
                    _renderRoutes();
                    if (!mounted) return;
                    setState(() {});
                  },
                  rateRouteClicked: (routeIndex, isBus) async {
                    final Const.ConfirmAction action =
                        await _asyncRateRouteDialog(context, routeIndex, isBus);
                  })),
        ],
      );
    } else {
      //_panelController.hide();
      return Container();
    }
  }

  Future<void> processData(String fileName) async {
    // data is from http://www.naturalearthdata.com
    final data = await rootBundle.loadString(fileName);
    final geojson = GeoJson();
    int index = 0;
    geojson.processedLines.listen((GeoJsonLine line) {
      final color = Colors.black;
      List<flutterLatLng.LatLng> latlngs = line.geoSerie.toLatLng();
      List<LatLng> polylineCoords = [];
      latlngs.forEach((flutterLatLng.LatLng p) {
        polylineCoords.add(LatLng(p.latitude, p.longitude));
      });

      PolylineId id = PolylineId(fileName + index.toString());
      Polyline pointLine = Polyline(
          polylineId: id, width: 2, color: color, points: polylineCoords);
      polylines[id] = pointLine;
      index++;
      if (!mounted) return;
      setState(() {});
    });

    geojson.processedPoints.listen((GeoJsonPoint point) {
      Marker m = Marker(
          markerId: MarkerId(point.geoPoint.latitude.toString() +
              "," +
              point.geoPoint.longitude.toString()),
          position: LatLng(point.geoPoint.latitude, point.geoPoint.longitude),
          infoWindow: InfoWindow(title: index.toString()),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueYellow));
      _markers[fileName + index.toString()] = m;
      index++;
      if (!mounted) return;
      setState(() {});
    });

    geojson.processedFeatures.listen((GeoJsonFeature feature) {
      if (feature.properties.length > 0 &&
          feature.properties.containsKey("Photo")) {
        imageFileList
            .add("assets/Photos/" + feature.properties["Photo"].toString());
        Marker m = Marker(
            markerId: MarkerId(feature.geometry.geoPoint.latitude.toString() +
                "," +
                feature.geometry.geoPoint.longitude.toString()),
            position: LatLng(feature.geometry.geoPoint.latitude,
                feature.geometry.geoPoint.longitude),
            infoWindow: InfoWindow(title: "photo"),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow),
            onTap: () {
              showImageCarousel();
              if (!mounted) return;
              setState(() {
                showCarousel = !showCarousel;
              });
            });
        _markers[fileName + index.toString()] = m;
        index++;
        if (!mounted) return;
        setState(() {});
      }
    });

    geojson.endSignal.listen((_) => geojson.dispose());
    geojson.parse(data, verbose: true);
  }

  void showGeoJsonLines() async {
    //_toggleVisiblePolylines("geoline-");
    polylines.clear();
    imageFileList.clear();
    await processData('assets/Project1_Obstacles.geojson');
    await processData('assets/Project1_sidewalk.geojson');
    await processData('assets/Project1_PHOTOS.geojson');
    await processData('assets/Project1_TRACKS.geojson');
  }

  Future<void> _toggleVisiblePolylines(String polylineId) async {
    polylines.forEach((key, value) {
      String id = value.polylineId.value;
      if (id.startsWith(polylineId)) {
        if (!mounted) return;
        setState(() {
          polylines[key] = value.copyWith(visibleParam: !value.visible);
        });
      }
    });
  }

  Widget showImageCarousel() {
    if (imageFileList.length > 0 && showCarousel) {
      return Positioned(
          bottom: 10.0,
          left: 20.0,
          right: 20.0,
          child: ImageViewer(
            imgList: imageFileList,
          ));
    } else {
      return Container(
        width: 0,
        height: 0,
      );
    }
  }

  void _addDraggableMarker(LatLng latLng) {
    List<Marker> pgMarkers = _findPGMarkers();
    if (pgMarkers.length == 2) return;

    if (!mounted) return;
    setState(() {
      _markers[latLng.toString()] = Marker(
          markerId: MarkerId("pgRoute" + latLng.toString()),
          draggable: true,
          position: latLng,
          infoWindow: InfoWindow(
            title: 'Custom Marker',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose));
    });
  }

  List<Marker> _findPGMarkers() {
    List<Marker> m = [];
    _markers.forEach((key, value) {
      String id = value.markerId.value;
      if (id.startsWith("pgRoute")) {
        m.add(value);
      }
    });
    return m;
  }

  Widget showGetPGRouteButton() {
    List<Marker> pgMarkers = _findPGMarkers();
    if (pgMarkers.length > 0 && pgMarkers.length < 3) {
      return new Stack(
        children: [
          Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 180,
                child: RaisedButton(
                  onPressed: () async {
                    await _getBusRoutes(
                        pgMarkers[0].position, pgMarkers[1].position);
                    // AllRoutes.WalkPathJSON w =
                    //     await DataService().fetchPGRoutes(pgMarkers);
                    // _renderWalkRoute(w);

                    // if (!mounted) return;
                    // setState(() {
                    //   _isLoading = false;
                    // });

                    // _controller.animateCamera(
                    //   CameraUpdate.newCameraPosition(
                    //     CameraPosition(
                    //       target: LatLng(w.pathData[0].location[0].latitude,
                    //           w.pathData[0].location[0].longitude),
                    //       zoom: 15.0,
                    //     ),
                    //   ),
                    // );
                  },
                  child: const Text('Get PG Routing'),
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

  Future<Const.ConfirmAction> _asyncRateRouteDialog(
      BuildContext context, int routeIndex, bool isBus) async {
    return showDialog<Const.ConfirmAction>(
      context: context,
      barrierDismissible: false, // user must tap button to close dialog!
      builder: (BuildContext context) {
        return RateDialog(
          allRoutes: this.allRoutes,
          routeIndex: routeIndex,
          isBus: isBus,
          origin: _markers["Origin"].position,
          destination: _markers["Destination"].position
        );
      },
    );
  }
}
