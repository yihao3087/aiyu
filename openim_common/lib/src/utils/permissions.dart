import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sprintf/sprintf.dart';
import 'package:synchronized/synchronized.dart';

class Permissions {
  Permissions._();
  static final Lock _permissionLock = Lock();

  static Future<PermissionStatus> _request(Permission permission) {
    return _permissionLock.synchronized(() => permission.request());
  }

  static Future<Map<Permission, PermissionStatus>> _requestAll(List<Permission> permissions) {
    return _permissionLock.synchronized(() => permissions.request());
  }

  static Future<PermissionStatus> requestSingle(Permission permission) => _request(permission);

  static Future<bool> checkSystemAlertWindow() async {
    return Permission.systemAlertWindow.isGranted;
  }

  static Future<bool> ensureSystemAlertWindow() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.systemAlertWindow.status;
    if (status.isGranted) {
      return true;
    }
    final result = await _request(Permission.systemAlertWindow);
    if (result.isGranted) {
      return true;
    }
    IMViews.showToast(StrRes.floatingWindowPermissionHint);
    return false;
  }

  static Future<bool> checkStorage() async {
    return await Permission.storage.isGranted;
  }

  static void camera(Function()? onGranted) async {
    final status = await _request(Permission.camera);
    if (status.isGranted) {
      onGranted?.call();
    }
    if (status.isPermanentlyDenied || status.isDenied) {
      _showPermissionDeniedDialog(Permission.camera.title);
    }
  }

  static void storage(Function()? onGranted) async {
    if (!Platform.isAndroid) {
      onGranted?.call();
    } else {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      late Permission permisson;

      if (androidInfo.version.sdkInt <= 32) {
        permisson = Permission.storage;
      } else {
        permisson = Permission.manageExternalStorage;
      }
      final status = await _request(permisson);
      if (status.isGranted) {
        onGranted?.call();
      }
      if (status.isPermanentlyDenied || status.isDenied) {
        _showPermissionDeniedDialog(permisson.title);
      }
    }
  }

  static void manageExternalStorage(Function()? onGranted) async {
    final status = await _request(Permission.manageExternalStorage);
    if (status.isGranted) {
      onGranted?.call();
    }
    if (status.isPermanentlyDenied || status.isDenied) {
      _showPermissionDeniedDialog(Permission.storage.title);
    }
  }

  static void microphone(Function()? onGranted) async {
    final status = await _request(Permission.microphone);
    if (status.isGranted) {
      onGranted?.call();
    }
    if (status.isPermanentlyDenied || status.isDenied) {
      _showPermissionDeniedDialog(Permission.microphone.title);
    }
  }

  static void location(Function()? onGranted) async {
    final before = await Permission.location.status;
    debugPrint('[Permissions.location] before request: $before');

    PermissionStatus status = before;
    if (!status.isGranted && !status.isLimited) {
      status = await _request(Permission.location);
      debugPrint('[Permissions.location] after first request: $status');
      if (status == PermissionStatus.denied) {
        status = await _request(Permission.location);
        debugPrint('[Permissions.location] after second request: $status');
      }
      if (status == PermissionStatus.denied ||
          status == PermissionStatus.restricted) {
        final serviceStatus = await Permission.locationWhenInUse.serviceStatus;
        debugPrint('[Permissions.location] location service status: $serviceStatus');
        if (serviceStatus == ServiceStatus.enabled) {
          status = await _request(Permission.locationAlways);
          debugPrint('[Permissions.location] after fallback request: $status');
        }
      }
    }

    if (status.isGranted || status.isLimited) {
      debugPrint('[Permissions.location] granted, execute callback');
      onGranted?.call();
    } else if (status.isPermanentlyDenied ||
        status.isDenied ||
        status.isRestricted) {
      debugPrint('[Permissions.location] denied, show dialog');
      _showPermissionDeniedDialog(Permission.location.title);
    }
  }

  static void speech(Function()? onGranted) async {
    final status = await _request(Permission.speech);
    if (status.isGranted) {
      onGranted?.call();
    }
    if (status.isPermanentlyDenied || status.isDenied) {
      _showPermissionDeniedDialog(Permission.speech.title);
    }
  }

  static void photos(Function()? onGranted) async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 32) {
        storage(onGranted);
      } else {
        final status = await _request(Permission.photos);
        if (status.isGranted || status.isLimited) {
          onGranted?.call();
        } else if (status.isPermanentlyDenied || status.isDenied) {
          _showPermissionDeniedDialog(Permission.photos.title);
        }
      }
    } else {
      final status = await _request(Permission.photos);
      if (status.isGranted || status.isLimited) {
        onGranted?.call();
      } else if (status.isPermanentlyDenied || status.isDenied) {
        _showPermissionDeniedDialog(Permission.photos.title);
      }
    }
  }

  static Future<bool> notification() async {
    final status = await _request(Permission.notification);
    if (status.isGranted) {
      return true;
    }
    if (status.isPermanentlyDenied || status.isDenied) {
      _showPermissionDeniedDialog(Permission.notification.title);
    }

    return false;
  }

  static void ignoreBatteryOptimizations(Function()? onGranted) async {
    final status = await _request(Permission.ignoreBatteryOptimizations);
    if (status.isGranted) {
      onGranted?.call();
    }
    if (status.isPermanentlyDenied) {}
  }

  static void cameraAndMicrophone(Function()? onGranted) async {
    final permissions = [
      Permission.camera,
      Permission.microphone,
    ];
    bool isAllGranted = true;
    var msg = '';

    for (var permission in permissions) {
      final state = await _request(permission);
      final granted = state.isGranted || state.isLimited;
      isAllGranted = isAllGranted && granted;
      if (!granted) {
        msg += '${permission.title}、';
      }
    }
    if (isAllGranted) {
      onGranted?.call();
    } else {
      msg = msg.substring(0, msg.length - 1);
      _showPermissionDeniedDialog(msg);
    }
  }

  static Future<bool> media() async {
    final permissions = [
      Permission.camera,
      Permission.microphone,
    ];
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 32) {
        permissions.add(Permission.storage);
      } else {
        permissions.add(Permission.photos);
      }
    } else {
      permissions.add(Permission.photos);
    }

    bool isAllGranted = true;
    var msg = '';

    for (var permission in permissions) {
      final state = await _request(permission);
      isAllGranted = isAllGranted && state.isGranted;
      if (!state.isGranted) {
        msg += '${permission.title}、';
      }
    }

    if (!isAllGranted) {
      msg = msg.substring(0, msg.length - 1);
      _showPermissionDeniedDialog(msg);
    }

    return isAllGranted;
  }

  static void storageAndMicrophone(Function()? onGranted) async {
    final permissions = [
      Permission.microphone,
    ];

    final androidInfo = await DeviceInfoPlugin().androidInfo;

    if (androidInfo.version.sdkInt <= 32) {
      permissions.add(Permission.storage);
    } else {
      permissions.add(Permission.manageExternalStorage);
    }

    bool isAllGranted = true;
    var msg = '';

    for (var permission in permissions) {
      final state = await _request(permission);
      isAllGranted = isAllGranted && state.isGranted;
      if (!state.isGranted) {
        msg += '${permission.title}、';
      }
    }
    if (isAllGranted) {
      onGranted?.call();
    } else {
      msg = msg.substring(0, msg.length - 1);
      _showPermissionDeniedDialog(msg);
    }
  }

  static Future<Map<Permission, PermissionStatus>> request(List<Permission> permissions) async {
    Map<Permission, PermissionStatus> statuses = await _requestAll(permissions);
    return statuses;
  }

  static void _showPermissionDeniedDialog(String tips) {
    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(StrRes.permissionDeniedTitle),
          content: Text(
            sprintf(StrRes.permissionDeniedHint, [tips]),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(StrRes.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(StrRes.determine),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }
}

extension PermissionExt on Permission {
  String get title {
    switch (this) {
      case Permission.storage:
        return StrRes.externalStorage;
      case Permission.photos:
        return StrRes.gallery;
      case Permission.camera:
        return StrRes.camera;
      case Permission.microphone:
        return StrRes.microphone;
      case Permission.notification:
        return StrRes.notification;
      default:
        return '';
    }
  }
}


