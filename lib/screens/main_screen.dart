import 'package:flutter/material.dart';
import '../api/bakery_repository.dart';
import '../models/bakery.dart';
import '../widgets/bakery_list_item.dart';
import '../widgets/map_placeholder.dart';
import 'bakery_detail_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final BakeryRepository _repository = BakeryRepository();
  List<Bakery> _bakeries = [];
  bool _isLoading = false;
  int _selectedIndex = 0;

  // 바텀시트 확장 상태
  bool _isBottomSheetExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadBakeries();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  Future<void> _loadBakeries() async {
    setState(() {
      _isLoading = true;
    });

    // Mock 데이터 (API 호출 실패 시 대비)
    final mockBakeries = [
      Bakery(
        id: 1,
        name: '성심당 본점',
        address: '대전광역시 중구 은행동 145',
        latitude: 36.3271,
        longitude: 127.4275,
        phoneNumber: '042-256-7730',
        imageUrls: [],
        rating: 4.8,
        reviewCount: 1523,
        distance: 0.35,
        openingHours: '매일 08:00 - 20:00',
        specialMenu: '튀김소보루, 부추빵, 판도로',
        amenities: ['주차가능', 'WiFi'],
      ),
      Bakery(
        id: 2,
        name: '빵긍정',
        address: '대전광역시 서구 둔산동 920',
        latitude: 36.3500,
        longitude: 127.3800,
        phoneNumber: '042-123-4567',
        imageUrls: [],
        rating: 4.6,
        reviewCount: 342,
        distance: 0.62,
        openingHours: '화-일 10:00 - 21:00',
        specialMenu: '크루아상, 바게트',
        amenities: ['포장가능'],
      ),
      Bakery(
        id: 3,
        name: '오븐이야기',
        address: '대전광역시 유성구 봉명동 580',
        latitude: 36.3700,
        longitude: 127.3500,
        phoneNumber: '042-234-5678',
        imageUrls: [],
        rating: 4.5,
        reviewCount: 218,
        distance: 0.89,
        openingHours: '매일 09:00 - 22:00',
        specialMenu: '수제빵, 케이크',
        amenities: ['주차가능', '포장가능'],
      ),
    ];

    final response = await _repository.getBakeries(
      latitude: 36.3271,
      longitude: 127.4275,
    );

    setState(() {
      _isLoading = false;
      _bakeries = response.isSuccess && response.data != null
          ? response.data!
          : mockBakeries;
    });
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      // 검색 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SearchScreen()),
      );
    } else if (index == 2) {
      // 즐겨찾기 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FavoritesScreen()),
      );
    }
  }

  void _onBakeryTap(Bakery bakery) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BakeryDetailScreen(bakeryId: bakery.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 지도 영역
          MapPlaceholder(
            bakeries: _bakeries,
            onMarkerTap: _onBakeryTap,
          ),

          // 상단 검색바
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildSearchBar(),
          ),

          // 하단 빵집 리스트 바텀시트
          if (_bakeries.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 88,
              child: _buildBottomSheet(),
            ),

          // 하단 네비게이션 바
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchScreen()),
        );
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 12),
            Text(
              '빵집 이름 검색',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < -5) {
          // 위로 스와이프
          setState(() {
            _isBottomSheetExpanded = true;
          });
        } else if (details.primaryDelta! > 5) {
          // 아래로 스와이프
          setState(() {
            _isBottomSheetExpanded = false;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        height: _isBottomSheetExpanded ? 450 : 180,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // 핸들
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '가까운 빵집',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '거리순 추천',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '총 ${_bakeries.length}개',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // 리스트
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _bakeries.length,
                      itemBuilder: (context, index) {
                        return BakeryListItem(
                          bakery: _bakeries[index],
                          onTap: () => _onBakeryTap(_bakeries[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 88,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E5E5), width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.map, '지도'),
            _buildNavItem(1, Icons.search, '검색'),
            _buildNavItem(2, Icons.star, '즐겨찾기'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? const Color(0xFFD97941) : Colors.grey;

    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
