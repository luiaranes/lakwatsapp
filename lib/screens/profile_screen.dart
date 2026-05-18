import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:larga/services/auth_service.dart';
import 'package:larga/services/profile_service.dart';
import 'package:larga/services/friendship_service.dart';
import 'package:larga/models/user_profile.dart';
import 'package:larga/screens/sign_in_screen.dart';
import 'package:larga/screens/edit_profile_screen.dart';
import 'package:larga/screens/friends_screen.dart';
import 'package:larga/screens/notifications_screen.dart';
import 'package:larga/services/notification_service.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/widgets/skeleton_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  /// Public method to refresh data when tab is selected
  void refreshData() {
    _loadProfile();
  }
  final _authService = AuthService();
  final _profileService = ProfileService();
  final _friendshipService = FriendshipService();
  final _notificationService = NotificationService();

  UserProfile? _profile;
  bool _isLoading = true;
  int _tripCount = 0;
  int _placesCount = 0;
  int _friendCount = 0;
  int _pendingRequestCount = 0;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      var profile = await _profileService.getCurrentUserProfile();
      
      // Auto-create profile if it doesn't exist (e.g., was deleted or trigger failed)
      if (profile == null) {
        debugPrint('ProfileScreen: No profile found, creating one...');
        profile = await _profileService.createProfileIfNotExists();
      }
      
      debugPrint('ProfileScreen: Loaded profile: ${profile?.id}');
      
      int tripCount = 0;
      int placesCount = 0;
      int friendCount = 0;
      int pendingCount = 0;
      int unreadCount = 0;

      if (profile != null) {
        final results = await Future.wait([
          _profileService.getTripCount(profile.id),
          _profileService.getPlacesVisitedCount(profile.id),
          _friendshipService.getFriendCount(),
          _friendshipService.getPendingRequestCount(),
          _notificationService.getUnreadCount(),
        ]);
        tripCount = results[0] as int;
        placesCount = results[1] as int;
        friendCount = results[2] as int;
        pendingCount = results[3] as int;
        unreadCount = results[4] as int;
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _tripCount = tripCount;
          _placesCount = placesCount;
          _friendCount = friendCount;
          _pendingRequestCount = pendingCount;
          _unreadNotificationCount = unreadCount;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('ProfileScreen: Error loading profile: $e');
      debugPrint('ProfileScreen: Stack trace: $stack');
      if (mounted) {
        setState(() {
          // Don't show error, just proceed without profile data
          _profile = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Sign out failed: ${e.toString()}');
      }
    }
  }

  void _navigateToFriends() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FriendsScreen()),
    );
    _loadProfile();
  }

  void _navigateToEditProfile() async {
    if (_profile == null) {
      // Profile doesn't exist in database yet, try to create it first
      try {
        await _profileService.createProfileIfNotExists();
        await _loadProfile();
        if (_profile == null) {
          if (mounted) {
            SnackBarUtils.showInfo(context, 'Unable to load profile. Please try again.');
          }
          return;
        }
      } catch (e) {
        debugPrint('Error creating profile: $e');
        if (mounted) {
          SnackBarUtils.showInfo(context, 'Unable to create profile. Please try again.');
        }
        return;
      }
    }
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: _profile!),
      ),
    );
    
    if (result == true) {
      _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _authService.currentUser;
    final email = user?.email ?? '';

    final displayName = _profile?.displayName ?? 
        user?.userMetadata?['full_name'] as String? ?? 
        'Traveler';
    final avatarUrl = _profile?.avatarUrl ?? 
        user?.userMetadata?['avatar_url'] as String?;
    final bio = _profile?.bio;
    final location = _buildLocationString();

    if (_isLoading) {
      return const ProfileSkeleton();
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          slivers: [
            // Profile Header
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Top actions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 48),
                            Text(
                              'Profile',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined, color: Colors.white),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Avatar
                      GestureDetector(
                        onTap: _navigateToEditProfile,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                backgroundColor: Colors.white,
                                child: avatarUrl == null
                                    ? Text(
                                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Name
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Location
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              location,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                      // Bio
                      if (bio != null && bio.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            bio,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Stats
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatItem(value: '$_tripCount', label: 'Trips'),
                            _divider(),
                            _StatItem(value: '$_placesCount', label: 'Places'),
                            _divider(),
                            _ClickableStatItem(
                              value: '$_friendCount',
                              label: 'Friends',
                              badgeCount: _pendingRequestCount,
                              onTap: _navigateToFriends,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          
          // Menu Items
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MenuCard(
                    children: [
                      _MenuItem(
                        icon: Icons.person_outline,
                        iconColor: Colors.blue,
                        title: 'Edit Profile',
                        subtitle: 'Update your info and photo',
                        onTap: _navigateToEditProfile,
                      ),
                      _MenuItemWithBadge(
                        icon: Icons.people_outline,
                        iconColor: Colors.purple,
                        title: 'Friends',
                        subtitle: 'Manage your friends list',
                        badgeCount: _pendingRequestCount,
                        onTap: _navigateToFriends,
                      ),
                      _MenuItem(
                        icon: Icons.wallet_outlined,
                        iconColor: Colors.green,
                        title: 'Payment Methods',
                        subtitle: 'Manage cards and wallets',
                        onTap: () => _showComingSoon(context),
                      ),
                      _MenuItemWithBadge(
                        icon: Icons.notifications_outlined,
                        iconColor: Colors.orange,
                        title: 'Notifications',
                        subtitle: 'Packing assignments and trip updates',
                        badgeCount: _unreadNotificationCount,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          );
                          _loadProfile();
                        },
                        showDivider: false,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  Text(
                    'Preferences',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MenuCard(
                    children: [
                      _MenuItem(
                        icon: Icons.language,
                        iconColor: Colors.purple,
                        title: 'Language',
                        trailing: Text(
                          'English',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        onTap: () => _showComingSoon(context),
                      ),
                      _MenuItem(
                        icon: Icons.attach_money,
                        iconColor: Colors.teal,
                        title: 'Currency',
                        trailing: Text(
                          'PHP',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        onTap: () => _showComingSoon(context),
                      ),
                      _MenuItem(
                        icon: Icons.dark_mode_outlined,
                        iconColor: Colors.indigo,
                        title: 'Dark Mode',
                        trailing: Switch.adaptive(
                          value: false,
                          onChanged: (_) => _showComingSoon(context),
                        ),
                        showDivider: false,
                        onTap: () {},
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  Text(
                    'Support',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MenuCard(
                    children: [
                      _MenuItem(
                        icon: Icons.help_outline,
                        iconColor: Colors.cyan,
                        title: 'Help Center',
                        onTap: () => _showComingSoon(context),
                      ),
                      _MenuItem(
                        icon: Icons.chat_bubble_outline,
                        iconColor: Colors.pink,
                        title: 'Send Feedback',
                        onTap: () => _showComingSoon(context),
                      ),
                      _MenuItem(
                        icon: Icons.info_outline,
                        iconColor: Colors.grey,
                        title: 'About Lakwatsapp',
                        trailing: Text(
                          'v1.0.0',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        onTap: () => _showComingSoon(context),
                        showDivider: false,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _buildLocationString() {
    final city = _profile?.homeCity;
    final country = _profile?.homeCountry;
    
    if (city != null && city.isNotEmpty && country != null && country.isNotEmpty) {
      return '$city, $country';
    } else if (city != null && city.isNotEmpty) {
      return city;
    } else if (country != null && country.isNotEmpty) {
      return country;
    }
    return '';
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.3),
    );
  }

  void _showComingSoon(BuildContext context) {
    SnackBarUtils.showInfo(context, 'Coming soon!');
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _ClickableStatItem extends StatelessWidget {
  final String value;
  final String label;
  final int badgeCount;
  final VoidCallback onTap;

  const _ClickableStatItem({
    required this.value,
    required this.label,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -12,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;

  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool showDivider;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                )
              : null,
          trailing: trailing ?? Icon(Icons.chevron_right, color: Colors.grey[400]),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: Colors.grey[200],
          ),
      ],
    );
  }
}

class _MenuItemWithBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final int badgeCount;
  final VoidCallback onTap;
  final bool showDivider;

  const _MenuItemWithBadge({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.badgeCount = 0,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                )
              : null,
          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: Colors.grey[200],
          ),
      ],
    );
  }
}
