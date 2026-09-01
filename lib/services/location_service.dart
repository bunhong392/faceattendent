import 'package:geolocator/geolocator.dart';

/// Result of checking whether the device is ready to provide a GPS fix
/// before letting someone attempt a check-in/check-out.
enum LocationReadiness {
  ready,
  serviceDisabled, // device location (GPS) toggle is off
  permissionDenied, // user hasn't granted the permission (yet)
  permissionDeniedForever, // user permanently denied it — needs App Settings
}

/// Wraps GPS location checks used to validate that a check-in/check-out is
/// happening within an authorized area (geofence), per the schedule's
/// latitude/longitude/radiusMeters fields.
class LocationService {
  LocationService._();

  /// Checks — and where possible requests — everything needed for a GPS fix
  /// to succeed: the device's location service being turned on, and the
  /// app having permission to read it. Employees/members must pass this
  /// check before they're allowed to attempt a face check-in/check-out,
  /// regardless of whether the specific schedule enforces a geofence.
  static Future<LocationReadiness> checkReadiness() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return LocationReadiness.serviceDisabled;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationReadiness.permissionDeniedForever;
      }
      if (permission == LocationPermission.denied) {
        return LocationReadiness.permissionDenied;
      }
      return LocationReadiness.ready;
    } catch (_) {
      return LocationReadiness.serviceDisabled;
    }
  }

  /// Opens the device's location (GPS) settings screen so the user can turn
  /// it on.
  static Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  /// Opens this app's settings screen so the user can grant location
  /// permission after having permanently denied it.
  static Future<void> openAppSettings() => Geolocator.openAppSettings();

  /// Requests permission (if needed) and returns the device's current
  /// position, or null if location is unavailable/denied. Never throws.
  static Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  /// Distance in meters between two coordinates.
  static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Returns true if [position] is within [radiusMeters] of
  /// ([targetLat], [targetLng]).
  static bool isWithinGeofence({
    required Position position,
    required double targetLat,
    required double targetLng,
    required double radiusMeters,
  }) {
    final d = distanceMeters(position.latitude, position.longitude, targetLat, targetLng);
    return d <= radiusMeters;
  }
}
