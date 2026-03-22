enum FriendshipStatus {
  pending,
  accepted,
  rejected,
  blocked;

  static FriendshipStatus fromString(String value) {
    return FriendshipStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FriendshipStatus.pending,
    );
  }

  String get displayName {
    return switch (this) {
      FriendshipStatus.pending => 'Pending',
      FriendshipStatus.accepted => 'Friends',
      FriendshipStatus.rejected => 'Rejected',
      FriendshipStatus.blocked => 'Blocked',
    };
  }
}

class Friendship {
  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    this.status = FriendshipStatus.pending,
    required this.createdAt,
    this.respondedAt,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      addresseeId: json['addressee_id'] as String,
      status: FriendshipStatus.fromString(json['status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester_id': requesterId,
      'addressee_id': addresseeId,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'requester_id': requesterId,
      'addressee_id': addresseeId,
      'status': status.name,
    };
  }

  Friendship copyWith({
    String? id,
    String? requesterId,
    String? addresseeId,
    FriendshipStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return Friendship(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      addresseeId: addresseeId ?? this.addresseeId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  bool get isPending => status == FriendshipStatus.pending;
  bool get isAccepted => status == FriendshipStatus.accepted;
  bool get isRejected => status == FriendshipStatus.rejected;
  bool get isBlocked => status == FriendshipStatus.blocked;

  bool isRequester(String userId) => requesterId == userId;
  bool isAddressee(String userId) => addresseeId == userId;

  String getOtherUserId(String currentUserId) {
    return requesterId == currentUserId ? addresseeId : requesterId;
  }
}
