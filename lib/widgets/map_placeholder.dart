import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/bakery.dart';

class MapPlaceholder extends StatefulWidget {
  final List<Bakery> bakeries;
  final Function(Bakery)? onMarkerTap;

  const MapPlaceholder({
    Key? key,
    this.bakeries = const [],
    this.onMarkerTap,
  }) : super(key: key);

  @override
  State<MapPlaceholder> createState() => _MapPlaceholderState();
}

class _MapPlaceholderState extends State<MapPlaceholder> {
  GoogleMapController? _mapController;

  // 대전 중심 좌표 (성심당 본점 근처)
  static const LatLng _daejeonCenter = LatLng(36.3271, 127.4275);

  static const double _defaultZoom = 14.0;

  Set<Marker> _buildMarkers() {
    return widget.bakeries.map((bakery) {
      return Marker(
        markerId: MarkerId(bakery.id.toString()),
        position: LatLng(bakery.latitude, bakery.longitude),
        infoWindow: InfoWindow(
          title: bakery.name,
          snippet: '⭐ ${bakery.rating} · ${bakery.address}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () {
          if (widget.onMarkerTap != null) {
            widget.onMarkerTap!(bakery);
          }
        },
      );
    }).toSet();
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
      markers: _buildMarkers(),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}
