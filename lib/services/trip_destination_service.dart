import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/destination.dart';
import 'package:larga/models/trip_destination.dart';
import 'package:larga/services/activity_log_service.dart';

class TripDestinationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLogService = ActivityLogService();

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Get all destinations for a trip with full destination details
  Future<List<TripDestinationWithDetails>> getTripDestinations(String tripId) async {
    try {
      final response = await _supabase
          .from('trip_destinations')
          .select('*, destination:destinations(*)')
          .eq('trip_id', tripId)
          .order('day_number', ascending: true, nullsFirst: false)
          .order('sort_order', ascending: true);

      return (response as List).map((item) {
        final tripDest = TripDestination.fromJson(item as Map<String, dynamic>);
        final destData = item['destination'] as Map<String, dynamic>?;
        final destination = destData != null ? Destination.fromJson(destData) : null;
        return TripDestinationWithDetails(tripDestination: tripDest, destination: destination);
      }).toList();
    } catch (e) {
      debugPrint('TripDestinationService: Error getting trip destinations: $e');
      rethrow;
    }
  }

  /// Get destinations for a specific day
  Future<List<TripDestinationWithDetails>> getDestinationsForDay(
    String tripId,
    int dayNumber,
  ) async {
    try {
      final response = await _supabase
          .from('trip_destinations')
          .select('*, destination:destinations(*)')
          .eq('trip_id', tripId)
          .eq('day_number', dayNumber)
          .order('sort_order', ascending: true);

      return (response as List).map((item) {
        final tripDest = TripDestination.fromJson(item as Map<String, dynamic>);
        final destData = item['destination'] as Map<String, dynamic>?;
        final destination = destData != null ? Destination.fromJson(destData) : null;
        return TripDestinationWithDetails(tripDestination: tripDest, destination: destination);
      }).toList();
    } catch (e) {
      debugPrint('TripDestinationService: Error getting day destinations: $e');
      rethrow;
    }
  }

  /// Add a destination to a trip
  Future<TripDestination> addDestinationToTrip({
    required String tripId,
    required String destinationId,
    int? dayNumber,
    DateTime? plannedDate,
    String? notes,
    String? destinationName,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final existing = await _supabase
          .from('trip_destinations')
          .select('id')
          .eq('trip_id', tripId)
          .eq('destination_id', destinationId)
          .maybeSingle();

      if (existing != null) {
        throw Exception('This destination is already added to the trip');
      }

      var countQuery = _supabase
          .from('trip_destinations')
          .select('id')
          .eq('trip_id', tripId);

      if (dayNumber != null) {
        countQuery = countQuery.eq('day_number', dayNumber);
      } else {
        countQuery = countQuery.isFilter('day_number', null);
      }

      final countResponse = await countQuery;
      final sortOrder = (countResponse as List).length;

      final response = await _supabase
          .from('trip_destinations')
          .insert({
            'trip_id': tripId,
            'destination_id': destinationId,
            'day_number': dayNumber,
            'sort_order': sortOrder,
            'notes': notes,
            'planned_date': plannedDate?.toIso8601String().split('T').first,
          })
          .select()
          .single();

      debugPrint('TripDestinationService: Added destination to trip');
      final tripDestination = TripDestination.fromJson(response);

      await _activityLogService.logDestinationAdded(
        tripId,
        tripDestination.id,
        destinationName ?? 'a destination',
        dayNumber: dayNumber,
      );

      return tripDestination;
    } catch (e) {
      debugPrint('TripDestinationService: Error adding destination: $e');
      rethrow;
    }
  }

  /// Update a trip destination (change day, notes, etc.)
  Future<TripDestination> updateTripDestination({
    required String tripDestinationId,
    int? dayNumber,
    int? sortOrder,
    String? notes,
    DateTime? plannedDate,
    bool clearNotes = false,
    bool clearPlannedDate = false,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final updates = <String, dynamic>{};

      if (dayNumber != null) {
        updates['day_number'] = dayNumber;
      }

      if (sortOrder != null) {
        updates['sort_order'] = sortOrder;
      }

      if (clearNotes) {
        updates['notes'] = null;
      } else if (notes != null) {
        updates['notes'] = notes.trim().isEmpty ? null : notes.trim();
      }

      if (clearPlannedDate) {
        updates['planned_date'] = null;
      } else if (plannedDate != null) {
        updates['planned_date'] = plannedDate.toIso8601String().split('T').first;
      }

      if (updates.isEmpty) {
        final existing = await _supabase
            .from('trip_destinations')
            .select()
            .eq('id', tripDestinationId)
            .single();
        return TripDestination.fromJson(existing);
      }

      final response = await _supabase
          .from('trip_destinations')
          .update(updates)
          .eq('id', tripDestinationId)
          .select()
          .single();

      debugPrint('TripDestinationService: Updated trip destination');
      return TripDestination.fromJson(response);
    } catch (e) {
      debugPrint('TripDestinationService: Error updating destination: $e');
      rethrow;
    }
  }

  /// Remove a destination from a trip
  Future<void> removeDestinationFromTrip({
    required String tripDestinationId,
    String? tripId,
    String? destinationName,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      String? logTripId = tripId;
      if (logTripId == null) {
        final existing = await _supabase
            .from('trip_destinations')
            .select('trip_id')
            .eq('id', tripDestinationId)
            .maybeSingle();
        logTripId = existing?['trip_id'] as String?;
      }

      await _supabase
          .from('trip_destinations')
          .delete()
          .eq('id', tripDestinationId);

      debugPrint('TripDestinationService: Removed destination from trip');

      if (logTripId != null) {
        await _activityLogService.logDestinationRemoved(
          logTripId,
          tripDestinationId,
          destinationName ?? 'a destination',
        );
      }
    } catch (e) {
      debugPrint('TripDestinationService: Error removing destination: $e');
      rethrow;
    }
  }

  /// Check if a destination is already in a trip
  Future<bool> isInTrip(String tripId, String destinationId) async {
    try {
      final response = await _supabase
          .from('trip_destinations')
          .select('id')
          .eq('trip_id', tripId)
          .eq('destination_id', destinationId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('TripDestinationService: Error checking destination: $e');
      return false;
    }
  }

  /// Reorder destinations for a day
  Future<void> reorderDestinations(
    String tripId,
    int dayNumber,
    List<String> orderedIds,
  ) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      for (var i = 0; i < orderedIds.length; i++) {
        await _supabase
            .from('trip_destinations')
            .update({'sort_order': i})
            .eq('id', orderedIds[i]);
      }

      debugPrint('TripDestinationService: Reordered destinations for day $dayNumber');
    } catch (e) {
      debugPrint('TripDestinationService: Error reordering: $e');
      rethrow;
    }
  }
}

class TripDestinationWithDetails {
  final TripDestination tripDestination;
  final Destination? destination;

  TripDestinationWithDetails({
    required this.tripDestination,
    this.destination,
  });

  String get id => tripDestination.id;
  String get tripId => tripDestination.tripId;
  String get destinationId => tripDestination.destinationId;
  int? get dayNumber => tripDestination.dayNumber;
  int get sortOrder => tripDestination.sortOrder;
  String? get notes => tripDestination.notes;
  DateTime? get plannedDate => tripDestination.plannedDate;
  DateTime get createdAt => tripDestination.createdAt;

  String get name => destination?.name ?? 'Unknown Destination';
  String? get description => destination?.description;
  String get fullLocation => destination?.fullLocation ?? '';
  DestinationCategory get category => destination?.category ?? DestinationCategory.other;
  List<String> get photos => destination?.photos ?? [];
  double? get averageRating => destination?.averageRating;

  /// True when the linked [Destination] has latitude/longitude for map pins.
  bool get hasMapPin => destination?.hasCoordinates ?? false;
  double? get latitude => destination?.latitude;
  double? get longitude => destination?.longitude;
}
