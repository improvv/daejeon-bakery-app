import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../api/bakery_repository.dart';
import '../models/bakery.dart';
import '../theme/app_colors.dart';
import '../utils/time_utils.dart';
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
  LatLng? _currentLocation;

  BottomSheetState _bottomSheetState = BottomSheetState.collapsed;

  static const double _hiddenHeight    = 36.0;
  static const double _collapsedHeight = 220.0;
  static const double _expandedHeight  = 650.0;

  late final AnimationController _sheetController;

  // 구 필터 칩
  static const _districts = ['전체', '동구', '대덕구', '서구', '중구', '유성구'];

  static const _districtCenters = {
    '전체':  LatLng(36.3500, 127.3845),
    '동구':  LatLng(36.3476, 127.4534),
    '대덕구': LatLng(36.3748, 127.4152), // 오문창 순대국밥 인근
    '서구':  LatLng(36.3538, 127.3823),
    '중구':  LatLng(36.3271, 127.4275),
    '유성구': LatLng(36.3624, 127.3564),
  };

  String _selectedDistrict = '전체';
  bool _showOpenOnly = false;
  String _selectedSort = '거리순';

  // 선택된 구에 해당하지 않는 빵집 (비활성 마커용)
  List<Bakery> get _inactiveBakeries {
    if (_selectedDistrict == '전체') return const [];
    return _bakeries.where((b) => !b.address.contains(_selectedDistrict)).toList();
  }

  List<Bakery> get _filteredBakeries {
    var list = _selectedDistrict == '전체'
        ? List<Bakery>.from(_bakeries)
        : _bakeries.where((b) => b.address.contains(_selectedDistrict)).toList();
    if (_showOpenOnly) {
      list = list.where((b) => isOpenNow(b.openingHours)).toList();
    }
    list.sort((a, b) {
      final aOpen = isOpenNow(a.openingHours) ? 0 : 1;
      final bOpen = isOpenNow(b.openingHours) ? 0 : 1;
      if (aOpen != bOpen) return aOpen.compareTo(bOpen);
      switch (_selectedSort) {
        case '평점 높은순': return b.rating.compareTo(a.rating);
        case '리뷰 많은순': return b.reviewCount.compareTo(a.reviewCount);
        default: return (a.distance ?? 999).compareTo(b.distance ?? 999);
      }
    });
    return list;
  }

  void _onDistrictSelected(String district) {
    setState(() => _selectedDistrict = district);
    final center = _districtCenters[district];
    if (center != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(center, district == '전체' ? 13.0 : 14.5),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _sheetController = AnimationController(
      vsync: this,
      lowerBound: _hiddenHeight,
      upperBound: _expandedHeight,
      value: _collapsedHeight,
    );
    _initLocationAndLoad();
  }

  Future<void> _initLocationAndLoad() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        final current = LatLng(position.latitude, position.longitude);
        setState(() => _currentLocation = current);
        await _loadBakeries(lat: position.latitude, lon: position.longitude);
        return;
      }
    } catch (_) {}
    await _loadBakeries();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _repository.dispose();
    super.dispose();
  }

  double _targetHeight(BottomSheetState state) {
    switch (state) {
      case BottomSheetState.hidden:     return _hiddenHeight;
      case BottomSheetState.collapsed:  return _collapsedHeight;
      case BottomSheetState.expanded:   return _expandedHeight;
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

  Future<void> _loadBakeries({double lat = 36.3504, double lon = 127.3845}) async {
    setState(() => _isLoading = true);
    final response = await _repository.getBakeries(latitude: lat, longitude: lon, radius: 10);
    setState(() {
      _isLoading = false;
      _bakeries = response.isSuccess && response.data != null ? response.data! : [];
    });
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
    );
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('위치 권한이 거부되었습니다.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 허용해주세요.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final current = LatLng(position.latitude, position.longitude);
      setState(() => _currentLocation = current);
      if (_mapController != null) {
        await _mapController!.animateCamera(CameraUpdate.newLatLngZoom(current, 15.0));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 지도 - AnimatedBuilder 밖에 고정하여 바텀시트 애니메이션과 완전 분리
          Positioned.fill(
            child: MapPlaceholder(
              bakeries: _filteredBakeries,
              inactiveBakeries: _inactiveBakeries,
              onMarkerTap: _onBakeryTap,
              onMapCreated: (controller) => _mapController = controller,
              currentLocation: _currentLocation,
            ),
          ),

          // 검색창 (지도 위 고정)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildSearchBar(),
          ),

          // 구 필터 칩 (지도 위 고정)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16 + 52 + 10,
            left: 0,
            right: 0,
            child: _buildDistrictChips(),
          ),

          // 줌 버튼 — 바텀시트 완전히 닫혔을 때만 왼쪽 하단에 표시
          Positioned(
            left: 16,
            bottom: 80,
            child: IgnorePointer(
              ignoring: _bottomSheetState != BottomSheetState.hidden,
              child: AnimatedOpacity(
                opacity: _bottomSheetState == BottomSheetState.hidden ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: _buildZoomButtons(),
              ),
            ),
          ),

          // 바텀시트 + FAB — 이 둘만 AnimatedBuilder로 감싸서 애니메이션 처리
          AnimatedBuilder(
            animation: _sheetController,
            builder: (context, _) {
              final h = _sheetController.value;
              final isExpanded = _bottomSheetState == BottomSheetState.expanded;
              final fabBottom = _filteredBakeries.isNotEmpty ? h + 16 : 16.0;

              return Stack(
                children: [
                  // 현재 위치 FAB
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
                          backgroundColor: AppColors.surface,
                          elevation: 3,
                          shape: const CircleBorder(),
                          child: const Icon(Icons.my_location_rounded, color: AppColors.crustBrown),
                        ),
                      ),
                    ),
                  ),

                  // 바텀시트
                  if (_filteredBakeries.isNotEmpty)
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: _buildBottomSheet(h),
                    ),
                ],
              );
            },
          ),
        ],
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.crustBrown.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search_rounded, color: AppColors.crustBrown, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '대전 빵집을 찾아보세요 🍞',
                style: TextStyle(fontSize: 15, color: AppColors.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictChips() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.none,
        children: [
          // 구 선택 칩들
          ..._districts.map((district) {
            final isSelected = district == _selectedDistrict;
            return GestureDetector(
              onTap: () => _onDistrictSelected(district),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.creamFill : AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? AppColors.crustBrown : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.crustBrown.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  district,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppColors.crustBrown : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }),

          // 구 / 영업중 구분선
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            color: AppColors.border,
          ),

          // 영업중 토글 칩
          GestureDetector(
            onTap: () => setState(() => _showOpenOnly = !_showOpenOnly),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _showOpenOnly ? const Color(0xFFE8F5E9) : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _showOpenOnly ? const Color(0xFF388E3C) : AppColors.border,
                  width: _showOpenOnly ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.crustBrown.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _showOpenOnly ? const Color(0xFF388E3C) : AppColors.textHint,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '영업중',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _showOpenOnly ? FontWeight.w600 : FontWeight.w400,
                      color: _showOpenOnly ? const Color(0xFF388E3C) : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomButtons() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.crustBrown.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              onTap: () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
              child: const Padding(
                padding: EdgeInsets.all(11),
                child: Icon(Icons.add_rounded, size: 20, color: AppColors.crustBrown),
              ),
            ),
          ),
          Container(height: 1, color: AppColors.border),
          Material(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
            child: InkWell(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
              onTap: () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
              child: const Padding(
                padding: EdgeInsets.all(11),
                child: Icon(Icons.remove_rounded, size: 20, color: AppColors.crustBrown),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(double height) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _bottomSheetState != BottomSheetState.expanded ? (_) {} : null,
      onVerticalDragEnd: (details) {
        final double velocity = details.primaryVelocity ?? 0;
        const double threshold = 300.0;
        if (velocity < -threshold) {
          if (_bottomSheetState == BottomSheetState.hidden) {
            _setBottomSheetState(BottomSheetState.collapsed);
          } else if (_bottomSheetState == BottomSheetState.collapsed) {
            _setBottomSheetState(BottomSheetState.expanded);
          }
        } else if (velocity > threshold) {
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
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: AppColors.crustBrown.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height: _expandedHeight,
            child: Column(
              children: [
                // 핸들 바
                Container(
                  width: 44, height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // 헤더
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        '가까운 빵집',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.creamFill,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_filteredBakeries.length}곳',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.crustBrown,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showSortOptions,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_selectedSort, style: const TextStyle(fontSize: 12, color: AppColors.textSec)),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSec),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 리스트
                Expanded(
                  child: _isLoading
                      ? _buildSkeletonList()
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          physics: _bottomSheetState == BottomSheetState.expanded
                              ? const AlwaysScrollableScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          itemCount: _filteredBakeries.length,
                          itemBuilder: (context, index) => BakeryListItem(
                            bakery: _filteredBakeries[index],
                            onTap: () => _onBakeryTap(_filteredBakeries[index]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44, height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('정렬 기준', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
          ),
          for (final opt in ['거리순', '평점 높은순', '리뷰 많은순'])
            ListTile(
              title: Text(opt, style: const TextStyle(color: AppColors.textPrimary)),
              trailing: opt == _selectedSort
                  ? const Icon(Icons.check_rounded, color: AppColors.crustBrown)
                  : null,
              onTap: () {
                setState(() => _selectedSort = opt);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
