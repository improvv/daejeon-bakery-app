import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

enum BottomSheetState { hidden, collapsed, expanded }

class _MainScreenState extends State<MainScreen> {
  final BakeryRepository _repository = BakeryRepository();
  List<Bakery> _bakeries = [];
  bool _isLoading = false;

  GoogleMapController? _mapController;

  BottomSheetState _bottomSheetState = BottomSheetState.collapsed;

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

  Future<void> _moveToCurrentLocation() async {
    try {
      if (_mapController != null) {
        // 실제 앱 배포 시에는 Geolocator 플러그인을 사용하여 사용자 실제 위치를 가져와야 합니다.
        // 예: Position position = await Geolocator.getCurrentPosition();
        // 임시로 대전역 근처 위치를 '현재 위치'라고 가정하고 이동합니다.
        const LatLng mockCurrentLocation = LatLng(36.3325, 127.4342); 
        
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(mockCurrentLocation, 15.0),
        );
      }
    } catch (e) {
      // 위치 권한이 없거나 예외 발생 시 앱이 꺼지지 않도록 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 위치를 가져올 수 없습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapPlaceholder(
            bakeries: _bakeries,
            onMarkerTap: _onBakeryTap,
            onMapCreated: (controller) => _mapController = controller,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildSearchBar(),
          ),
          // 현재 위치로 이동하는 Floating Button (바텀시트가 최소화되었을 때만 우측 하단에 고정 표시)
          Positioned(
            right: 16,
            bottom: 36 + 16, // BottomSheetState.hidden 시 높이(36) + 여백(16)
            child: AnimatedScale(
              scale: _bottomSheetState == BottomSheetState.hidden ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: FloatingActionButton(
                heroTag: 'myLocationBtn',
                onPressed: _moveToCurrentLocation,
                backgroundColor: Colors.white,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(Icons.my_location, color: Colors.blue),
              ),
            ),
          ),
          if (_bakeries.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              // 바텀 네비게이션이 외부 RootScreen에 속하므로 바닥 여백 없이 0을 줍니다.
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
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const SearchScreen()));
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

  double _getBottomSheetHeight() {
    switch (_bottomSheetState) {
      case BottomSheetState.expanded:
        return 650.0;
      case BottomSheetState.collapsed:
        return 220.0; // 기존 180보다 살짝 더 보여주는게 자연스럽습니다.
      case BottomSheetState.hidden:
        return 36.0; // 상하 margin 16 + 손잡이 height 4 = 36. 딱 손잡이만 보입니다.
    }
  }

  Widget _buildBottomSheet() {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        final double velocity = details.primaryVelocity ?? 0;
        final double threshold = 300.0; // 스와이프 민감도

        setState(() {
          if (velocity < -threshold) {
            // 위로 드래그 (확장)
            if (_bottomSheetState == BottomSheetState.hidden) {
              _bottomSheetState = BottomSheetState.collapsed;
            } else if (_bottomSheetState == BottomSheetState.collapsed) {
              _bottomSheetState = BottomSheetState.expanded;
            }
          } else if (velocity > threshold) {
            // 아래로 드래그 (축소)
            if (_bottomSheetState == BottomSheetState.expanded) {
              _bottomSheetState = BottomSheetState.collapsed;
            } else if (_bottomSheetState == BottomSheetState.collapsed) {
              _bottomSheetState = BottomSheetState.hidden;
            }
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: _getBottomSheetHeight(),
        clipBehavior: Clip.hardEdge, // 높이가 줄어들 때 내용물이 넘치지 않고 깔끔하게 잘리도록 설정
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))
          ],
        ),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(), // 레이아웃 스크롤 방지
          child: SizedBox(
            height: 650.0, // 최대 높이(expanded) 고정을 통해 Overflow(에러) 방지
            child: Column(
              children: [
                // 스와이프 손잡이(handle)
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 16),
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
                              style:
                                  TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                      Text('총 ${_bakeries.length}개',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          // 확장(expanded) 상태일 때만 내부를 스크롤 할 수 있도록 허용 (아닐 땐 드래그용으로 잠금)
                          physics:
                              _bottomSheetState == BottomSheetState.expanded
                                  ? const AlwaysScrollableScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
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
        ),
      ),
    );
  }
}
