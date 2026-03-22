import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/activity_log.dart';

class ActivityLogService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Log an activity
  Future<ActivityLog?> logActivity({
    required ActivityEntityType entityType,
    required String entityId,
    String? tripId,
    required ActivityAction action,
    Map<String, dynamic>? details,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('activity_logs')
          .insert({
            'entity_type': entityType.toDbString(),
            'entity_id': entityId,
            'trip_id': tripId,
            'user_id': userId,
            'action': action.toDbString(),
            'details': details ?? {},
          })
          .select()
          .single();

      debugPrint('ActivityLogService: Logged ${action.name} on ${entityType.name}');
      return ActivityLog.fromJson(response);
    } catch (e) {
      debugPrint('ActivityLogService: Error logging activity: $e');
      return null;
    }
  }

  /// Get activity logs for a trip
  Future<List<ActivityLog>> getTripActivityLogs(
    String tripId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('activity_logs')
          .select()
          .eq('trip_id', tripId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((item) => ActivityLog.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ActivityLogService: Error getting trip logs: $e');
      rethrow;
    }
  }

  /// Get activity logs for a specific entity
  Future<List<ActivityLog>> getEntityActivityLogs({
    required ActivityEntityType entityType,
    required String entityId,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from('activity_logs')
          .select()
          .eq('entity_type', entityType.toDbString())
          .eq('entity_id', entityId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => ActivityLog.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ActivityLogService: Error getting entity logs: $e');
      rethrow;
    }
  }

  /// Get recent activity logs for the current user
  Future<List<ActivityLog>> getMyRecentActivity({int limit = 20}) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('activity_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => ActivityLog.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ActivityLogService: Error getting my logs: $e');
      rethrow;
    }
  }

  // ============================================================================
  // CONVENIENCE METHODS FOR COMMON LOGGING SCENARIOS
  // ============================================================================

  /// Log trip creation
  Future<void> logTripCreated(String tripId, String tripTitle) async {
    await logActivity(
      entityType: ActivityEntityType.trip,
      entityId: tripId,
      tripId: tripId,
      action: ActivityAction.created,
      details: {'title': tripTitle},
    );
  }

  /// Log trip deletion
  /// Note: This log will be cascade deleted with the trip, but remains
  /// visible in the user's personal activity history until then
  Future<void> logTripDeleted(String tripId, String tripTitle) async {
    await logActivity(
      entityType: ActivityEntityType.trip,
      entityId: tripId,
      tripId: tripId,
      action: ActivityAction.deleted,
      details: {'title': tripTitle},
    );
  }

  /// Log trip update with detailed changes
  /// [changes] is a map of field name -> {'from': oldValue, 'to': newValue}
  Future<void> logTripUpdated(
    String tripId,
    String tripTitle, {
    List<String>? changedFields,
    Map<String, Map<String, dynamic>>? changes,
  }) async {
    await logActivity(
      entityType: ActivityEntityType.trip,
      entityId: tripId,
      tripId: tripId,
      action: ActivityAction.updated,
      details: {
        'title': tripTitle,
        if (changedFields != null) 'changed_fields': changedFields,
        if (changes != null) 'changes': changes,
      },
    );
  }

  /// Log itinerary item created
  Future<void> logItineraryItemCreated(String itemId, String tripId, String title, int dayNumber) async {
    await logActivity(
      entityType: ActivityEntityType.itineraryItem,
      entityId: itemId,
      tripId: tripId,
      action: ActivityAction.created,
      details: {'title': title, 'day_number': dayNumber},
    );
  }

  /// Log itinerary item updated with detailed changes
  /// [changes] is a map of field name -> {'from': oldValue, 'to': newValue}
  Future<void> logItineraryItemUpdated(
    String itemId,
    String tripId,
    String title, {
    List<String>? changedFields,
    Map<String, Map<String, dynamic>>? changes,
  }) async {
    await logActivity(
      entityType: ActivityEntityType.itineraryItem,
      entityId: itemId,
      tripId: tripId,
      action: ActivityAction.updated,
      details: {
        'title': title,
        if (changedFields != null) 'changed_fields': changedFields,
        if (changes != null) 'changes': changes,
      },
    );
  }

  /// Log itinerary item deleted
  Future<void> logItineraryItemDeleted(String itemId, String tripId, String title) async {
    await logActivity(
      entityType: ActivityEntityType.itineraryItem,
      entityId: itemId,
      tripId: tripId,
      action: ActivityAction.deleted,
      details: {'title': title},
    );
  }

  /// Log itinerary items reordered
  Future<void> logItineraryReordered(String tripId, int dayNumber) async {
    await logActivity(
      entityType: ActivityEntityType.itineraryItem,
      entityId: tripId,
      tripId: tripId,
      action: ActivityAction.reordered,
      details: {'day_number': dayNumber},
    );
  }

  /// Log member joined
  Future<void> logMemberJoined(String tripId, String memberId, String memberName) async {
    await logActivity(
      entityType: ActivityEntityType.tripMember,
      entityId: memberId,
      tripId: tripId,
      action: ActivityAction.joined,
      details: {'name': memberName},
    );
  }

  /// Log member invited
  Future<void> logMemberInvited(
    String tripId,
    String memberId,
    String memberName, {
    String? role,
  }) async {
    await logActivity(
      entityType: ActivityEntityType.tripMember,
      entityId: memberId,
      tripId: tripId,
      action: ActivityAction.invited,
      details: {
        'target_user_name': memberName,
        if (role != null) 'role': role,
      },
    );
  }

  /// Log member left
  Future<void> logMemberLeft(String tripId, String memberId, String memberName) async {
    await logActivity(
      entityType: ActivityEntityType.tripMember,
      entityId: memberId,
      tripId: tripId,
      action: ActivityAction.left,
      details: {'name': memberName},
    );
  }

  /// Log member removed
  Future<void> logMemberRemoved(String tripId, String memberId, String memberName) async {
    await logActivity(
      entityType: ActivityEntityType.tripMember,
      entityId: memberId,
      tripId: tripId,
      action: ActivityAction.removed,
      details: {'target_user_name': memberName},
    );
  }
}
