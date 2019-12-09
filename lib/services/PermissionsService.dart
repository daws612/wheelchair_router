import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  final PermissionHandler _permissionHandler = new PermissionHandler();

  Future<bool> requestPermission(PermissionGroup _permissionGroup) async{
    var result = await _permissionHandler.requestPermissions([_permissionGroup]);
    if(result[_permissionGroup] == PermissionStatus.granted)
      return true;
    return false;
  }

  Future<bool> hasPermission(PermissionGroup permissionGroup) async{
    var result = await _permissionHandler.checkPermissionStatus(permissionGroup);
    return result == PermissionStatus.granted;
  }

  void openAppSettings() {
    _permissionHandler.openAppSettings();
  }
}