enum MemberRole {
  owner,
  editor,
  viewer;

  static MemberRole fromString(String value) {
    return MemberRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MemberRole.viewer,
    );
  }
}

class TripMember {
  final String id;
  final String tripId;
  final String userId;
  final MemberRole role;
  final DateTime joinedAt;

  TripMember({
    required this.id,
    required this.tripId,
    required this.userId,
    this.role = MemberRole.viewer,
    required this.joinedAt,
  });

  factory TripMember.fromJson(Map<String, dynamic> json) {
    return TripMember(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      userId: json['user_id'] as String,
      role: MemberRole.fromString(json['role'] as String? ?? 'viewer'),
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'user_id': userId,
      'role': role.name,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'trip_id': tripId,
      'user_id': userId,
      'role': role.name,
    };
  }

  TripMember copyWith({
    String? id,
    String? tripId,
    String? userId,
    MemberRole? role,
    DateTime? joinedAt,
  }) {
    return TripMember(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  bool get canEdit => true; // All members can edit
  bool get isOwner => role == MemberRole.owner;
}
