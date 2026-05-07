import 'package:flutter/material.dart';
import '../api/bakery_repository.dart';
import '../models/bakery.dart';
import '../theme/app_colors.dart';
import '../widgets/bakery_list_item.dart';
import 'bakery_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  const FavoritesScreen({Key? key, this.onNavigateToTab}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  final BakeryRepository _repository = BakeryRepository();
  List<Bakery> _favorites = [];
  bool _isLoading = true;
  late AnimationController _listAnimController;

  @override
  void initState() {
    super.initState();
    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadFavorites();
  }

  @override
  void dispose() {
    _repository.dispose();
    _listAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final response = await _repository.getFavorites();
    setState(() {
      _isLoading = false;
      _favorites = response.isSuccess && response.data != null
          ? response.data!
          : [
              Bakery(id: 1, name: '성심당 본점', address: '대전광역시 중구 은행동 145', latitude: 36.3271, longitude: 127.4275, rating: 4.8, reviewCount: 1523, distance: 0.35, isFavorite: true),
              Bakery(id: 2, name: '빵긍정',      address: '대전광역시 서구 둔산동 920',  latitude: 36.3500, longitude: 127.3800, rating: 4.6, reviewCount: 342,  distance: 0.62, isFavorite: true),
            ];
    });
    if (_favorites.isNotEmpty) _listAnimController.forward(from: 0);
  }

  void _onBakeryTap(Bakery bakery) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => BakeryDetailScreen(bakeryId: bakery.id),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        ),
      ),
    ).then((_) => _loadFavorites());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (widget.onNavigateToTab != null) {
              widget.onNavigateToTab!(0);
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          '즐겨찾기',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _favorites.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.crustBrown,
                  onRefresh: _loadFavorites,
                  child: _buildFavoritesList(),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo.png', width: 110, fit: BoxFit.contain),
          const SizedBox(height: 24),
          const Text(
            '아직 즐겨찾기한 빵집이 없어요',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            '마음에 드는 빵집을 찾아\n북마크해보세요 🔖',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSec, height: 1.6),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => widget.onNavigateToTab?.call(0),
            icon: const Icon(Icons.explore_outlined, size: 18),
            label: const Text('빵집 찾으러 가기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.crustBrown,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final itemAnim = CurvedAnimation(
          parent: _listAnimController,
          curve: Interval(
            (index * 0.15).clamp(0.0, 0.7),
            ((index * 0.15) + 0.4).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        );
        return AnimatedBuilder(
          animation: itemAnim,
          builder: (context, child) => Opacity(
            opacity: itemAnim.value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - itemAnim.value)),
              child: child,
            ),
          ),
          child: BakeryListItem(
            bakery: _favorites[index],
            onTap: () => _onBakeryTap(_favorites[index]),
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
