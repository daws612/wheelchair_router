import 'package:flutter/material.dart';
import 'services/UserService.dart';
import 'package:routing/screens/MainScreen.dart';
import 'package:f_logs/f_logs.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  init();
  runApp(MyApp());
}

init() {
  LogsConfig config = FLog.getDefaultConfigurations()
    ..isDevelopmentDebuggingEnabled = true
    ..timestampFormat = TimestampFormat.TIME_FORMAT_FULL_3
    ..formatType = FormatType.FORMAT_CUSTOM
    ..fieldOrderFormatCustom = [
      FieldName.TIMESTAMP,
      FieldName.LOG_LEVEL,
      FieldName.CLASSNAME,
      FieldName.METHOD_NAME,
      FieldName.TEXT,
      FieldName.EXCEPTION,
      FieldName.STACKTRACE
    ]
    ..customOpeningDivider = "|"
    ..customClosingDivider = "|";

  FLog.applyConfigurations(config);

  FLog.logThis(
    className: "Main",
    methodName: "init",
    text: "Device",
    type: LogLevel.INFO,
    dataLogType: DataLogType.DEVICE.toString(),
  );
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
