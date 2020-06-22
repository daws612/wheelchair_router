import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:routing/models/AllRoutesJSON.dart';

class WalkingDirections extends StatelessWidget {
  WalkingDirections({Key key, this.route, this.radioValue, this.onClicked, this.rateRouteClicked})
      : super(key: key);

  final WalkPathJSON route;
  final int radioValue;
  final Function(int) onClicked;
  final Function(int, bool) rateRouteClicked;

  @override
  Widget build(BuildContext context) {
    return Card(
        child: InkWell(
            onTap: () => onClicked(route.routeIndex),
            child: Padding(
                padding: const EdgeInsets.all(0),
                child: SizedBox(
                    height: 100,
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
                                            "Route total distance " +
                                                _printDistance(route.distanceM),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            "Route total duration " +
                                                printDuration(Duration(
                                                    seconds:
                                                        route.durationSec)),
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
                                    rateRouteClicked(route.routeIndex, false);
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
    if(distanceMeters == null)
      return "??m";
    if (distanceMeters < 1000)
      return distanceMeters.toString() + "m";
    else {
      double km = distanceMeters / 1000;
      return km.toString() + "km";
    }
  }
}
