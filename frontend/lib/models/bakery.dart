class Bakery {
  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phoneNumber;
  final String? description;
  final List<String> imageUrls;
  final double rating;
  final int reviewCount;
  final bool isFavorite;
  final String? openingHours;
  final List<String>? openingHoursAll;
  final List<String> amenities;
  final String? specialMenu;
  final double? distance; // 현재 위치에서의 거리 (km)

  Bakery({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phoneNumber,
    this.description,
    this.imageUrls = const [],
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isFavorite = false,
    this.openingHours,
    this.openingHoursAll,
    this.amenities = const [],
    this.specialMenu,
    this.distance,
  });

  factory Bakery.fromJson(Map<String, dynamic> json) {
    return Bakery(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      phoneNumber: json['phoneNumber'] as String?,
      description: json['description'] as String?,
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      isFavorite: json['isFavorite'] as bool? ?? false,
      openingHours: json['openingHours'] as String?,
      openingHoursAll: (json['openingHoursAll'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      amenities: (json['amenities'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      specialMenu: json['specialMenu'] as String?,
      distance: (json['distance'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phoneNumber': phoneNumber,
      'description': description,
      'imageUrls': imageUrls,
      'rating': rating,
      'reviewCount': reviewCount,
      'isFavorite': isFavorite,
      'openingHours': openingHours,
      'openingHoursAll': openingHoursAll,
      'amenities': amenities,
      'specialMenu': specialMenu,
      'distance': distance,
    };
  }

  Bakery copyWith({
    int? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? phoneNumber,
    String? description,
    List<String>? imageUrls,
    double? rating,
    int? reviewCount,
    bool? isFavorite,
    String? openingHours,
    List<String>? openingHoursAll,
    List<String>? amenities,
    String? specialMenu,
    double? distance,
  }) {
    return Bakery(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isFavorite: isFavorite ?? this.isFavorite,
      openingHours: openingHours ?? this.openingHours,
      openingHoursAll: openingHoursAll ?? this.openingHoursAll,
      amenities: amenities ?? this.amenities,
      specialMenu: specialMenu ?? this.specialMenu,
      distance: distance ?? this.distance,
    );
  }
}
