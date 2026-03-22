import 'package:flutter/material.dart';
import 'package:larga/utils/snackbar_utils.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Placeholder: set to true to show empty state, false to show sample trips
  final bool _hasTrips = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Past'),
              ],
            ),
          ),
        ],
        body: _hasTrips ? _buildTripsContent() : _buildEmptyState(theme),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          SnackBarUtils.showInfo(context, 'Create trip coming in Phase 1!');
        },
        icon: const Icon(Icons.add),
        label: const Text('New Trip'),
      ),
    );
  }

  Widget _buildTripsContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        // Upcoming Trips
        ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _TripCard(
              title: 'Siargao Surfing Trip',
              destination: 'Siargao Island, Philippines',
              dateRange: 'Mar 28 - Apr 2, 2026',
              status: TripStatus.planning,
              memberCount: 4,
              daysUntil: 7,
              color: Color(0xFF1E88E5),
              icon: Icons.surfing,
            ),
            SizedBox(height: 16),
            _TripCard(
              title: 'Palawan Adventure',
              destination: 'El Nido, Palawan',
              dateRange: 'Apr 15 - 20, 2026',
              status: TripStatus.planning,
              memberCount: 6,
              daysUntil: 25,
              color: Color(0xFF43A047),
              icon: Icons.kayaking,
            ),
            SizedBox(height: 100),
          ],
        ),
        // Past Trips
        ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _TripCard(
              title: 'Baguio Weekend',
              destination: 'Baguio City, Philippines',
              dateRange: 'Feb 14 - 16, 2026',
              status: TripStatus.completed,
              memberCount: 3,
              color: Color(0xFF8E24AA),
              icon: Icons.forest,
            ),
            SizedBox(height: 16),
            _TripCard(
              title: 'Cebu Food Trip',
              destination: 'Cebu City, Philippines',
              dateRange: 'Jan 5 - 8, 2026',
              status: TripStatus.completed,
              memberCount: 5,
              color: Color(0xFFFF7043),
              icon: Icons.restaurant,
            ),
            SizedBox(height: 100),
          ],
        ),
      ],
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
              onPressed: () {},
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

enum TripStatus { planning, ongoing, completed }

class _TripCard extends StatelessWidget {
  final String title;
  final String destination;
  final String dateRange;
  final TripStatus status;
  final int memberCount;
  final int? daysUntil;
  final Color color;
  final IconData icon;

  const _TripCard({
    required this.title,
    required this.destination,
    required this.dateRange,
    required this.status,
    required this.memberCount,
    required this.color,
    required this.icon,
    this.daysUntil,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    color.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Background Icon
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      icon,
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
                            _StatusBadge(status: status),
                            if (daysUntil != null)
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
                                  '$daysUntil days',
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
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Destination
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              destination,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Bottom Row
                        Row(
                          children: [
                            // Date
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  dateRange,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Members
                            Row(
                              children: [
                                ...List.generate(
                                  memberCount > 3 ? 3 : memberCount,
                                  (i) => Align(
                                    widthFactor: 0.7,
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.white,
                                      child: CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.primaries[i * 3 % Colors.primaries.length],
                                        child: Text(
                                          ['J', 'A', 'M', 'K'][i],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (memberCount > 3)
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                                    child: Text(
                                      '+${memberCount - 3}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TripStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bgColor, icon) = switch (status) {
      TripStatus.planning => ('Planning', Colors.white.withValues(alpha: 0.2), Icons.edit_note),
      TripStatus.ongoing => ('Ongoing', Colors.green.withValues(alpha: 0.8), Icons.flight_takeoff),
      TripStatus.completed => ('Completed', Colors.white.withValues(alpha: 0.2), Icons.check_circle),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
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
