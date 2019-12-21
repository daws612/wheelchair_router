import 'package:charts_flutter/flutter.dart';
import 'package:flutter/material.dart';
import 'package:routing/models/RoutesJSON.dart';

class PathDetails extends StatelessWidget {
  PathDetails({Key key, this.route}) : super(key: key);

  final RoutesJSON route;

  @override
  Widget build(BuildContext context) {
   

    List<Series<PolylineJSON, int>> data = [
      new Series<PolylineJSON, int>(
        id: 'Slope',
        colorFn: (_, __) => MaterialPalette.blue.shadeDefault,
        domainFn: (PolylineJSON line, _) => line.pathIndex,
        measureFn: (PolylineJSON line, _) => line.elevation1,
        data: route.polylineJSON,
      )
    ];
  

    return Card(
        child: Padding(
            padding: const EdgeInsets.all(0),
            child: SizedBox(
                height: 200,
                
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      CircleAvatar(
                        backgroundColor: Colors.transparent,
                        backgroundImage:
                            AssetImage('assets/images/icons8-walking-50.png'),
                      ),
                      Expanded(
                        child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20.0, 0.0, 2.0, 0.0),
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
                                        "Route Distance: " +
                                            route.routeTotalDistance,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 10,
                                  child: LineChart(
                                    data, 
                                    animate: true, 
                                    animationDuration: Duration(seconds: 2),
                                    
                                  )
                                ),
                              ],
                            )),
                      )
                    ]))));
  }
}
