import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/friendship.dart';
import 'package:larga/models/user_profile.dart';

class FriendWithProfile {
  final Friendship? friendship;
  final UserProfile profile;

  FriendWithProfile({this.friendship, required this.profile});
}

class FriendRequest {
  final Friendship friendship;
  final UserProfile requesterProfile;

  FriendRequest({required this.friendship, required this.requesterProfile});
}

class FriendshipService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Send a friend request to another user
  Future<Friendship> sendFriendRequest(String addresseeId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (userId == addresseeId) {
      throw Exception('Cannot send friend request to yourself');
    }

    try {
      // Check if there's already a friendship between these users
      final existing = await _supabase
          .from('friendships')
          .select()
          .or('and(requester_id.eq.$userId,addressee_id.eq.$addresseeId),and(requester_id.eq.$addresseeId,addressee_id.eq.$userId)')
          .maybeSingle();

      if (existing != null) {
        final existingFriendship = Friendship.fromJson(existing);
        if (existingFriendship.isAccepted) {
          throw Exception('You are already friends');
        } else if (existingFriendship.isPending) {
          if (existingFriendship.requesterId == userId) {
            throw Exception('Friend request already sent');
          } else {
            throw Exception('This user has already sent you a friend request');
          }
        } else if (existingFriendship.isBlocked) {
          throw Exception('Cannot send friend request');
        }
      }

      final response = await _supabase
          .from('friendships')
          .insert({
            'requester_id': userId,
            'addressee_id': addresseeId,
            'status': 'pending',
          })
          .select()
          .single();

      debugPrint('FriendshipService: Friend request sent to $addresseeId');
      return Friendship.fromJson(response);
    } catch (e) {
      debugPrint('FriendshipService: Error sending friend request: $e');
      rethrow;
    }
  }

  /// Accept a pending friend request
  Future<Friendship> acceptFriendRequest(String friendshipId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _supabase
          .from('friendships')
          .update({
            'status': 'accepted',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', friendshipId)
          .eq('addressee_id', userId)
          .eq('status', 'pending')
          .select()
          .single();

      debugPrint('FriendshipService: Friend request accepted: $friendshipId');
      return Friendship.fromJson(response);
    } catch (e) {
      debugPrint('FriendshipService: Error accepting friend request: $e');
      rethrow;
    }
  }

  /// Reject a pending friend request
  Future<Friendship> rejectFriendRequest(String friendshipId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _supabase
          .from('friendships')
          .update({
            'status': 'rejected',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', friendshipId)
          .eq('addressee_id', userId)
          .eq('status', 'pending')
          .select()
          .single();

      debugPrint('FriendshipService: Friend request rejected: $friendshipId');
      return Friendship.fromJson(response);
    } catch (e) {
      debugPrint('FriendshipService: Error rejecting friend request: $e');
      rethrow;
    }
  }

  /// Cancel a sent friend request (requester only)
  Future<void> cancelFriendRequest(String friendshipId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase
          .from('friendships')
          .delete()
          .eq('id', friendshipId)
          .eq('requester_id', userId)
          .eq('status', 'pending');

      debugPrint('FriendshipService: Friend request cancelled: $friendshipId');
    } catch (e) {
      debugPrint('FriendshipService: Error cancelling friend request: $e');
      rethrow;
    }
  }

  /// Remove a friend (unfriend)
  Future<void> removeFriend(String friendUserId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase
          .from('friendships')
          .delete()
          .or('and(requester_id.eq.$userId,addressee_id.eq.$friendUserId),and(requester_id.eq.$friendUserId,addressee_id.eq.$userId)')
          .eq('status', 'accepted');

      debugPrint('FriendshipService: Friend removed: $friendUserId');
    } catch (e) {
      debugPrint('FriendshipService: Error removing friend: $e');
      rethrow;
    }
  }

  /// Get all accepted friends with their profiles
  Future<List<FriendWithProfile>> getFriends() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabase.rpc(
        'get_friends',
        params: {'user_id': userId},
      );

      if (response == null) return [];

      return (response as List)
          .map((item) => FriendWithProfile(
                profile: UserProfile.fromJson(item as Map<String, dynamic>),
              ))
          .toList();
    } catch (e) {
      debugPrint('FriendshipService: Error getting friends: $e');
      return [];
    }
  }

  /// Get pending incoming friend requests
  Future<List<FriendRequest>> getPendingRequests() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('friendships')
          .select('*, requester:user_profiles!friendships_requester_id_fkey(*)')
          .eq('addressee_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        final friendship = Friendship.fromJson(item);
        final requesterData = item['requester'] as Map<String, dynamic>;
        final requesterProfile = UserProfile.fromJson(requesterData);
        return FriendRequest(
          friendship: friendship,
          requesterProfile: requesterProfile,
        );
      }).toList();
    } catch (e) {
      debugPrint('FriendshipService: Error getting pending requests: $e');
      
      // Fallback: try without the join
      try {
        final friendships = await _supabase
            .from('friendships')
            .select()
            .eq('addressee_id', userId)
            .eq('status', 'pending')
            .order('created_at', ascending: false);

        final requests = <FriendRequest>[];
        for (final item in friendships as List) {
          final friendship = Friendship.fromJson(item as Map<String, dynamic>);
          final profile = await _getProfileByAuthId(friendship.requesterId);
          if (profile != null) {
            requests.add(FriendRequest(
              friendship: friendship,
              requesterProfile: profile,
            ));
          }
        }
        return requests;
      } catch (e2) {
        debugPrint('FriendshipService: Fallback also failed: $e2');
        return [];
      }
    }
  }

  /// Get sent friend requests (outgoing, still pending)
  Future<List<FriendRequest>> getSentRequests() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('friendships')
          .select()
          .eq('requester_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final requests = <FriendRequest>[];
      for (final item in response as List) {
        final friendship = Friendship.fromJson(item as Map<String, dynamic>);
        final profile = await _getProfileByAuthId(friendship.addresseeId);
        if (profile != null) {
          requests.add(FriendRequest(
            friendship: friendship,
            requesterProfile: profile,
          ));
        }
      }
      return requests;
    } catch (e) {
      debugPrint('FriendshipService: Error getting sent requests: $e');
      return [];
    }
  }

  /// Get count of pending incoming requests
  Future<int> getPendingRequestCount() async {
    final userId = _currentUserId;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('friendships')
          .select('id')
          .eq('addressee_id', userId)
          .eq('status', 'pending');

      return (response as List).length;
    } catch (e) {
      debugPrint('FriendshipService: Error getting pending count: $e');
      return 0;
    }
  }

  /// Get total friend count
  Future<int> getFriendCount() async {
    final userId = _currentUserId;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('friendships')
          .select('id')
          .eq('status', 'accepted')
          .or('requester_id.eq.$userId,addressee_id.eq.$userId');

      return (response as List).length;
    } catch (e) {
      debugPrint('FriendshipService: Error getting friend count: $e');
      return 0;
    }
  }

  /// Check if two users are friends
  Future<bool> areFriends(String otherUserId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      final response = await _supabase
          .from('friendships')
          .select('id')
          .eq('status', 'accepted')
          .or('and(requester_id.eq.$userId,addressee_id.eq.$otherUserId),and(requester_id.eq.$otherUserId,addressee_id.eq.$userId)')
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('FriendshipService: Error checking friendship: $e');
      return false;
    }
  }

  /// Get the friendship status with another user
  Future<FriendshipStatus?> getFriendshipStatus(String otherUserId) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('friendships')
          .select()
          .or('and(requester_id.eq.$userId,addressee_id.eq.$otherUserId),and(requester_id.eq.$otherUserId,addressee_id.eq.$userId)')
          .maybeSingle();

      if (response == null) return null;
      return Friendship.fromJson(response).status;
    } catch (e) {
      debugPrint('FriendshipService: Error getting friendship status: $e');
      return null;
    }
  }

  /// Get the friendship record with another user (if exists)
  Future<Friendship?> getFriendship(String otherUserId) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('friendships')
          .select()
          .or('and(requester_id.eq.$userId,addressee_id.eq.$otherUserId),and(requester_id.eq.$otherUserId,addressee_id.eq.$userId)')
          .maybeSingle();

      if (response == null) return null;
      return Friendship.fromJson(response);
    } catch (e) {
      debugPrint('FriendshipService: Error getting friendship: $e');
      return null;
    }
  }

  /// Helper to get a user profile by auth ID
  Future<UserProfile?> _getProfileByAuthId(String authId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('auth_id', authId)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
