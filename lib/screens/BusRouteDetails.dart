import 'package:charts_flutter/flutter.dart';
import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:routing/models/BusRoutesJSON.dart';

class BusRouteDetails extends StatelessWidget {
  BusRouteDetails(
      {Key key, this.route, this.index, this.radioValue, this.onClicked})
      : super(key: key);

  final RoutesJSON route;
  final int index;
  final int radioValue;
  final VoidCallback onClicked;

  @override
  Widget build(BuildContext context) {
    List<Series<PolylineJSON, int>> data = [
      new Series<PolylineJSON, int>(
        id: 'Slope',
        colorFn: (_, __) => MaterialPalette.blue.shadeDefault,
        domainFn: (PolylineJSON line, _) => line.pathIndex,
        measureFn: (PolylineJSON line, _) => line.slope,
        data: route.toFirstStop.pathData,
      )
    ];

    return Card(
        child: InkWell(
            onTap: () => onClicked(),
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
                                  value: index,
                                  groupValue: radioValue,
                                  onChanged: (value) {
                                    onClicked();
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
                                            "To " + route.toFirstStop.stop.stopName + ": " +
                                                _printDistance(route.toFirstStop.distanceM)
                                                    .toString() +
                                                " in " + printDuration(Duration(
                                                    seconds: route.toFirstStop
                                                        .durationSec), abbreviated: true),
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
                                            "From " + route.fromLastStop.stop.stopName + ": " +
                                                _printDistance(route.fromLastStop.distanceM)
                                                    .toString() +
                                                " in " +
                                                printDuration(Duration(
                                                    seconds: route.fromLastStop
                                                        .durationSec), abbreviated: true),
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
                          )
                        ])))));
  }

  String _printDistance(int distanceMeters) {
    if(distanceMeters < 1000)
      return distanceMeters.toString() + "m";
    else{
      double km = distanceMeters/1000;
      return km.toString() + "km";
    }
  }
}
