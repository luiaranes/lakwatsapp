enum PackingCategory {
  clothing,
  toiletries,
  electronics,
  documents,
  health,
  gear,
  other;

  static PackingCategory fromString(String value) {
    return PackingCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PackingCategory.other,
    );
  }

  String get displayName {
    switch (this) {
      case PackingCategory.clothing:
        return 'Clothing';
      case PackingCategory.toiletries:
        return 'Toiletries';
      case PackingCategory.electronics:
        return 'Electronics';
      case PackingCategory.documents:
        return 'Documents';
      case PackingCategory.health:
        return 'Health';
      case PackingCategory.gear:
        return 'Gear';
      case PackingCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case PackingCategory.clothing:
        return '👕';
      case PackingCategory.toiletries:
        return '🧴';
      case PackingCategory.electronics:
        return '🔌';
      case PackingCategory.documents:
        return '📄';
      case PackingCategory.health:
        return '💊';
      case PackingCategory.gear:
        return '🎒';
      case PackingCategory.other:
        return '📦';
    }
  }
}

enum PackingItemSource {
  manual,
  ai;

  static PackingItemSource fromString(String value) {
    return PackingItemSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PackingItemSource.manual,
    );
  }
}

class PackingItem {
  final String id;
  final String tripId;
  final String createdByUserId;
  final String assignedToUserId;
  final String? assignedByUserId;
  final DateTime? assignedAt;
  final String name;
  final PackingCategory category;
  final PackingItemSource source;
  final bool isChecked;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  PackingItem({
    required this.id,
    required this.tripId,
    required this.createdByUserId,
    required this.assignedToUserId,
    this.assignedByUserId,
    this.assignedAt,
    required this.name,
    this.category = PackingCategory.other,
    this.source = PackingItemSource.manual,
    this.isChecked = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PackingItem.fromJson(Map<String, dynamic> json) {
    return PackingItem(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      createdByUserId: json['created_by_user_id'] as String,
      assignedToUserId: json['assigned_to_user_id'] as String,
      assignedByUserId: json['assigned_by_user_id'] as String?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      name: json['name'] as String,
      category: PackingCategory.fromString(json['category'] as String? ?? 'other'),
      source: PackingItemSource.fromString(json['source'] as String? ?? 'manual'),
      isChecked: json['is_checked'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool isAssignedTo(String userId) => assignedToUserId == userId;

  bool isCreatedBy(String userId) => createdByUserId == userId;

  Map<String, dynamic> toInsertJson() {
    return {
      'trip_id': tripId,
      'created_by_user_id': createdByUserId,
      'assigned_to_user_id': assignedToUserId,
      'assigned_by_user_id': assignedByUserId,
      'name': name.trim(),
      'category': category.name,
      'source': source.name,
      'is_checked': isChecked,
      'sort_order': sortOrder,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name.trim(),
      'category': category.name,
      'is_checked': isChecked,
      'sort_order': sortOrder,
      'assigned_to_user_id': assignedToUserId,
      'assigned_by_user_id': assignedByUserId,
    };
  }

  PackingItem copyWith({
    String? id,
    String? tripId,
    String? createdByUserId,
    String? assignedToUserId,
    String? assignedByUserId,
    DateTime? assignedAt,
    String? name,
    PackingCategory? category,
    PackingItemSource? source,
    bool? isChecked,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PackingItem(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      assignedByUserId: assignedByUserId ?? this.assignedByUserId,
      assignedAt: assignedAt ?? this.assignedAt,
      name: name ?? this.name,
      category: category ?? this.category,
      source: source ?? this.source,
      isChecked: isChecked ?? this.isChecked,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
