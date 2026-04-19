import 'package:flutter/material.dart';
import 'package:larga/models/destination.dart';
import 'package:larga/services/destination_service.dart';
import 'package:larga/screens/destination_detail_screen.dart';
import 'package:larga/widgets/skeleton_widgets.dart';

class DestinationsListScreen extends StatefulWidget {
  final String title;
  final DestinationCategory? category;
  final String? mode;

  const DestinationsListScreen({
    super.key,
    required this.title,
    this.category,
    this.mode,
  });

  @override
  State<DestinationsListScreen> createState() => _DestinationsListScreenState();
}

class _DestinationsListScreenState extends State<DestinationsListScreen> {
  final _destinationService = DestinationService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Destination> _destinations = [];
  List<String> _cities = [];
  List<String> _provinces = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _selectedCity;
  String? _selectedProvince;
  DestinationCategory? _selectedCategory;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
    _loadDestinations();
    _loadFilterOptions();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreDestinations();
    }
  }

  Future<void> _loadDestinations() async {
    setState(() => _isLoading = true);

    try {
      List<Destination> destinations;

      if (widget.mode == 'featured') {
        destinations = await _destinationService.getFeatured(limit: 50);
      } else if (widget.mode == 'popular') {
        destinations = await _destinationService.getPopular(limit: 50);
      } else {
        destinations = await _destinationService.getDestinations(
          searchQuery: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          category: _selectedCategory,
          city: _selectedCity,
          province: _selectedProvince,
          limit: 20,
          offset: 0,
        );
      }

      if (!mounted) return;
      setState(() {
        _destinations = destinations;
        _isLoading = false;
        _hasMore = destinations.length >= 20;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreDestinations() async {
    if (_isLoadingMore || !_hasMore || widget.mode != null) return;

    setState(() => _isLoadingMore = true);

    try {
      final destinations = await _destinationService.getDestinations(
        searchQuery: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        category: _selectedCategory,
        city: _selectedCity,
        province: _selectedProvince,
        limit: 20,
        offset: _destinations.length,
      );

      if (!mounted) return;
      setState(() {
        _destinations.addAll(destinations);
        _isLoadingMore = false;
        _hasMore = destinations.length >= 20;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      final results = await Future.wait([
        _destinationService.getCities(),
        _destinationService.getProvinces(),
      ]);

      if (!mounted) return;
      setState(() {
        _cities = results[0];
        _provinces = results[1];
      });
    } catch (e) {
      debugPrint('Failed to load filter options: $e');
    }
  }

  void _onSearchChanged() {
    _loadDestinations();
  }

  void _clearFilters() {
    setState(() {
      _selectedCity = null;
      _selectedProvince = null;
      _selectedCategory = widget.category;
      _searchController.clear();
    });
    _loadDestinations();
  }

  bool get _hasActiveFilters {
    return _selectedCity != null ||
        _selectedProvince != null ||
        (_selectedCategory != null && _selectedCategory != widget.category);
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.mode == null)
            IconButton(
              onPressed: () => setState(() => _showFilters = !_showFilters),
              icon: Badge(
                isLabelVisible: _hasActiveFilters,
                child: Icon(
                  _showFilters ? Icons.filter_list_off : Icons.filter_list,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.mode == null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _onSearchChanged(),
                  decoration: InputDecoration(
                    hintText: 'Search destinations...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged();
                            },
                            icon: Icon(Icons.clear, color: Colors.grey[500]),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            if (_showFilters) _buildFiltersSection(theme),
          ],
          Expanded(
            child: _isLoading
                ? _buildLoadingList()
                : _destinations.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadDestinations,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _destinations.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _destinations.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final dest = _destinations[index];
                            return _DestinationTile(
                              destination: dest,
                              onTap: () => _navigateToDestination(dest),
                              categoryColor: _getCategoryColor(dest.category),
                              categoryIcon: _getCategoryIcon(dest.category),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (_) {
                    setState(() => _selectedCategory = null);
                    _loadDestinations();
                  },
                ),
                const SizedBox(width: 8),
                ...DestinationCategory.values.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(
                        _getCategoryIcon(cat),
                        size: 16,
                        color: _selectedCategory == cat
                            ? Colors.white
                            : _getCategoryColor(cat),
                      ),
                      label: Text(cat.displayName),
                      selected: _selectedCategory == cat,
                      selectedColor: _getCategoryColor(cat),
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                        _loadDestinations();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedProvince,
                  decoration: InputDecoration(
                    labelText: 'Province',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Provinces'),
                    ),
                    ..._provinces.map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedProvince = value);
                    _loadDestinations();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCity,
                  decoration: InputDecoration(
                    labelText: 'City',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Cities'),
                    ),
                    ..._cities.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedCity = value);
                    _loadDestinations();
                  },
                ),
              ),
            ],
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return ShimmerWrapper(
          child: Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_off, size: 64, color: Colors.grey[300]),
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
            _hasActiveFilters
                ? 'Try adjusting your filters'
                : 'Check back later for new destinations',
            style: TextStyle(color: Colors.grey[500]),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  final Destination destination;
  final VoidCallback onTap;
  final Color categoryColor;
  final IconData categoryIcon;

  const _DestinationTile({
    required this.destination,
    required this.onTap,
    required this.categoryColor,
    required this.categoryIcon,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = destination.photos.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: hasPhoto ? null : categoryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
                image: hasPhoto
                    ? DecorationImage(
                        image: NetworkImage(destination.photos.first),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: hasPhoto
                  ? null
                  : Center(
                      child: Icon(
                        categoryIcon,
                        color: categoryColor,
                        size: 40,
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            destination.category.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: categoryColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (destination.averageRating != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                destination.averageRating!.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            destination.fullLocation,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
