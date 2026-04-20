import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/draft_itinerary.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/services/draft_itinerary_service.dart';
import 'package:larga/screens/create_trip_screen.dart';
import 'package:larga/screens/trip_detail_screen.dart';
import 'package:larga/screens/review_itinerary_screen.dart';
import 'package:larga/widgets/skeleton_widgets.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  TripsScreenState createState() => TripsScreenState();
}

class TripsScreenState extends State<TripsScreen> with SingleTickerProviderStateMixin {
  /// Public method to refresh data when tab is selected
  void refreshData() {
    _loadTrips();
  }
  late TabController _tabController;
  final _tripService = TripService();
  final _draftService = DraftItineraryService();

  List<Trip> _upcomingTrips = [];
  List<Trip> _pastTrips = [];
  List<DraftItinerary> _drafts = [];
  bool _isLoading = true;
  String? _error;

  StreamSubscription<void>? _tripsSubscription;
  StreamSubscription<void>? _draftsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrips();
    _setupRealtimeSubscriptions();
  }

  void _setupRealtimeSubscriptions() {
    _tripsSubscription = _tripService.subscribeToTripsChanges(
      onUpdate: () {
        if (mounted) _loadTrips();
      },
    );

    _draftsSubscription = _draftService.subscribeToDraftChanges(
      onUpdate: () {
        if (mounted) _loadTrips();
      },
    );
  }

  @override
  void dispose() {
    _tripsSubscription?.cancel();
    _draftsSubscription?.cancel();
    _tripService.unsubscribeFromTrips();
    _draftService.unsubscribeFromDrafts();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _tripService.getUpcomingTrips(),
        _tripService.getPastTrips(),
        _draftService.getDrafts(),
      ]);

      if (!mounted) return;
      setState(() {
        _upcomingTrips = results[0] as List<Trip>;
        _pastTrips = results[1] as List<Trip>;
        _drafts = results[2] as List<DraftItinerary>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openDraft(DraftItinerary draft) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReviewItineraryScreen.fromDraft(draftId: draft.id),
      ),
    );
    _loadTrips();
  }

  Future<void> _deleteDraft(DraftItinerary draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft?'),
        content: Text(
          'Delete the draft itinerary for "${draft.destination?.name ?? 'Unknown'}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _draftService.deleteDraft(draft.id);
      _loadTrips();
    }
  }

  Future<void> _createTrip() async {
    final result = await Navigator.of(context).push<Trip>(
      MaterialPageRoute(
        builder: (context) => const CreateTripScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      _loadTrips();
    }
  }

  Future<void> _openTrip(Trip trip) async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (context) => TripDetailScreen(
          tripId: trip.id,
          initialTrip: trip,
        ),
      ),
    );

    if (result == true) {
      _loadTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTrips = _upcomingTrips.isNotEmpty || _pastTrips.isNotEmpty;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            toolbarHeight: 70,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Trips',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Plan and manage your adventures',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: theme.colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(text: 'Upcoming (${_upcomingTrips.length})'),
                Tab(text: 'Past (${_pastTrips.length})'),
              ],
            ),
          ),
        ],
        body: _isLoading
            ? const TripsListSkeleton()
            : _error != null
                ? _buildErrorState(theme)
                : hasTrips
                    ? _buildTripsContent()
                    : _buildEmptyState(theme),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTrip,
        icon: const Icon(Icons.add),
        label: const Text('New Trip'),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load trips',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadTrips,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftsSection(ThemeData theme) {
    if (_drafts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.pending_actions, size: 20, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Text(
                'Draft Itineraries',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_drafts.length} pending',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _drafts.length,
            itemBuilder: (context, index) {
              final draft = _drafts[index];
              return _DraftCard(
                draft: draft,
                onTap: () => _openDraft(draft),
                onDelete: () => _deleteDraft(draft),
              );
            },
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  Widget _buildTripsContent() {
    final theme = Theme.of(context);
    
    return RefreshIndicator(
      onRefresh: _loadTrips,
      child: TabBarView(
        controller: _tabController,
        children: [
          // Upcoming Trips
          _upcomingTrips.isEmpty && _drafts.isEmpty
              ? _buildTabEmptyState(
                  'No upcoming trips',
                  'Plan your next adventure!',
                  Icons.flight_takeoff,
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _upcomingTrips.length + (_drafts.isNotEmpty ? 2 : 1),
                  itemBuilder: (context, index) {
                    // Drafts section at the top
                    if (_drafts.isNotEmpty && index == 0) {
                      return _buildDraftsSection(theme);
                    }
                    
                    final tripIndex = _drafts.isNotEmpty ? index - 1 : index;
                    
                    if (tripIndex >= _upcomingTrips.length) {
                      return const SizedBox(height: 80);
                    }
                    final trip = _upcomingTrips[tripIndex];
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        16, 
                        tripIndex == 0 && _drafts.isEmpty ? 16 : 0, 
                        16, 
                        16,
                      ),
                      child: _TripCard(
                        trip: trip,
                        onTap: () => _openTrip(trip),
                      ),
                    );
                  },
                ),
          // Past Trips
          _pastTrips.isEmpty
              ? _buildTabEmptyState(
                  'No past trips',
                  'Your completed trips will appear here',
                  Icons.history,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pastTrips.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _pastTrips.length) {
                      return const SizedBox(height: 80);
                    }
                    final trip = _pastTrips[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _TripCard(
                        trip: trip,
                        onTap: () => _openTrip(trip),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildTabEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.luggage_outlined,
                size: 60,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No trips yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start planning your next adventure!\nCreate your first trip and invite friends.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _createTrip,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Trip'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;

  const _TripCard({
    required this.trip,
    required this.onTap,
  });

  // Generate a unique color based on trip ID for visual variety
  Color get _tripColor {
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
    final hash = trip.id.hashCode.abs();
    return colors[hash % colors.length];
  }

  IconData get _tripIcon {
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
    final hash = trip.id.hashCode.abs();
    return icons[hash % icons.length];
  }

  IconData get _statusIcon {
    return switch (trip.status) {
      TripStatus.planning => Icons.edit_note,
      TripStatus.ongoing => Icons.flight_takeoff,
      TripStatus.completed => Icons.check_circle,
    };
  }

  String get _statusLabel {
    return switch (trip.status) {
      TripStatus.planning => 'Planning',
      TripStatus.ongoing => 'Ongoing',
      TripStatus.completed => 'Completed',
    };
  }

  String _formatDateRange() {
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

  int? get _daysUntil {
    if (trip.startDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(trip.startDate!.year, trip.startDate!.month, trip.startDate!.day);
    final difference = start.difference(today).inDays;
    return difference >= 0 ? difference : null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background
              Container(
                key: ValueKey(trip.coverImageUrl ?? 'no-cover'),
                height: 180,
                decoration: BoxDecoration(
                  gradient: trip.coverImageUrl == null
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _tripColor,
                            _tripColor.withValues(alpha: 0.8),
                          ],
                        )
                      : null,
                  image: trip.coverImageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(trip.coverImageUrl!),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.3),
                            BlendMode.darken,
                          ),
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    // Background Icon (when no cover image)
                    if (trip.coverImageUrl == null)
                      Positioned(
                        right: -20,
                        bottom: -20,
                        child: Icon(
                          _tripIcon,
                          size: 150,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Badge & Days Until
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _StatusBadge(
                                label: _statusLabel,
                                icon: _statusIcon,
                              ),
                              if (_daysUntil != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _daysUntil == 0 ? 'Today!' : '$_daysUntil days',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          // Title
                          Text(
                            trip.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Date Range
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatDateRange(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              if (trip.tripDurationDays != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${trip.tripDurationDays} days',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  final DraftItinerary draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DraftCard({
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    final destination = draft.destination;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Colors.orange[700],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI Draft',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    destination?.name ?? 'Unknown Destination',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dateFormat.format(draft.preferences.startDate)} - ${dateFormat.format(draft.preferences.endDate)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: draft.reviewProgress,
                            backgroundColor: Colors.grey[200],
                            color: Colors.orange,
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(draft.reviewProgress * 100).toInt()}%',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
