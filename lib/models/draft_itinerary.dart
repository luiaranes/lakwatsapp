import 'package:larga/models/destination.dart';
import 'package:larga/models/trip_preferences.dart';
import 'package:larga/services/trip_planning_service.dart';

enum ActivityReviewStatus { pending, accepted, skipped, edited }

class DraftItinerary {
  final String id;
  final String visitorId;
  final String destinationId;
  final TripPreferences preferences;
  final GeneratedItinerary generatedItinerary;
  final Map<String, Map<int, ActivityReviewStatus>> reviewState;
  final Map<String, GeneratedActivity> editedActivities;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  
  // Joined data
  final Destination? destination;

  DraftItinerary({
    required this.id,
    required this.visitorId,
    required this.destinationId,
    required this.preferences,
    required this.generatedItinerary,
    required this.reviewState,
    required this.editedActivities,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    this.destination,
  });

  factory DraftItinerary.fromJson(Map<String, dynamic> json) {
    // Parse review state
    final reviewStateJson = json['review_state'] as Map<String, dynamic>? ?? {};
    final reviewState = <String, Map<int, ActivityReviewStatus>>{};
    reviewStateJson.forEach((dayKey, dayValue) {
      if (dayValue is Map) {
        reviewState[dayKey] = {};
        dayValue.forEach((activityIndex, status) {
          final index = int.tryParse(activityIndex.toString()) ?? 0;
          reviewState[dayKey]![index] = _parseStatus(status as String);
        });
      }
    });

    // Parse edited activities
    final editedJson = json['edited_activities'] as Map<String, dynamic>? ?? {};
    final editedActivities = <String, GeneratedActivity>{};
    editedJson.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        editedActivities[key] = GeneratedActivity.fromJson(value);
      }
    });

    // Parse destination if joined
    Destination? destination;
    if (json['destinations'] != null) {
      destination = Destination.fromJson(json['destinations'] as Map<String, dynamic>);
    }

    return DraftItinerary(
      id: json['id'] as String,
      visitorId: json['user_id'] as String,
      destinationId: json['destination_id'] as String,
      preferences: TripPreferences.fromJson(json['preferences'] as Map<String, dynamic>),
      generatedItinerary: GeneratedItinerary.fromJson(json['generated_itinerary'] as Map<String, dynamic>),
      reviewState: reviewState,
      editedActivities: editedActivities,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      destination: destination,
    );
  }

  Map<String, dynamic> toJson() {
    // Convert review state to JSON
    final reviewStateJson = <String, dynamic>{};
    reviewState.forEach((dayKey, dayValue) {
      reviewStateJson[dayKey] = {};
      dayValue.forEach((index, status) {
        (reviewStateJson[dayKey] as Map<String, dynamic>)[index.toString()] = status.name;
      });
    });

    // Convert edited activities to JSON
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

    return {
      'id': id,
      'user_id': visitorId,
      'destination_id': destinationId,
      'preferences': preferences.toJson(),
      'generated_itinerary': _generatedItineraryToJson(generatedItinerary),
      'review_state': reviewStateJson,
      'edited_activities': editedJson,
    };
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

  static ActivityReviewStatus _parseStatus(String status) {
    return switch (status) {
      'accepted' => ActivityReviewStatus.accepted,
      'skipped' => ActivityReviewStatus.skipped,
      'edited' => ActivityReviewStatus.edited,
      _ => ActivityReviewStatus.pending,
    };
  }

  DraftItinerary copyWith({
    String? id,
    String? visitorId,
    String? destinationId,
    TripPreferences? preferences,
    GeneratedItinerary? generatedItinerary,
    Map<String, Map<int, ActivityReviewStatus>>? reviewState,
    Map<String, GeneratedActivity>? editedActivities,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    Destination? destination,
  }) {
    return DraftItinerary(
      id: id ?? this.id,
      visitorId: visitorId ?? this.visitorId,
      destinationId: destinationId ?? this.destinationId,
      preferences: preferences ?? this.preferences,
      generatedItinerary: generatedItinerary ?? this.generatedItinerary,
      reviewState: reviewState ?? this.reviewState,
      editedActivities: editedActivities ?? this.editedActivities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      destination: destination ?? this.destination,
    );
  }

  int get totalActivities {
    return generatedItinerary.days.fold(0, (sum, day) => sum + day.activities.length);
  }

  int get reviewedActivities {
    int count = 0;
    for (final dayState in reviewState.values) {
      count += dayState.values.where((s) => s != ActivityReviewStatus.pending).length;
    }
    return count;
  }

  int get acceptedActivities {
    int count = 0;
    for (final dayState in reviewState.values) {
      count += dayState.values.where((s) => s == ActivityReviewStatus.accepted || s == ActivityReviewStatus.edited).length;
    }
    return count;
  }

  double get reviewProgress {
    if (totalActivities == 0) return 0;
    return reviewedActivities / totalActivities;
  }

  bool get isFullyReviewed => reviewedActivities == totalActivities;
}
