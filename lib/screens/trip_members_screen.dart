import 'package:flutter/material.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/trip_member.dart';
import 'package:larga/models/user_profile.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/services/profile_service.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/screens/invite_member_sheet.dart';
import 'package:larga/widgets/skeleton_widgets.dart';

class TripMembersScreen extends StatefulWidget {
  final String tripId;
  final Trip? trip;

  const TripMembersScreen({
    super.key,
    required this.tripId,
    this.trip,
  });

  @override
  State<TripMembersScreen> createState() => _TripMembersScreenState();
}

class _TripMembersScreenState extends State<TripMembersScreen> {
  final _tripService = TripService();
  final _profileService = ProfileService();

  List<_MemberWithProfile> _members = [];
  bool _isLoading = true;
  MemberRole? _myRole;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _tripService.getTripMembers(widget.tripId),
        _tripService.getMyRole(widget.tripId),
        _profileService.getCurrentUserProfile(),
      ]);

      final members = results[0] as List<TripMember>;
      _myRole = results[1] as MemberRole?;
      final currentProfile = results[2] as UserProfile?;
      _currentUserId = currentProfile?.authId;

      // Fetch profiles for all members
      final authIds = members.map((m) => m.userId).toList();
      final profiles = await _profileService.getProfilesByAuthIds(authIds);
      final profileMap = {for (var p in profiles) p.authId: p};

      _members = members.map((m) {
        return _MemberWithProfile(
          member: m,
          profile: profileMap[m.userId],
        );
      }).toList();

      // Sort: owner first, then editors, then viewers
      _members.sort((a, b) {
        final roleOrder = {
          MemberRole.owner: 0,
          MemberRole.editor: 1,
          MemberRole.viewer: 2,
        };
        return roleOrder[a.member.role]!.compareTo(roleOrder[b.member.role]!);
      });

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarUtils.showError(context, 'Failed to load members');
      }
    }
  }

  Future<void> _inviteMember() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => InviteMemberSheet(tripId: widget.tripId),
    );

    if (result == true) {
      _loadMembers();
    }
  }

  Future<void> _updateMemberRole(_MemberWithProfile memberData) async {
    if (_myRole != MemberRole.owner) return;
    if (memberData.member.userId == _currentUserId) return;
    if (memberData.member.isOwner) return;

    final newRole = await showModalBottomSheet<MemberRole>(
      context: context,
      builder: (context) => _RolePickerSheet(
        currentRole: memberData.member.role,
        memberName: memberData.profile?.displayName ?? 'Member',
      ),
    );

    if (newRole == null || newRole == memberData.member.role) return;

    try {
      if (newRole == MemberRole.owner) {
        final confirmed = await _showTransferOwnershipDialog(memberData);
        if (confirmed != true) return;
      }

      await _tripService.updateMemberRole(
        tripId: widget.tripId,
        userId: memberData.member.userId,
        newRole: newRole,
      );

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Role updated');
        _loadMembers();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    }
  }

  Future<bool?> _showTransferOwnershipDialog(_MemberWithProfile memberData) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Ownership'),
        content: Text(
          'Are you sure you want to make ${memberData.profile?.displayName ?? 'this member'} the owner of this trip?\n\n'
          'You will become an editor and lose owner privileges.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(_MemberWithProfile memberData) async {
    if (_myRole != MemberRole.owner) return;
    if (memberData.member.isOwner) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove ${memberData.profile?.displayName ?? 'this member'} from the trip?',
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
      await _tripService.removeMember(widget.tripId, memberData.member.userId);

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Member removed');
        _loadMembers();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    }
  }

  Future<void> _leaveTrip() async {
    final isOwner = _myRole == MemberRole.owner;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Trip'),
        content: Text(
          isOwner && _members.length > 1
              ? 'You are the owner. Please transfer ownership before leaving, or delete the trip.'
              : 'Are you sure you want to leave this trip?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          if (!(isOwner && _members.length > 1))
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(isOwner ? 'Delete Trip' : 'Leave'),
            ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _tripService.leaveTrip(widget.tripId);

      if (mounted) {
        SnackBarUtils.showSuccess(context, isOwner ? 'Trip deleted' : 'You left the trip');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canInvite = _myRole == MemberRole.owner || _myRole == MemberRole.editor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Members'),
        actions: [
          if (canInvite)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: _inviteMember,
              tooltip: 'Invite Member',
            ),
        ],
      ),
      body: _isLoading
          ? const MembersListSkeleton()
          : RefreshIndicator(
              onRefresh: _loadMembers,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _members.length + 1,
                itemBuilder: (context, index) {
                  if (index == _members.length) {
                    return _buildLeaveSection();
                  }
                  return _buildMemberTile(_members[index]);
                },
              ),
            ),
      floatingActionButton: canInvite
          ? FloatingActionButton.extended(
              onPressed: _inviteMember,
              icon: const Icon(Icons.person_add),
              label: const Text('Invite'),
            )
          : null,
    );
  }

  Widget _buildMemberTile(_MemberWithProfile memberData) {
    final isCurrentUser = memberData.member.userId == _currentUserId;
    final canManage = _myRole == MemberRole.owner && 
                      !memberData.member.isOwner && 
                      !isCurrentUser;

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: memberData.profile?.avatarUrl != null
            ? NetworkImage(memberData.profile!.avatarUrl!)
            : null,
        child: memberData.profile?.avatarUrl == null
            ? Text(
                _getInitials(memberData.profile?.displayName),
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              memberData.profile?.displayName ?? 'Unknown User',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'You',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          _RoleBadge(role: memberData.member.role),
          if (memberData.profile?.homeCity != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                memberData.profile!.homeCity!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      trailing: canManage
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'role':
                    _updateMemberRole(memberData);
                    break;
                  case 'remove':
                    _removeMember(memberData);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'role',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings_outlined),
                      SizedBox(width: 12),
                      Text('Change Role'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_outlined, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Remove', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            )
          : null,
      onTap: canManage ? () => _updateMemberRole(memberData) : null,
    );
  }

  Widget _buildLeaveSection() {
    if (_myRole == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _leaveTrip,
              icon: Icon(
                _myRole == MemberRole.owner && _members.length == 1
                    ? Icons.delete_outline
                    : Icons.exit_to_app,
                color: Colors.red,
              ),
              label: Text(
                _myRole == MemberRole.owner && _members.length == 1
                    ? 'Delete Trip'
                    : 'Leave Trip',
                style: const TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
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

class _MemberWithProfile {
  final TripMember member;
  final UserProfile? profile;

  _MemberWithProfile({required this.member, this.profile});
}

class _RoleBadge extends StatelessWidget {
  final MemberRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      MemberRole.owner => ('Owner', Colors.amber),
      MemberRole.editor => ('Editor', Colors.blue),
      MemberRole.viewer => ('Viewer', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            role == MemberRole.owner
                ? Icons.star
                : role == MemberRole.editor
                    ? Icons.edit
                    : Icons.visibility,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePickerSheet extends StatelessWidget {
  final MemberRole currentRole;
  final String memberName;

  const _RolePickerSheet({
    required this.currentRole,
    required this.memberName,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Change role for $memberName',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Divider(height: 1),
          ...MemberRole.values.map((role) => ListTile(
                leading: Icon(_getRoleIcon(role)),
                title: Text(_getRoleLabel(role)),
                subtitle: Text(_getRoleDescription(role)),
                trailing: currentRole == role
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => Navigator.pop(context, role),
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  IconData _getRoleIcon(MemberRole role) {
    return switch (role) {
      MemberRole.owner => Icons.star,
      MemberRole.editor => Icons.edit,
      MemberRole.viewer => Icons.visibility,
    };
  }

  String _getRoleLabel(MemberRole role) {
    return switch (role) {
      MemberRole.owner => 'Owner',
      MemberRole.editor => 'Editor',
      MemberRole.viewer => 'Viewer',
    };
  }

  String _getRoleDescription(MemberRole role) {
    return switch (role) {
      MemberRole.owner => 'Full control, can delete trip and manage all members',
      MemberRole.editor => 'Can edit trip details, itinerary, and expenses',
      MemberRole.viewer => 'Can view trip details only',
    };
  }
}
