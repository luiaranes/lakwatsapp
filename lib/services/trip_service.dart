import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/trip_member.dart';

class TripService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Fetch all trips for the current user (as owner or member)
  Future<List<Trip>> getMyTrips() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      // Get trips where user is a member
      final response = await _supabase
          .from('trip_members')
          .select('trip:trips(*)')
          .eq('user_id', userId)
          .order('joined_at', ascending: false);

      final trips = <Trip>[];
      for (final item in response as List) {
        final tripData = item['trip'];
        if (tripData != null) {
          trips.add(Trip.fromJson(tripData as Map<String, dynamic>));
        }
      }

      // Sort by start_date (upcoming first), then by created_at
      trips.sort((a, b) {
        if (a.startDate != null && b.startDate != null) {
          return a.startDate!.compareTo(b.startDate!);
        }
        if (a.startDate != null) return -1;
        if (b.startDate != null) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      return trips;
    } catch (e) {
      debugPrint('TripService: Error getting trips: $e');
      rethrow;
    }
  }

  /// Get upcoming trips (planning or ongoing, start date >= today or no start date)
  Future<List<Trip>> getUpcomingTrips() async {
    final allTrips = await getMyTrips();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return allTrips.where((trip) {
      if (trip.status == TripStatus.completed) return false;
      if (trip.endDate != null && trip.endDate!.isBefore(today)) return false;
      return true;
    }).toList();
  }

  /// Get past trips (completed or end date < today)
  Future<List<Trip>> getPastTrips() async {
    final allTrips = await getMyTrips();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return allTrips.where((trip) {
      if (trip.status == TripStatus.completed) return true;
      if (trip.endDate != null && trip.endDate!.isBefore(today)) return true;
      return false;
    }).toList();
  }

  /// Get a single trip by ID
  Future<Trip?> getTripById(String tripId) async {
    try {
      final response = await _supabase
          .from('trips')
          .select()
          .eq('id', tripId)
          .maybeSingle();

      if (response == null) return null;
      return Trip.fromJson(response);
    } catch (e) {
      debugPrint('TripService: Error getting trip: $e');
      rethrow;
    }
  }

  /// Create a new trip and add current user as owner
  Future<Trip> createTrip({
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    String currency = 'PHP',
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Create the trip
      final tripResponse = await _supabase
          .from('trips')
          .insert({
            'owner_id': userId,
            'title': title,
            'description': description,
            'start_date': startDate?.toIso8601String().split('T').first,
            'end_date': endDate?.toIso8601String().split('T').first,
            'budget': budget,
            'currency': currency,
            'status': TripStatus.planning.name,
            'is_public': false,
          })
          .select()
          .single();

      final trip = Trip.fromJson(tripResponse);

      // Add current user as owner in trip_members
      await _supabase.from('trip_members').insert({
        'trip_id': trip.id,
        'user_id': userId,
        'role': MemberRole.owner.name,
      });

      debugPrint('TripService: Trip created: ${trip.id}');
      return trip;
    } catch (e) {
      debugPrint('TripService: Error creating trip: $e');
      rethrow;
    }
  }

  /// Update an existing trip
  Future<Trip> updateTrip({
    required String tripId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    TripStatus? status,
    String? coverImageUrl,
    double? budget,
    String? currency,
    bool? isPublic,
    bool clearDescription = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearBudget = false,
    bool clearCoverImage = false,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final updates = <String, dynamic>{};

      if (title != null && title.trim().isNotEmpty) {
        updates['title'] = title.trim();
      }

      if (clearDescription) {
        updates['description'] = null;
      } else if (description != null) {
        updates['description'] = description.trim().isNotEmpty ? description.trim() : null;
      }

      if (clearStartDate) {
        updates['start_date'] = null;
      } else if (startDate != null) {
        updates['start_date'] = startDate.toIso8601String().split('T').first;
      }

      if (clearEndDate) {
        updates['end_date'] = null;
      } else if (endDate != null) {
        updates['end_date'] = endDate.toIso8601String().split('T').first;
      }

      if (status != null) {
        updates['status'] = status.name;
      }

      if (clearCoverImage) {
        updates['cover_image_url'] = null;
      } else if (coverImageUrl != null) {
        updates['cover_image_url'] = coverImageUrl;
      }

      if (clearBudget) {
        updates['budget'] = null;
      } else if (budget != null) {
        updates['budget'] = budget;
      }

      if (currency != null) {
        updates['currency'] = currency;
      }

      if (isPublic != null) {
        updates['is_public'] = isPublic;
      }

      if (updates.isEmpty) {
        final current = await getTripById(tripId);
        if (current == null) throw Exception('Trip not found');
        return current;
      }

      final response = await _supabase
          .from('trips')
          .update(updates)
          .eq('id', tripId)
          .select()
          .single();

      debugPrint('TripService: Trip updated: $tripId');
      return Trip.fromJson(response);
    } catch (e) {
      debugPrint('TripService: Error updating trip: $e');
      rethrow;
    }
  }

  /// Update trip status
  Future<Trip> updateTripStatus(String tripId, TripStatus status) async {
    return updateTrip(tripId: tripId, status: status);
  }

  /// Delete a trip (only owner can delete)
  Future<void> deleteTrip(String tripId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Verify user is the owner
      final trip = await getTripById(tripId);
      if (trip == null) {
        throw Exception('Trip not found');
      }
      if (trip.ownerId != userId) {
        throw Exception('Only the trip owner can delete the trip');
      }

      // Delete the trip (cascade will handle trip_members)
      await _supabase.from('trips').delete().eq('id', tripId);

      debugPrint('TripService: Trip deleted: $tripId');
    } catch (e) {
      debugPrint('TripService: Error deleting trip: $e');
      rethrow;
    }
  }

  /// Get trip members
  Future<List<TripMember>> getTripMembers(String tripId) async {
    try {
      final response = await _supabase
          .from('trip_members')
          .select()
          .eq('trip_id', tripId)
          .order('joined_at', ascending: true);

      return (response as List)
          .map((item) => TripMember.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('TripService: Error getting trip members: $e');
      rethrow;
    }
  }

  /// Get member count for a trip
  Future<int> getTripMemberCount(String tripId) async {
    try {
      final response = await _supabase
          .from('trip_members')
          .select('id')
          .eq('trip_id', tripId);

      return (response as List).length;
    } catch (e) {
      debugPrint('TripService: Error getting member count: $e');
      return 0;
    }
  }

  /// Get current user's role in a trip
  Future<MemberRole?> getMyRole(String tripId) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('trip_members')
          .select('role')
          .eq('trip_id', tripId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return MemberRole.fromString(response['role'] as String);
    } catch (e) {
      debugPrint('TripService: Error getting role: $e');
      return null;
    }
  }

  /// Check if current user can edit the trip (all members can edit)
  Future<bool> canEdit(String tripId) async {
    final role = await getMyRole(tripId);
    return role != null;
  }

  /// Check if current user is the trip owner
  Future<bool> isOwner(String tripId) async {
    final role = await getMyRole(tripId);
    return role == MemberRole.owner;
  }

  /// Calculate days until trip starts
  int? getDaysUntil(Trip trip) {
    if (trip.startDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(trip.startDate!.year, trip.startDate!.month, trip.startDate!.day);
    final difference = start.difference(today).inDays;
    return difference >= 0 ? difference : null;
  }

  /// Add a member to a trip
  Future<TripMember> addMember({
    required String tripId,
    required String userId,
    MemberRole role = MemberRole.viewer,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if current user is a member (all members can invite)
      final myRole = await getMyRole(tripId);
      if (myRole == null) {
        throw Exception('You do not have permission to add members');
      }

      // Owner role can only be set by existing owner
      if (role == MemberRole.owner && myRole != MemberRole.owner) {
        throw Exception('Only the trip owner can add another owner');
      }

      // Check if user is already a member
      final existingMember = await _supabase
          .from('trip_members')
          .select()
          .eq('trip_id', tripId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingMember != null) {
        throw Exception('User is already a member of this trip');
      }

      final response = await _supabase
          .from('trip_members')
          .insert({
            'trip_id': tripId,
            'user_id': userId,
            'role': role.name,
          })
          .select()
          .single();

      debugPrint('TripService: Member added: $userId to trip $tripId');
      return TripMember.fromJson(response);
    } catch (e) {
      debugPrint('TripService: Error adding member: $e');
      rethrow;
    }
  }

  /// Remove a member from a trip
  Future<void> removeMember(String tripId, String userId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final myRole = await getMyRole(tripId);
      
      // Get the member being removed
      final memberResponse = await _supabase
          .from('trip_members')
          .select()
          .eq('trip_id', tripId)
          .eq('user_id', userId)
          .maybeSingle();

      if (memberResponse == null) {
        throw Exception('Member not found');
      }

      final memberToRemove = TripMember.fromJson(memberResponse);

      // Only owner can remove others; owners can't be removed
      if (memberToRemove.isOwner) {
        throw Exception('Cannot remove the trip owner');
      }

      if (myRole != MemberRole.owner) {
        throw Exception('Only the trip owner can remove members');
      }

      await _supabase
          .from('trip_members')
          .delete()
          .eq('trip_id', tripId)
          .eq('user_id', userId);

      debugPrint('TripService: Member removed: $userId from trip $tripId');
    } catch (e) {
      debugPrint('TripService: Error removing member: $e');
      rethrow;
    }
  }

  /// Leave a trip (current user removes themselves)
  Future<void> leaveTrip(String tripId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final myRole = await getMyRole(tripId);
      
      if (myRole == null) {
        throw Exception('You are not a member of this trip');
      }

      if (myRole == MemberRole.owner) {
        // Check if there are other members
        final members = await getTripMembers(tripId);
        if (members.length > 1) {
          throw Exception('Transfer ownership before leaving, or delete the trip');
        }
        // If owner is the only member, delete the trip instead
        await deleteTrip(tripId);
        return;
      }

      await _supabase
          .from('trip_members')
          .delete()
          .eq('trip_id', tripId)
          .eq('user_id', userId);

      debugPrint('TripService: User left trip: $tripId');
    } catch (e) {
      debugPrint('TripService: Error leaving trip: $e');
      rethrow;
    }
  }

  /// Update a member's role
  Future<TripMember> updateMemberRole({
    required String tripId,
    required String userId,
    required MemberRole newRole,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final myRole = await getMyRole(tripId);
      
      if (myRole != MemberRole.owner) {
        throw Exception('Only the trip owner can change member roles');
      }

      // Can't change own role (owner)
      if (userId == currentUserId) {
        throw Exception('Cannot change your own role');
      }

      // If setting someone as owner, need to transfer ownership
      if (newRole == MemberRole.owner) {
        return await transferOwnership(tripId, userId);
      }

      final response = await _supabase
          .from('trip_members')
          .update({'role': newRole.name})
          .eq('trip_id', tripId)
          .eq('user_id', userId)
          .select()
          .single();

      debugPrint('TripService: Member role updated: $userId to ${newRole.name}');
      return TripMember.fromJson(response);
    } catch (e) {
      debugPrint('TripService: Error updating member role: $e');
      rethrow;
    }
  }

  /// Transfer trip ownership to another member
  Future<TripMember> transferOwnership(String tripId, String newOwnerId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final myRole = await getMyRole(tripId);
      
      if (myRole != MemberRole.owner) {
        throw Exception('Only the trip owner can transfer ownership');
      }

      // Demote current owner to editor
      await _supabase
          .from('trip_members')
          .update({'role': MemberRole.editor.name})
          .eq('trip_id', tripId)
          .eq('user_id', currentUserId);

      // Promote new owner
      final response = await _supabase
          .from('trip_members')
          .update({'role': MemberRole.owner.name})
          .eq('trip_id', tripId)
          .eq('user_id', newOwnerId)
          .select()
          .single();

      // Update trip owner_id
      await _supabase
          .from('trips')
          .update({'owner_id': newOwnerId})
          .eq('id', tripId);

      debugPrint('TripService: Ownership transferred to: $newOwnerId');
      return TripMember.fromJson(response);
    } catch (e) {
      debugPrint('TripService: Error transferring ownership: $e');
      rethrow;
    }
  }

  /// Check if a user is already a member of a trip
  Future<bool> isMember(String tripId, String userId) async {
    try {
      final response = await _supabase
          .from('trip_members')
          .select('id')
          .eq('trip_id', tripId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('TripService: Error checking membership: $e');
      return false;
    }
  }
}
