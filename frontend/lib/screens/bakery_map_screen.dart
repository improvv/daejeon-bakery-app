import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_colors.dart';

class BakeryMapScreen extends StatefulWidget {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const BakeryMapScreen({
    super.key,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<BakeryMapScreen> createState() => _BakeryMapScreenState();
}

class _BakeryMapScreenState extends State<BakeryMapScreen> {
  GoogleMapController? _mapController;

  late final Set<Marker> _markers = {
    Marker(
      markerId: const MarkerId('bakery'),
      position: LatLng(widget.latitude, widget.longitude),
      infoWindow: InfoWindow(title: widget.name, snippet: widget.address),
    ),
  };

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.latitude, widget.longitude),
              zoom: 16.0,
            ),
            markers: _markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              controller.showMarkerInfoWindow(const MarkerId('bakery'));
            },
          ),

          // X 버튼
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.close_rounded, color: AppColors.textPrimary, size: 20),
              ),
            ),
          ),

          // 하단 빵집 정보
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
