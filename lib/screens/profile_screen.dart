import 'package:flutter/material.dart';
import 'package:larga/services/auth_service.dart';
import 'package:larga/screens/sign_in_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _authService.currentUser;
    final displayName = user?.userMetadata?['full_name'] as String? ?? 'Traveler';
    final email = user?.email ?? '';
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;

    return Scaffold(
      body: CustomScrollView(
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
                    const SizedBox(height: 16),
                    // Name & Email
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
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
                          _StatItem(value: '4', label: 'Trips'),
                          _divider(),
                          _StatItem(value: '12', label: 'Places'),
                          _divider(),
                          _StatItem(value: '8', label: 'Friends'),
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
                        onTap: () => _showComingSoon(context),
                      ),
                      _MenuItem(
                        icon: Icons.wallet_outlined,
                        iconColor: Colors.green,
                        title: 'Payment Methods',
                        subtitle: 'Manage cards and wallets',
                        onTap: () => _showComingSoon(context),
                      ),
                      _MenuItem(
                        icon: Icons.notifications_outlined,
                        iconColor: Colors.orange,
                        title: 'Notifications',
                        subtitle: 'Trip reminders and updates',
                        onTap: () => _showComingSoon(context),
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
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.3),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon!')),
    );
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
