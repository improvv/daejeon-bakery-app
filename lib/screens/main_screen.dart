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

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final BakeryRepository _repository = BakeryRepository();
  List<Bakery> _bakeries = [];
  bool _isLoading = false;

  GoogleMapController? _mapController;

  BottomSheetState _bottomSheetState = BottomSheetState.collapsed;

  static const double _hiddenHeight = 36.0;
  static const double _collapsedHeight = 220.0;
  static const double _expandedHeight = 650.0;

  late final AnimationController _sheetController;

  @override
  void initState() {
    super.initState();
    _sheetController = AnimationController(
      vsync: this,
      lowerBound: _hiddenHeight,
      upperBound: _expandedHeight,
      value: _collapsedHeight,
    );
    _loadBakeries();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _repository.dispose();
    super.dispose();
  }

  double _targetHeight(BottomSheetState state) {
    switch (state) {
      case BottomSheetState.hidden:
        return _hiddenHeight;
      case BottomSheetState.collapsed:
        return _collapsedHeight;
      case BottomSheetState.expanded:
        return _expandedHeight;
    }
  }

  void _setBottomSheetState(BottomSheetState newState) {
    setState(() => _bottomSheetState = newState);
    _sheetController.animateTo(
      _targetHeight(newState),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
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
        amenities: ['PARKING', 'WIFI'],
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
        amenities: ['PACKING'],
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
        amenities: ['PARKING', 'PACKING'],
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
        const LatLng mockCurrentLocation = LatLng(36.3325, 127.4342);
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(mockCurrentLocation, 15.0),
        );
      }
    } catch (e) {
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
      body: AnimatedBuilder(
        animation: _sheetController,
        builder: (context, _) {
          final h = _sheetController.value;
          final isExpanded = _bottomSheetState == BottomSheetState.expanded;
          // 바텀시트가 없을 때는 버튼을 기본 위치(바닥 + 여백)에 고정
          final fabBottom = _bakeries.isNotEmpty ? h + 16 : 16.0;

          return Stack(
            children: [
              // 지도: 바텀시트 높이만큼 padding을 줘서 카메라 중심이 바텀시트 위 영역에 맞춰짐
              Positioned.fill(
                child: MapPlaceholder(
                  bakeries: _bakeries,
                  onMarkerTap: _onBakeryTap,
                  onMapCreated: (controller) => _mapController = controller,
                  bottomPadding: h,
                ),
              ),
              // 검색바
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: _buildSearchBar(),
              ),
              // 내 위치 버튼: hidden/collapsed 때는 바텀시트 바로 위, expanded 때는 숨김
              Positioned(
                right: 16,
                bottom: fabBottom,
                child: IgnorePointer(
                  ignoring: isExpanded,
                  child: AnimatedOpacity(
                    opacity: isExpanded ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
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
              ),
              // 바텀시트
              if (_bakeries.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomSheet(h),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        if (widget.onNavigateToTab != null) {
          widget.onNavigateToTab!(1);
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
                color: Colors.black.withValues(alpha: 0.1),
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

  Widget _buildBottomSheet(double height) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // expanded가 아닐 때: 수직 드래그를 흡수해서 지도로 전달되지 않게 차단
      onVerticalDragUpdate: _bottomSheetState != BottomSheetState.expanded
          ? (_) {}
          : null,
      onVerticalDragEnd: (details) {
        final double velocity = details.primaryVelocity ?? 0;
        const double threshold = 300.0;

        if (velocity < -threshold) {
          // 위로 스와이프: 확장
          if (_bottomSheetState == BottomSheetState.hidden) {
            _setBottomSheetState(BottomSheetState.collapsed);
          } else if (_bottomSheetState == BottomSheetState.collapsed) {
            _setBottomSheetState(BottomSheetState.expanded);
          }
        } else if (velocity > threshold) {
          // 아래로 스와이프: 축소
          if (_bottomSheetState == BottomSheetState.expanded) {
            _setBottomSheetState(BottomSheetState.collapsed);
          } else if (_bottomSheetState == BottomSheetState.collapsed) {
            _setBottomSheetState(BottomSheetState.hidden);
          }
        }
      },
      child: Container(
        height: height,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))
          ],
        ),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height: _expandedHeight,
            child: Column(
              children: [
                // 스와이프 손잡이
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
