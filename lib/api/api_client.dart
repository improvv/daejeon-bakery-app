import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';

class ApiClient {
  // 사용자가 만든 Gist 주소 (파일 그 자체)
  static const String baseUrl = 'https://gist.githubusercontent.com/rlaxodnjs02/fce8b71cc84542f35ed7722e2911a526/raw/06c685414f0bf8cc84d40bf0aa66cdaa7dde3aa7/bakeries.json'; 
  
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      Uri uri;

      // [핵심 수정] BaseUrl이 Gist(깃허브)라면?
      // 호출할 때 들어오는 path('/api/v1/bakeries')를 무시하고
      // 오직 baseUrl(파일 주소)만 사용하도록 분기 처리했습니다.
      if (baseUrl.contains('gist.githubusercontent.com')) {
        uri = Uri.parse(baseUrl).replace(queryParameters: queryParameters);
      } else {
        // 나중에 진짜 서버 쓸 때는 원래대로 동작
        uri = Uri.parse('$baseUrl$path').replace(
          queryParameters: queryParameters,
        );
      }

      print("✅ [ApiClient] 요청 주소: $uri"); // 디버깅용 로그

      final response = await _client.get(
        uri,
        // [중요] Gist 요청 시 불필요한 헤더가 있으면 CORS 에러가 날 수 있어 최소화합니다.
        headers: baseUrl.contains('gist') 
          ? {} 
          : {'Content-Type': 'application/json'},
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse<T>(
        code: 'ERROR',
        message: e.toString(),
        data: null,
      );
    }
  }

  // POST, DELETE는 Gist에서 안 되므로 에러 처리하거나 그대로 둡니다.
  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic)? fromJson,
  }) async {
    return ApiResponse(code: 'ERROR', message: 'Gist에서는 POST를 지원하지 않습니다.', data: null);
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    T Function(dynamic)? fromJson,
  }) async {
     return ApiResponse(code: 'ERROR', message: 'Gist에서는 DELETE를 지원하지 않습니다.', data: null);
  }

  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic)? fromJson,
  ) {
    // 한글 깨짐 방지 (utf8.decode 추가)
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponse<T>.fromJson(json, fromJson);
    } else {
      return ApiResponse<T>(
        code: json['code'] as String? ?? 'ERROR',
        message: json['message'] as String? ?? 'Unknown error',
        data: null,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}