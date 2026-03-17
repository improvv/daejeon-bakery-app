import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/bakery_repository.dart';
import '../models/bakery.dart';
import '../models/review.dart';
import '../widgets/image_slider.dart';
import '../widgets/review_item.dart';

class BakeryDetailScreen extends StatefulWidget {
  final int bakeryId;

  const BakeryDetailScreen({
    Key? key,
    required this.bakeryId,
  }) : super(key: key);

  @override
  State<BakeryDetailScreen> createState() => _BakeryDetailScreenState();
}

class _BakeryDetailScreenState extends State<BakeryDetailScreen> {
  final BakeryRepository _repository = BakeryRepository();
  
  Bakery? _bakery;
  List<Review> _reviews = [];
  bool _isLoading = true;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadBakeryDetail();
    _loadReviews();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  Future<void> _loadBakeryDetail() async {
    setState(() {
      _isLoading = true;
    });

    final response = await _repository.getBakeryDetail(widget.bakeryId);

    if (response.isSuccess && response.data != null) {
      setState(() {
        _bakery = response.data;
        _isFavorite = response.data!.isFavorite;
        _isLoading = false;
      });
    } else {
      // Mock 데이터
      setState(() {
        _bakery = Bakery(
          id: widget.bakeryId,
          name: '성심당 본점',
          address: '대전광역시 중구 은행동 145',
          latitude: 36.3271,
          longitude: 127.4275,
          phoneNumber: '042-256-7730',
          description: '대전을 대표하는 베이커리입니다.',
          imageUrls: [],
          rating: 4.8,
          reviewCount: 1523,
          distance: 0.35,
          openingHours: '매일 08:00 - 20:00',
          specialMenu: '튀김소보루, 부추빵, 판도로, 앙버터바게트',
          amenities: ['주차가능', 'WiFi', '포장가능'],
          isFavorite: false,
        );
        _isFavorite = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    final response = await _repository.getBakeryReviews(widget.bakeryId);

    if (response.isSuccess && response.data != null) {
      setState(() {
        _reviews = response.data!;
      });
    } else {
      // Mock 리뷰
      setState(() {
        _reviews = [
          Review(
            id: 1,
            bakeryId: widget.bakeryId,
            userName: '김민수',
            rating: 5.0,
            content: '튀김소보루가 정말 맛있어요! 대전 오면 꼭 들리는 곳입니다.',
            imageUrls: [],
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
          Review(
            id: 2,
            bakeryId: widget.bakeryId,
            userName: '이지은',
            rating: 4.5,
            content: '부추빵이 특이하고 맛있네요. 줄이 길지만 기다릴 가치가 있어요.',
            imageUrls: [],
            createdAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
        ];
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final response = await _repository.toggleFavorite(widget.bakeryId);

    if (response.isSuccess && response.data != null) {
      setState(() {
        _isFavorite = response.data!;
      });
    } else {
      // Mock toggle
      setState(() {
        _isFavorite = !_isFavorite;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFavorite ? '즐겨찾기에 추가했습니다' : '즐겨찾기에서 제거했습니다'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _makePhoneCall() async {
    if (_bakery?.phoneNumber == null) return;
    
    final uri = Uri(scheme: 'tel', path: _bakery!.phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_bakery == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('빵집 정보를 불러올 수 없습니다'),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 앱바 + 이미지 슬라이더
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _bakery!.imageUrls.isNotEmpty
                  ? ImageSlider(imageUrls: _bakery!.imageUrls)
                  : Container(
                      color: const Color(0xFFF5E6D3),
                      child: const Center(
                        child: Icon(Icons.bakery_dining, size: 80, color: Color(0xFFD97941)),
                      ),
                    ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.star : Icons.star_border,
                  color: _isFavorite ? Colors.amber : Colors.white,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
          ),

          // 상세 정보
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름 + 평점
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _bakery!.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        _bakery!.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' (${_bakery!.reviewCount})',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 영업시간
                  if (_bakery!.openingHours != null)
                    _buildInfoRow(
                      Icons.access_time,
                      '영업 중 · ${_bakery!.openingHours}',
                      Colors.green,
                    ),

                  const SizedBox(height: 12),

                  // 주소 + 거리
                  _buildInfoRow(
                    Icons.location_on,
                    '${_bakery!.address}\n현재 위치에서 ${_bakery!.distance?.toStringAsFixed(1)}km',
                    null,
                  ),

                  const SizedBox(height: 12),

                  // 전화번호
                  if (_bakery!.phoneNumber != null)
                    _buildInfoRow(
                      Icons.phone,
                      _bakery!.phoneNumber!,
                      null,
                    ),

                  const SizedBox(height: 24),

                  // 편의시설
                  if (_bakery!.amenities.isNotEmpty) ...[
                    const Text(
                      '편의시설',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _bakery!.amenities.map((amenity) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5E6D3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getAmenityIcon(amenity) + amenity,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFB85E2E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 대표 메뉴
                  if (_bakery!.specialMenu != null) ...[
                    const Text(
                      '대표 메뉴',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFD97941),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _bakery!.specialMenu!,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 액션 버튼들
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _makePhoneCall,
                          icon: const Icon(Icons.phone),
                          label: const Text('전화'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97941),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.share),
                          label: const Text('공유'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD97941),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFFD97941)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.map),
                          label: const Text('지도'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD97941),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFFD97941)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 리뷰 섹션
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '리뷰 (${_reviews.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 리뷰 리스트
                  if (_reviews.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          '아직 리뷰가 없습니다',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...(_reviews.map((review) => ReviewItem(review: review))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color? iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor ?? Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
      ],
    );
  }

  String _getAmenityIcon(String amenity) {
    if (amenity.contains('주차')) return '🅿️ ';
    if (amenity.contains('WiFi') || amenity.contains('와이파이')) return '📶 ';
    if (amenity.contains('포장')) return '📦 ';
    return '';
  }
}
