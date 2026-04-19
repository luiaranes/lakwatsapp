import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/destination.dart';

class DestinationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all destinations with optional filtering
  Future<List<Destination>> getDestinations({
    String? searchQuery,
    DestinationCategory? category,
    String? city,
    String? province,
    String? country,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('destinations').select();

      // Apply search query filter at database level for correct pagination
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'name.ilike.%$searchQuery%,city.ilike.%$searchQuery%,province.ilike.%$searchQuery%,description.ilike.%$searchQuery%',
        );
      }

      if (category != null) {
        query = query.eq('category', category.name);
      }

      if (city != null && city.isNotEmpty) {
        query = query.ilike('city', '%$city%');
      }

      if (province != null && province.isNotEmpty) {
        query = query.ilike('province', '%$province%');
      }

      if (country != null && country.isNotEmpty) {
        query = query.eq('country', country);
      }

      final response = await query
          .order('average_rating', ascending: false, nullsFirst: false)
          .order('review_count', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((item) => Destination.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('DestinationService: Error getting destinations: $e');
      rethrow;
    }
  }

  /// Search destinations by text query
  Future<List<Destination>> searchDestinations(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];

    try {
      final response = await _supabase
          .from('destinations')
          .select()
          .or('name.ilike.%$query%,city.ilike.%$query%,province.ilike.%$query%,description.ilike.%$query%')
          .order('average_rating', ascending: false, nullsFirst: false)
          .limit(limit);

      return (response as List)
          .map((item) => Destination.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('DestinationService: Error searching destinations: $e');
      rethrow;
    }
  }

  /// Get destinations by category
  Future<List<Destination>> getByCategory(
    DestinationCategory category, {
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from('destinations')
          .select()
          .eq('category', category.name)
          .order('average_rating', ascending: false, nullsFirst: false)
          .limit(limit);

      return (response as List)
          .map((item) => Destination.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('DestinationService: Error getting by category: $e');
      rethrow;
    }
  }

  /// Get featured destinations (highest rated)
  Future<List<Destination>> getFeatured({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('destinations')
          .select()
          .not('average_rating', 'is', null)
          .order('average_rating', ascending: false)
          .order('review_count', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => Destination.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('DestinationService: Error getting featured: $e');
      rethrow;
    }
  }

  /// Get popular destinations (most reviews)
  Future<List<Destination>> getPopular({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('destinations')
          .select()
          .gt('review_count', 0)
          .order('review_count', ascending: false)
          .order('average_rating', ascending: false, nullsFirst: false)
          .limit(limit);

      return (response as List)
          .map((item) => Destination.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('DestinationService: Error getting popular: $e');
      rethrow;
    }
  }

  /// Get a single destination by ID
  Future<Destination?> getById(String id) async {
    try {
      final response = await _supabase
          .from('destinations')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Destination.fromJson(response);
    } catch (e) {
      debugPrint('DestinationService: Error getting destination: $e');
      rethrow;
    }
  }

  /// Get all unique cities (for filter dropdown)
  Future<List<String>> getCities() async {
    try {
      final response = await _supabase
          .from('destinations')
          .select('city')
          .not('city', 'is', null)
          .order('city');

      final cities = <String>{};
      for (final item in response as List) {
        final city = item['city'] as String?;
        if (city != null && city.isNotEmpty) {
          cities.add(city);
        }
      }
      return cities.toList();
    } catch (e) {
      debugPrint('DestinationService: Error getting cities: $e');
      rethrow;
    }
  }

  /// Get all unique provinces (for filter dropdown)
  Future<List<String>> getProvinces() async {
    try {
      final response = await _supabase
          .from('destinations')
          .select('province')
          .not('province', 'is', null)
          .order('province');

      final provinces = <String>{};
      for (final item in response as List) {
        final province = item['province'] as String?;
        if (province != null && province.isNotEmpty) {
          provinces.add(province);
        }
      }
      return provinces.toList();
    } catch (e) {
      debugPrint('DestinationService: Error getting provinces: $e');
      rethrow;
    }
  }

  /// Get nearby destinations (requires lat/lng)
  Future<List<Destination>> getNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('destinations')
          .select()
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      final destinations = (response as List)
          .map((item) => Destination.fromJson(item as Map<String, dynamic>))
          .where((d) {
        if (!d.hasCoordinates) return false;
        final distance = _calculateDistance(
          latitude,
          longitude,
          d.latitude!,
          d.longitude!,
        );
        return distance <= radiusKm;
      }).toList();

      destinations.sort((a, b) {
        final distA = _calculateDistance(latitude, longitude, a.latitude!, a.longitude!);
        final distB = _calculateDistance(latitude, longitude, b.latitude!, b.longitude!);
        return distA.compareTo(distB);
      });

      return destinations.take(limit).toList();
    } catch (e) {
      debugPrint('DestinationService: Error getting nearby: $e');
      rethrow;
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}
