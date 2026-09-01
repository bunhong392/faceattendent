import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Produces a stable identifier for the current device/install, used for
/// optional "device validation" (binding a user's face check-in to the
/// device they enrolled on, to reduce someone else using a copied face
/// profile from a different device — see README "Notes on the face
/// recognition approach" for what this does and doesn't protect against).
class DeviceService {
  DeviceService._();
  static final _plugin = DeviceInfoPlugin();

  static String? _cached;

  static Future<String?> getDeviceId() async {
    if (_cached != null) return _cached;
    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        // androidId is per-app-install on modern Android, which is enough
        // to detect "a different physical device or a reinstall", the
        // signal this check actually cares about.
        _cached = info.id;
      } else if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        _cached = info.identifierForVendor;
      }
    } catch (_) {
      _cached = null;
    }
    return _cached;
  }
}
