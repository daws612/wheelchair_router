import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:routing/services/PermissionsService.dart';

class MainScreen extends StatefulWidget {
  MainScreen({this.title});

  final String title;

  @override
  State<StatefulWidget> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  GoogleMapController _controller;
  bool isLoading = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    isLoading = false;
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
              isLoading = false;
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
      isLoading = true;
    });
    print("Permission now Granted");
    Position position = await Geolocator()
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15.0,
        ),
      ),
    );

    setState(() {
      isLoading = false;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Stack(
          children: <Widget>[
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(target: _center, zoom: 15),
            ),
            showCircularProgress()
          ],
        ));
  }

  Widget showCircularProgress() {
    if (isLoading) {
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
}
