import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/draft_itinerary.dart';
import 'package:larga/models/destination.dart';
import 'package:larga/models/trip_preferences.dart';
import 'package:larga/services/trip_planning_service.dart';

class DraftItineraryService {
  final _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  Future<DraftItinerary> createDraft({
    required Destination destination,
    required TripPreferences preferences,
    required GeneratedItinerary generatedItinerary,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      debugPrint('DraftItineraryService: Creating draft for ${destination.name}');

      final data = {
        'user_id': _userId,
        'destination_id': destination.id,
        'preferences': preferences.toJson(),
        'generated_itinerary': _generatedItineraryToJson(generatedItinerary),
        'review_state': <String, dynamic>{},
        'edited_activities': <String, dynamic>{},
      };

      final response = await _supabase
          .from('draft_itineraries')
          .insert(data)
          .select('*, destinations(*)')
          .single();

      debugPrint('DraftItineraryService: Draft created: ${response['id']}');
      return DraftItinerary.fromJson(response);
    } catch (e) {
      debugPrint('DraftItineraryService: Error creating draft: $e');
      rethrow;
    }
  }

  Future<List<DraftItinerary>> getDrafts() async {
    if (_userId == null) return [];

    try {
      debugPrint('DraftItineraryService: Fetching drafts for user');

      final response = await _supabase
          .from('draft_itineraries')
          .select('*, destinations(*)')
          .eq('user_id', _userId!)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('updated_at', ascending: false);

      final drafts = (response as List)
          .map((json) => DraftItinerary.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('DraftItineraryService: Found ${drafts.length} drafts');
      return drafts;
    } catch (e) {
      debugPrint('DraftItineraryService: Error fetching drafts: $e');
      return [];
    }
  }

  Future<DraftItinerary?> getDraft(String draftId) async {
    if (_userId == null) return null;

    try {
      debugPrint('DraftItineraryService: Fetching draft $draftId');

      final response = await _supabase
          .from('draft_itineraries')
          .select('*, destinations(*)')
          .eq('id', draftId)
          .eq('user_id', _userId!)
          .maybeSingle();

      if (response == null) return null;

      return DraftItinerary.fromJson(response);
    } catch (e) {
      debugPrint('DraftItineraryService: Error fetching draft: $e');
      return null;
    }
  }

  Future<void> updateReviewState({
    required String draftId,
    required Map<String, Map<int, ActivityReviewStatus>> reviewState,
    required Map<String, GeneratedActivity> editedActivities,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      debugPrint('DraftItineraryService: Updating review state for $draftId');

      // Convert review state to JSON format
      final reviewStateJson = <String, dynamic>{};
      reviewState.forEach((dayKey, dayValue) {
        reviewStateJson[dayKey] = <String, dynamic>{};
        dayValue.forEach((index, status) {
          (reviewStateJson[dayKey] as Map<String, dynamic>)[index.toString()] = status.name;
        });
      });

      // Convert edited activities to JSON format
      final editedJson = <String, dynamic>{};
      editedActivities.forEach((key, activity) {
        editedJson[key] = {
          'title': activity.title,
          'description': activity.description,
          'start_time': activity.startTime,
          'end_time': activity.endTime,
          'location': activity.location,
          'category': activity.category,
          'estimated_cost': activity.estimatedCost,
          'notes': activity.notes,
        };
      });

      await _supabase
          .from('draft_itineraries')
          .update({
            'review_state': reviewStateJson,
            'edited_activities': editedJson,
          })
          .eq('id', draftId)
          .eq('user_id', _userId!);

      debugPrint('DraftItineraryService: Review state updated');
    } catch (e) {
      debugPrint('DraftItineraryService: Error updating review state: $e');
      rethrow;
    }
  }

  Future<void> deleteDraft(String draftId) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      debugPrint('DraftItineraryService: Deleting draft $draftId');

      await _supabase
          .from('draft_itineraries')
          .delete()
          .eq('id', draftId)
          .eq('user_id', _userId!);

      debugPrint('DraftItineraryService: Draft deleted');
    } catch (e) {
      debugPrint('DraftItineraryService: Error deleting draft: $e');
      rethrow;
    }
  }

  Future<int> getDraftCount() async {
    if (_userId == null) return 0;

    try {
      final response = await _supabase
          .from('draft_itineraries')
          .select('id')
          .eq('user_id', _userId!)
          .gt('expires_at', DateTime.now().toIso8601String());

      return (response as List).length;
    } catch (e) {
      debugPrint('DraftItineraryService: Error getting draft count: $e');
      return 0;
    }
  }

  Map<String, dynamic> _generatedItineraryToJson(GeneratedItinerary itinerary) {
    return {
      'trip_title': itinerary.tripTitle,
      'trip_description': itinerary.tripDescription,
      'estimated_total_budget': itinerary.estimatedTotalBudget,
      'currency': itinerary.currency,
      'days': itinerary.days.map((day) => {
        'day_number': day.dayNumber,
        'date': day.date,
        'theme': day.theme,
        'activities': day.activities.map((a) => {
          'title': a.title,
          'description': a.description,
          'start_time': a.startTime,
          'end_time': a.endTime,
          'location': a.location,
          'category': a.category,
          'estimated_cost': a.estimatedCost,
          'notes': a.notes,
        }).toList(),
      }).toList(),
      'packing_suggestions': itinerary.packingSuggestions,
      'travel_tips': itinerary.travelTips,
    };
  }
}
