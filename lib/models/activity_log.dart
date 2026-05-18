enum ActivityEntityType {
  trip,
  itineraryItem,
  expense,
  expenseSplit,
  tripMember,
  tripDestination,
  booking,
  other;

  static ActivityEntityType fromString(String value) {
    return switch (value) {
      'trip' => ActivityEntityType.trip,
      'itinerary_item' => ActivityEntityType.itineraryItem,
      'expense' => ActivityEntityType.expense,
      'expense_split' => ActivityEntityType.expenseSplit,
      'trip_member' => ActivityEntityType.tripMember,
      'trip_destination' => ActivityEntityType.tripDestination,
      'booking' => ActivityEntityType.booking,
      _ => ActivityEntityType.other,
    };
  }

  String toDbString() {
    return switch (this) {
      ActivityEntityType.trip => 'trip',
      ActivityEntityType.itineraryItem => 'itinerary_item',
      ActivityEntityType.expense => 'expense',
      ActivityEntityType.expenseSplit => 'expense_split',
      ActivityEntityType.tripMember => 'trip_member',
      ActivityEntityType.tripDestination => 'trip_destination',
      ActivityEntityType.booking => 'booking',
      ActivityEntityType.other => 'other',
    };
  }

  String get displayName {
    return switch (this) {
      ActivityEntityType.trip => 'Trip',
      ActivityEntityType.itineraryItem => 'Activity',
      ActivityEntityType.expense => 'Expense',
      ActivityEntityType.expenseSplit => 'Expense Split',
      ActivityEntityType.tripMember => 'Member',
      ActivityEntityType.tripDestination => 'Destination',
      ActivityEntityType.booking => 'Booking',
      ActivityEntityType.other => 'Item',
    };
  }

  String get icon {
    return switch (this) {
      ActivityEntityType.trip => '✈️',
      ActivityEntityType.itineraryItem => '📍',
      ActivityEntityType.expense => '💰',
      ActivityEntityType.expenseSplit => '💸',
      ActivityEntityType.tripMember => '👤',
      ActivityEntityType.tripDestination => '🗺️',
      ActivityEntityType.booking => '🎫',
      ActivityEntityType.other => '📝',
    };
  }
}

enum ActivityAction {
  created,
  updated,
  deleted,
  joined,
  left,
  invited,
  removed,
  reordered,
  settled,
  other;

  static ActivityAction fromString(String value) {
    return switch (value) {
      'created' => ActivityAction.created,
      'updated' => ActivityAction.updated,
      'deleted' => ActivityAction.deleted,
      'joined' => ActivityAction.joined,
      'left' => ActivityAction.left,
      'invited' => ActivityAction.invited,
      'removed' => ActivityAction.removed,
      'reordered' => ActivityAction.reordered,
      'settled' => ActivityAction.settled,
      _ => ActivityAction.other,
    };
  }

  String toDbString() => name;

  String get pastTense {
    return switch (this) {
      ActivityAction.created => 'created',
      ActivityAction.updated => 'updated',
      ActivityAction.deleted => 'deleted',
      ActivityAction.joined => 'joined',
      ActivityAction.left => 'left',
      ActivityAction.invited => 'invited',
      ActivityAction.removed => 'removed',
      ActivityAction.reordered => 'reordered',
      ActivityAction.settled => 'settled',
      ActivityAction.other => 'modified',
    };
  }
}

class ActivityLog {
  final String id;
  final ActivityEntityType entityType;
  final String entityId;
  final String? tripId;
  final String userId;
  final ActivityAction action;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.tripId,
    required this.userId,
    required this.action,
    this.details = const {},
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String,
      entityType: ActivityEntityType.fromString(json['entity_type'] as String),
      entityId: json['entity_id'] as String,
      tripId: json['trip_id'] as String?,
      userId: json['user_id'] as String,
      action: ActivityAction.fromString(json['action'] as String),
      details: json['details'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType.toDbString(),
      'entity_id': entityId,
      'trip_id': tripId,
      'user_id': userId,
      'action': action.toDbString(),
      'details': details,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'entity_type': entityType.toDbString(),
      'entity_id': entityId,
      'trip_id': tripId,
      'user_id': userId,
      'action': action.toDbString(),
      'details': details,
    };
  }

  String? get itemTitle => details['title'] as String?;
  String? get itemName => details['name'] as String?;
  String? get targetUserName => details['target_user_name'] as String?;
  List<String>? get changedFields => (details['changed_fields'] as List?)?.cast<String>();
  
  /// Get detailed changes map: {fieldName: {from: oldValue, to: newValue}}
  Map<String, Map<String, dynamic>>? get changes {
    final changesData = details['changes'];
    if (changesData == null) return null;
    if (changesData is! Map) return null;
    
    final result = <String, Map<String, dynamic>>{};
    changesData.forEach((key, value) {
      if (value is Map) {
        result[key as String] = Map<String, dynamic>.from(value);
      }
    });
    return result.isEmpty ? null : result;
  }

  /// Check if this log has detailed changes
  bool get hasDetailedChanges => changes != null && changes!.isNotEmpty;

  String getDescription({String? actorName}) {
    final actor = actorName ?? 'Someone';
    final target = itemTitle ?? itemName ?? entityType.displayName.toLowerCase();

    if (entityType == ActivityEntityType.expenseSplit) {
      final memberCount = details['member_count'];
      final fromName = details['from_user_name'];
      final toName = details['to_user_name'];
      
      return switch (action) {
        ActivityAction.created => '$actor split "$target" among $memberCount members',
        ActivityAction.updated => '$actor updated split for "$target"',
        ActivityAction.deleted => '$actor removed split for "$target"',
        ActivityAction.settled => '$actor settled debt: $fromName paid $toName',
        _ => '$actor modified split for "$target"',
      };
    }

    return switch (action) {
      ActivityAction.created => '$actor added "$target"',
      ActivityAction.updated => '$actor updated "$target"',
      ActivityAction.deleted => '$actor removed "$target"',
      ActivityAction.joined => '$actor joined the trip',
      ActivityAction.left => '$actor left the trip',
      ActivityAction.invited => '$actor invited ${targetUserName ?? "a member"}',
      ActivityAction.removed => '$actor removed ${targetUserName ?? "a member"}',
      ActivityAction.reordered => '$actor reordered activities',
      ActivityAction.settled => '$actor settled "$target"',
      ActivityAction.other => '$actor modified "$target"',
    };
  }
}
