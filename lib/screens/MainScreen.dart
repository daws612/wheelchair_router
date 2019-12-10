import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:routing/screens/PlacesSearchScreen.dart';
import 'package:routing/services/PermissionsService.dart';
import 'package:google_maps_webservice/places.dart';

class MainScreen extends StatefulWidget {
  MainScreen({this.title});

  final String title;

  @override
  State<StatefulWidget> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  GoogleMapController _controller;
  Geolocator _geolocator = Geolocator();
  bool _isLoading = false, _destinationSet = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  final Map<String, Marker> _markers = {};

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
              child: AppBar(
                backgroundColor: Colors.white,
                leading: Icon(
                  Icons.menu,
                  color: Theme.of(context).accentColor,
                ),
                primary: false,
                title: TextField(
                  decoration: InputDecoration(
                      hintText: "Search your destination...",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey)),
                  onTap: () {
                    _navigateAndDisplaySelection(context);
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
                ],
              ),
            ),
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
                  onPressed: () {},
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

  _navigateAndDisplaySelection(BuildContext context) async {
    // Navigator.push returns a Future that completes after calling
    // Navigator.pop on the Selection Screen.
    final PlacesDetailsResponse result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PlacesSearchScreen(
                mapController: _controller,
              )),
    );
    if (result != null) {
      _markers.clear();
      final location = result.result.geometry.location;
      final m = Marker(
          markerId: MarkerId(location.lat.toString() + location.lng.toString()),
          position: LatLng(location.lat, location.lng),
          infoWindow: InfoWindow(title: "Destination"));
      _markers["Destination"] = m;

      _controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(location.lat, location.lng),
            zoom: 15.0,
          ),
        ),
      );

      setState(() {
        _destinationSet = true;
      });
    }
  }
}
