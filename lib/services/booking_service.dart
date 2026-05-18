import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/booking.dart';
import 'package:larga/models/activity_log.dart';
import 'package:larga/services/activity_log_service.dart';
import 'package:larga/services/realtime_service.dart';

class BookingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLogService = ActivityLogService();
  final RealtimeService _realtimeService = RealtimeService();

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<List<Booking>> getBookings(String tripId) async {
    try {
      final response = await _supabase
          .from('trip_bookings')
          .select()
          .eq('trip_id', tripId)
          .order('start_date', ascending: true, nullsFirst: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => Booking.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('BookingService: Error getting bookings: $e');
      rethrow;
    }
  }

  Future<Booking?> getBookingById(String bookingId) async {
    try {
      final response = await _supabase
          .from('trip_bookings')
          .select()
          .eq('id', bookingId)
          .maybeSingle();

      if (response == null) return null;
      return Booking.fromJson(response);
    } catch (e) {
      debugPrint('BookingService: Error getting booking: $e');
      rethrow;
    }
  }

  Future<Booking> createBooking({
    required String tripId,
    required String title,
    BookingType bookingType = BookingType.other,
    String? provider,
    String? confirmationNumber,
    DateTime? startDate,
    DateTime? endDate,
    String? startTime,
    String? endTime,
    String? location,
    String? address,
    double? amount,
    String? currency,
    String? notes,
    String? itineraryItemId,
    Map<String, dynamic>? details,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _supabase
          .from('trip_bookings')
          .insert({
            'trip_id': tripId,
            'created_by_user_id': _currentUserId,
            'booking_type': bookingType.name,
            'source': BookingSource.manual.name,
            'title': title.trim(),
            'provider': provider?.trim(),
            'confirmation_number': confirmationNumber?.trim(),
            'start_date': startDate?.toIso8601String().split('T').first,
            'end_date': endDate?.toIso8601String().split('T').first,
            'start_time': startTime?.trim(),
            'end_time': endTime?.trim(),
            'location': location?.trim(),
            'address': address?.trim(),
            'amount': amount,
            'currency': currency,
            'notes': notes?.trim(),
            'itinerary_item_id': itineraryItemId,
            'details': details ?? {},
          })
          .select()
          .single();

      final booking = Booking.fromJson(response);
      await _activityLogService.logActivity(
        entityType: ActivityEntityType.booking,
        entityId: booking.id,
        tripId: tripId,
        action: ActivityAction.created,
        details: {'title': booking.title, 'type': booking.bookingType.name},
      );
      return booking;
    } catch (e) {
      debugPrint('BookingService: Error creating booking: $e');
      rethrow;
    }
  }

  Future<Booking> updateBooking(Booking booking) async {
    try {
      final response = await _supabase
          .from('trip_bookings')
          .update(booking.toUpdateJson())
          .eq('id', booking.id)
          .select()
          .single();

      final updated = Booking.fromJson(response);
      await _activityLogService.logActivity(
        entityType: ActivityEntityType.booking,
        entityId: updated.id,
        tripId: updated.tripId,
        action: ActivityAction.updated,
        details: {'title': updated.title},
      );
      return updated;
    } catch (e) {
      debugPrint('BookingService: Error updating booking: $e');
      rethrow;
    }
  }

  Future<void> deleteBooking(String bookingId, String tripId) async {
    try {
      await _supabase.from('trip_bookings').delete().eq('id', bookingId);
      await _activityLogService.logActivity(
        entityType: ActivityEntityType.booking,
        entityId: bookingId,
        tripId: tripId,
        action: ActivityAction.deleted,
      );
    } catch (e) {
      debugPrint('BookingService: Error deleting booking: $e');
      rethrow;
    }
  }

  StreamSubscription<void>? subscribeToBookingsChanges({
    required String tripId,
    required void Function() onUpdate,
  }) {
    final stream = _realtimeService.subscribeToBookings(tripId);
    if (stream == const Stream.empty()) return null;

    return stream.listen((payload) {
      debugPrint('BookingService: Realtime booking change: ${payload.event}');
      onUpdate();
    });
  }

  void unsubscribeFromBookings(String tripId) {
    _realtimeService.unsubscribeFromBookings(tripId);
  }
}
