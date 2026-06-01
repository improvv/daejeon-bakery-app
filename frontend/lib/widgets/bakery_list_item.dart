import 'package:flutter/material.dart';
import '../models/bakery.dart';
import '../theme/app_colors.dart';
import '../utils/time_utils.dart';

class BakeryListItem extends StatefulWidget {
  final Bakery bakery;
  final VoidCallback onTap;

  const BakeryListItem({Key? key, required this.bakery, required this.onTap})
      : super(key: key);

  @override
  State<BakeryListItem> createState() => _BakeryListItemState();
}

class _BakeryListItemState extends State<BakeryListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = isOpenNow(widget.bakery.openingHours);
    final hasHours = widget.bakery.openingHours != null;
    final menuTag = _getMenuTag(widget.bakery);

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) { _pressController.reverse(); widget.onTap(); },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.crustBrown.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 썸네일
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.creamFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                    ),
                  ),
                  if (widget.bakery.isFavorite)
                    Positioned(
                      top: 4, right: 4,
                      child: Container(
                        width: 18, height: 18,
                        decoration: const BoxDecoration(
                          color: AppColors.crustBrown,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bookmark_rounded, size: 11, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이름 + 거리
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.bakery.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.bakery.distance != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            widget.bakery.distance! >= 1
                                ? '${widget.bakery.distance!.toStringAsFixed(1)}km'
                                : '${(widget.bakery.distance! * 1000).toInt()}m',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSec),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),

                    // 별점 + 리뷰수
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.caramel, size: 15),
                        const SizedBox(width: 3),
                        Text(
                          widget.bakery.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.crustBrown,
                          ),
                        ),
                        Text(
                          '  ·  ${widget.bakery.reviewCount}개 리뷰',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSec),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // 영업상태 뱃지 + 태그
                    Row(
                      children: [
                        if (hasHours)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: open
                                  ? AppColors.openGreen.withValues(alpha: 0.10)
                                  : AppColors.closedRed.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              open ? '영업 중' : '영업 종료',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: open ? AppColors.openGreen : AppColors.closedRed,
                              ),
                            ),
                          ),
                        if (hasHours && menuTag != null)
                          const SizedBox(width: 6),
                        if (menuTag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.creamFill,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              menuTag,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.caramel,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _getMenuTag(Bakery bakery) {
    if (bakery.specialMenu == null || bakery.specialMenu!.isEmpty) return null;
    final menus = bakery.specialMenu!
        .split(',')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .take(4)
        .toList();
    return menus.isEmpty ? null : menus.join(' · ');
  }
}
