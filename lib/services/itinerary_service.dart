import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/itinerary_item.dart';
import 'package:larga/services/activity_log_service.dart';

class ItineraryService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLogService = ActivityLogService();

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Fetch all itinerary items for a trip, sorted by day and order
  Future<List<ItineraryItem>> getItineraryItems(String tripId) async {
    try {
      final response = await _supabase
          .from('itinerary_items')
          .select()
          .eq('trip_id', tripId)
          .order('day_number', ascending: true)
          .order('sort_order', ascending: true)
          .order('start_time', ascending: true);

      return (response as List)
          .map((item) => ItineraryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ItineraryService: Error getting items: $e');
      rethrow;
    }
  }

  /// Fetch itinerary items for a specific day
  Future<List<ItineraryItem>> getItemsForDay(String tripId, int dayNumber) async {
    try {
      final response = await _supabase
          .from('itinerary_items')
          .select()
          .eq('trip_id', tripId)
          .eq('day_number', dayNumber)
          .order('sort_order', ascending: true)
          .order('start_time', ascending: true);

      return (response as List)
          .map((item) => ItineraryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ItineraryService: Error getting items for day: $e');
      rethrow;
    }
  }

  /// Get a single itinerary item by ID
  Future<ItineraryItem?> getItemById(String itemId) async {
    try {
      final response = await _supabase
          .from('itinerary_items')
          .select()
          .eq('id', itemId)
          .maybeSingle();

      if (response == null) return null;
      return ItineraryItem.fromJson(response);
    } catch (e) {
      debugPrint('ItineraryService: Error getting item: $e');
      rethrow;
    }
  }

  /// Get the next sort order for a day
  Future<int> _getNextSortOrder(String tripId, int dayNumber) async {
    try {
      final response = await _supabase
          .from('itinerary_items')
          .select('sort_order')
          .eq('trip_id', tripId)
          .eq('day_number', dayNumber)
          .order('sort_order', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return 0;
      return (response['sort_order'] as int) + 1;
    } catch (e) {
      return 0;
    }
  }

  /// Create a new itinerary item
  Future<ItineraryItem> createItem({
    required String tripId,
    required int dayNumber,
    required String title,
    String? description,
    String? startTime,
    String? endTime,
    String? location,
    double? latitude,
    double? longitude,
    ItineraryCategory category = ItineraryCategory.other,
    double? estimatedCost,
    String? currency,
    String? notes,
    int? sortOrder,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final nextSortOrder = sortOrder ?? await _getNextSortOrder(tripId, dayNumber);

      final response = await _supabase
          .from('itinerary_items')
          .insert({
            'trip_id': tripId,
            'day_number': dayNumber,
            'sort_order': nextSortOrder,
            'title': title.trim(),
            'description': description?.trim(),
            'start_time': startTime,
            'end_time': endTime,
            'location': location?.trim(),
            'latitude': latitude,
            'longitude': longitude,
            'category': category.name,
            'estimated_cost': estimatedCost,
            'currency': currency,
            'notes': notes?.trim(),
          })
          .select()
          .single();

      debugPrint('ItineraryService: Item created');
      final item = ItineraryItem.fromJson(response);
      
      // Log the activity
      await _activityLogService.logItineraryItemCreated(
        item.id,
        tripId,
        title.trim(),
        dayNumber,
      );
      
      return item;
    } catch (e) {
      debugPrint('ItineraryService: Error creating item: $e');
      rethrow;
    }
  }

  /// Update an existing itinerary item
  Future<ItineraryItem> updateItem({
    required String itemId,
    int? dayNumber,
    int? sortOrder,
    String? title,
    String? description,
    String? startTime,
    String? endTime,
    String? location,
    double? latitude,
    double? longitude,
    ItineraryCategory? category,
    double? estimatedCost,
    String? currency,
    String? notes,
    bool clearDescription = false,
    bool clearStartTime = false,
    bool clearEndTime = false,
    bool clearLocation = false,
    bool clearCoordinates = false,
    bool clearEstimatedCost = false,
    bool clearCurrency = false,
    bool clearNotes = false,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Fetch original item for change tracking
      final original = await getItemById(itemId);
      if (original == null) throw Exception('Item not found');

      final updates = <String, dynamic>{};
      final changes = <String, Map<String, dynamic>>{};

      if (dayNumber != null) {
        updates['day_number'] = dayNumber;
        changes['day_number'] = {'from': original.dayNumber, 'to': dayNumber};
      }
      if (sortOrder != null) {
        updates['sort_order'] = sortOrder;
        changes['sort_order'] = {'from': original.sortOrder, 'to': sortOrder};
      }
      if (title != null) {
        updates['title'] = title.trim();
        changes['title'] = {'from': original.title, 'to': title.trim()};
      }
      
      if (clearDescription) {
        updates['description'] = null;
        changes['description'] = {'from': original.description, 'to': null};
      } else if (description != null) {
        final newDesc = description.trim().isNotEmpty ? description.trim() : null;
        updates['description'] = newDesc;
        changes['description'] = {'from': original.description, 'to': newDesc};
      }

      if (clearStartTime) {
        updates['start_time'] = null;
        changes['start_time'] = {'from': original.startTime, 'to': null};
      } else if (startTime != null) {
        updates['start_time'] = startTime;
        changes['start_time'] = {'from': original.startTime, 'to': startTime};
      }

      if (clearEndTime) {
        updates['end_time'] = null;
        changes['end_time'] = {'from': original.endTime, 'to': null};
      } else if (endTime != null) {
        updates['end_time'] = endTime;
        changes['end_time'] = {'from': original.endTime, 'to': endTime};
      }

      if (clearLocation) {
        updates['location'] = null;
        changes['location'] = {'from': original.location, 'to': null};
      } else if (location != null) {
        final newLoc = location.trim().isNotEmpty ? location.trim() : null;
        updates['location'] = newLoc;
        changes['location'] = {'from': original.location, 'to': newLoc};
      }

      if (clearCoordinates) {
        updates['latitude'] = null;
        updates['longitude'] = null;
        changes['coordinates'] = {
          'from': {'lat': original.latitude, 'lng': original.longitude},
          'to': null,
        };
      } else {
        if (latitude != null) {
          updates['latitude'] = latitude;
          changes['latitude'] = {'from': original.latitude, 'to': latitude};
        }
        if (longitude != null) {
          updates['longitude'] = longitude;
          changes['longitude'] = {'from': original.longitude, 'to': longitude};
        }
      }

      if (category != null) {
        updates['category'] = category.name;
        changes['category'] = {'from': original.category.name, 'to': category.name};
      }

      if (clearEstimatedCost) {
        updates['estimated_cost'] = null;
        updates['currency'] = null;
        changes['estimated_cost'] = {'from': original.estimatedCost, 'to': null};
        // Also log currency change if it was previously set
        if (original.currency != null) {
          changes['currency'] = {'from': original.currency, 'to': null};
        }
      } else if (estimatedCost != null) {
        updates['estimated_cost'] = estimatedCost;
        changes['estimated_cost'] = {'from': original.estimatedCost, 'to': estimatedCost};
      }

      if (clearCurrency) {
        updates['currency'] = null;
        changes['currency'] = {'from': original.currency, 'to': null};
      } else if (currency != null) {
        updates['currency'] = currency;
        changes['currency'] = {'from': original.currency, 'to': currency};
      }

      if (clearNotes) {
        updates['notes'] = null;
        changes['notes'] = {'from': original.notes, 'to': null};
      } else if (notes != null) {
        final newNotes = notes.trim().isNotEmpty ? notes.trim() : null;
        updates['notes'] = newNotes;
        changes['notes'] = {'from': original.notes, 'to': newNotes};
      }

      if (updates.isEmpty) {
        return original;
      }

      final response = await _supabase
          .from('itinerary_items')
          .update(updates)
          .eq('id', itemId)
          .select()
          .single();

      debugPrint('ItineraryService: Item updated: $itemId');
      final item = ItineraryItem.fromJson(response);
      
      // Log the activity with detailed changes
      await _activityLogService.logItineraryItemUpdated(
        item.id,
        item.tripId,
        item.title,
        changedFields: updates.keys.toList(),
        changes: changes,
      );
      
      return item;
    } catch (e) {
      debugPrint('ItineraryService: Error updating item: $e');
      rethrow;
    }
  }

  /// Delete an itinerary item
  Future<void> deleteItem(String itemId, {String? tripId, String? title}) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get item details for logging if not provided
      String? logTripId = tripId;
      String? logTitle = title;
      
      if (logTripId == null || logTitle == null) {
        final item = await getItemById(itemId);
        logTripId ??= item?.tripId;
        logTitle ??= item?.title;
      }
      
      await _supabase.from('itinerary_items').delete().eq('id', itemId);
      debugPrint('ItineraryService: Item deleted: $itemId');
      
      // Log the activity
      if (logTripId != null && logTitle != null) {
        await _activityLogService.logItineraryItemDeleted(itemId, logTripId, logTitle);
      }
    } catch (e) {
      debugPrint('ItineraryService: Error deleting item: $e');
      rethrow;
    }
  }

  /// Reorder items within a day
  Future<void> reorderItems(String tripId, int dayNumber, List<String> orderedIds) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      for (int i = 0; i < orderedIds.length; i++) {
        await _supabase
            .from('itinerary_items')
            .update({'sort_order': i})
            .eq('id', orderedIds[i]);
      }
      debugPrint('ItineraryService: Items reordered for day $dayNumber');
      
      // Log the activity
      await _activityLogService.logItineraryReordered(tripId, dayNumber);
    } catch (e) {
      debugPrint('ItineraryService: Error reordering items: $e');
      rethrow;
    }
  }

  /// Move an item to a different day
  Future<ItineraryItem> moveItemToDay({
    required String itemId,
    required int newDayNumber,
    int? sortOrder,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final item = await getItemById(itemId);
      if (item == null) throw Exception('Item not found');

      final newSortOrder = sortOrder ?? await _getNextSortOrder(item.tripId, newDayNumber);

      final response = await _supabase
          .from('itinerary_items')
          .update({
            'day_number': newDayNumber,
            'sort_order': newSortOrder,
          })
          .eq('id', itemId)
          .select()
          .single();

      debugPrint('ItineraryService: Item moved to day $newDayNumber');
      return ItineraryItem.fromJson(response);
    } catch (e) {
      debugPrint('ItineraryService: Error moving item: $e');
      rethrow;
    }
  }

  /// Get itinerary items grouped by day
  Future<Map<int, List<ItineraryItem>>> getItemsGroupedByDay(String tripId) async {
    final items = await getItineraryItems(tripId);
    final grouped = <int, List<ItineraryItem>>{};
    
    for (final item in items) {
      grouped.putIfAbsent(item.dayNumber, () => []);
      grouped[item.dayNumber]!.add(item);
    }
    
    return grouped;
  }

  /// Get total estimated cost for a trip's itinerary
  Future<double> getTotalEstimatedCost(String tripId) async {
    final items = await getItineraryItems(tripId);
    return items.fold<double>(0.0, (double sum, item) => sum + (item.estimatedCost ?? 0));
  }

  /// Get item count for a trip
  Future<int> getItemCount(String tripId) async {
    try {
      final response = await _supabase
          .from('itinerary_items')
          .select('id')
          .eq('trip_id', tripId);

      return (response as List).length;
    } catch (e) {
      debugPrint('ItineraryService: Error getting item count: $e');
      return 0;
    }
  }

  /// Duplicate an itinerary item (useful for similar activities)
  Future<ItineraryItem> duplicateItem(String itemId, {int? newDayNumber}) async {
    final item = await getItemById(itemId);
    if (item == null) throw Exception('Item not found');

    final targetDay = newDayNumber ?? item.dayNumber;

    return createItem(
      tripId: item.tripId,
      dayNumber: targetDay,
      title: '${item.title} (copy)',
      description: item.description,
      startTime: item.startTime,
      endTime: item.endTime,
      location: item.location,
      latitude: item.latitude,
      longitude: item.longitude,
      category: item.category,
      estimatedCost: item.estimatedCost,
      currency: item.currency,
      notes: item.notes,
    );
  }
}
