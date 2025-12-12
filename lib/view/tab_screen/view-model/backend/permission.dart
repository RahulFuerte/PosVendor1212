import 'package:permission_handler/permission_handler.dart';

class Permissions {
  bool _checkStatus(PermissionStatus status) {
    if (status.isDenied ||
        status.isRestricted ||
        status.isPermanentlyDenied ||
        status.isLimited) {
      return false;
    }
    return true;
  }

  Future<bool> requestSms() async {
    //checking, if found then okay else request again
    PermissionStatus ps = await Permission.sms.status;
    if (_checkStatus(ps)) {
      return true;
    } else {
      await Permission.sms.request();
    }
    ps = await Permission.sms.status;
    return _checkStatus(ps);
  }

  Future<bool> checkSms() async {
    return _checkStatus(await Permission.sms.status);
  }

  Future<bool> requestLocation() async {
    PermissionStatus ps = await Permission.location.status;
    if (_checkStatus(ps)) {
      return true;
    } else {
      await Permission.location.request();
    }
    ps = await Permission.location.status;
    return _checkStatus(ps);
  }

  Future<bool> requestCamera() async {
    PermissionStatus ps = await Permission.camera.status;
    if (_checkStatus(ps)) {
      return true;
    } else {
      await Permission.camera.request();
    }
    ps = await Permission.camera.status;
    return _checkStatus(ps);
  }

  Future<bool> checkLocation() async {
    return _checkStatus(await Permission.location.status);
  }

  Future<bool> checkCamera() async {
    return _checkStatus(await Permission.camera.status);
  }
}
