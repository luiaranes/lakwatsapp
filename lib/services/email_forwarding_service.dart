import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/trip_email_alias.dart';

class EmailForwardingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<TripEmailAlias> getOrCreateTripEmailAlias(String tripId) async {
    try {
      final response = await _supabase.rpc(
        'get_or_create_trip_email_alias',
        params: {'p_trip_id': tripId},
      );
      return _parseAliasResponse(response);
    } catch (e) {
      debugPrint('EmailForwardingService: Error getting alias: $e');
      rethrow;
    }
  }

  Future<TripEmailAlias> regenerateTripEmailAlias(String tripId) async {
    try {
      final response = await _supabase.rpc(
        'regenerate_trip_email_alias',
        params: {'p_trip_id': tripId},
      );
      return _parseAliasResponse(response);
    } catch (e) {
      debugPrint('EmailForwardingService: Error regenerating alias: $e');
      rethrow;
    }
  }

  TripEmailAlias _parseAliasResponse(dynamic response) {
    if (response == null) {
      throw Exception('Empty email alias response');
    }

    if (response is Map<String, dynamic>) {
      return TripEmailAlias.fromJson(response);
    }

    if (response is List &&
        response.isNotEmpty &&
        response.first is Map<String, dynamic>) {
      return TripEmailAlias.fromJson(response.first as Map<String, dynamic>);
    }

    throw Exception('Unexpected email alias response format');
  }
}
