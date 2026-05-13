import '../api/api_client.dart';
import '../models/api_response.dart';
import '../models/bakery.dart';
import '../models/review.dart';
import '../models/search_history.dart';

class BakeryRepository {
  final ApiClient _apiClient;

  BakeryRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// 빵집 목록 조회
  Future<ApiResponse<List<Bakery>>> getBakeries({
    String? keyword,
    String? district,
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    final queryParams = <String, String>{};

    if (keyword != null && keyword.isNotEmpty) {
      queryParams['keyword'] = keyword;
    }
    if (district != null && district.isNotEmpty) {
      queryParams['district'] = district;
    }
    if (latitude != null) {
      queryParams['lat'] = latitude.toString();
    }
    if (longitude != null) {
      queryParams['lon'] = longitude.toString();
    }
    if (radius != null) {
      queryParams['radius'] = radius.toString();
    }

    final response = await _apiClient.get<List<Bakery>>(
      '/api/v1/bakeries',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
      fromJson: (json) {
        final map = json as Map<String, dynamic>;
        final list = map['bakeries'] as List<dynamic>;
        return list.map((item) => Bakery.fromJson(item as Map<String, dynamic>)).toList();
      },
    );

    return response;
  }

  /// 빵집 상세 조회
  Future<ApiResponse<Bakery>> getBakeryDetail(int bakeryId) async {
    final response = await _apiClient.get<Bakery>(
      '/api/v1/bakeries/$bakeryId',
      fromJson: (json) => Bakery.fromJson(json as Map<String, dynamic>),
    );

    return response;
  }

  /// 빵집 리뷰 조회
  Future<ApiResponse<List<Review>>> getBakeryReviews(int bakeryId) async {
    final response = await _apiClient.get<List<Review>>(
      '/api/v1/bakeries/$bakeryId/reviews',
      fromJson: (json) {
        final map = json as Map<String, dynamic>;
        final list = map['reviews'] as List<dynamic>;
        return list.map((item) => Review.fromJson(item as Map<String, dynamic>)).toList();
      },
    );

    return response;
  }

  /// 검색 기록 조회
  Future<ApiResponse<List<SearchHistory>>> getSearchHistory() async {
    final response = await _apiClient.get<List<SearchHistory>>(
      '/api/v1/users/search-history',
      fromJson: (json) {
        final map = json as Map<String, dynamic>;
        final list = map['keywords'] as List<dynamic>;
        return list.map((item) => SearchHistory.fromJson(item as Map<String, dynamic>)).toList();
      },
    );

    return response;
  }

  /// 검색 기록 삭제
  Future<ApiResponse<void>> deleteSearchHistory(int historyId) async {
    final response = await _apiClient.delete<void>(
      '/api/v1/users/search-history/$historyId',
    );

    return response;
  }

  /// 즐겨찾기 토글
  Future<ApiResponse<bool>> toggleFavorite(int bakeryId) async {
    final response = await _apiClient.post<bool>(
      '/api/v1/bakeries/$bakeryId/favorite',
      fromJson: (json) => json['isFavorite'] as bool? ?? false,
    );

    return response;
  }

  /// 즐겨찾기 목록 조회
  Future<ApiResponse<List<Bakery>>> getFavorites() async {
    final response = await _apiClient.get<List<Bakery>>(
      '/api/v1/users/favorites',
      fromJson: (json) {
        final map = json as Map<String, dynamic>;
        final list = map['favorites'] as List<dynamic>;
        return list.map((item) => Bakery.fromJson(item as Map<String, dynamic>)).toList();
      },
    );

    return response;
  }

  void dispose() {
    _apiClient.dispose();
  }
}
