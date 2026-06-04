import 'package:flutter/foundation.dart';

class LocationService extends ChangeNotifier {
  LocationService._();
  static final LocationService instance = LocationService._();

  double? _lat;
  double? _lon;

  double? get lat => _lat;
  double? get lon => _lon;

  bool get hasLocation => _lat != null && _lon != null;

  void update(double latitude, double longitude) {
    _lat = latitude;
    _lon = longitude;
    notifyListeners();
  }
}
