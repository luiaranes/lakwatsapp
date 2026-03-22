import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/user_profile.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<UserProfile?> getCurrentUserProfile() async {
    final userId = _currentUserId;
    debugPrint('ProfileService: Getting profile for userId: $userId');
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('auth_id', userId)
          .maybeSingle();

      debugPrint('ProfileService: Response: $response');
      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('ProfileService: Error getting profile: $e');
      rethrow;
    }
  }

  Future<UserProfile?> getProfileById(String profileId) async {
    final response = await _supabase
        .from('user_profiles')
        .select()
        .eq('id', profileId)
        .maybeSingle();

    if (response == null) return null;
    return UserProfile.fromJson(response);
  }

  Future<UserProfile?> getProfileByAuthId(String authId) async {
    final response = await _supabase
        .from('user_profiles')
        .select()
        .eq('auth_id', authId)
        .maybeSingle();

    if (response == null) return null;
    return UserProfile.fromJson(response);
  }

  Future<UserProfile?> createProfileIfNotExists() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    // Check if profile already exists
    final existing = await getCurrentUserProfile();
    if (existing != null) return existing;

    // Create new profile
    final displayName = user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String?;
    final avatarUrl = user.userMetadata?['avatar_url'] as String?;

    try {
      final response = await _supabase
          .from('user_profiles')
          .insert({
            'auth_id': user.id,
            'display_name': displayName,
            'avatar_url': avatarUrl,
          })
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('ProfileService: Error creating profile: $e');
      rethrow;
    }
  }

  Future<UserProfile> updateProfile({
    String? displayName,
    String? bio,
    String? homeCity,
    String? homeCountry,
    String? avatarUrl,
    bool clearBio = false,
    bool clearHomeCity = false,
    bool clearHomeCountry = false,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final updates = <String, dynamic>{};
    
    // For displayName, treat empty string as no update (it's required)
    if (displayName != null && displayName.trim().isNotEmpty) {
      updates['display_name'] = displayName.trim();
    }
    
    // For optional fields, only update if explicitly provided with content
    // or if explicitly clearing (empty string with clear flag)
    if (clearBio) {
      updates['bio'] = null;
    } else if (bio != null && bio.trim().isNotEmpty) {
      updates['bio'] = bio.trim();
    }
    
    if (clearHomeCity) {
      updates['home_city'] = null;
    } else if (homeCity != null && homeCity.trim().isNotEmpty) {
      updates['home_city'] = homeCity.trim();
    }
    
    if (clearHomeCountry) {
      updates['home_country'] = null;
    } else if (homeCountry != null && homeCountry.trim().isNotEmpty) {
      updates['home_country'] = homeCountry.trim();
    }
    
    if (avatarUrl != null) {
      updates['avatar_url'] = avatarUrl.trim().isNotEmpty ? avatarUrl.trim() : null;
    }

    if (updates.isEmpty) {
      final current = await getCurrentUserProfile();
      if (current == null) throw Exception('Profile not found');
      return current;
    }

    final response = await _supabase
        .from('user_profiles')
        .update(updates)
        .eq('auth_id', userId)
        .select()
        .single();

    return UserProfile.fromJson(response);
  }

  Future<int> getTripCount(String profileId) async {
    try {
      // Get the auth_id from the profile to match with trip_members.user_id
      final profile = await _supabase
          .from('user_profiles')
          .select('auth_id')
          .eq('id', profileId)
          .single();
      
      final authId = profile['auth_id'] as String;
      
      final response = await _supabase
          .from('trip_members')
          .select('id')
          .eq('user_id', authId);

      return (response as List).length;
    } catch (e) {
      debugPrint('ProfileService: Error getting trip count: $e');
      return 0;
    }
  }

  Future<int> getPlacesVisitedCount(String profileId) async {
    try {
      // Get the auth_id from the profile to match with trip_members.user_id
      final profile = await _supabase
          .from('user_profiles')
          .select('auth_id')
          .eq('id', profileId)
          .single();
      
      final authId = profile['auth_id'] as String;
      
      final response = await _supabase
          .from('trip_members')
          .select('trip:trips!inner(trip_destinations(id))')
          .eq('user_id', authId);

      int count = 0;
      for (final item in response as List) {
        final trip = item['trip'];
        if (trip != null && trip['trip_destinations'] != null) {
          count += (trip['trip_destinations'] as List).length;
        }
      }
      return count;
    } catch (e) {
      debugPrint('ProfileService: Error getting places count: $e');
      return 0;
    }
  }
}
