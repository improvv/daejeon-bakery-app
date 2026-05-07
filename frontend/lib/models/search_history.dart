class SearchHistory {
  final int id;
  final String keyword;
  final DateTime searchedAt;

  SearchHistory({
    required this.id,
    required this.keyword,
    required this.searchedAt,
  });

  factory SearchHistory.fromJson(Map<String, dynamic> json) {
    return SearchHistory(
      id: json['id'] as int,
      keyword: json['keyword'] as String,
      searchedAt: DateTime.parse(json['searchedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'keyword': keyword,
      'searchedAt': searchedAt.toIso8601String(),
    };
  }
}

enum DistrictFilter {
  all('전체'),
  donggu('동구'),
  seogu('서구'),
  junggu('중구'),
  yuseonggu('유성구'),
  daedeokgu('대덕구');

  final String displayName;
  const DistrictFilter(this.displayName);
}
