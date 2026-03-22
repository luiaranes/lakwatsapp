import 'dart:async';
import 'package:flutter/material.dart';
import 'package:larga/models/user_profile.dart';
import 'package:larga/models/friendship.dart';
import 'package:larga/services/profile_service.dart';
import 'package:larga/services/friendship_service.dart';
import 'package:larga/utils/snackbar_utils.dart';

class AddFriendSheet extends StatefulWidget {
  const AddFriendSheet({super.key});

  @override
  State<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<AddFriendSheet> {
  final _profileService = ProfileService();
  final _friendshipService = FriendshipService();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  List<_UserWithStatus> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _currentUserId;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final profile = await _profileService.getCurrentUserProfile();
    setState(() => _currentUserId = profile?.authId);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _profileService.searchUsers(query, limit: 15);

      // Filter out current user
      final filtered = results
          .where((user) => user.authId != _currentUserId)
          .toList();

      // Get friendship status for each user
      final usersWithStatus = <_UserWithStatus>[];
      for (final user in filtered) {
        final friendship = await _friendshipService.getFriendship(user.authId);
        usersWithStatus.add(_UserWithStatus(
          profile: user,
          friendship: friendship,
        ));
      }

      if (mounted) {
        setState(() {
          _searchResults = usersWithStatus;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _hasSearched = true;
        });
      }
    }
  }

  Future<void> _sendFriendRequest(_UserWithStatus user) async {
    try {
      final friendship = await _friendshipService.sendFriendRequest(user.profile.authId);

      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          'Friend request sent to ${user.profile.displayName ?? 'user'}',
        );
        
        // Update the user's status in the list with the actual friendship from server
        setState(() {
          final index = _searchResults.indexOf(user);
          if (index >= 0) {
            _searchResults[index] = _UserWithStatus(
              profile: user.profile,
              friendship: friendship,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    }
  }

  Future<void> _acceptRequest(_UserWithStatus user) async {
    if (user.friendship == null) return;

    try {
      await _friendshipService.acceptFriendRequest(user.friendship!.id);

      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          'You are now friends with ${user.profile.displayName ?? 'user'}',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to accept request');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Add Friend',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                                _hasSearched = false;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),

              // Results
              Expanded(
                child: _buildResults(scrollController),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResults(ScrollController scrollController) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Find friends',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search by name or email address',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _UserSearchTile(
          user: user,
          currentUserId: _currentUserId,
          onAddFriend: () => _sendFriendRequest(user),
          onAccept: () => _acceptRequest(user),
        );
      },
    );
  }
}

class _UserWithStatus {
  final UserProfile profile;
  final Friendship? friendship;

  _UserWithStatus({required this.profile, this.friendship});

  bool get isFriend => friendship?.isAccepted ?? false;
  bool get isPendingOutgoing =>
      friendship?.isPending == true &&
      friendship?.requesterId != profile.authId;
  bool get isPendingIncoming =>
      friendship?.isPending == true &&
      friendship?.requesterId == profile.authId;
  bool get canAdd => friendship == null || friendship!.isRejected;
}

class _UserSearchTile extends StatelessWidget {
  final _UserWithStatus user;
  final String? currentUserId;
  final VoidCallback onAddFriend;
  final VoidCallback onAccept;

  const _UserSearchTile({
    required this.user,
    this.currentUserId,
    required this.onAddFriend,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: user.profile.avatarUrl != null
            ? NetworkImage(user.profile.avatarUrl!)
            : null,
        child: user.profile.avatarUrl == null
            ? Text(
                _getInitials(user.profile.displayName),
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Text(user.profile.displayName ?? 'Unknown User'),
      subtitle: user.profile.homeCity != null
          ? Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    user.profile.homeCity!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : null,
      trailing: _buildTrailingWidget(),
    );
  }

  Widget _buildTrailingWidget() {
    if (user.isFriend) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 16, color: Colors.green[700]),
            const SizedBox(width: 4),
            Text(
              'Friends',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (user.isPendingOutgoing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Pending',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (user.isPendingIncoming) {
      return FilledButton(
        onPressed: onAccept,
        child: const Text('Accept'),
      );
    }

    return FilledButton.tonal(
      onPressed: onAddFriend,
      child: const Text('Add Friend'),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
