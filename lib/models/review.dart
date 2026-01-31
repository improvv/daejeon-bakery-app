class Review {
  final int id;
  final int bakeryId;
  final String userName;
  final String? userProfileImage;
  final double rating;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.bakeryId,
    required this.userName,
    this.userProfileImage,
    required this.rating,
    required this.content,
    this.imageUrls = const [],
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      bakeryId: json['bakeryId'] as int,
      userName: json['userName'] as String,
      userProfileImage: json['userProfileImage'] as String?,
      rating: (json['rating'] as num).toDouble(),
      content: json['content'] as String,
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bakeryId': bakeryId,
      'userName': userName,
      'userProfileImage': userProfileImage,
      'rating': rating,
      'content': content,
      'imageUrls': imageUrls,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
