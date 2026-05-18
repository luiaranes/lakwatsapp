import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/packing_item.dart';
import 'package:larga/models/activity_log.dart';
import 'package:larga/services/activity_log_service.dart';
import 'package:larga/services/realtime_service.dart';

class SuggestedPackingItem {
  final String name;
  final PackingCategory category;

  SuggestedPackingItem({required this.name, required this.category});
}

enum PackingListView {
  myItems,
  assignedByMe,
}

class PackingListService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLogService = ActivityLogService();
  final RealtimeService _realtimeService = RealtimeService();

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<List<PackingItem>> getPackingItems(
    String tripId, {
    PackingListView view = PackingListView.myItems,
  }) async {
    if (_currentUserId == null) return [];

    try {
      var query = _supabase.from('trip_packing_items').select().eq('trip_id', tripId);

      switch (view) {
        case PackingListView.myItems:
          query = query.eq('assigned_to_user_id', _currentUserId!);
        case PackingListView.assignedByMe:
          query = query
              .eq('created_by_user_id', _currentUserId!)
              .neq('assigned_to_user_id', _currentUserId!);
      }

      final response = await query
          .order('is_checked', ascending: true)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);

      return (response as List)
          .map((item) => PackingItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('PackingListService: Error getting packing items: $e');
      rethrow;
    }
  }

  Future<List<PackingItem>> getMyPackingItems(String tripId) {
    return getPackingItems(tripId, view: PackingListView.myItems);
  }

  Future<PackingItem> createItem({
    required String tripId,
    required String name,
    required String assignedToUserId,
    PackingCategory category = PackingCategory.other,
    PackingItemSource source = PackingItemSource.manual,
    int? sortOrder,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final nextSortOrder = sortOrder ??
          await _nextSortOrder(tripId, assignedToUserId: assignedToUserId);
      final response = await _supabase
          .from('trip_packing_items')
          .insert({
            'trip_id': tripId,
            'created_by_user_id': _currentUserId,
            'assigned_to_user_id': assignedToUserId,
            'assigned_by_user_id': _currentUserId,
            'name': name.trim(),
            'category': category.name,
            'source': source.name,
            'sort_order': nextSortOrder,
          })
          .select()
          .single();

      final item = PackingItem.fromJson(response);
      await _activityLogService.logActivity(
        entityType: ActivityEntityType.packingItem,
        entityId: item.id,
        tripId: tripId,
        action: ActivityAction.created,
        details: {
          'name': item.name,
          'assigned_to_user_id': item.assignedToUserId,
        },
      );
      return item;
    } catch (e) {
      debugPrint('PackingListService: Error creating item: $e');
      rethrow;
    }
  }

  Future<List<PackingItem>> createItemsBulk({
    required String tripId,
    required List<SuggestedPackingItem> items,
    String? assignedToUserId,
    PackingItemSource source = PackingItemSource.ai,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }
    if (items.isEmpty) return [];

    final assigneeId = assignedToUserId ?? _currentUserId!;

    try {
      var sortOrder = await _nextSortOrder(tripId, assignedToUserId: assigneeId);
      final rows = items.map((item) {
        final row = {
          'trip_id': tripId,
          'created_by_user_id': _currentUserId,
          'assigned_to_user_id': assigneeId,
          'assigned_by_user_id': _currentUserId,
          'name': item.name.trim(),
          'category': item.category.name,
          'source': source.name,
          'sort_order': sortOrder,
        };
        sortOrder++;
        return row;
      }).toList();

      final response = await _supabase
          .from('trip_packing_items')
          .insert(rows)
          .select();

      final created = (response as List)
          .map((item) => PackingItem.fromJson(item as Map<String, dynamic>))
          .toList();

      await _activityLogService.logActivity(
        entityType: ActivityEntityType.packingItem,
        entityId: tripId,
        tripId: tripId,
        action: ActivityAction.created,
        details: {
          'count': created.length,
          'source': source.name,
          'assigned_to_user_id': assigneeId,
        },
      );

      return created;
    } catch (e) {
      debugPrint('PackingListService: Error bulk creating items: $e');
      rethrow;
    }
  }

  Future<PackingItem> updateItem(PackingItem item) async {
    try {
      final response = await _supabase
          .from('trip_packing_items')
          .update(item.toUpdateJson())
          .eq('id', item.id)
          .select()
          .single();

      return PackingItem.fromJson(response);
    } catch (e) {
      debugPrint('PackingListService: Error updating item: $e');
      rethrow;
    }
  }

  Future<PackingItem> reassignItem({
    required PackingItem item,
    required String assignedToUserId,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return updateItem(
      item.copyWith(
        assignedToUserId: assignedToUserId,
        assignedByUserId: _currentUserId,
      ),
    );
  }

  Future<PackingItem> toggleChecked(PackingItem item) async {
    if (_currentUserId == null || !item.isAssignedTo(_currentUserId!)) {
      throw Exception('Only the assignee can mark this item packed');
    }
    return updateItem(item.copyWith(isChecked: !item.isChecked));
  }

  Future<void> deleteItem(String itemId, String tripId) async {
    try {
      await _supabase.from('trip_packing_items').delete().eq('id', itemId);
      await _activityLogService.logActivity(
        entityType: ActivityEntityType.packingItem,
        entityId: itemId,
        tripId: tripId,
        action: ActivityAction.deleted,
      );
    } catch (e) {
      debugPrint('PackingListService: Error deleting item: $e');
      rethrow;
    }
  }

  Future<List<SuggestedPackingItem>> generateSuggestions({
    required String tripTitle,
    DateTime? startDate,
    DateTime? endDate,
    List<String> destinations = const [],
    List<String> activityTitles = const [],
    List<String> existingItemNames = const [],
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'generate-packing-suggestions',
        body: {
          'trip_title': tripTitle,
          'start_date': startDate?.toIso8601String().split('T').first,
          'end_date': endDate?.toIso8601String().split('T').first,
          'destinations': destinations,
          'activity_titles': activityTitles,
          'existing_items': existingItemNames,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to generate packing suggestions');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) {
        throw Exception(data['error'].toString());
      }

      final items = data['items'] as List<dynamic>? ?? [];
      return items.map((raw) {
        final item = raw as Map<String, dynamic>;
        return SuggestedPackingItem(
          name: item['name'] as String? ?? 'Item',
          category: PackingCategory.fromString(
            item['category'] as String? ?? 'other',
          ),
        );
      }).toList();
    } catch (e) {
      debugPrint('PackingListService: Error generating suggestions: $e');
      rethrow;
    }
  }

  Future<int> _nextSortOrder(
    String tripId, {
    required String assignedToUserId,
  }) async {
    final response = await _supabase
        .from('trip_packing_items')
        .select('sort_order')
        .eq('trip_id', tripId)
        .eq('assigned_to_user_id', assignedToUserId)
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return 0;
    return (response['sort_order'] as int? ?? 0) + 1;
  }

  StreamSubscription<void>? subscribeToPackingItemsChanges({
    required String tripId,
    required void Function() onUpdate,
  }) {
    final stream = _realtimeService.subscribeToPackingItems(tripId);
    if (stream == const Stream.empty()) return null;

    return stream.listen((payload) {
      debugPrint('PackingListService: Realtime change: ${payload.event}');
      onUpdate();
    });
  }

  void unsubscribeFromPackingItems(String tripId) {
    _realtimeService.unsubscribeFromPackingItems(tripId);
  }
}
