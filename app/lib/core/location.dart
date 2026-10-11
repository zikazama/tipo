import 'package:geolocator/geolocator.dart';

class LocatedPoint {
  const LocatedPoint(this.lat, this.lng, this.accuracyM);
  final double lat;
  final double lng;
  final double accuracyM;
}

/// Device GPS behind an interface so tests and kiosks can swap it out.
class Locator {
  const Locator();

  /// Returns null when location is off, denied, or slow. The report form then
  /// keeps the place the citizen picked.
  Future<LocatedPoint?> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      return LocatedPoint(pos.latitude, pos.longitude, pos.accuracy);
    } catch (_) {
      return null;
    }
  }
}
