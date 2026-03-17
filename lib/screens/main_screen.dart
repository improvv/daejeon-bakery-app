import 'package:flutter/material.dart';
import '../api/bakery_repository.dart';
import '../models/bakery.dart';
import '../widgets/bakery_list_item.dart';
import '../widgets/map_placeholder.dart';
import 'bakery_detail_screen.dart';
import 'search_screen.dart';

class MainScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const MainScreen({Key? key, this.onNavigateToTab}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final BakeryRepository _repository = BakeryRepository();
  List<Bakery> _bakeries = [];
  bool _isLoading = false;

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

  void _onBakeryTap(Bakery bakery) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => BakeryDetailScreen(bakeryId: bakery.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapPlaceholder(
            bakeries: _bakeries,
            onMarkerTap: _onBakeryTap,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildSearchBar(),
          ),
          if (_bakeries.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              // 수정됨: 바텀 네비게이션이 외부 RootScreen에 속하므로 바닥 여백 없이 0을 줍니다.
              bottom: 0,
              child: _buildBottomSheet(),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        if (widget.onNavigateToTab != null) {
          widget.onNavigateToTab!(1); // 1 is SearchScreen's index
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen()));
        }
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
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 12),
            Text('빵집 이름 검색',
                style: TextStyle(fontSize: 16, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < -5) {
          setState(() => _isBottomSheetExpanded = true);
        } else if (details.primaryDelta! > 5) {
          setState(() => _isBottomSheetExpanded = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        height: _isBottomSheetExpanded ? 650 : 180,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('가까운 빵집',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('거리순 추천',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                  Text('총 ${_bakeries.length}개',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
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
}
