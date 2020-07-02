import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:routing/models/AllRoutesJSON.dart';
import 'package:routing/screens/WalkingDirections.dart';

import 'BusRouteDetails.dart';

class RouteDetails extends StatelessWidget {
  RouteDetails(
      {Key key,
      this.allRoutes,
      this.radioValue,
      this.onClicked,
      this.rateRouteClicked})
      : super(key: key);

  final RoutesWithRecommended allRoutes;
  final int radioValue;
  final Function(int) onClicked;
  final Function(int, bool) rateRouteClicked;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: EdgeInsets.all(8.0), children: <Widget>[
      allRoutes.recommendations.busRoutes.length > 0 ||
              allRoutes.recommendations.walkingDirections.length > 0
          ?  Text(
                "Recommended Routes",
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              )
            
          : Container(
              width: 0,
              height: 0,
            ),
      walkDetails(context, allRoutes.recommendations.walkingDirections),
      busDetails(context, allRoutes.recommendations.busRoutes),
      Text(
          allRoutes.recommendations.busRoutes.length > 0 ||
                  allRoutes.recommendations.walkingDirections.length > 0
              ? "Other Routes Found"
              : "Routes Found",
          textAlign: TextAlign.left,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      walkDetails(context, allRoutes.walkingDirections),
      busDetails(context, allRoutes.busRoutes),
    ]);
  }

  Widget busDetails(BuildContext context, List<BusRoutesJSON> busRoutes) {
    double maxh = MediaQuery.of(context).size.height - 450;
    int h = busRoutes.length * 200;
    return busRoutes.length > 0
        ? ExpansionTile(
            title: Text(busRoutes.length.toString() + " bus routes"),
            children: <Widget>[
                SizedBox(
                    height: h.toDouble() > maxh ? maxh : h.toDouble(),
                    child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.all(0),
                        itemCount: busRoutes.length, // records.length
                        itemBuilder: (BuildContext context, int i) {
                          return BusRouteDetails(
                            route: busRoutes[i],
                            radioValue: radioValue,
                            onClicked: (value) {
                              onClicked(value);
                            },
                            rateRouteClicked: (value, isBus) {
                              rateRouteClicked(value, isBus);
                            },
                          );
                        })),
              ])
        : Container();
  }

  Widget walkDetails(
      BuildContext context, List<WalkPathJSON> walkingDirections) {
    double maxwh = MediaQuery.of(context).size.height - 650;
    int wh = walkingDirections.length * 100;
    return walkingDirections.length > 0
        ? ExpansionTile(
            title: Text(
                walkingDirections.length.toString() + " options without bus"),
            children: <Widget>[
              SizedBox(
                  height: wh.toDouble() > maxwh ? maxwh : wh.toDouble(),
                  child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.all(0),
                      itemCount: walkingDirections.length, // records.length
                      itemBuilder: (BuildContext context, int i) {
                        return WalkingDirections(
                          route: walkingDirections[i],
                          radioValue: radioValue,
                          onClicked: (value) {
                            onClicked(value);
                          },
                          rateRouteClicked: (value, isBus) {
                            rateRouteClicked(value, isBus);
                          },
                        );
                      }))
            ],
          )
        : Container();
  }
}

// allRoutes.busRoutes
//               .map((data) => BusRouteDetails(
//                     route: data,
//                     radioValue: radioValue,
//                     onClicked: () {
//                       onClicked();
//                     },
//                   ))
//               .toList()
