class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  double? lat;
  double? lon;

  bool get hasLocation => lat != null && lon != null;
}
