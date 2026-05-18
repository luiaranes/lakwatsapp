enum UserNotificationType {
  packingAssigned,
  other;

  static UserNotificationType fromString(String value) {
    return switch (value) {
      'packing_assigned' => UserNotificationType.packingAssigned,
      _ => UserNotificationType.other,
    };
  }

  String toDbString() {
    return switch (this) {
      UserNotificationType.packingAssigned => 'packing_assigned',
      UserNotificationType.other => 'other',
    };
  }
}

class UserNotification {
  final String id;
  final String userId;
  final String? tripId;
  final UserNotificationType type;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  UserNotification({
    required this.id,
    required this.userId,
    this.tripId,
    required this.type,
    required this.title,
    this.body,
    this.data = const {},
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  String? get packingItemId => data['packing_item_id'] as String?;

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tripId: json['trip_id'] as String?,
      type: UserNotificationType.fromString(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String?,
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : {},
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
