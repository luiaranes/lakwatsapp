enum ItineraryCategory {
  transport,
  accommodation,
  food,
  activity,
  sightseeing,
  shopping,
  rest,
  other;

  static ItineraryCategory fromString(String value) {
    return ItineraryCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ItineraryCategory.other,
    );
  }

  String get displayName {
    switch (this) {
      case ItineraryCategory.transport:
        return 'Transport';
      case ItineraryCategory.accommodation:
        return 'Accommodation';
      case ItineraryCategory.food:
        return 'Food & Dining';
      case ItineraryCategory.activity:
        return 'Activity';
      case ItineraryCategory.sightseeing:
        return 'Sightseeing';
      case ItineraryCategory.shopping:
        return 'Shopping';
      case ItineraryCategory.rest:
        return 'Rest';
      case ItineraryCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case ItineraryCategory.transport:
        return '🚗';
      case ItineraryCategory.accommodation:
        return '🏨';
      case ItineraryCategory.food:
        return '🍽️';
      case ItineraryCategory.activity:
        return '🎯';
      case ItineraryCategory.sightseeing:
        return '📸';
      case ItineraryCategory.shopping:
        return '🛍️';
      case ItineraryCategory.rest:
        return '😴';
      case ItineraryCategory.other:
        return '📌';
    }
  }
}

class ItineraryItem {
  final String id;
  final String tripId;
  final int dayNumber;
  final int sortOrder;
  final String title;
  final String? description;
  final String? startTime;
  final String? endTime;
  final String? location;
  final double? latitude;
  final double? longitude;
  final ItineraryCategory category;
  final double? estimatedCost;
  final String? currency;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  ItineraryItem({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    this.sortOrder = 0,
    required this.title,
    this.description,
    this.startTime,
    this.endTime,
    this.location,
    this.latitude,
    this.longitude,
    this.category = ItineraryCategory.other,
    this.estimatedCost,
    this.currency,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    return ItineraryItem(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      dayNumber: json['day_number'] as int,
      sortOrder: json['sort_order'] as int? ?? 0,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      category:
          ItineraryCategory.fromString(json['category'] as String? ?? 'other'),
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'day_number': dayNumber,
      'sort_order': sortOrder,
      'title': title,
      'description': description,
      'start_time': startTime,
      'end_time': endTime,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'category': category.name,
      'estimated_cost': estimatedCost,
      'currency': currency,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'trip_id': tripId,
      'day_number': dayNumber,
      'sort_order': sortOrder,
      'title': title,
      'description': description,
      'start_time': startTime,
      'end_time': endTime,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'category': category.name,
      'estimated_cost': estimatedCost,
      'currency': currency,
      'notes': notes,
    };
  }

  ItineraryItem copyWith({
    String? id,
    String? tripId,
    int? dayNumber,
    int? sortOrder,
    String? title,
    String? description,
    String? startTime,
    String? endTime,
    String? location,
    double? latitude,
    double? longitude,
    ItineraryCategory? category,
    double? estimatedCost,
    String? currency,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItineraryItem(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      dayNumber: dayNumber ?? this.dayNumber,
      sortOrder: sortOrder ?? this.sortOrder,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasTime => startTime != null;
  bool get hasLocation => latitude != null && longitude != null;
}
