import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

const kGoogleApiKey = "AIzaSyByv2kxHAnj0FaZHUdqe6cb2MJbaZEeQsc";
GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: kGoogleApiKey);

class PlacesSearchScreen extends StatefulWidget {
  PlacesSearchScreen({@required this.mapController,this.hintText});

  final GoogleMapController mapController;
  final String hintText;

  @override
  State<StatefulWidget> createState() => PlacesSearchScreenState();
}

class PlacesSearchScreenState extends State<PlacesSearchScreen> {
  TextEditingController _searchController = new TextEditingController();
  Timer _throttle;
  String _title = "Loading", errorLoading = "";
  List<Prediction> _placesList;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  _onSearchChanged() {
    if (_throttle?.isActive ?? false) _throttle.cancel();
    _throttle = Timer(const Duration(milliseconds: 500), () {
      getLocationResults(_searchController.text);
    });
  }

  void getLocationResults(String input) async {
    if (input.isEmpty) {
      setState(() {
        _title = "Suggestions";
        isLoading = true;
      });
      return;
    }

    PlacesAutocompleteResponse result = await _places.autocomplete(input);//.queryAutocomplete(input);
    if (result.status == "OK") {
      _placesList = result.predictions;
    } else {
      errorLoading = result.errorMessage;
    }

    setState(() {
      _title = "Results";
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyChild;
    String title;
    if (isLoading) {
      title = "Loading";
      bodyChild = Center(
        child: CircularProgressIndicator(
          value: null,
        ),
      );
    } else if (errorLoading != null && errorLoading.isNotEmpty) {
      title = "";
      bodyChild = Center(
        child: Text(errorLoading),
      );
    } else if (_placesList == null || _placesList.isEmpty) {
      title = "";
      bodyChild = Center(
        child: Text('Search...'),
      );
    } else {
      bodyChild = Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: buildPlaceDetailList(_placesList),
          )
        ],
      );
    }

    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: const BackButton(color: Colors.grey),
          title: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey),
            ),
            style:
                TextStyle(color: Theme.of(context).accentColor, fontSize: 16.0),
          ),
          actions: <Widget>[
            IconButton(
              padding: const EdgeInsets.only(right: 8.0),
              icon: CircleAvatar(
                backgroundImage: AssetImage('assets/images/kocaeli_logo.jpg'),
              ),
              onPressed: () {},
            ),
          ],
        ),
        body: bodyChild);
  }

  ListView buildPlaceDetailList(List<Prediction> placeDetail) {
    return ListView(
      //shrinkWrap: true,
      children: _placesList
            .map((data) => ListTile(
                  leading: Icon(Icons.place),
                  title: Text(data.description),
                  onTap: () {
                    getAndShowLocation(data.placeId);
                  },
                ))
            .toList(),
    );
  }

  void getAndShowLocation(String placeId) async {

    setState(() {
      this.isLoading = true;
      this.errorLoading = null;
    });

    PlacesDetailsResponse place = await _places.getDetailsByPlaceId(placeId);
    Position lastKnownPosition = await Geolocator().getLastKnownPosition(
        locationPermissionLevel: GeolocationPermission.locationAlways);
    String origin = await _getAddress(lastKnownPosition);

    if (mounted) {
      setState(() {
        this.isLoading = false;
        if (place.status == "OK") {
          Navigator.pop(context, {"selectedAddress":place, "currentLoc":origin});
        } else {
          this.errorLoading = place.errorMessage;
        }
      });
    }
  }

  Future<String> _getAddress(Position pos) async {
    List<Placemark> placemarks = await Geolocator()
        .placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (placemarks != null && placemarks.isNotEmpty) {
      final Placemark pos = placemarks[0];
      return pos.thoroughfare + ', ' + pos.subLocality + ' ' + pos.locality + ' ' + pos.country;
    }
    return "";
  }
}
