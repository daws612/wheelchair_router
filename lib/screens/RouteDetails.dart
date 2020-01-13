import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:routing/models/AllRoutesJSON.dart';
import 'package:routing/screens/WalkingDirections.dart';

import 'BusRouteDetails.dart';

class RouteDetails extends StatelessWidget {
  RouteDetails({Key key, this.allRoutes, this.radioValue, this.onClicked})
      : super(key: key);

  final AllRoutesJSON allRoutes;
  final int radioValue;
  final Function(int) onClicked;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: EdgeInsets.all(8.0), children: <Widget>[
      walkDetails(context),
      busDetails(context),
    ]);
  }

  Widget busDetails(BuildContext context) {
    double maxh = MediaQuery.of(context).size.height - 450;
    int h = allRoutes.busRoutes.length * 200;
    return allRoutes.busRoutes.length > 0
        ? ExpansionTile(title: Text(allRoutes.busRoutes.length.toString() + " bus routes"), children: <Widget>[
            SizedBox(
                height: h.toDouble() > maxh ? maxh : h.toDouble(),
                child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.all(0),
                    itemCount: allRoutes.busRoutes.length, // records.length
                    itemBuilder: (BuildContext context, int i) {
                      return BusRouteDetails(
                        route: allRoutes.busRoutes[i],
                        radioValue: radioValue,
                        onClicked: (value) {
                          onClicked(value);
                        },
                      );
                    })),
          ])
        : Container();
  }

  Widget walkDetails(BuildContext context) {
    double maxwh = MediaQuery.of(context).size.height - 650;
    int wh = allRoutes.walkingDirections.length * 100;
    return allRoutes.walkingDirections.length > 0
        ? ExpansionTile(
            title: Text(allRoutes.walkingDirections.length.toString() +
                " options without bus"),
            children: <Widget>[
              SizedBox(
                  height: wh.toDouble() > maxwh ? maxwh : wh.toDouble(),
                  child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.all(0),
                      itemCount:
                          allRoutes.walkingDirections.length, // records.length
                      itemBuilder: (BuildContext context, int i) {
                        return WalkingDirections(
                          route: allRoutes.walkingDirections[i],
                          radioValue: radioValue,
                          onClicked: (value) {
                            onClicked(value);
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
