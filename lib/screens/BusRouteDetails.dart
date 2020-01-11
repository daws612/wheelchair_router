import 'package:charts_flutter/flutter.dart';
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
                                        children: <Widget>[
                                          Text(
                                            "Route: "  + route.routeShortName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )),
                          )
                        ])))));
  }
}
