import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:routing/models/AllRoutesJSON.dart' as AllRoutes;
import 'package:routing/models/LocationJSON.dart';
import 'package:routing/models/RoutesJSON.dart';
import 'package:routing/models/StopsJSON.dart';
import 'package:routing/screens/PathDetails.dart';
import 'package:routing/screens/PlacesSearchScreen.dart';
import 'package:routing/services/DataService.dart';
import 'package:routing/services/PermissionsService.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:google_maps_webservice/directions.dart' as DirectionsAPI;
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'RouteDetails.dart';

const kGoogleApiKey = "AIzaSyBUOmQEmER7vOSpaf0UvwYSwzQmhG2hcTs";
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
  bool _isLoading = false, _destinationSet = false, _originSet = false;

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

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _isLoading = false;
    WidgetsBinding.instance.addObserver(this);
    _fabHeight = _initFabHeight;

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _panelController.hide());

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
    });
    // handling in callback to prevent blocking UI

    BitmapDescriptor.fromAssetImage(ImageConfiguration(size: Size(48, 48)),
            'assets/images/bus_stop_32.png')
        .then((onValue) {
      busStopIcon = onValue;
    });
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

  void _onCameraIdle() async {
    if (_controller == null) return;
    LatLngBounds visibleRegion = await _controller.getVisibleRegion();
    //print("Camera Idle! VisibleRegion: " + visibleRegion.toString());
    getStopsWithinArea(visibleRegion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Stack(alignment: Alignment.topCenter, children: <Widget>[
        GoogleMap(
          onMapCreated: _onMapCreated,
          onCameraIdle: _onCameraIdle,
          initialCameraPosition: CameraPosition(target: _center, zoom: 15),
          markers: _markers.values.toSet(),
          polylines: Set<Polyline>.of(polylines.values),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          padding: EdgeInsets.only(
            top: _destinationSet ? 170 : 100.0,
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
        toggleStopsButton(),
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
              topLeft: Radius.circular(18.0), topRight: Radius.circular(18.0)),
          onPanelSlide: (double pos) => setState(() {
            _fabHeight =
                pos * (_panelHeightOpen - _panelHeightClosed) + _initFabHeight;
          }),
        ),
      ]),
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
                  final ConfirmAction action =
                      await _asyncConfirmDialog(context);
                  if (action == ConfirmAction.ACCEPT) _closeRouting();
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

      setState(() {
        _resetMap();
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

  _closeRouting() {
    _destinationSet = false;
    _originSet = false;
    _destinationController.clear();
    _originController.clear();
    _markers.remove('Origin');
    _markers.remove('Destination');
    routes.clear();
    allRoutes = null;
    polylines.clear();
    if (_panelController.isPanelShown()) _panelController.hide();
    selectedRoute = 0;
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

  Future<ConfirmAction> _asyncConfirmDialog(BuildContext context) async {
    return showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: false, // user must tap button for close dialog!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reset Map?'),
          content: const Text(
              'This will remove the displayed routes and their details.'),
          actions: <Widget>[
            FlatButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.CANCEL);
              },
            ),
            FlatButton(
              child: const Text('ACCEPT'),
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.ACCEPT);
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
        setState(() {});
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _toggleVisible() async {
    //find stop markers only and toggle their visibility
    _markers.forEach((key, value) {
      String id = value.markerId.value;
      if (id.startsWith("stop-")) {
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
            walkRoute.routeIndex.toString() + "-toFirstStop-" + index.toString(),
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
            walkRoute.routeIndex.toString() + "-fromLastStop-" + index.toString(),
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
    if (allRoutes != null && (allRoutes.busRoutes.isNotEmpty)) {
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
                flex: 9,
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
                  onTap: () async {
                    final ConfirmAction action =
                        await _asyncConfirmDialog(context);
                    if (action == ConfirmAction.ACCEPT) _closeRouting();
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CircleAvatar(
                      radius: 8.0,
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
              setState(() {});
            },
          )),
        ],
      );
    } else {
      //_panelController.hide();
      return Container();
    }
  }
}

enum ConfirmAction { CANCEL, ACCEPT }
