import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/booking.dart';
import 'package:larga/models/itinerary_item.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/services/booking_service.dart';
import 'package:larga/services/itinerary_service.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/screens/add_edit_booking_screen.dart';
import 'package:larga/utils/snackbar_utils.dart';

class BookingDetailScreen extends StatefulWidget {
  final Booking booking;
  final Trip? trip;

  const BookingDetailScreen({
    super.key,
    required this.booking,
    this.trip,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final _bookingService = BookingService();
  final _itineraryService = ItineraryService();
  final _tripService = TripService();

  late Booking _booking;
  ItineraryItem? _linkedItineraryItem;
  bool _canEdit = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _tripService.canEdit(_booking.tripId),
        if (_booking.itineraryItemId != null)
          _itineraryService.getItemById(_booking.itineraryItemId!)
        else
          Future<ItineraryItem?>.value(null),
        _bookingService.getBookingById(_booking.id),
      ]);

      if (!mounted) return;
      setState(() {
        _canEdit = results[0] as bool;
        _linkedItineraryItem = results[1] as ItineraryItem?;
        final fresh = results[2] as Booking?;
        if (fresh != null) _booking = fresh;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context).push<Booking>(
      MaterialPageRoute(
        builder: (context) => AddEditBookingScreen(
          tripId: _booking.tripId,
          existingBooking: _booking,
          trip: widget.trip,
        ),
      ),
    );
    if (result != null) {
      setState(() => _booking = result);
      _load();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete booking?'),
        content: Text('Remove "${_booking.title}" from this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _bookingService.deleteBooking(_booking.id, _booking.tripId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to delete booking');
    }
  }

  Widget _detailRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String? _formatDateRange() {
    if (_booking.startDate == null && _booking.endDate == null) return null;
    final fmt = DateFormat.yMMMd();
    if (_booking.startDate != null && _booking.endDate != null) {
      if (_booking.startDate == _booking.endDate) {
        return fmt.format(_booking.startDate!);
      }
      return '${fmt.format(_booking.startDate!)} – ${fmt.format(_booking.endDate!)}';
    }
    return fmt.format(_booking.startDate ?? _booking.endDate!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking'),
        actions: [
          if (_canEdit) ...[
            IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
            IconButton(
              onPressed: _delete,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _booking.bookingType.icon,
                        style: const TextStyle(fontSize: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _booking.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _booking.bookingType.displayName,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            if (_booking.source == BookingSource.email) ...[
                              const SizedBox(height: 6),
                              Chip(
                                label: const Text('Imported from email'),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _detailRow('Provider', _booking.provider),
                _detailRow('Confirmation', _booking.confirmationNumber),
                _detailRow('Dates', _formatDateRange()),
                if (_booking.startTime != null || _booking.endTime != null)
                  _detailRow(
                    'Times',
                    [
                      if (_booking.startTime != null) _booking.startTime,
                      if (_booking.endTime != null) _booking.endTime,
                    ].whereType<String>().join(' – '),
                  ),
                _detailRow('Location', _booking.location),
                _detailRow('Address', _booking.address),
                if (_booking.bookingType == BookingType.flight) ...[
                  _detailRow('Airline', _booking.detailAirline),
                  _detailRow('Flight', _booking.detailFlightNumber),
                  _detailRow(
                    'Route',
                    [
                      _booking.detailDepartureAirport,
                      _booking.detailArrivalAirport,
                    ].whereType<String>().where((s) => s.isNotEmpty).join(' → '),
                  ),
                ],
                _detailRow('Amount', _booking.formattedAmount),
                if (_linkedItineraryItem != null)
                  _detailRow(
                    'Itinerary',
                    'Day ${_linkedItineraryItem!.dayNumber}: ${_linkedItineraryItem!.title}',
                  ),
                if (_booking.notes != null && _booking.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Notes',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(_booking.notes!),
                ],
              ],
            ),
    );
  }
}
