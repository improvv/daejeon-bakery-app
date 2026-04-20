import 'package:flutter/material.dart';
import '../api/bakery_repository.dart';
import '../models/bakery.dart';
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
    setState(() {
      _isLoading = true;
    });

    final response = await _repository.getFavorites();

    if (response.isSuccess && response.data != null) {
      setState(() {
        _favorites = response.data!;
        _isLoading = false;
      });
    } else {
      // Mock 데이터
      setState(() {
        _favorites = [
          Bakery(
            id: 1,
            name: '성심당 본점',
            address: '대전광역시 중구 은행동 145',
            latitude: 36.3271,
            longitude: 127.4275,
            rating: 4.8,
            reviewCount: 1523,
            distance: 0.35,
            isFavorite: true,
          ),
          Bakery(
            id: 2,
            name: '빵긍정',
            address: '대전광역시 서구 둔산동 920',
            latitude: 36.3500,
            longitude: 127.3800,
            rating: 4.6,
            reviewCount: 342,
            distance: 0.62,
            isFavorite: true,
          ),
        ];
        _isLoading = false;
      });
    }

    if (_favorites.isNotEmpty) {
      _listAnimController.forward(from: 0);
    }
  }

  void _onBakeryTap(Bakery bakery) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BakeryDetailScreen(bakeryId: bakery.id),
      ),
    ).then((_) {
      _loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/dreamdol.png',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 24),
          const Text(
            '아직 즐겨찾기한 빵집이 없어요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C2C2C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '마음에 드는 빵집을 찾아\n즐겨찾기에 추가해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.6,
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
        // 각 아이템마다 staggered fade+slide 애니메이션
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
              offset: Offset(0, 24 * (1 - itemAnim.value)),
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
}
