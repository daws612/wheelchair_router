import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class ImageViewer extends StatelessWidget {
  ImageViewer({Key key, this.imgList}) : super(key: key);

  final List<String> imgList;

  @override
  Widget build(BuildContext context) {
    final basicSlider = CarouselSlider(
      items: getImages(),
      autoPlay: false,
      enlargeCenterPage: true,
      viewportFraction: 0.9,
      aspectRatio: 2.0,
      initialPage: 0,
      scrollPhysics: BouncingScrollPhysics(),
      enableInfiniteScroll: false,
    );

    if (imgList.length > 0) {
      return Column(children: [
        basicSlider,
        // Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        //   Flexible(
        //     child: RaisedButton(
        //       onPressed: () => basicSlider.previousPage(
        //           duration: Duration(milliseconds: 300), curve: Curves.linear),
        //       child: Text('←'),
        //     ),
        //   ),
        //   Flexible(
        //     child: RaisedButton(
        //       onPressed: () => basicSlider.nextPage(
        //           duration: Duration(milliseconds: 300), curve: Curves.linear),
        //       child: Text('→'),
        //     ),
        //   ),
        //   // ...Iterable<int>.generate(imgList.length).map(
        //   //   (int pageIndex) => Flexible(
        //   //     child: RaisedButton(
        //   //       onPressed: () => basicSlider.animateToPage(pageIndex,
        //   //           duration: Duration(milliseconds: 300),
        //   //           curve: Curves.linear),
        //   //       child: Text("$pageIndex"),
        //   //     ),
        //   //   ),
        //   // ),
        // ]),
      ]);
    } else {
      return Container(
        width: 0,
        height: 0,
      );
    }
  }

  List<Widget> getImages() {
    List child = map<Widget>(
      imgList,
      (index, i) {
        return Container(
          margin: EdgeInsets.all(5.0),
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(5.0)),
            child: Stack(children: <Widget>[
              Image.asset(i, fit: BoxFit.cover, width: 1000.0),
              Positioned(
                bottom: 0.0,
                left: 0.0,
                right: 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(200, 0, 0, 0),
                        Color.fromARGB(0, 0, 0, 0)
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  padding:
                      EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                  child: Text(
                    'No. $index image',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    ).toList();
    return child;
  }

  List<T> map<T>(List list, Function handler) {
    List<T> result = [];
    for (var i = 0; i < list.length; i++) {
      result.add(handler(i, list[i]));
    }

    return result;
  }
}
