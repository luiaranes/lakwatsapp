import 'package:flutter/material.dart';
import 'package:larga/models/destination.dart';
import 'package:larga/services/destination_service.dart';
import 'package:larga/screens/destination_detail_screen.dart';
import 'package:larga/screens/destinations_list_screen.dart';
import 'package:larga/widgets/skeleton_widgets.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _destinationService = DestinationService();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  List<Destination> _featured = [];
  List<Destination> _popular = [];
  List<Destination> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadDestinations();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDestinations() async {
    try {
      final results = await Future.wait([
        _destinationService.getFeatured(limit: 10),
        _destinationService.getPopular(limit: 10),
      ]);

      if (!mounted) return;
      setState(() {
        _featured = results[0];
        _popular = results[1];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    try {
      final results = await _destinationService.searchDestinations(query);
      if (!mounted) return;
      if (_searchController.text.trim() == query) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
  }

  void _onCategoryTap(DestinationCategory? category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DestinationsListScreen(
          category: category,
          title: category?.displayName ?? 'All Destinations',
        ),
      ),
    );
  }

  void _navigateToDestination(Destination destination) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DestinationDetailScreen(
          destinationId: destination.id,
          initialDestination: destination,
        ),
      ),
    );
  }

  void _navigateToSeeAll({required String title, required String mode}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DestinationsListScreen(
          title: title,
          mode: mode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSearchQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            toolbarHeight: 70,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Discover your next adventure',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search destinations...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                    suffixIcon: hasSearchQuery
                        ? IconButton(
                            onPressed: _clearSearch,
                            icon: Icon(Icons.clear, color: Colors.grey[500]),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (hasSearchQuery)
            _buildSearchResults()
          else ...[
            SliverToBoxAdapter(
              child: SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _CategoryChip(
                      icon: Icons.beach_access,
                      label: 'Beaches',
                      color: Colors.blue,
                      onTap: () => _onCategoryTap(DestinationCategory.beach),
                    ),
                    _CategoryChip(
                      icon: Icons.terrain,
                      label: 'Mountains',
                      color: Colors.green,
                      onTap: () => _onCategoryTap(DestinationCategory.mountain),
                    ),
                    _CategoryChip(
                      icon: Icons.location_city,
                      label: 'Cities',
                      color: Colors.purple,
                      onTap: () => _onCategoryTap(DestinationCategory.city),
                    ),
                    _CategoryChip(
                      icon: Icons.sailing,
                      label: 'Islands',
                      color: Colors.teal,
                      onTap: () => _onCategoryTap(DestinationCategory.island),
                    ),
                    _CategoryChip(
                      icon: Icons.park,
                      label: 'Parks',
                      color: Colors.lightGreen,
                      onTap: () => _onCategoryTap(DestinationCategory.park),
                    ),
                    _CategoryChip(
                      icon: Icons.account_balance,
                      label: 'Historic',
                      color: Colors.orange,
                      onTap: () => _onCategoryTap(DestinationCategory.historicSite),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Featured Destinations',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _navigateToSeeAll(
                        title: 'Featured Destinations',
                        mode: 'featured',
                      ),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: 280,
                child: _isLoading
                    ? _buildFeaturedSkeleton()
                    : _featured.isEmpty
                        ? _buildEmptyState('No featured destinations yet')
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _featured.length,
                            itemBuilder: (context, index) {
                              final dest = _featured[index];
                              return _DestinationCard(
                                destination: dest,
                                onTap: () => _navigateToDestination(dest),
                              );
                            },
                          ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Popular with Travelers',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _navigateToSeeAll(
                        title: 'Popular Destinations',
                        mode: 'popular',
                      ),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPopularSkeleton(),
                    childCount: 3,
                  ),
                ),
              )
            else if (_popular.isEmpty)
              SliverToBoxAdapter(
                child: _buildEmptyState('No popular destinations yet'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _popular.length) {
                        return const SizedBox(height: 100);
                      }
                      final dest = _popular[index];
                      return _PopularTile(
                        destination: dest,
                        onTap: () => _navigateToDestination(dest),
                      );
                    },
                    childCount: _popular.length + 1,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildPopularSkeleton(),
            childCount: 5,
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No destinations found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= _searchResults.length) {
              return const SizedBox(height: 100);
            }
            final dest = _searchResults[index];
            return _PopularTile(
              destination: dest,
              onTap: () => _navigateToDestination(dest),
            );
          },
          childCount: _searchResults.length + 1,
        ),
      ),
    );
  }

  Widget _buildFeaturedSkeleton() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return ShimmerWrapper(
          child: Container(
            width: 200,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopularSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ShimmerWrapper(
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.explore_off, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final Destination destination;
  final VoidCallback onTap;

  const _DestinationCard({
    required this.destination,
    required this.onTap,
  });

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

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(destination.category);
    final hasPhoto = destination.photos.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPhoto)
                Image.network(
                  destination.photos.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(color),
                )
              else
                _buildPlaceholder(color),
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getCategoryIcon(destination.category),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      destination.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            destination.fullLocation,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (destination.averageRating != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              destination.averageRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(Color color) {
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
          _getCategoryIcon(destination.category),
          size: 80,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _PopularTile extends StatelessWidget {
  final Destination destination;
  final VoidCallback onTap;

  const _PopularTile({
    required this.destination,
    required this.onTap,
  });

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

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(destination.category);
    final hasPhoto = destination.photos.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: hasPhoto ? null : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                image: hasPhoto
                    ? DecorationImage(
                        image: NetworkImage(destination.photos.first),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: hasPhoto
                  ? null
                  : Icon(
                      _getCategoryIcon(destination.category),
                      color: color,
                      size: 32,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.fullLocation,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (destination.averageRating != null)
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        destination.averageRating!.toStringAsFixed(1),
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else if (destination.reviewCount > 0)
                  Row(
                    children: [
                      Icon(Icons.people, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        '${destination.reviewCount}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
