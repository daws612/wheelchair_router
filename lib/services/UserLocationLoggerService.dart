import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:routing/Constants.dart';
import 'package:routing/services/UserService.dart';

class UserLocationLoggerService {
  static Future<void>logCurrentLocation(Geolocator _geolocator, String origin, String destination) async {
     String userId = await UserService.getFirebaseUserId();
     Position _currentLocationPos = await _geolocator.getLastKnownPosition();
     if(_currentLocationPos == null)
      return;
     String _currentLocation = _currentLocationPos.latitude.toString() + "," + _currentLocationPos.longitude.toString();
      print("Logging location: currentLocation: $_currentLocation:  Origin: $origin, Destination: $destination UserID: $userId");
      String params = "?userId=" +
              userId +
              '&origin=' +
              origin +
              '&destination=' +
              destination;
            var url = Constants.serverUrl +'/userLocationLogger$params';
            print("Saving user location - " + url);
             try {
              Dio().get(url);            
          } catch (exception) {
              print(exception);
          }
  }
}