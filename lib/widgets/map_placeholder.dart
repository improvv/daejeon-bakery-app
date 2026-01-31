import 'package:flutter/material.dart';

class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE9E5DB),
            Color(0xFFDDD8CC),
          ],
        ),
      ),
      child: CustomPaint(
        painter: MapGridPainter(),
        child: Stack(
          children: [
            // Mock 빵집 핀들
            Positioned(
              top: 280,
              left: 140,
              child: _buildMapPin(false),
            ),
            Positioned(
              top: 380,
              left: 200,
              child: _buildMapPin(false),
            ),
            Positioned(
              top: 320,
              left: 260,
              child: _buildMapPin(true), // 활성화된 핀
            ),
            Positioned(
              top: 420,
              left: 100,
              child: _buildMapPin(false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPin(bool isActive) {
    return Transform.rotate(
      angle: -0.785398, // -45도
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFF6B35) : const Color(0xFFD97941),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Transform.rotate(
            angle: 0.785398, // 45도 (원래대로 복원)
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.02)
      ..strokeWidth = 1;

    const gridSize = 50.0;

    // 세로 선
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // 가로 선
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
