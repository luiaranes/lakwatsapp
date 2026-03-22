import 'package:flutter/material.dart';
import 'package:larga/models/user_profile.dart';
import 'package:larga/services/friendship_service.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/screens/add_friend_sheet.dart';
import 'package:larga/widgets/skeleton_widgets.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final _friendshipService = FriendshipService();
  late TabController _tabController;

  List<FriendWithProfile> _friends = [];
  List<FriendRequest> _pendingRequests = [];
  List<FriendRequest> _sentRequests = [];
  bool _isLoading = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _friendshipService.getFriends(),
        _friendshipService.getPendingRequests(),
        _friendshipService.getSentRequests(),
      ]);

      if (mounted) {
        setState(() {
          _friends = results[0] as List<FriendWithProfile>;
          _pendingRequests = results[1] as List<FriendRequest>;
          _sentRequests = results[2] as List<FriendRequest>;
          _pendingCount = _pendingRequests.length;
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

  Future<void> _acceptRequest(FriendRequest request) async {
    try {
      await _friendshipService.acceptFriendRequest(request.friendship.id);
      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          'You are now friends with ${request.requesterProfile.displayName ?? 'this user'}',
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to accept request');
      }
    }
  }

  Future<void> _rejectRequest(FriendRequest request) async {
    try {
      await _friendshipService.rejectFriendRequest(request.friendship.id);
      if (mounted) {
        SnackBarUtils.showInfo(context, 'Friend request declined');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to decline request');
      }
    }
  }

  Future<void> _cancelSentRequest(FriendRequest request) async {
    try {
      await _friendshipService.cancelFriendRequest(request.friendship.id);
      if (mounted) {
        SnackBarUtils.showInfo(context, 'Friend request cancelled');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to cancel request');
      }
    }
  }

  Future<void> _removeFriend(FriendWithProfile friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
          'Are you sure you want to remove ${friend.profile.displayName ?? 'this friend'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _friendshipService.removeFriend(friend.profile.authId);
      if (mounted) {
        SnackBarUtils.showInfo(context, 'Friend removed');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to remove friend');
      }
    }
  }

  Future<void> _openAddFriend() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const AddFriendSheet(),
    );

    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _openAddFriend,
            tooltip: 'Add Friend',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Friends'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  if (_pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const FriendsListSkeleton()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFriendsTab(),
                  _buildRequestsTab(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddFriend,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Friend'),
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_friends.isEmpty) {
      return Center(
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
              'Add friends to invite them to trips',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openAddFriend,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Friend'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return _FriendTile(
          profile: friend.profile,
          onRemove: () => _removeFriend(friend),
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    if (_pendingRequests.isEmpty && _sentRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mail_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No friend requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Friend requests will appear here',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_pendingRequests.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Pending Requests',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          ..._pendingRequests.map((request) => _FriendRequestTile(
                profile: request.requesterProfile,
                isIncoming: true,
                onAccept: () => _acceptRequest(request),
                onReject: () => _rejectRequest(request),
              )),
        ],
        if (_sentRequests.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Sent Requests',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          ..._sentRequests.map((request) => _FriendRequestTile(
                profile: request.requesterProfile,
                isIncoming: false,
                onCancel: () => _cancelSentRequest(request),
              )),
        ],
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onRemove;

  const _FriendTile({
    required this.profile,
    required this.onRemove,
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
      title: Text(profile.displayName ?? 'Unknown'),
      subtitle: profile.homeCity != null
          ? Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
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
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          if (value == 'remove') {
            onRemove();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.person_remove_outlined, color: Colors.red),
                SizedBox(width: 12),
                Text('Remove Friend', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
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

class _FriendRequestTile extends StatelessWidget {
  final UserProfile profile;
  final bool isIncoming;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  const _FriendRequestTile({
    required this.profile,
    required this.isIncoming,
    this.onAccept,
    this.onReject,
    this.onCancel,
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
      title: Text(profile.displayName ?? 'Unknown'),
      subtitle: profile.homeCity != null
          ? Text(
              profile.homeCity!,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            )
          : null,
      trailing: isIncoming
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: onReject,
                  tooltip: 'Decline',
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
              ],
            )
          : TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              child: const Text('Cancel'),
            ),
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
