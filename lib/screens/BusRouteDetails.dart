import 'package:charts_flutter/flutter.dart';
import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:routing/models/AllRoutesJSON.dart';

class BusRouteDetails extends StatelessWidget {
  BusRouteDetails({Key key, this.route, this.radioValue, this.onClicked, this.rateRouteClicked})
      : super(key: key);

  final BusRoutesJSON route;
  final int radioValue;
  final Function(int) onClicked;
  final Function(int, bool) rateRouteClicked;

  @override
  Widget build(BuildContext context) {
    List<Series<PolylineJSON, int>> data = [
      new Series<PolylineJSON, int>(
        id: 'Slope',
        colorFn: (_, __) => MaterialPalette.blue.shadeDefault,
        domainFn: (PolylineJSON line, _) => line.pathIndex,
        measureFn: (PolylineJSON line, _) => line.slope,
        data: route.toFirstStop[0].pathData,
      )
    ];

    return Card(
        child: InkWell(
            onTap: () => onClicked(route.routeIndex),
            child: Padding(
                padding: const EdgeInsets.all(0),
                child: SizedBox(
                    height: 200,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                CircleAvatar(
                                  backgroundColor: Colors.transparent,
                                  backgroundImage: AssetImage(
                                      'assets/images/accessible1.png'),
                                ),
                                new Radio(
                                  value: route.routeIndex,
                                  groupValue: radioValue,
                                  onChanged: (value) {
                                    onClicked(value);
                                  },
                                ),
                              ]),
                          Expanded(
                            child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    20.0, 0.0, 2.0, 0.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      flex: 1,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: <Widget>[
                                          Text(
                                            "Route: " +
                                                route.routeShortName +
                                                " - " +
                                                route.routeLongName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            "To " +
                                                route.stops[0].stopName +
                                                ": " +
                                                _printDistance(route
                                                        .toFirstStop[0]
                                                        .distanceM)
                                                    .toString() +
                                                " in " +
                                                printDuration(
                                                    Duration(
                                                        seconds: route
                                                            .toFirstStop[0]
                                                            .durationSec),
                                                    abbreviated: true),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            "Bus Time From: " +
                                                route.departureTime +
                                                " to " +
                                                route.arrivalTime,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            "From " +
                                                route
                                                    .stops[
                                                        route.stops.length - 1]
                                                    .stopName +
                                                ": " +
                                                _printDistance(route
                                                        .fromLastStop[0]
                                                        .distanceM)
                                                    .toString() +
                                                " in " +
                                                printDuration(
                                                    Duration(
                                                        seconds: route
                                                            .fromLastStop[0]
                                                            .durationSec),
                                                    abbreviated: true),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Expanded(
                                    //     flex: 10,
                                    //     child: LineChart(
                                    //       data,
                                    //       animate: true,
                                    //       animationDuration:
                                    //           Duration(seconds: 2),
                                    //       behaviors: <ChartBehavior> [

                                    //       ],
                                    //     )),
                                  ],
                                )),
                          ),
                          Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                GestureDetector(
                                  onTap: () {
                                    rateRouteClicked(route.routeIndex, true);
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(5, 5, 15, 20),
                                    child: CircleAvatar(
                                      radius: 15.0,
                                      backgroundColor:
                                          Theme.of(context).primaryColor,
                                      child: Icon(
                                        Icons.star,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ]),
                        ])))));
  }

  String _printDistance(int distanceMeters) {
    if (distanceMeters < 1000)
      return distanceMeters.toString() + "m";
    else {
      double km = distanceMeters / 1000;
      return km.toString() + "km";
    }
  }
}
