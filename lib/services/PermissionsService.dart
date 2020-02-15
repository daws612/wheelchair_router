import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  final PermissionHandler _permissionHandler = new PermissionHandler();

  Future<bool> requestPermission(List<PermissionGroup> _permissionGroup) async {
    var result = await _permissionHandler.requestPermissions(_permissionGroup);
    var checkIfAllGranted = await getPermissionsToAsk(_permissionGroup);
    if (checkIfAllGranted.length == 0) return true;
    return false;
  }

  Future<List<PermissionGroup>> getPermissionsToAsk(
      List<PermissionGroup> permissionGroupList) async {
    List<PermissionGroup> needToAsk = [];
    for (PermissionGroup permissionGroup in permissionGroupList) {
      var result =
          await _permissionHandler.checkPermissionStatus(permissionGroup);
      if (result != PermissionStatus.granted) {
        needToAsk.add(permissionGroup);
      }
    }
    return needToAsk;
  }

  void openAppSettings() {
    _permissionHandler.openAppSettings();
  }
}
