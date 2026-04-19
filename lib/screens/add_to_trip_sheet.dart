import 'package:flutter/material.dart';
import 'package:larga/models/destination.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/services/trip_destination_service.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/widgets/skeleton_widgets.dart';
import 'package:intl/intl.dart';

class AddToTripSheet extends StatefulWidget {
  final Destination destination;

  const AddToTripSheet({
    super.key,
    required this.destination,
  });

  @override
  State<AddToTripSheet> createState() => _AddToTripSheetState();
}

class _AddToTripSheetState extends State<AddToTripSheet> {
  final _tripService = TripService();
  final _tripDestinationService = TripDestinationService();

  List<Trip> _trips = [];
  bool _isLoading = true;
  String? _selectedTripId;
  int? _selectedDay;
  bool _isAdding = false;
  Map<String, bool> _alreadyAdded = {};

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final trips = await _tripService.getUpcomingTrips();
      if (!mounted) return;

      final alreadyAdded = <String, bool>{};
      for (final trip in trips) {
        final isInTrip = await _tripDestinationService.isInTrip(
          trip.id,
          widget.destination.id,
        );
        alreadyAdded[trip.id] = isInTrip;
      }

      setState(() {
        _trips = trips;
        _alreadyAdded = alreadyAdded;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarUtils.showError(context, 'Failed to load trips');
    }
  }

  int _getTripDays(Trip trip) {
    if (trip.startDate == null || trip.endDate == null) return 0;
    return trip.endDate!.difference(trip.startDate!).inDays + 1;
  }

  Future<void> _addToTrip() async {
    if (_selectedTripId == null) {
      SnackBarUtils.showError(context, 'Please select a trip');
      return;
    }

    setState(() => _isAdding = true);

    try {
      await _tripDestinationService.addDestinationToTrip(
        tripId: _selectedTripId!,
        destinationId: widget.destination.id,
        dayNumber: _selectedDay,
        destinationName: widget.destination.name,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      SnackBarUtils.showSuccess(
        context,
        '${widget.destination.name} added to trip',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      SnackBarUtils.showError(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_location_alt, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add to Trip',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.destination.name,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: List.generate(
                  3,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ShimmerWrapper(
                      child: SkeletonBox(width: double.infinity, height: 80),
                    ),
                  ),
                ),
              ),
            )
          else if (_trips.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.luggage_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No upcoming trips',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a trip first to add destinations',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _trips.length,
                itemBuilder: (context, index) {
                  final trip = _trips[index];
                  final isAlreadyAdded = _alreadyAdded[trip.id] ?? false;
                  final isSelected = _selectedTripId == trip.id;

                  return _TripTile(
                    trip: trip,
                    isSelected: isSelected,
                    isAlreadyAdded: isAlreadyAdded,
                    onTap: isAlreadyAdded
                        ? null
                        : () {
                            setState(() {
                              _selectedTripId = trip.id;
                              _selectedDay = null;
                            });
                          },
                  );
                },
              ),
            ),
          if (_selectedTripId != null && !_isLoading) ...[
            const Divider(height: 1),
            _buildDaySelector(),
          ],
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedTripId == null || _isAdding ? null : _addToTrip,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isAdding
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add to Trip'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    final selectedTrip = _trips.firstWhere((t) => t.id == _selectedTripId);
    final tripDays = _getTripDays(selectedTrip);

    if (tripDays == 0) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Set trip dates to assign this destination to a specific day',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'Assign to day (optional)',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tripDays + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedDay == null;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Any day'),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedDay = null),
                  ),
                );
              }

              final dayNumber = index;
              final isSelected = _selectedDay == dayNumber;
              final date = selectedTrip.startDate?.add(Duration(days: dayNumber - 1));

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    date != null
                        ? 'Day $dayNumber (${DateFormat('MMM d').format(date)})'
                        : 'Day $dayNumber',
                  ),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedDay = dayNumber),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _TripTile extends StatelessWidget {
  final Trip trip;
  final bool isSelected;
  final bool isAlreadyAdded;
  final VoidCallback? onTap;

  const _TripTile({
    required this.trip,
    required this.isSelected,
    required this.isAlreadyAdded,
    this.onTap,
  });

  Color _getStatusColor(TripStatus status) {
    return switch (status) {
      TripStatus.planning => Colors.blue,
      TripStatus.ongoing => Colors.green,
      TripStatus.completed => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(trip.status);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.05) : null,
          border: Border(
            left: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: trip.coverImageUrl != null
                    ? null
                    : statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                image: trip.coverImageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(trip.coverImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: trip.coverImageUrl == null
                  ? Icon(Icons.luggage, color: statusColor)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isAlreadyAdded ? Colors.grey : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (trip.startDate != null)
                    Text(
                      trip.endDate != null
                          ? '${DateFormat('MMM d').format(trip.startDate!)} - ${DateFormat('MMM d, y').format(trip.endDate!)}'
                          : DateFormat('MMMM d, y').format(trip.startDate!),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    )
                  else
                    Text(
                      'No dates set',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            if (isAlreadyAdded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 14, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Added',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else if (isSelected)
              const Icon(Icons.check_circle, color: Colors.blue)
            else
              Icon(Icons.circle_outlined, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}
