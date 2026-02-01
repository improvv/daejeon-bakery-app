import 'package:flutter/material.dart';
import '../api/bakery_repository.dart';
import '../models/bakery.dart';
import '../widgets/bakery_list_item.dart';
import 'bakery_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final BakeryRepository _repository = BakeryRepository();
  List<Bakery> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _repository.dispose();
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
  }

  void _onBakeryTap(Bakery bakery) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BakeryDetailScreen(bakeryId: bakery.id),
      ),
    ).then((_) {
      // 상세 화면에서 돌아왔을 때 목록 새로고침
      _loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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
          Icon(
            Icons.star_border,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          const Text(
            '아직 즐겨찾기한 빵집이 없어요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '마음에 드는 빵집을 찾아\n즐겨찾기에 추가해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
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
        return BakeryListItem(
          bakery: _favorites[index],
          onTap: () => _onBakeryTap(_favorites[index]),
        );
      },
    );
  }
}
