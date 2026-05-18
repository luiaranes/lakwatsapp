import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/destination.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/trip_preferences.dart';
import 'package:larga/models/itinerary_item.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/services/itinerary_service.dart';
import 'package:larga/services/trip_destination_service.dart';
import 'package:larga/services/packing_list_service.dart';
import 'package:larga/models/packing_item.dart';

class GeneratedItinerary {
  final String tripTitle;
  final String tripDescription;
  final double estimatedTotalBudget;
  final String currency;
  final List<GeneratedDay> days;
  final List<String> packingSuggestions;
  final List<String> travelTips;

  GeneratedItinerary({
    required this.tripTitle,
    required this.tripDescription,
    required this.estimatedTotalBudget,
    required this.currency,
    required this.days,
    this.packingSuggestions = const [],
    this.travelTips = const [],
  });

  factory GeneratedItinerary.fromJson(Map<String, dynamic> json) {
    return GeneratedItinerary(
      tripTitle: json['trip_title'] as String? ?? 'My Trip',
      tripDescription: json['trip_description'] as String? ?? '',
      estimatedTotalBudget: (json['estimated_total_budget'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'PHP',
      days: (json['days'] as List<dynamic>?)
              ?.map((d) => GeneratedDay.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      packingSuggestions: (json['packing_suggestions'] as List<dynamic>?)
              ?.map((s) => s as String)
              .toList() ??
          [],
      travelTips: (json['travel_tips'] as List<dynamic>?)
              ?.map((s) => s as String)
              .toList() ??
          [],
    );
  }
}

class GeneratedDay {
  final int dayNumber;
  final String date;
  final String? theme;
  final List<GeneratedActivity> activities;

  GeneratedDay({
    required this.dayNumber,
    required this.date,
    this.theme,
    required this.activities,
  });

  factory GeneratedDay.fromJson(Map<String, dynamic> json) {
    return GeneratedDay(
      dayNumber: json['day_number'] as int? ?? 1,
      date: json['date'] as String? ?? '',
      theme: json['theme'] as String?,
      activities: (json['activities'] as List<dynamic>?)
              ?.map((a) => GeneratedActivity.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class GeneratedActivity {
  final String title;
  final String? description;
  final String startTime;
  final String? endTime;
  final String? location;
  final String category;
  final double? estimatedCost;
  final String? notes;

  GeneratedActivity({
    required this.title,
    this.description,
    required this.startTime,
    this.endTime,
    this.location,
    required this.category,
    this.estimatedCost,
    this.notes,
  });

  factory GeneratedActivity.fromJson(Map<String, dynamic> json) {
    return GeneratedActivity(
      title: json['title'] as String? ?? 'Activity',
      description: json['description'] as String?,
      startTime: json['start_time'] as String? ?? '09:00',
      endTime: json['end_time'] as String?,
      location: json['location'] as String?,
      category: json['category'] as String? ?? 'activity',
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  ItineraryCategory toItineraryCategory() {
    return switch (category.toLowerCase()) {
      'transport' => ItineraryCategory.transport,
      'accommodation' => ItineraryCategory.accommodation,
      'food' => ItineraryCategory.food,
      'activity' => ItineraryCategory.activity,
      'sightseeing' => ItineraryCategory.sightseeing,
      'shopping' => ItineraryCategory.shopping,
      'rest' => ItineraryCategory.rest,
      _ => ItineraryCategory.other,
    };
  }
}

class TripPlanningService {
  final _supabase = Supabase.instance.client;
  final _tripService = TripService();
  final _itineraryService = ItineraryService();
  final _tripDestinationService = TripDestinationService();
  final _packingListService = PackingListService();

  Future<GeneratedItinerary> generateItinerary({
    required Destination destination,
    required TripPreferences preferences,
  }) async {
    try {
      debugPrint('TripPlanningService: Generating itinerary for ${destination.name}');

      final response = await _supabase.functions.invoke(
        'generate-itinerary',
        body: {
          'destination': {
            'name': destination.name,
            'description': destination.description,
            'city': destination.city,
            'province': destination.province,
            'country': destination.country,
            'category': destination.category.name,
            'tips': destination.tips,
          },
          'preferences': preferences.toJson(),
        },
      );

      if (response.status != 200) {
        debugPrint('TripPlanningService: Error response: ${response.data}');
        throw Exception('Failed to generate itinerary');
      }

      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null) {
        throw Exception(data['error'].toString());
      }

      debugPrint('TripPlanningService: Generated itinerary successfully');
      return GeneratedItinerary.fromJson(data);
    } catch (e) {
      debugPrint('TripPlanningService: Error generating itinerary: $e');
      rethrow;
    }
  }

  Future<Trip> createTripFromItinerary({
    required Destination destination,
    required TripPreferences preferences,
    required GeneratedItinerary generatedItinerary,
  }) async {
    try {
      debugPrint('TripPlanningService: Creating trip from generated itinerary');

      // Create the trip
      final trip = await _tripService.createTrip(
        title: generatedItinerary.tripTitle,
        description: generatedItinerary.tripDescription,
        startDate: preferences.startDate,
        endDate: preferences.endDate,
        budget: generatedItinerary.estimatedTotalBudget,
        currency: preferences.currency,
      );

      debugPrint('TripPlanningService: Trip created: ${trip.id}');

      // Add the destination to the trip
      await _tripDestinationService.addDestinationToTrip(
        tripId: trip.id,
        destinationId: destination.id,
        destinationName: destination.name,
      );

      debugPrint('TripPlanningService: Destination added to trip');

      // Create itinerary items for each day
      for (final day in generatedItinerary.days) {
        int sortOrder = 0;
        for (final activity in day.activities) {
          await _itineraryService.createItem(
            tripId: trip.id,
            title: activity.title,
            description: activity.description,
            dayNumber: day.dayNumber,
            startTime: activity.startTime,
            endTime: activity.endTime,
            location: activity.location,
            category: activity.toItineraryCategory(),
            estimatedCost: activity.estimatedCost,
            currency: preferences.currency,
            notes: activity.notes,
            sortOrder: sortOrder,
          );
          sortOrder++;
        }
      }

      debugPrint('TripPlanningService: All itinerary items created');

      if (generatedItinerary.packingSuggestions.isNotEmpty) {
        await _packingListService.createItemsBulk(
          tripId: trip.id,
          items: generatedItinerary.packingSuggestions
              .map(
                (name) => SuggestedPackingItem(
                  name: name,
                  category: PackingCategory.other,
                ),
              )
              .toList(),
          source: PackingItemSource.ai,
        );
        debugPrint('TripPlanningService: Packing suggestions saved');
      }

      return trip;
    } catch (e) {
      debugPrint('TripPlanningService: Error creating trip: $e');
      rethrow;
    }
  }

  Future<Trip> planTripFromDestination({
    required Destination destination,
    required TripPreferences preferences,
    void Function(String status)? onStatusUpdate,
  }) async {
    try {
      onStatusUpdate?.call('Generating your personalized itinerary...');
      
      final generatedItinerary = await generateItinerary(
        destination: destination,
        preferences: preferences,
      );

      onStatusUpdate?.call('Creating your trip...');

      final trip = await createTripFromItinerary(
        destination: destination,
        preferences: preferences,
        generatedItinerary: generatedItinerary,
      );

      onStatusUpdate?.call('Trip created successfully!');

      return trip;
    } catch (e) {
      debugPrint('TripPlanningService: Error planning trip: $e');
      rethrow;
    }
  }
}
