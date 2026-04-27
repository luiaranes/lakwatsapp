import 'package:flutter/material.dart';
import 'package:larga/models/destination.dart';
import 'package:larga/services/destination_service.dart';
import 'package:larga/widgets/skeleton_widgets.dart';
import 'package:larga/screens/add_to_trip_sheet.dart';
import 'package:larga/screens/plan_trip_screen.dart';
import 'package:larga/screens/single_location_map_screen.dart';

class DestinationDetailScreen extends StatefulWidget {
  final String destinationId;
  final Destination? initialDestination;

  const DestinationDetailScreen({
    super.key,
    required this.destinationId,
    this.initialDestination,
  });

  @override
  State<DestinationDetailScreen> createState() => _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  final _destinationService = DestinationService();

  Destination? _destination;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _destination = widget.initialDestination;
    _loadDestination();
  }

  Future<void> _loadDestination() async {
    try {
      final destination = await _destinationService.getById(widget.destinationId);
      if (!mounted) return;
      setState(() {
        _destination = destination;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _navigateToPlanTrip() {
    if (_destination == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlanTripScreen(destination: _destination!),
      ),
    );
  }

  void _showAddToTripSheet() {
    if (_destination == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddToTripSheet(destination: _destination!),
    );
  }

  void _showTripOptions() {
    if (_destination == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.blue),
                ),
                title: const Text(
                  'Plan a Trip with AI',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Generate a personalized itinerary'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToPlanTrip();
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_location_alt, color: Colors.green),
                ),
                title: const Text(
                  'Add to Existing Trip',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Add this destination to a trip you\'re planning'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToTripSheet();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(DestinationCategory category) {
    return switch (category) {
      DestinationCategory.beach => Icons.beach_access,
      DestinationCategory.mountain => Icons.terrain,
      DestinationCategory.city => Icons.location_city,
      DestinationCategory.island => Icons.sailing,
      DestinationCategory.historicSite => Icons.account_balance,
      DestinationCategory.naturalWonder => Icons.landscape,
      DestinationCategory.park => Icons.park,
      DestinationCategory.resort => Icons.hotel,
      DestinationCategory.other => Icons.place,
    };
  }

  Color _getCategoryColor(DestinationCategory category) {
    return switch (category) {
      DestinationCategory.beach => Colors.blue,
      DestinationCategory.mountain => Colors.green,
      DestinationCategory.city => Colors.purple,
      DestinationCategory.island => Colors.teal,
      DestinationCategory.historicSite => Colors.orange,
      DestinationCategory.naturalWonder => Colors.amber,
      DestinationCategory.park => Colors.lightGreen,
      DestinationCategory.resort => Colors.pink,
      DestinationCategory.other => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading && _destination == null) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: ShimmerWrapper(child: Container(color: Colors.grey[300])),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerWrapper(child: SkeletonBox(width: 200, height: 32)),
                    const SizedBox(height: 8),
                    ShimmerWrapper(child: SkeletonBox(width: 150, height: 16)),
                    const SizedBox(height: 24),
                    ShimmerWrapper(child: SkeletonBox(width: double.infinity, height: 100)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_destination == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Destination not found')),
      );
    }

    final dest = _destination!;
    final categoryColor = _getCategoryColor(dest.category);
    final hasPhotos = dest.photos.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            backgroundColor: categoryColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasPhotos)
                    Image.network(
                      dest.photos.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(dest),
                    )
                  else
                    _buildPlaceholderImage(dest),
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
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: categoryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getCategoryIcon(dest.category),
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dest.category.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          dest.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                dest.fullLocation,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (dest.hasCoordinates)
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => SingleLocationMapScreen(
                          title: dest.name,
                          subtitle: dest.fullLocation,
                          latitude: dest.latitude!,
                          longitude: dest.longitude!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map),
                  tooltip: 'View on map',
                ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dest.averageRating != null || dest.reviewCount > 0) ...[
                    _buildRatingSection(dest),
                    const SizedBox(height: 24),
                  ],

                  if (dest.description != null && dest.description!.isNotEmpty) ...[
                    Text(
                      'About',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dest.description!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (dest.address != null && dest.address!.isNotEmpty) ...[
                    _buildInfoRow(
                      icon: Icons.location_on_outlined,
                      title: 'Address',
                      value: dest.address!,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (dest.tips != null && dest.tips!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildTipsSection(dest.tips!, theme),
                    const SizedBox(height: 24),
                  ],

                  if (dest.photos.length > 1) ...[
                    Text(
                      'Photos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: dest.photos.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 160,
                            margin: EdgeInsets.only(
                              right: index < dest.photos.length - 1 ? 12 : 0,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                dest.photos[index],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTripOptions,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Plan a Trip'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildPlaceholderImage(Destination dest) {
    final color = _getCategoryColor(dest.category);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.7)],
        ),
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(dest.category),
          size: 80,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildRatingSection(Destination dest) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (dest.averageRating != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.white, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    dest.averageRating!.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getRatingText(dest.averageRating),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (dest.reviewCount > 0)
                  Text(
                    '${dest.reviewCount} ${dest.reviewCount == 1 ? 'review' : 'reviews'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingText(double? rating) {
    if (rating == null) return 'Not rated yet';
    if (rating >= 4.5) return 'Exceptional';
    if (rating >= 4.0) return 'Excellent';
    if (rating >= 3.5) return 'Very Good';
    if (rating >= 3.0) return 'Good';
    if (rating >= 2.0) return 'Fair';
    return 'Poor';
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection(String tips, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Travel Tips',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tips,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
