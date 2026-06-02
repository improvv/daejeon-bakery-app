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
  LatLngBounds? _pendingBounds;

  LatLng? _userLocation;
  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _steps = [];
  String? _distance;
  String? _duration;
  int? _transfers;
  bool _isLoadingRoute = false;
  bool _isNavigating = false;
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
          if (mounted) setState(() => _isLoadingRoute = false);
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
          _transfers = data['transfers'] as int?;
          _steps = (data['steps'] as List<dynamic>)
              .map((s) => s as Map<String, dynamic>)
              .toList();
        });
        _fitBounds();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingRoute = false);
  }

  void _fitBounds() {
    if (_userLocation == null) return;
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
    if (_mapController == null) {
      _pendingBounds = bounds;
    } else {
      Future.delayed(const Duration(milliseconds: 100), () {
        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      });
    }
  }

  void _onModeChanged(TravelMode mode) {
    setState(() {
      _selectedMode = mode;
      _routePoints = [];
      _steps = [];
      _distance = null;
      _duration = null;
      _transfers = null;
      _isNavigating = false;
    });
    _loadLocationAndRoute(mode: mode);
  }

  void _startNavigation() {
    setState(() => _isNavigating = true);
    if (_userLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 17.0),
      );
    }
  }

  IconData _maneuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'turn-left': return Icons.turn_left_rounded;
      case 'turn-right': return Icons.turn_right_rounded;
      case 'turn-slight-left': return Icons.turn_slight_left_rounded;
      case 'turn-slight-right': return Icons.turn_slight_right_rounded;
      case 'turn-sharp-left': return Icons.turn_sharp_left_rounded;
      case 'turn-sharp-right': return Icons.turn_sharp_right_rounded;
      case 'uturn-left': return Icons.u_turn_left_rounded;
      case 'uturn-right': return Icons.u_turn_right_rounded;
      case 'roundabout-left': return Icons.roundabout_left_rounded;
      case 'roundabout-right': return Icons.roundabout_right_rounded;
      case 'straight': return Icons.straight_rounded;
      case 'merge': return Icons.merge_rounded;
      case 'ramp-left': return Icons.ramp_left_rounded;
      case 'ramp-right': return Icons.ramp_right_rounded;
      case 'fork-left': return Icons.turn_left_rounded;
      case 'fork-right': return Icons.turn_right_rounded;
      default: return Icons.navigation_rounded;
    }
  }

  IconData _vehicleIcon(String? type) {
    switch (type) {
      case 'SUBWAY': case 'HEAVY_RAIL': return Icons.subway_rounded;
      case 'TRAM': case 'LIGHT_RAIL': return Icons.tram_rounded;
      default: return Icons.directions_bus_rounded;
    }
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
              if (_pendingBounds != null) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngBounds(_pendingBounds!, 80),
                  );
                  _pendingBounds = null;
                });
              } else if (_userLocation != null && widget.showRoute) {
                _fitBounds();
              }
            },
          ),

          // X 버튼
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () {
                if (_isNavigating) {
                  setState(() => _isNavigating = false);
                  _fitBounds();
                } else {
                  Navigator.pop(context);
                }
              },
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Icon(
                  _isNavigating ? Icons.arrow_back_rounded : Icons.close_rounded,
                  color: AppColors.textPrimary, size: 20,
                ),
              ),
            ),
          ),

          // 이동수단 선택 (길찾기 모드, 안내 중 아닐 때)
          if (widget.showRoute && !_isNavigating)
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? mode.color.withValues(alpha: 0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(mode.icon, size: 17, color: isSelected ? mode.color : AppColors.textHint),
                              const SizedBox(width: 4),
                              Text(mode.label, style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                color: isSelected ? mode.color : AppColors.textHint,
                              )),
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
              bottom: 150, left: 0, right: 0,
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

          // 안내 중 패널
          if (_isNavigating && _steps.isNotEmpty)
            _buildNavigationPanel(),

          // 하단 카드 (안내 중 아닐 때)
          if (!_isNavigating)
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
                    if (widget.showRoute && _distance != null) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(_selectedMode.icon, size: 18, color: _selectedMode.color),
                          const SizedBox(width: 6),
                          Text('$_distance  ·  $_duration',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _selectedMode.color)),
                          if (_transfers != null && _transfers! >= 0) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _transfers == 0 ? '환승 없음' : '환승 ${_transfers}회',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // 대중교통 경유 정보
                      if (_selectedMode == TravelMode.transit && _steps.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildTransitSummary(),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _steps.isEmpty ? null : _startNavigation,
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: const Text('안내 시작'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedMode.color,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
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

  Widget _buildTransitSummary() {
    final transitSteps = _steps.where((s) => s['transit'] != null).toList();
    if (transitSteps.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6, runSpacing: 4,
      children: transitSteps.map((step) {
        final t = step['transit'] as Map<String, dynamic>;
        final type = t['vehicleType'] as String?;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.creamFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_vehicleIcon(type), size: 14, color: AppColors.crustBrown),
              const SizedBox(width: 4),
              Text('${t['lineName']}  ${t['numStops']}정거장',
                  style: const TextStyle(fontSize: 11, color: AppColors.crustBrown, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNavigationPanel() {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.15,
      maxChildSize: 0.75,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, -4))],
          ),
          child: Column(
            children: [
              Container(
                width: 44, height: 5,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3)),
              ),
              // 전체 요약
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Icon(_selectedMode.icon, size: 20, color: _selectedMode.color),
                    const SizedBox(width: 8),
                    Text('$_distance  ·  $_duration',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _selectedMode.color)),
                    const Spacer(),
                    Text('${_steps.length}단계', style: const TextStyle(fontSize: 12, color: AppColors.textSec)),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              // 단계별 안내
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _steps.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider, indent: 60),
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    final transit = step['transit'] as Map<String, dynamic>?;
                    final maneuver = step['maneuver'] as String?;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: transit != null
                                  ? _selectedMode.color.withValues(alpha: 0.12)
                                  : AppColors.surfaceAlt,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              transit != null ? _vehicleIcon(transit['vehicleType'] as String?) : _maneuverIcon(maneuver),
                              size: 18,
                              color: transit != null ? _selectedMode.color : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (transit != null) ...[
                                  Text(
                                    '${_vehicleTypeName(transit['vehicleType'] as String?)} ${transit['lineName']} 탑승',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _selectedMode.color),
                                  ),
                                  const SizedBox(height: 3),
                                  Text('${transit['departureStop']} 승차 → ${transit['arrivalStop']} 하차',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSec)),
                                  const SizedBox(height: 2),
                                  Text('${transit['numStops']}정거장  ·  ${step['duration']}',
                                      style: TextStyle(fontSize: 12, color: _selectedMode.color, fontWeight: FontWeight.w500)),
                                ] else ...[
                                  Text(step['instruction'] as String,
                                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                                  const SizedBox(height: 3),
                                  Text(step['distance'] as String,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSec)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _vehicleTypeName(String? type) {
    switch (type) {
      case 'SUBWAY': case 'HEAVY_RAIL': return '지하철';
      case 'TRAM': case 'LIGHT_RAIL': return '트램';
      default: return '버스';
    }
  }
}
