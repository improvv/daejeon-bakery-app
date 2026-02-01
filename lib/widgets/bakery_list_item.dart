import 'package:flutter/material.dart';
import '../models/bakery.dart';

class BakeryListItem extends StatelessWidget {
  final Bakery bakery;
  final VoidCallback onTap;

  const BakeryListItem({
    Key? key,
    required this.bakery,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E5E5), width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이름 + 거리
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          bakery.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        bakery.isFavorite ? Icons.star : Icons.star_border,
                        size: 18,
                        color: bakery.isFavorite ? Colors.amber : Colors.grey[300],
                      ),
                    ],
                  ),
                ),
                if (bakery.distance != null)
                  Text(
                    '${(bakery.distance! * 1000).toInt()}m',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            // 평점 + 태그
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  bakery.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                if (bakery.specialMenu != null && bakery.specialMenu!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E6D3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getTag(bakery),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFD97941),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTag(Bakery bakery) {
    if (bakery.rating >= 4.7) return '대전 대표';
    if (bakery.reviewCount > 500) return '유명';
    if (bakery.specialMenu?.contains('수제') == true) return '수제빵';
    return '동네빵집';
  }
}
