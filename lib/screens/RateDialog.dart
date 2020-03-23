import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:WeRoute/Constants.dart';
import 'package:WeRoute/models/AllRoutesJSON.dart';
import 'package:WeRoute/services/UserService.dart';
import 'package:smooth_star_rating/smooth_star_rating.dart';

class RateDialog extends StatefulWidget {
  RateDialog({this.allRoutes, this.routeIndex, this.isBus});

  final AllRoutesJSON allRoutes;
  final int routeIndex;
  final bool isBus;

  @override
  State<StatefulWidget> createState() => RateDialogState();
}

class RateDialogState extends State<RateDialog> {
  BusRoutesJSON busRoute;
  WalkPathJSON walkPath;

  @override
  Widget build(BuildContext context) {
    if (widget.isBus) {
      widget.allRoutes.busRoutes.forEach((BusRoutesJSON route) {
        if (route != null && widget.routeIndex == route.routeIndex)
          busRoute = route;
      });
    } else {
      widget.allRoutes.walkingDirections.forEach((WalkPathJSON route) {
        if (route != null && widget.routeIndex == route.routeIndex)
          walkPath = route;
      });
    }

    return AlertDialog(
      // contentPadding: EdgeInsets.all(15.0),
      title: Text('Rate Route'),
      content: widget.isBus
          ? Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(height: 16.0),
                Text(
                  "Path to " + busRoute.stops[0].stopName,
                  textAlign: TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 10.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SmoothStarRating(
                        allowHalfRating: false,
                        onRatingChanged: (v) {
                          busRoute.toFirstStop[0].rating = v;
                          setState(() {});
                        },
                        starCount: 5,
                        rating: busRoute.toFirstStop[0].rating,
                        size: 40.0,
                        filledIconData: Icons.star,
                        halfFilledIconData: Icons.star_border,
                        color: Colors.yellow,
                        borderColor: Colors.yellow,
                        spacing: 0.0)
                  ],
                ),
                SizedBox(height: 16.0),
                Text(
                  "Bus Route: " +
                      busRoute.routeShortName +
                      " - " +
                      busRoute.routeLongName,
                  //maxLines: 1,
                  //overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                ),
                SizedBox(height: 10.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SmoothStarRating(
                        allowHalfRating: false,
                        onRatingChanged: (v) {
                          busRoute.rating = v;
                          setState(() {});
                        },
                        starCount: 5,
                        rating: busRoute.rating,
                        size: 40.0,
                        filledIconData: Icons.star,
                        halfFilledIconData: Icons.star_border,
                        color: Colors.yellow,
                        borderColor: Colors.yellow,
                        spacing: 0.0)
                  ],
                ),
                SizedBox(height: 16.0),
                Text(
                  "Path From " +
                      busRoute.stops[busRoute.stops.length - 1].stopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                ),
                SizedBox(height: 10.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SmoothStarRating(
                        allowHalfRating: false,
                        onRatingChanged: (v) {
                          busRoute.fromLastStop[0].rating = v;
                          setState(() {});
                        },
                        starCount: 5,
                        rating: busRoute.fromLastStop[0].rating,
                        size: 40.0,
                        filledIconData: Icons.star,
                        halfFilledIconData: Icons.star_border,
                        color: Colors.yellow,
                        borderColor: Colors.yellow,
                        spacing: 0.0)
                  ],
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                  SizedBox(height: 16.0),
                  Text(
                    "Walk Path of distance " +
                        walkPath.distanceM.toString() +
                        " m and duration " +
                        walkPath.durationSec.toString() +
                        " secs",
                    textAlign: TextAlign.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 10.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SmoothStarRating(
                          allowHalfRating: false,
                          onRatingChanged: (v) {
                            setState(() {
                              walkPath.rating = v;
                            });
                          },
                          starCount: 5,
                          rating: walkPath.rating,
                          size: 40.0,
                          filledIconData: Icons.star,
                          halfFilledIconData: Icons.star_border,
                          color: Colors.yellow,
                          borderColor: Colors.yellow,
                          spacing: 0.0)
                    ],
                  )
                ]),
      actions: <Widget>[
        FlatButton(
          child: const Text('CANCEL'),
          onPressed: () {
            Navigator.of(context).pop(ConfirmAction.CANCEL);
          },
        ),
        FlatButton(
          child: const Text('RATE'),
          onPressed: () {
            Navigator.of(context).pop(ConfirmAction.ACCEPT);
            _setRating();
          },
        )
      ],
    );
  }

  _setRating() async {
    try {
      List<Map<String, dynamic>> body = new List<Map<String, dynamic>>();
      if (widget.isBus) {
        body.add(new RatingJSON(
                dbRouteId: busRoute.dbRouteId, rating: busRoute.rating)
            .toJson());
        body.add(new RatingJSON(
                dbRouteId: busRoute.toFirstStop[0].dbRouteId,
                rating: busRoute.toFirstStop[0].rating)
            .toJson());
        body.add(new RatingJSON(
                dbRouteId: busRoute.fromLastStop[0].dbRouteId,
                rating: busRoute.fromLastStop[0].rating)
            .toJson());
      } else {
        body.add(new RatingJSON(
                dbRouteId: walkPath.dbRouteId, rating: walkPath.rating)
            .toJson());
      }

      FirebaseUser user = await UserService.currentUser();

      Response response = await Dio().post(Constants.serverUrl + "/saveRating",
          data: {"rating": body, "firebaseId": user.uid});
      if (response.statusCode == 200) {}
    } catch (exception) {
      print(exception);
    }
  }
}

class RatingJSON {
  double rating;
  String dbRouteId;

  RatingJSON({this.dbRouteId, this.rating});

  Map<String, dynamic> toJson() => {
        'dbRouteId': dbRouteId,
        'rating': rating,
      };
}
