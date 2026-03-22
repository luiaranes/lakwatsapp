import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/itinerary_item.dart';
import 'package:larga/services/itinerary_service.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/screens/add_edit_itinerary_item_screen.dart';
import 'package:larga/widgets/itinerary_item_card.dart';

class ItineraryScreen extends StatefulWidget {
  final String tripId;
  final Trip? trip;

  const ItineraryScreen({
    super.key,
    required this.tripId,
    this.trip,
  });

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  final _itineraryService = ItineraryService();
  final _tripService = TripService();

  Trip? _trip;
  Map<int, List<ItineraryItem>> _itemsByDay = {};
  bool _isLoading = true;
  bool _canEdit = false;
  int _totalDays = 1;
  int _currentDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _tripService.getTripById(widget.tripId),
        _tripService.canEdit(widget.tripId),
        _itineraryService.getItemsGroupedByDay(widget.tripId),
      ]);

      if (!mounted) return;

      final trip = results[0] as Trip?;
      final canEdit = results[1] as bool;
      final itemsByDay = results[2] as Map<int, List<ItineraryItem>>;

      // Calculate total days from trip dates or from existing items
      int totalDays = 1;
      if (trip?.tripDurationDays != null && trip!.tripDurationDays! > 0) {
        totalDays = trip.tripDurationDays!;
      } else if (itemsByDay.isNotEmpty) {
        totalDays = itemsByDay.keys.reduce((a, b) => a > b ? a : b);
      }

      // Ensure minimum of 1 day
      totalDays = totalDays.clamp(1, 365);

      setState(() {
        _trip = trip;
        _canEdit = canEdit;
        _itemsByDay = itemsByDay;
        _totalDays = totalDays;
        _currentDayIndex = _currentDayIndex.clamp(0, totalDays - 1);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarUtils.showError(context, 'Failed to load itinerary');
    }
  }

  Future<void> _addItem(int dayNumber) async {
    final result = await Navigator.of(context).push<ItineraryItem>(
      MaterialPageRoute(
        builder: (context) => AddEditItineraryItemScreen(
          tripId: widget.tripId,
          dayNumber: dayNumber,
          trip: _trip,
        ),
      ),
    );

    if (result != null) {
      _loadData();
    }
  }

  Future<void> _editItem(ItineraryItem item) async {
    final result = await Navigator.of(context).push<ItineraryItem>(
      MaterialPageRoute(
        builder: (context) => AddEditItineraryItemScreen(
          tripId: widget.tripId,
          dayNumber: item.dayNumber,
          existingItem: item,
          trip: _trip,
        ),
      ),
    );

    if (result != null) {
      _loadData();
    }
  }

  Future<void> _deleteItem(ItineraryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity'),
        content: Text('Are you sure you want to delete "${item.title}"?'),
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

    if (confirmed != true) return;

    try {
      await _itineraryService.deleteItem(item.id);
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'Activity deleted');
      _loadData();
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to delete activity');
    }
  }

  Future<void> _onReorder(int dayNumber, int oldIndex, int newIndex) async {
    final items = List<ItineraryItem>.from(_itemsByDay[dayNumber] ?? []);
    if (items.isEmpty) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // Update UI immediately
    setState(() {
      _itemsByDay[dayNumber] = items;
    });

    // Persist to database
    try {
      final orderedIds = items.map((i) => i.id).toList();
      await _itineraryService.reorderItems(widget.tripId, dayNumber, orderedIds);
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to reorder');
      _loadData();
    }
  }

  String _getDayTitle(int dayNumber) {
    if (_trip?.startDate == null) {
      return 'Day $dayNumber';
    }

    final date = _trip!.startDate!.add(Duration(days: dayNumber - 1));
    final format = DateFormat('EEEE, MMMM d');
    return 'Day $dayNumber • ${format.format(date)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_trip?.title ?? 'Itinerary'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: _totalDays,
      initialIndex: _currentDayIndex.clamp(0, _totalDays - 1),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_trip?.title ?? 'Itinerary'),
              bottom: TabBar(
                isScrollable: _totalDays > 4,
                tabAlignment: _totalDays > 4 ? TabAlignment.start : TabAlignment.fill,
                onTap: (index) {
                  _currentDayIndex = index;
                },
                tabs: List.generate(
                  _totalDays,
                  (index) {
                    final dayNumber = index + 1;
                    final itemCount = _itemsByDay[dayNumber]?.length ?? 0;
                    return Tab(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Day $dayNumber',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (itemCount > 0)
                            Text(
                              '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            body: TabBarView(
              children: List.generate(
                _totalDays,
                (index) => _buildDayView(index + 1),
              ),
            ),
            floatingActionButton: _canEdit
                ? FloatingActionButton.extended(
                    onPressed: () {
                      final currentDay = DefaultTabController.of(context).index + 1;
                      _addItem(currentDay);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Activity'),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildDayView(int dayNumber) {
    final items = _itemsByDay[dayNumber] ?? [];

    if (items.isEmpty) {
      return _buildEmptyDay(dayNumber);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _getDayTitle(dayNumber),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${items.length} ${items.length == 1 ? 'activity' : 'activities'}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Reorderable list
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            itemCount: items.length,
            onReorder: (oldIndex, newIndex) => _onReorder(dayNumber, oldIndex, newIndex),
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final double elevation = Tween<double>(begin: 0, end: 8)
                      .animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      ))
                      .value;
                  return Material(
                    elevation: elevation,
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  );
                },
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final item = items[index];
              return ItineraryItemCard(
                key: ValueKey(item.id),
                item: item,
                index: index,
                canEdit: _canEdit,
                onTap: () => _editItem(item),
                onDelete: () => _deleteItem(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDay(int dayNumber) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _getDayTitle(dayNumber),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No activities planned yet',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            if (_canEdit)
              FilledButton.icon(
                onPressed: () => _addItem(dayNumber),
                icon: const Icon(Icons.add),
                label: const Text('Add Activity'),
              ),
          ],
        ),
      ),
    );
  }
}
