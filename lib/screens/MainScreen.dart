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
import 'package:sliding_up_panel/sliding_up_panel.dart';

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
  bool _isLoading = false, _destinationSet = false, _originSet = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  final Map<String, Marker> _markers = {};

  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  Map<PolylineId, Polyline> polylines = {};

  String _progressText = 'Loading';

  final double _initFabHeight = 120.0;
  double _fabHeight;
  double _panelHeightOpen = 575.0;
  double _panelHeightClosed = 95.0;
  PanelController _panelController = new PanelController();

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
      body: Stack(alignment: Alignment.topCenter, children: <Widget>[
        SlidingUpPanel(
          controller: _panelController,
          maxHeight: _panelHeightOpen,
          minHeight: _panelHeightClosed,
          parallaxEnabled: true,
          parallaxOffset: .5,
          body: GoogleMap(
            onMapCreated: _onMapCreated,
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
          panel: _panel(),
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18.0), topRight: Radius.circular(18.0)),
          onPanelSlide: (double pos) => setState(() {
            _fabHeight =
                pos * (_panelHeightOpen - _panelHeightClosed) + _initFabHeight;
          }),
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
      ]),
      // body: Stack(
      //   children: <Widget>[
      //     GoogleMap(
      //       onMapCreated: _onMapCreated,
      //       initialCameraPosition: CameraPosition(target: _center, zoom: 15),
      //       markers: _markers.values.toSet(),
      //       polylines: Set<Polyline>.of(polylines.values),
      //       myLocationEnabled: true,
      //       myLocationButtonEnabled: true,
      //       padding: EdgeInsets.only(
      //         top: _destinationSet ? 170 : 100.0,
      //       ),
      //       mapType: MapType.normal,
      //     ),
      //     showOriginTextField(),
      //     Positioned(
      //         // To take AppBar Size only
      //         top: _destinationSet ? 115.0 : 50.0,
      //         left: 20.0,
      //         right: 20.0,
      //         child: AppBar(
      //             backgroundColor: Colors.white,
      //             primary: false,
      //             title: TextField(
      //               readOnly: true,
      //               controller: _destinationController,
      //               decoration: InputDecoration(
      //                   hintText: "Search your destination...",
      //                   border: InputBorder.none,
      //                   hintStyle: TextStyle(color: Colors.grey)),
      //               onTap: () {
      //                 _navigateAndDisplaySelection(context, false);
      //               },
      //             ),
      //             actions: <Widget>[
      //               IconButton(
      //                 icon: Icon(Icons.search,
      //                     color: Theme.of(context).accentColor),
      //                 onPressed: () {_navigateAndDisplaySelection(context, false);},
      //               ),
      //               IconButton(
      //                 padding: const EdgeInsets.only(right: 8.0),
      //                 icon: CircleAvatar(
      //                   backgroundImage:
      //                       AssetImage('assets/images/kocaeli_logo.jpg'),
      //                 ),
      //                 onPressed: () {},
      //               ),
      //             ])),
      //     showCircularProgress(),
      //     showGetDirectionsButton(),
      //   ],
      // )
    );
  }

  Widget _panel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 12.0,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 30,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "Explore Pittsburgh",
              style: TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 24.0,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 36.0,
        ),
        SizedBox(
          height: 36.0,
        ),
        Container(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text("Images",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  )),
              SizedBox(
                height: 12.0,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 36.0,
        ),
        Container(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text("About",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  )),
              SizedBox(
                height: 12.0,
              ),
              Text(
                "Pittsburgh is a city in the Commonwealth of Pennsylvania "
                "in the United States, and is the county seat of Allegheny County. "
                "As of 2017, a population of 305,704 lives within the city limits, "
                "making it the 63rd-largest city in the U.S. The metropolitan population "
                "of 2,353,045 is the largest in both the Ohio Valley and Appalachia, "
                "the second-largest in Pennsylvania (behind Philadelphia), "
                "and the 26th-largest in the U.S.  Pittsburgh is located in the "
                "south west of the state, at the confluence of the Allegheny, "
                "Monongahela, and Ohio rivers, Pittsburgh is known both as 'the Steel City' "
                "for its more than 300 steel-related businesses and as the 'City of Bridges' "
                "for its 446 bridges. The city features 30 skyscrapers, two inclined railways, "
                "a pre-revolutionary fortification and the Point State Park at the "
                "confluence of the rivers. The city developed as a vital link of "
                "the Atlantic coast and Midwest, as the mineral-rich Allegheny "
                "Mountains made the area coveted by the French and British "
                "empires, Virginians, Whiskey Rebels, and Civil War raiders. ",
                maxLines: 7,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
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
        // _panelController.show();
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

    List<dynamic> routesJSON;
    try {
      Response response = await Dio().get(url);
      if (response.statusCode == 200) {
        routesJSON = jsonDecode(response.data);

        int index = -1;
        if (routesJSON.isNotEmpty) {
          List<RoutesJSON> lines =
              routesJSON.map((i) => RoutesJSON.fromJson(i)).toList();

          lines.forEach((RoutesJSON route) {
            route.polylineJSON.forEach((PolylineJSON point) {
              index++;
              List<LatLng> polylineCoordinates = [];
              polylineCoordinates
                  .add(LatLng(point.origin.latitude, point.origin.longitude));
              polylineCoordinates.add(LatLng(
                  point.destination.latitude, point.destination.longitude));
              _addPolyLine(index, polylineCoordinates, point.slope, route);
            });
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
    //_panelController.show();
  }

  _addPolyLine(int index, List<LatLng> polylineCoordinates, double slope,
      RoutesJSON route) {
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
        patterns: patterns[route.routeIndex % 2],
        consumeTapEvents: true,
        onTap: () {
          print('Distance is ' + route.routeTotalDistance);
        });
    polylines[id] = polyline;
    setState(() {});
  }
}

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
  final int routeIndex;

  PolylineJSON({
    this.slope,
    this.origin,
    this.destination,
    this.routeIndex,
  });

  factory PolylineJSON.fromJson(Map<String, dynamic> json) {
    return new PolylineJSON(
      slope: json['slope'] as double,
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
