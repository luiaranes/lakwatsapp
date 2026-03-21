enum DestinationCategory {
  city,
  beach,
  mountain,
  island,
  historicSite,
  naturalWonder,
  park,
  resort,
  other;

  static DestinationCategory fromString(String value) {
    return DestinationCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DestinationCategory.other,
    );
  }

  String get displayName {
    switch (this) {
      case DestinationCategory.city:
        return 'City';
      case DestinationCategory.beach:
        return 'Beach';
      case DestinationCategory.mountain:
        return 'Mountain';
      case DestinationCategory.island:
        return 'Island';
      case DestinationCategory.historicSite:
        return 'Historic Site';
      case DestinationCategory.naturalWonder:
        return 'Natural Wonder';
      case DestinationCategory.park:
        return 'Park';
      case DestinationCategory.resort:
        return 'Resort';
      case DestinationCategory.other:
        return 'Other';
    }
  }
}

class Destination {
  final String id;
  final String name;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;
  final String? province;
  final String country;
  final DestinationCategory category;
  final List<String> photos;
  final String? tips;
  final double? averageRating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Destination({
    required this.id,
    required this.name,
    this.description,
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.province,
    this.country = 'Philippines',
    this.category = DestinationCategory.other,
    this.photos = const [],
    this.tips,
    this.averageRating,
    this.reviewCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      country: json['country'] as String? ?? 'Philippines',
      category:
          DestinationCategory.fromString(json['category'] as String? ?? 'other'),
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      tips: json['tips'] as String?,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      reviewCount: json['review_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'province': province,
      'country': country,
      'category': category.name,
      'photos': photos,
      'tips': tips,
      'average_rating': averageRating,
      'review_count': reviewCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Destination copyWith({
    String? id,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? province,
    String? country,
    DestinationCategory? category,
    List<String>? photos,
    String? tips,
    double? averageRating,
    int? reviewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Destination(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      province: province ?? this.province,
      country: country ?? this.country,
      category: category ?? this.category,
      photos: photos ?? this.photos,
      tips: tips ?? this.tips,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get fullLocation {
    final parts = <String>[];
    if (city != null) parts.add(city!);
    if (province != null) parts.add(province!);
    parts.add(country);
    return parts.join(', ');
  }

  bool get hasCoordinates => latitude != null && longitude != null;
}
