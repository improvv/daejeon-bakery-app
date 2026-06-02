import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../api/bakery_repository.dart';
import '../theme/app_colors.dart';

enum TravelMode {
  walking('walking', '도보', Icons.directions_walk_rounded, Color(0xFFE8973A)),
  driving('driving', '차', Icons.directions_car_rounded, Color(0xFF1565C0)),
  transit('transit', '대중교통', Icons.directions_bus_rounded, Color(0xFF2E7D32));

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const TravelMode(this.value, this.label, this.icon, this.color);
}

class BakeryMapScreen extends StatefulWidget {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final bool showRoute;

  const BakeryMapScreen({
    super.key,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.showRoute = false,
  });

  @override
  State<BakeryMapScreen> createState() => _BakeryMapScreenState();
}

class _BakeryMapScreenState extends State<BakeryMapScreen> {
  final BakeryRepository _repository = BakeryRepository();
  GoogleMapController? _mapController;

  LatLng? _userLocation;
  List<LatLng> _routePoints = [];
  String? _distance;
  String? _duration;
  bool _isLoadingRoute = false;
  TravelMode _selectedMode = TravelMode.walking;

  late final LatLng _destLatLng = LatLng(widget.latitude, widget.longitude);

  @override
  void initState() {
    super.initState();
    if (widget.showRoute) _loadLocationAndRoute();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _repository.dispose();
    super.dispose();
  }

  Future<void> _loadLocationAndRoute({TravelMode? mode}) async {
    final targetMode = mode ?? _selectedMode;
    setState(() => _isLoadingRoute = true);
    try {
      if (_userLocation == null) {
        final permission = await Geolocator.checkPermission();
        if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
          setState(() => _isLoadingRoute = false);
          return;
        }
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (mounted) setState(() => _userLocation = LatLng(position.latitude, position.longitude));
      }

      final response = await _repository.getRoute(
        originLat: _userLocation!.latitude,
        originLon: _userLocation!.longitude,
        destLat: widget.latitude,
        destLon: widget.longitude,
        mode: targetMode.value,
      );

      if (response.isSuccess && response.data != null && mounted) {
        final data = response.data!;
        final points = (data['points'] as List<dynamic>).map((p) {
          final m = p as Map<String, dynamic>;
          return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
        }).toList();
        setState(() {
          _routePoints = points;
          _distance = data['distance'] as String?;
          _duration = data['duration'] as String?;
        });
        _fitBounds();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingRoute = false);
  }

  void _onModeChanged(TravelMode mode) {
    setState(() {
      _selectedMode = mode;
      _routePoints = [];
      _distance = null;
      _duration = null;
    });
    _loadLocationAndRoute(mode: mode);
  }

  void _fitBounds() {
    if (_mapController == null || _userLocation == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        min(_userLocation!.latitude, widget.latitude),
        min(_userLocation!.longitude, widget.longitude),
      ),
      northeast: LatLng(
        max(_userLocation!.latitude, widget.latitude),
        max(_userLocation!.longitude, widget.longitude),
      ),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Set<Marker> get _markers {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('bakery'),
        position: _destLatLng,
        infoWindow: InfoWindow(title: widget.name, snippet: widget.address),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    };
    if (_userLocation != null && widget.showRoute) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: _userLocation!,
        infoWindow: const InfoWindow(title: '내 위치'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }
    return markers;
  }

  Set<Polyline> get _polylines {
    if (_routePoints.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: _selectedMode.color,
        width: 5,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _destLatLng, zoom: 16.0),
            markers: _markers,
            polylines: _polylines,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              controller.showMarkerInfoWindow(const MarkerId('bakery'));
              if (_userLocation != null) _fitBounds();
            },
          ),

          // X 버튼
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.close_rounded, color: AppColors.textPrimary, size: 20),
              ),
            ),
          ),

          // 이동수단 선택 (길찾기 모드일 때만)
          if (widget.showRoute)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: TravelMode.values.map((mode) {
                      final isSelected = mode == _selectedMode;
                      return GestureDetector(
                        onTap: _isLoadingRoute ? null : () => _onModeChanged(mode),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? mode.color.withValues(alpha: 0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(mode.icon, size: 18, color: isSelected ? mode.color : AppColors.textHint),
                              const SizedBox(width: 4),
                              Text(
                                mode.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                  color: isSelected ? mode.color : AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

          // 경로 탐색 중
          if (_isLoadingRoute)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 130,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _selectedMode.color)),
                      const SizedBox(width: 8),
                      const Text('경로 탐색 중', style: TextStyle(fontSize: 12, color: AppColors.textSec)),
                    ],
                  ),
                ),
              ),
            ),

          // 하단 카드
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(widget.address,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSec)),
                  if (widget.showRoute && _distance != null && _duration != null) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(_selectedMode.icon, size: 18, color: _selectedMode.color),
                        const SizedBox(width: 6),
                        Text(
                          '$_distance  ·  $_duration',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _selectedMode.color),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
