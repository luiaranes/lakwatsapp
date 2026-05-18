import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/user_notification.dart';
import 'package:larga/services/realtime_service.dart' show RealtimeEvent, RealtimeService;

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RealtimeService _realtimeService = RealtimeService();

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<List<UserNotification>> getNotifications({int limit = 50}) async {
    if (_currentUserId == null) return [];

    try {
      final response = await _supabase
          .from('user_notifications')
          .select()
          .eq('user_id', _currentUserId!)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((row) => UserNotification.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('NotificationService: Error loading notifications: $e');
      rethrow;
    }
  }

  Future<int> getUnreadCount() async {
    if (_currentUserId == null) return 0;

    try {
      final response = await _supabase
          .from('user_notifications')
          .select('id')
          .eq('user_id', _currentUserId!)
          .isFilter('read_at', null);

      return (response as List).length;
    } catch (e) {
      debugPrint('NotificationService: Error counting unread: $e');
      return 0;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('user_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId)
        .eq('user_id', _currentUserId!);
  }

  Future<void> markAllAsRead() async {
    if (_currentUserId == null) return;
    await _supabase
        .from('user_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', _currentUserId!)
        .isFilter('read_at', null);
  }

  StreamSubscription<void>? subscribeToNotifications({
    required void Function(UserNotification notification) onNotification,
  }) {
    final userId = _currentUserId;
    if (userId == null) return null;

    final stream = _realtimeService.subscribeToUserNotifications(userId);
    if (stream == const Stream.empty()) return null;

    return stream.listen((payload) {
      if (payload.event != RealtimeEvent.insert) return;
      final record = payload.newRecord;
      if (record == null) return;
      try {
        onNotification(UserNotification.fromJson(record));
      } catch (e) {
        debugPrint('NotificationService: Failed to parse notification: $e');
      }
    });
  }

  void unsubscribeFromNotifications() {
    final userId = _currentUserId;
    if (userId != null) {
      _realtimeService.unsubscribeFromUserNotifications(userId);
    }
  }
}
