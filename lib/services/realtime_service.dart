import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

enum RealtimeEvent { insert, update, delete }

class RealtimePayload<T> {
  final RealtimeEvent event;
  final T? newRecord;
  final T? oldRecord;

  const RealtimePayload({
    required this.event,
    this.newRecord,
    this.oldRecord,
  });
}

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController> _controllers = {};

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  String _channelKey(String table, {String? filter}) {
    return '$table${filter != null ? ':$filter' : ''}';
  }

  Stream<RealtimePayload<Map<String, dynamic>>> subscribeToTable({
    required String table,
    String? filterColumn,
    String? filterValue,
  }) {
    final key = _channelKey(table, filter: filterValue);
    
    if (_controllers.containsKey(key)) {
      return (_controllers[key] as StreamController<RealtimePayload<Map<String, dynamic>>>).stream;
    }

    final controller = StreamController<RealtimePayload<Map<String, dynamic>>>.broadcast(
      onCancel: () {
        _unsubscribe(key);
      },
    );
    _controllers[key] = controller;

    final PostgresChangeFilter? pgFilter = filterColumn != null && filterValue != null
        ? PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: filterColumn,
            value: filterValue,
          )
        : null;

    final channel = _supabase.channel('realtime:$key');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      filter: pgFilter,
      callback: (payload) {
        if (controller.isClosed) return;
        
        final event = switch (payload.eventType) {
          PostgresChangeEvent.insert => RealtimeEvent.insert,
          PostgresChangeEvent.update => RealtimeEvent.update,
          PostgresChangeEvent.delete => RealtimeEvent.delete,
          _ => RealtimeEvent.update,
        };

        controller.add(RealtimePayload(
          event: event,
          newRecord: payload.newRecord.isNotEmpty ? payload.newRecord : null,
          oldRecord: payload.oldRecord.isNotEmpty ? payload.oldRecord : null,
        ));
      },
    ).subscribe((status, [error]) {
      debugPrint('RealtimeService: Channel $key status: $status');
      if (error != null) {
        debugPrint('RealtimeService: Channel $key error: $error');
      }
    });

    _channels[key] = channel;
    debugPrint('RealtimeService: Subscribed to $key');

    return controller.stream;
  }

  Stream<RealtimePayload<Map<String, dynamic>>> subscribeToTrips() {
    final userId = _currentUserId;
    if (userId == null) {
      return const Stream.empty();
    }
    return subscribeToTable(table: 'trips');
  }

  Stream<RealtimePayload<Map<String, dynamic>>> subscribeToTripMembers(String tripId) {
    return subscribeToTable(
      table: 'trip_members',
      filterColumn: 'trip_id',
      filterValue: tripId,
    );
  }

  Stream<RealtimePayload<Map<String, dynamic>>> subscribeToExpenses(String tripId) {
    return subscribeToTable(
      table: 'expenses',
      filterColumn: 'trip_id',
      filterValue: tripId,
    );
  }

  Stream<RealtimePayload<Map<String, dynamic>>> subscribeToItineraryItems(String tripId) {
    return subscribeToTable(
      table: 'itinerary_items',
      filterColumn: 'trip_id',
      filterValue: tripId,
    );
  }

  Stream<RealtimePayload<Map<String, dynamic>>> subscribeToBookings(String tripId) {
    return subscribeToTable(
      table: 'trip_bookings',
      filterColumn: 'trip_id',
      filterValue: tripId,
    );
  }

  Stream<RealtimePayload<Map<String, dynamic>>> subscribeToActivityLogs(String tripId) {
    return subscribeToTable(
      table: 'activity_logs',
      filterColumn: 'trip_id',
      filterValue: tripId,
    );
  }

  Stream<RealtimePayload<Map<String, dynamic>>> subscribeToDraftItineraries() {
    final userId = _currentUserId;
    if (userId == null) {
      return const Stream.empty();
    }
    return subscribeToTable(
      table: 'draft_itineraries',
      filterColumn: 'user_id',
      filterValue: userId,
    );
  }

  Stream<RealtimePayload<Map<String, dynamic>>> subscribeToTrip(String tripId) {
    return subscribeToTable(
      table: 'trips',
      filterColumn: 'id',
      filterValue: tripId,
    );
  }

  void _unsubscribe(String key) {
    final channel = _channels.remove(key);
    if (channel != null) {
      channel.unsubscribe();
      debugPrint('RealtimeService: Unsubscribed from $key');
    }
    final controller = _controllers.remove(key);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
  }

  void unsubscribeFromTrip(String tripId) {
    _unsubscribe(_channelKey('trips', filter: tripId));
  }

  void unsubscribeFromTripMembers(String tripId) {
    _unsubscribe(_channelKey('trip_members', filter: tripId));
  }

  void unsubscribeFromExpenses(String tripId) {
    _unsubscribe(_channelKey('expenses', filter: tripId));
  }

  void unsubscribeFromItineraryItems(String tripId) {
    _unsubscribe(_channelKey('itinerary_items', filter: tripId));
  }

  void unsubscribeFromBookings(String tripId) {
    _unsubscribe(_channelKey('trip_bookings', filter: tripId));
  }

  void unsubscribeFromActivityLogs(String tripId) {
    _unsubscribe(_channelKey('activity_logs', filter: tripId));
  }

  void unsubscribeFromDraftItineraries() {
    final userId = _currentUserId;
    if (userId != null) {
      _unsubscribe(_channelKey('draft_itineraries', filter: userId));
    }
  }

  void unsubscribeFromTrips() {
    _unsubscribe(_channelKey('trips'));
  }

  void unsubscribeAll() {
    for (final key in _channels.keys.toList()) {
      _unsubscribe(key);
    }
    debugPrint('RealtimeService: Unsubscribed from all channels');
  }

  void dispose() {
    unsubscribeAll();
    for (final controller in _controllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _controllers.clear();
  }
}
