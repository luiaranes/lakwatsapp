import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/booking.dart';
import 'package:larga/models/itinerary_item.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/trip_email_alias.dart';
import 'package:larga/services/booking_service.dart';
import 'package:larga/services/email_forwarding_service.dart';
import 'package:larga/services/itinerary_service.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/screens/add_edit_booking_screen.dart';
import 'package:larga/screens/booking_detail_screen.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/widgets/skeleton_widgets.dart';

class BookingsScreen extends StatefulWidget {
  final String tripId;
  final Trip? trip;

  const BookingsScreen({super.key, required this.tripId, this.trip});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _bookingService = BookingService();
  final _emailForwardingService = EmailForwardingService();
  final _tripService = TripService();
  final _itineraryService = ItineraryService();

  Trip? _trip;
  List<Booking> _bookings = [];
  Map<String, ItineraryItem> _itineraryItems = {};
  bool _isLoading = true;
  bool _canEdit = false;

  StreamSubscription<void>? _bookingsSubscription;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _loadData();
    _bookingsSubscription = _bookingService.subscribeToBookingsChanges(
      tripId: widget.tripId,
      onUpdate: () {
        if (mounted) _loadData();
      },
    );
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _bookingService.unsubscribeFromBookings(widget.tripId);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _tripService.getTripById(widget.tripId),
        _tripService.canEdit(widget.tripId),
        _bookingService.getBookings(widget.tripId),
        _itineraryService.getItineraryItems(widget.tripId),
      ]);

      if (!mounted) return;
      final itineraryItems = results[3] as List<ItineraryItem>;
      setState(() {
        _trip = results[0] as Trip?;
        _canEdit = results[1] as bool;
        _bookings = results[2] as List<Booking>;
        _itineraryItems = {for (final item in itineraryItems) item.id: item};
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarUtils.showError(context, 'Failed to load bookings');
    }
  }

  Future<void> _addBooking() async {
    final result = await Navigator.of(context).push<Booking>(
      MaterialPageRoute(
        builder: (context) => AddEditBookingScreen(
          tripId: widget.tripId,
          trip: _trip,
        ),
      ),
    );
    if (result != null) _loadData();
  }

  Future<void> _openBooking(Booking booking) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => BookingDetailScreen(
          booking: booking,
          trip: _trip,
        ),
      ),
    );
    if (deleted == true) _loadData();
  }

  Future<void> _showEmailForwardingDialog() async {
    try {
      final alias = await _emailForwardingService.getOrCreateTripEmailAlias(
        widget.tripId,
      );
      if (!mounted) return;
      await _presentEmailForwardingDialog(alias);
    } catch (_) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to load trip email address');
    }
  }

  Future<void> _presentEmailForwardingDialog(TripEmailAlias initialAlias) async {
    TripEmailAlias currentAlias = initialAlias;
    bool isRegenerating = false;
    final isOwner = _trip?.ownerId == _tripService.currentUserId;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Import Bookings by Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Forward flight or hotel confirmation emails to this address. We detect bookings and add them to this trip.',
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  currentAlias.emailAddress,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Same address as receipt forwarding. Booking emails are parsed first; receipts still work.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sender must be trip member. Booking dates must match trip window (+/- 30 days).',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isRegenerating ? null : () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: currentAlias.emailAddress),
                );
                if (context.mounted) {
                  SnackBarUtils.showSuccess(context, 'Email copied');
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy'),
            ),
            if (isOwner)
              FilledButton.icon(
                onPressed: isRegenerating
                    ? null
                    : () async {
                        setDialogState(() => isRegenerating = true);
                        try {
                          final regenerated = await _emailForwardingService
                              .regenerateTripEmailAlias(widget.tripId);
                          setDialogState(() {
                            currentAlias = regenerated;
                            isRegenerating = false;
                          });
                        } catch (_) {
                          setDialogState(() => isRegenerating = false);
                          if (context.mounted) {
                            SnackBarUtils.showError(
                              context,
                              'Failed to regenerate email',
                            );
                          }
                        }
                      },
                icon: isRegenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('Regenerate'),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitleFor(Booking booking) {
    final parts = <String>[];
    if (booking.confirmationNumber != null) {
      parts.add(booking.confirmationNumber!);
    }
    if (booking.startDate != null) {
      parts.add(DateFormat.yMMMd().format(booking.startDate!));
    }
    if (booking.itineraryItemId != null) {
      final item = _itineraryItems[booking.itineraryItemId!];
      if (item != null) parts.add('Day ${item.dayNumber}');
    }
    return parts.isEmpty ? booking.bookingType.displayName : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings'),
        actions: [
          IconButton(
            onPressed: _showEmailForwardingDialog,
            icon: const Icon(Icons.forward_to_inbox_outlined),
            tooltip: 'Email import',
          ),
        ],
      ),
      body: _isLoading
          ? const TripDetailSkeleton()
          : _bookings.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final booking = _bookings[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: Text(
                            booking.bookingType.icon,
                            style: const TextStyle(fontSize: 28),
                          ),
                          title: Text(
                            booking.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(_subtitleFor(booking)),
                          trailing: booking.formattedAmount != null
                              ? Text(
                                  booking.formattedAmount!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: () => _openBooking(booking),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: _addBooking,
              icon: const Icon(Icons.add),
              label: const Text('Add booking'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎫', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'No bookings yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add flight, hotel, or activity confirmations',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_canEdit) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _addBooking,
                icon: const Icon(Icons.add),
                label: const Text('Add booking'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _showEmailForwardingDialog,
                icon: const Icon(Icons.forward_to_inbox_outlined),
                label: const Text('Import from email'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
