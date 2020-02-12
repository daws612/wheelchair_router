import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLocationLoggerService {
  static final _auth = FirebaseAuth.instance;
  

  static void logCurrentLocation(currentLocation, origin, destination) {
      _auth.currentUser().then((onValue) {
            String userId = onValue.uid;
            String params = "?userId=" +
              userId +
              '&origin=' +
              origin +
              '&destination=' +
              destination;
            var url = 'https://api.jaywjay.com/wheelchair//userLocationLogger$params';
            print("Saving user location - " + url);
             try {
              Dio().get(url);            
          } catch (exception) {
              print(exception);
          }
        });
  }
}