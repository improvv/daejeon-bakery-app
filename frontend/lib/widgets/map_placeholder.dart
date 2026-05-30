import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/bakery.dart';

class MapPlaceholder extends StatefulWidget {
  final List<Bakery> bakeries;
  final List<Bakery> inactiveBakeries;
  final Function(Bakery)? onMarkerTap;
  final void Function(GoogleMapController)? onMapCreated;
  final LatLng? currentLocation;

  const MapPlaceholder({
    Key? key,
    this.bakeries = const [],
    this.inactiveBakeries = const [],
    this.onMarkerTap,
    this.onMapCreated,
    this.currentLocation,
  }) : super(key: key);

  @override
  State<MapPlaceholder> createState() => _MapPlaceholderState();
}

class _MapPlaceholderState extends State<MapPlaceholder> {
  GoogleMapController? _mapController;

  static const LatLng _daejeonCenter = LatLng(36.3271, 127.4275);
  static const double _defaultZoom = 14.0;

  // 현재 위치 마커 — 빵집 마커와 완전히 분리된 객체
  Marker? _currentLocationMarker;
  BitmapDescriptor? _currentLocationIcon;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocationIcon();
  }

  @override
  void didUpdateWidget(MapPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentLocation != oldWidget.currentLocation &&
        widget.currentLocation != null) {
      _updateCurrentLocationMarker(widget.currentLocation!);
    }
  }

  // 파란 점 + 흰 테두리 커스텀 아이콘 생성
  Future<void> _loadCurrentLocationIcon() async {
    const double size = 48.0;
    const double cx = size / 2;
    const double cy = size / 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    // 그림자
    canvas.drawCircle(
      const Offset(cx, cy + 1.5),
      size * 0.30,
      Paint()
        ..color = const Color(0xFFC8622A).withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // 크림 테두리 링
    canvas.drawCircle(
      const Offset(cx, cy),
      size * 0.36,
      Paint()..color = const Color(0xFFFDF0DC),
    );
    // 카라멜 채움
    canvas.drawCircle(
      const Offset(cx, cy),
      size * 0.30,
      Paint()..color = const Color(0xFFE8973A),
    );

    final img = await recorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;

    if (mounted) {
      setState(() {
        _currentLocationIcon =
            BitmapDescriptor.bytes(data.buffer.asUint8List());
      });
      // 아이콘 로드 후 이미 위치가 있으면 마커 적용
      if (widget.currentLocation != null) {
        _updateCurrentLocationMarker(widget.currentLocation!);
      }
    }
  }

  // 현재 위치 마커 생성/업데이트 — 항상 같은 MarkerId로 덮어써 중복 방지
  void _updateCurrentLocationMarker(LatLng position) {
    if (_currentLocationIcon == null) return;
    setState(() {
      _currentLocationMarker = _buildCurrentLocationMarker(position);
    });
  }

  Marker _buildCurrentLocationMarker(LatLng position) {
    return Marker(
      markerId: const MarkerId('current_location'), // 고정 ID → 중복 생성 방지
      position: position,
      icon: _currentLocationIcon!,
      anchor: const Offset(0.5, 0.5),
      zIndexInt: 10, // 빵집 마커보다 위에
      infoWindow: InfoWindow.noText,
      consumeTapEvents: false, // 탭해도 이벤트 전파
    );
  }

  // 빵집 마커 — 기존 로직 그대로 유지
  Set<Marker> _buildBakeryMarkers() {
    return widget.bakeries.map((bakery) {
      return Marker(
        markerId: MarkerId(bakery.id.toString()),
        position: LatLng(bakery.latitude, bakery.longitude),
        infoWindow: InfoWindow(
          title: bakery.name,
          snippet: '⭐ ${bakery.rating} · ${bakery.address}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () => widget.onMarkerTap?.call(bakery),
      );
    }).toSet();
  }

  // 비활성 마커 — 선택된 구 외 빵집을 흐릿하게 표시, 탭 불가
  Set<Marker> _buildInactiveMarkers() {
    return widget.inactiveBakeries.map((bakery) {
      return Marker(
        markerId: MarkerId('inactive_${bakery.id}'),
        position: LatLng(bakery.latitude, bakery.longitude),
        alpha: 0.3,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        consumeTapEvents: true,
        infoWindow: InfoWindow.noText,
      );
    }).toSet();
  }

  // 전체 마커 = 비활성 → 활성 → 현재 위치 순 (z-order)
  Set<Marker> _buildAllMarkers() {
    final markers = _buildInactiveMarkers();
    markers.addAll(_buildBakeryMarkers());
    if (_currentLocationMarker != null) {
      markers.add(_currentLocationMarker!);
    }
    return markers;
  }

  // 현재 위치 주변 반투명 halo Circle
  Set<Circle> _buildCircles() {
    if (widget.currentLocation == null) return {};
    return {
      Circle(
        circleId: const CircleId('current_location_halo'),
        center: widget.currentLocation!,
        radius: 120, // 미터 단위
        fillColor: const Color(0xFFE8973A).withValues(alpha: 0.10),
        strokeColor: const Color(0xFFE8973A).withValues(alpha: 0.30),
        strokeWidth: 1,
      ),
    };
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: _daejeonCenter,
        zoom: _defaultZoom,
      ),
      markers: _buildAllMarkers(),
      circles: _buildCircles(),
      onMapCreated: (controller) {
        _mapController = controller;
        widget.onMapCreated?.call(controller);
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      padding: EdgeInsets.zero,
    );
  }
}
