import 'package:flutter/material.dart';
import 'package:larga/models/trip_member.dart';
import 'package:larga/models/user_profile.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/services/friendship_service.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/screens/friends_screen.dart';

class InviteMemberSheet extends StatefulWidget {
  final String tripId;

  const InviteMemberSheet({
    super.key,
    required this.tripId,
  });

  @override
  State<InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends State<InviteMemberSheet> {
  final _tripService = TripService();
  final _friendshipService = FriendshipService();
  final _searchController = TextEditingController();

  List<FriendWithProfile> _allFriends = [];
  List<FriendWithProfile> _filteredFriends = [];
  Set<String> _existingMemberIds = {};
  bool _isLoading = true;
  bool _isAdding = false;

  MemberRole _selectedRole = MemberRole.viewer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _friendshipService.getFriends(),
        _tripService.getTripMembers(widget.tripId),
      ]);

      final friends = results[0] as List<FriendWithProfile>;
      final members = results[1] as List<TripMember>;

      if (mounted) {
        setState(() {
          _allFriends = friends;
          _filteredFriends = friends;
          _existingMemberIds = members.map((m) => m.userId).toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarUtils.showError(context, 'Failed to load friends');
      }
    }
  }

  void _filterFriends(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredFriends = _allFriends);
      return;
    }

    final searchTerm = query.toLowerCase();
    setState(() {
      _filteredFriends = _allFriends.where((friend) {
        final name = friend.profile.displayName?.toLowerCase() ?? '';
        final city = friend.profile.homeCity?.toLowerCase() ?? '';
        return name.contains(searchTerm) || city.contains(searchTerm);
      }).toList();
    });
  }

  Future<void> _inviteFriend(FriendWithProfile friend) async {
    if (_existingMemberIds.contains(friend.profile.authId)) {
      SnackBarUtils.showInfo(
        context,
        '${friend.profile.displayName ?? 'User'} is already a member',
      );
      return;
    }

    setState(() => _isAdding = true);

    try {
      await _tripService.addMember(
        tripId: widget.tripId,
        userId: friend.profile.authId,
        role: _selectedRole,
      );

      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          '${friend.profile.displayName ?? 'User'} added to the trip',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAdding = false);
        SnackBarUtils.showError(context, e.toString());
      }
    }
  }

  void _goToAddFriends() {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FriendsScreen()),
    );
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
                      'Invite Friends',
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

              // Search field (filter friends)
              if (_allFriends.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Filter friends...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterFriends('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: _filterFriends,
                  ),
                ),

              if (_allFriends.isNotEmpty) const SizedBox(height: 12),

              // Role selector
              if (_allFriends.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Role:',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RoleChip(
                        role: MemberRole.viewer,
                        isSelected: _selectedRole == MemberRole.viewer,
                        onTap: () =>
                            setState(() => _selectedRole = MemberRole.viewer),
                      ),
                      const SizedBox(width: 8),
                      _RoleChip(
                        role: MemberRole.editor,
                        isSelected: _selectedRole == MemberRole.editor,
                        onTap: () =>
                            setState(() => _selectedRole = MemberRole.editor),
                      ),
                    ],
                  ),
                ),

              if (_allFriends.isNotEmpty) const SizedBox(height: 12),
              if (_allFriends.isNotEmpty) const Divider(height: 1),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildContent(scrollController),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_allFriends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No friends yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add friends first to invite them to trips',
                style: TextStyle(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _goToAddFriends,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Friends'),
              ),
            ],
          ),
        ),
      );
    }

    // Separate available friends from existing members
    final availableFriends = _filteredFriends
        .where((f) => !_existingMemberIds.contains(f.profile.authId))
        .toList();
    final alreadyMembers = _filteredFriends
        .where((f) => _existingMemberIds.contains(f.profile.authId))
        .toList();

    if (_filteredFriends.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No matching friends',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (availableFriends.isNotEmpty) ...[
          ...availableFriends.map((friend) => _FriendInviteTile(
                profile: friend.profile,
                isExistingMember: false,
                isAdding: _isAdding,
                onInvite: () => _inviteFriend(friend),
              )),
        ],
        if (alreadyMembers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Already in trip',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
          ),
          ...alreadyMembers.map((friend) => _FriendInviteTile(
                profile: friend.profile,
                isExistingMember: true,
                isAdding: false,
                onInvite: () {},
              )),
        ],
        // Link to add more friends
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton.icon(
            onPressed: _goToAddFriends,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add more friends'),
          ),
        ),
      ],
    );
  }
}

class _FriendInviteTile extends StatelessWidget {
  final UserProfile profile;
  final bool isExistingMember;
  final bool isAdding;
  final VoidCallback onInvite;

  const _FriendInviteTile({
    required this.profile,
    required this.isExistingMember,
    required this.isAdding,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage:
            profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
        child: profile.avatarUrl == null
            ? Text(
                _getInitials(profile.displayName),
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Text(
        profile.displayName ?? 'Unknown User',
        style: TextStyle(
          color: isExistingMember ? Colors.grey[500] : null,
        ),
      ),
      subtitle: profile.homeCity != null
          ? Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    profile.homeCity!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : null,
      trailing: isExistingMember
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 14, color: Colors.green[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Member',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : isAdding
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton(
                  onPressed: onInvite,
                  child: const Text('Invite'),
                ),
      enabled: !isExistingMember && !isAdding,
      onTap: isExistingMember || isAdding ? null : onInvite,
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

class _RoleChip extends StatelessWidget {
  final MemberRole role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (role) {
      MemberRole.owner => ('Owner', Icons.star),
      MemberRole.editor => ('Editor', Icons.edit),
      MemberRole.viewer => ('Viewer', Icons.visibility),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: Theme.of(context).colorScheme.primary)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
