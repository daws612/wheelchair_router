import 'package:expandable/expandable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:routing/models/AllRoutesJSON.dart';

import 'BusRouteDetails.dart';

class RouteDetails extends StatelessWidget {
  RouteDetails(
      {Key key, this.allRoutes, this.index, this.radioValue, this.onClicked})
      : super(key: key);

  final AllRoutesJSON allRoutes;
  final int index;
  final int radioValue;
  final VoidCallback onClicked;

  @override
  Widget build(BuildContext context) {
    GlobalKey _keyTile = GlobalKey();
    //final RenderBox renderBoxRed = _keyTile.currentContext.findRenderObject();

    double maxh = MediaQuery.of(context).size.height - 450;
    int h = allRoutes.busRoutes.length * 200;

    return ListView(padding: EdgeInsets.all(8.0), children: <Widget>[
      ExpansionTile(title: Text("Bus routes"), children: <Widget>[
        SizedBox(
            height: h.toDouble() > maxh ? maxh : h.toDouble(),
            child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.all(0),
                itemCount: allRoutes.busRoutes.length, // records.length
                itemBuilder: (BuildContext context, int i) {
                  return BusRouteDetails(
                    route: allRoutes.busRoutes[i],
                    index: i,
                    radioValue: radioValue,
                    onClicked: () {
                      onClicked();
                    },
                  );
                })),
      ]),
      ExpansionTile(
        key: _keyTile,
        title: Text("Only walking"),
        children: <Widget>[
          SizedBox(
              height: h.toDouble() > maxh ? maxh : h.toDouble(),
              child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.all(0),
                  itemCount: allRoutes.busRoutes.length, // records.length
                  itemBuilder: (BuildContext context, int i) {
                    return BusRouteDetails(
                      route: allRoutes.busRoutes[i],
                      index: i,
                      radioValue: radioValue,
                      onClicked: () {
                        onClicked();
                      },
                    );
                  }))
        ],
      )
    ]);
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
