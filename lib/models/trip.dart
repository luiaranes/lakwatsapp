enum TripStatus {
  planning,
  ongoing,
  completed;

  static TripStatus fromString(String value) {
    return TripStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TripStatus.planning,
    );
  }
}

class Trip {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final TripStatus status;
  final String? coverImageUrl;
  final double? budget;
  final String currency;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  Trip({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    this.startDate,
    this.endDate,
    this.status = TripStatus.planning,
    this.coverImageUrl,
    this.budget,
    this.currency = 'PHP',
    this.isPublic = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      status: TripStatus.fromString(json['status'] as String? ?? 'planning'),
      coverImageUrl: json['cover_image_url'] as String?,
      budget: (json['budget'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'PHP',
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'status': status.name,
      'cover_image_url': coverImageUrl,
      'budget': budget,
      'currency': currency,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'status': status.name,
      'cover_image_url': coverImageUrl,
      'budget': budget,
      'currency': currency,
      'is_public': isPublic,
    };
  }

  Trip copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    TripStatus? status,
    String? coverImageUrl,
    double? budget,
    String? currency,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      budget: budget ?? this.budget,
      currency: currency ?? this.currency,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int? get tripDurationDays {
    if (startDate == null || endDate == null) return null;
    return endDate!.difference(startDate!).inDays + 1;
  }
}
