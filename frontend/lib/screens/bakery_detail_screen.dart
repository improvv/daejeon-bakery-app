import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/bakery_repository.dart';
import '../models/bakery.dart';
import '../models/review.dart';
import '../theme/app_colors.dart';
import '../utils/time_utils.dart';
import '../widgets/image_slider.dart';
import '../widgets/review_item.dart';

class BakeryDetailScreen extends StatefulWidget {
  final int bakeryId;
  const BakeryDetailScreen({Key? key, required this.bakeryId}) : super(key: key);

  @override
  State<BakeryDetailScreen> createState() => _BakeryDetailScreenState();
}

class _BakeryDetailScreenState extends State<BakeryDetailScreen> {
  final BakeryRepository _repository = BakeryRepository();
  final ScrollController _scrollController = ScrollController();

  Bakery? _bakery;
  List<Review> _reviews = [];
  bool _isLoading = true;
  bool _isFavorite = false;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final scrolled = _scrollController.offset > 220;
      if (scrolled != _isScrolled) setState(() => _isScrolled = scrolled);
    });
    _loadBakeryDetail();
    _loadReviews();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _repository.dispose();
    super.dispose();
  }

  Future<void> _loadBakeryDetail() async {
    setState(() => _isLoading = true);
    final response = await _repository.getBakeryDetail(widget.bakeryId);
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _bakery = response.data;
        _isFavorite = response.data!.isFavorite;
      } else {
        _bakery = Bakery(
          id: widget.bakeryId,
          name: '성심당 본점',
          address: '대전광역시 중구 은행동 145',
          latitude: 36.3271, longitude: 127.4275,
          phoneNumber: '042-256-7730',
          description: '대전을 대표하는 베이커리입니다.',
          imageUrls: [],
          rating: 4.8, reviewCount: 1523, distance: 0.35,
          openingHours: '매일 08:00 - 20:00',
          specialMenu: '튀김소보루, 부추빵, 판도로, 앙버터바게트',
          amenities: ['PARKING', 'WIFI', 'PACKING'],
          isFavorite: false,
        );
        _isFavorite = false;
      }
    });
  }

  Future<void> _loadReviews() async {
    final response = await _repository.getBakeryReviews(widget.bakeryId);
    setState(() {
      _reviews = response.isSuccess && response.data != null
          ? response.data!
          : [
              Review(id: 1, bakeryId: widget.bakeryId, userName: '김민수', rating: 5.0, content: '튀김소보루가 정말 맛있어요! 대전 오면 꼭 들리는 곳입니다.', imageUrls: [], createdAt: DateTime.now().subtract(const Duration(days: 2))),
              Review(id: 2, bakeryId: widget.bakeryId, userName: '이지은', rating: 4.5, content: '부추빵이 특이하고 맛있네요. 줄이 길지만 기다릴 가치가 있어요.', imageUrls: [], createdAt: DateTime.now().subtract(const Duration(days: 5))),
            ];
    });
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.lightImpact();
    final response = await _repository.toggleFavorite(widget.bakeryId);
    setState(() {
      _isFavorite = response.isSuccess && response.data != null
          ? response.data!
          : !_isFavorite;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: AppColors.caramel, size: 18),
            const SizedBox(width: 8),
            Text(_isFavorite ? '즐겨찾기에 추가했어요' : '즐겨찾기에서 제거했어요'),
          ],
        ),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _makePhoneCall() async {
    if (_bakery?.phoneNumber == null) return;
    final uri = Uri(scheme: 'tel', path: _bakery!.phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMap() async {
    if (_bakery == null) return;
    final lat = _bakery!.latitude;
    final lng = _bakery!.longitude;
    final kakaoUrl = Uri.parse('kakaomap://look?p=$lat,$lng');
    final googleUrl = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(kakaoUrl)) {
      await launchUrl(kakaoUrl);
    } else {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();
    if (_bakery == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('빵집 정보를 불러올 수 없습니다', style: TextStyle(color: AppColors.textSec))),
      );
    }

    final open = isOpenNow(_bakery!.openingHours);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 앱바 + 이미지
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: _isScrolled ? AppColors.surface : Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: _isScrolled ? 0 : 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: _isScrolled ? AppColors.textPrimary : Colors.white,
                shadows: _isScrolled ? null : [const Shadow(blurRadius: 8, color: Colors.black54)],
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: _isFavorite
                      ? AppColors.caramel
                      : (_isScrolled ? AppColors.textPrimary : Colors.white),
                  shadows: _isScrolled ? null : [const Shadow(blurRadius: 8, color: Colors.black54)],
                ),
                onPressed: _toggleFavorite,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _bakery!.imageUrls.isNotEmpty
                  ? ImageSlider(imageUrls: _bakery!.imageUrls)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFF3E4), Color(0xFFFFDDB8), AppColors.crustBrown],
                          stops: [0.0, 0.6, 1.0],
                        ),
                      ),
                      child: Center(
                        child: Image.asset('assets/logo.png', width: 160, height: 160, fit: BoxFit.contain),
                      ),
                    ),
            ),
          ),

          // 상세 정보
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이름 + 평점
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _bakery!.name,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: AppColors.caramel, size: 18),
                                const SizedBox(width: 3),
                                Text(
                                  _bakery!.rating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.crustBrown),
                                ),
                              ],
                            ),
                            Text('리뷰 ${_bakery!.reviewCount}개',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSec)),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 16),

                    // 영업시간
                    if (_bakery!.openingHours != null) ...[
                      _buildInfoRow(
                        Icons.access_time_rounded,
                        open ? '영업 중  ·  ${_bakery!.openingHours}' : '영업 종료  ·  ${_bakery!.openingHours}',
                        open ? AppColors.openGreen : AppColors.closedRed,
                      ),
                      if (_bakery!.openingHoursAll != null && _bakery!.openingHoursAll!.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 28, top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _bakery!.openingHoursAll!
                                .map((h) => Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(h, style: const TextStyle(fontSize: 12, color: AppColors.textSec, height: 1.5)),
                                    ))
                                .toList(),
                          ),
                        ),
                    ],

                    const SizedBox(height: 12),

                    // 주소 + 거리
                    _buildInfoRow(
                      Icons.location_on_rounded,
                      _bakery!.distance != null
                          ? '${_bakery!.address}\n현재 위치에서 ${_bakery!.distance!.toStringAsFixed(1)}km'
                          : _bakery!.address,
                      AppColors.textSec,
                    ),

                    const SizedBox(height: 12),

                    // 전화번호
                    if (_bakery!.phoneNumber != null)
                      _buildInfoRow(Icons.phone_rounded, _bakery!.phoneNumber!, AppColors.textSec),

                    const SizedBox(height: 24),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 20),

                    // 편의시설
                    if (_bakery!.amenities.isNotEmpty) ...[
                      const Text('편의시설',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _bakery!.amenities.map((amenity) {
                          final cfg = _amenityConfig[amenity];
                          if (cfg == null) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.creamFill,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border, width: 1),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(cfg.$1, size: 22, color: AppColors.crustBrown),
                                const SizedBox(height: 4),
                                Text(cfg.$2,
                                    style: const TextStyle(fontSize: 11, color: AppColors.crustBrown, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 20),
                    ],

                    // 대표 메뉴
                    if (_bakery!.specialMenu != null) ...[
                      const Text('대표 메뉴',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _bakery!.specialMenu!
                            .split(',')
                            .map((m) => m.trim())
                            .where((m) => m.isNotEmpty)
                            .map((menu) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.creamFill,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.border, width: 1),
                                  ),
                                  child: Text(menu,
                                      style: const TextStyle(fontSize: 13, color: AppColors.crustBrown, fontWeight: FontWeight.w500)),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 20),
                    ],

                    // 액션 버튼
                    Row(
                      children: [
                        Expanded(child: _buildActionButton(Icons.phone_rounded, '전화', filled: true, onPressed: _makePhoneCall)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildActionButton(Icons.map_outlined, '지도', filled: false, onPressed: _openMap)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildActionButton(Icons.share_outlined, '공유', filled: false, onPressed: () {})),
                      ],
                    ),

                    const SizedBox(height: 32),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 20),

                    // 리뷰 헤더
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('리뷰 (${_reviews.length})',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('리뷰 작성'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.crustBrown,
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 리뷰 리스트
                    if (_reviews.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text('아직 리뷰가 없습니다\n첫 번째 리뷰를 작성해보세요 ✍️',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textHint, fontSize: 14, height: 1.6)),
                        ),
                      )
                    else
                      ...(_reviews.map((review) => ReviewItem(review: review))),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label,
      {required bool filled, required VoidCallback onPressed}) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.crustBrown,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.crustBrown,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(height: 300, color: AppColors.surfaceAlt),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 26, width: 180, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 12),
                  Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 8),
                  Container(height: 14, width: 260, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const Map<String, (IconData, String)> _amenityConfig = {
    'PARKING':  (Icons.local_parking_rounded,    '주차'),
    'PACKING':  (Icons.shopping_bag_outlined,     '포장'),
    'DELIVERY': (Icons.delivery_dining_outlined,  '배달'),
    'WIFI':     (Icons.wifi_rounded,              'WiFi'),
    'RESTROOM': (Icons.wc_rounded,                '화장실'),
  };
}
