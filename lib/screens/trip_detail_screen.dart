import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/services/storage_service.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/screens/edit_trip_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  final Trip? initialTrip;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.initialTrip,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _tripService = TripService();
  final _storageService = StorageService();

  Trip? _trip;
  bool _isLoading = true;
  bool _canEdit = false;
  bool _isOwner = false;
  int _memberCount = 1;

  @override
  void initState() {
    super.initState();
    _trip = widget.initialTrip;
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final results = await Future.wait([
        _tripService.getTripById(widget.tripId),
        _tripService.canEdit(widget.tripId),
        _tripService.isOwner(widget.tripId),
        _tripService.getTripMemberCount(widget.tripId),
      ]);

      if (!mounted) return;

      setState(() {
        _trip = results[0] as Trip?;
        _canEdit = results[1] as bool;
        _isOwner = results[2] as bool;
        _memberCount = results[3] as int;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarUtils.showError(context, 'Failed to load trip');
    }
  }

  Future<void> _uploadCoverImage() async {
    if (_trip == null || !_canEdit) return;

    try {
      final image = await _storageService.pickImageFromGallery();
      if (image == null) return;

      if (!mounted) return;
      SnackBarUtils.showInfo(context, 'Uploading cover image...');

      final coverUrl = await _storageService.uploadTripCover(_trip!.id, image);
      if (coverUrl == null) throw Exception('Upload failed');

      final updatedTrip = await _tripService.updateTrip(
        tripId: _trip!.id,
        coverImageUrl: coverUrl,
      );

      if (!mounted) return;
      setState(() => _trip = updatedTrip);
      SnackBarUtils.showSuccess(context, 'Cover image updated!');
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to upload image');
    }
  }

  Future<void> _updateStatus(TripStatus status) async {
    if (_trip == null || !_canEdit) return;

    try {
      final updatedTrip = await _tripService.updateTripStatus(_trip!.id, status);
      if (!mounted) return;
      setState(() => _trip = updatedTrip);
      SnackBarUtils.showSuccess(context, 'Status updated!');
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to update status');
    }
  }

  Future<void> _deleteTrip() async {
    if (_trip == null || !_isOwner) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: Text(
          'Are you sure you want to delete "${_trip!.title}"?\n\n'
          'This action cannot be undone. All itineraries, expenses, and member data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _tripService.deleteTrip(_trip!.id);
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'Trip deleted');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to delete trip');
    }
  }

  Future<void> _editTrip() async {
    if (_trip == null || !_canEdit) return;

    final updatedTrip = await Navigator.of(context).push<Trip>(
      MaterialPageRoute(
        builder: (context) => EditTripScreen(trip: _trip!),
      ),
    );

    if (updatedTrip != null && mounted) {
      setState(() => _trip = updatedTrip);
    }
  }

  String _formatDateRange(Trip trip) {
    if (trip.startDate == null || trip.endDate == null) {
      return 'Dates not set';
    }
    final dateFormat = DateFormat('MMM d');
    final yearFormat = DateFormat('MMM d, yyyy');

    if (trip.startDate!.year == trip.endDate!.year) {
      return '${dateFormat.format(trip.startDate!)} - ${yearFormat.format(trip.endDate!)}';
    }
    return '${yearFormat.format(trip.startDate!)} - ${yearFormat.format(trip.endDate!)}';
  }

  String _formatBudget(Trip trip) {
    if (trip.budget == null) return 'No budget set';
    final formatter = NumberFormat.currency(
      symbol: _getCurrencySymbol(trip.currency),
      decimalDigits: 0,
    );
    return formatter.format(trip.budget);
  }

  String _getCurrencySymbol(String currency) {
    return switch (currency) {
      'PHP' => '₱',
      'USD' => '\$',
      'EUR' => '€',
      'JPY' => '¥',
      'SGD' => 'S\$',
      'THB' => '฿',
      'KRW' => '₩',
      _ => currency,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading && _trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Trip not found')),
      );
    }

    final daysUntil = _tripService.getDaysUntil(_trip!);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            stretch: true,
            backgroundColor: _getTripColor(),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              if (_canEdit)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                  onPressed: _editTrip,
                ),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'change_cover':
                      _uploadCoverImage();
                      break;
                    case 'delete':
                      _deleteTrip();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (_canEdit)
                    const PopupMenuItem(
                      value: 'change_cover',
                      child: Row(
                        children: [
                          Icon(Icons.image_outlined),
                          SizedBox(width: 12),
                          Text('Change Cover'),
                        ],
                      ),
                    ),
                  if (_isOwner)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Delete Trip', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover Image or Gradient
                  if (_trip!.coverImageUrl != null)
                    Image.network(
                      _trip!.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildGradientCover(theme),
                    )
                  else
                    _buildGradientCover(theme),
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  // Status Badge & Days Until
                  Positioned(
                    top: 100,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        _StatusChip(status: _trip!.status, onTap: _canEdit ? _showStatusPicker : null),
                        const Spacer(),
                        if (daysUntil != null && daysUntil >= 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              daysUntil == 0 
                                  ? 'Today!' 
                                  : '$daysUntil day${daysUntil == 1 ? '' : 's'} away',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Title
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _trip!.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_trip!.startDate != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                _formatDateRange(_trip!),
                                style: const TextStyle(color: Colors.white70, fontSize: 15),
                              ),
                              if (_trip!.tripDurationDays != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_trip!.tripDurationDays} days',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                if (_trip!.description != null && _trip!.description!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _trip!.description!,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ),
                  const Divider(),
                ],

                // Quick Stats
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _StatCard(
                        icon: Icons.people_outline,
                        label: 'Members',
                        value: '$_memberCount',
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Budget',
                        value: _formatBudget(_trip!),
                        color: Colors.green,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.receipt_long_outlined,
                        label: 'Expenses',
                        value: '₱0',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Sections
                _buildSectionHeader(context, 'Itinerary', Icons.map_outlined),
                _buildPlaceholderCard(
                  'No itinerary yet',
                  'Add activities and places to visit',
                  Icons.add_location_alt_outlined,
                  onTap: () => SnackBarUtils.showInfo(context, 'Itinerary builder coming soon!'),
                ),

                _buildSectionHeader(context, 'Expenses', Icons.receipt_outlined),
                _buildPlaceholderCard(
                  'No expenses yet',
                  'Track your trip spending',
                  Icons.add_card,
                  onTap: () => SnackBarUtils.showInfo(context, 'Expense tracking coming soon!'),
                ),

                _buildSectionHeader(context, 'Members', Icons.group_outlined),
                _buildMembersPreview(),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTripIcon() {
    if (_trip == null) return Icons.flight;
    final icons = [
      Icons.flight,
      Icons.beach_access,
      Icons.landscape,
      Icons.location_city,
      Icons.surfing,
      Icons.hiking,
      Icons.restaurant,
      Icons.attractions,
      Icons.directions_boat,
      Icons.forest,
    ];
    final hash = _trip!.id.hashCode.abs();
    return icons[hash % icons.length];
  }

  Color _getTripColor() {
    if (_trip == null) return Colors.blue;
    final colors = [
      const Color(0xFF1E88E5), // Blue
      const Color(0xFF43A047), // Green
      const Color(0xFF8E24AA), // Purple
      const Color(0xFFFF7043), // Deep Orange
      const Color(0xFF00ACC1), // Cyan
      const Color(0xFFE91E63), // Pink
      const Color(0xFF5C6BC0), // Indigo
      const Color(0xFF26A69A), // Teal
      const Color(0xFFFF5722), // Orange
      const Color(0xFF7B1FA2), // Deep Purple
    ];
    final hash = _trip!.id.hashCode.abs();
    return colors[hash % colors.length];
  }

  Widget _buildGradientCover(ThemeData theme) {
    final tripColor = _getTripColor();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tripColor,
            tripColor.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _getTripIcon(),
          size: 80,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard(String title, String subtitle, IconData icon, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            // Member avatars
            SizedBox(
              width: 80,
              height: 36,
              child: Stack(
                clipBehavior: Clip.none,
                children: List.generate(
                  (_memberCount > 3 ? 3 : _memberCount).clamp(1, 3),
                  (i) => Positioned(
                    left: i * 20.0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.primaries[i * 3 % Colors.primaries.length],
                        child: Text(
                          ['Y', 'M', 'J'][i % 3],
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_memberCount.clamp(1, 999)} member${_memberCount <= 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invite friends to join',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => SnackBarUtils.showInfo(context, 'Invite members coming soon!'),
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Invite'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Change Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ...TripStatus.values.map((status) => ListTile(
              leading: Icon(_getStatusIcon(status)),
              title: Text(_getStatusLabel(status)),
              trailing: _trip!.status == status 
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _updateStatus(status);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(TripStatus status) {
    return switch (status) {
      TripStatus.planning => Icons.edit_note,
      TripStatus.ongoing => Icons.flight_takeoff,
      TripStatus.completed => Icons.check_circle,
    };
  }

  String _getStatusLabel(TripStatus status) {
    return switch (status) {
      TripStatus.planning => 'Planning',
      TripStatus.ongoing => 'Ongoing',
      TripStatus.completed => 'Completed',
    };
  }
}

class _StatusChip extends StatelessWidget {
  final TripStatus status;
  final VoidCallback? onTap;

  const _StatusChip({required this.status, this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (status) {
      TripStatus.planning => ('Planning', Icons.edit_note),
      TripStatus.ongoing => ('Ongoing', Icons.flight_takeoff),
      TripStatus.completed => ('Completed', Icons.check_circle),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
