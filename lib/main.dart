import 'package:flutter/material.dart';
import 'services/UserService.dart';
import 'package:routing/screens/MainScreen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

const primaryColor = const Color(0xFF00AA4F);
const accentColor = const Color(0xff5f7676);

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    UserService.anonymousLogin();
    return MaterialApp(
      title: 'Wheelchair Router',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primaryColor: primaryColor,
        accentColor: accentColor,
      ),
      home: MainScreen(title: 'Maps Page'),
    );
  }
}
