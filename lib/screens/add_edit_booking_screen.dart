import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/booking.dart';
import 'package:larga/models/itinerary_item.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/services/booking_service.dart';
import 'package:larga/services/itinerary_service.dart';
import 'package:larga/utils/snackbar_utils.dart';

class AddEditBookingScreen extends StatefulWidget {
  final String tripId;
  final Booking? existingBooking;
  final Trip? trip;

  const AddEditBookingScreen({
    super.key,
    required this.tripId,
    this.existingBooking,
    this.trip,
  });

  @override
  State<AddEditBookingScreen> createState() => _AddEditBookingScreenState();
}

class _AddEditBookingScreenState extends State<AddEditBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bookingService = BookingService();
  final _itineraryService = ItineraryService();

  late final TextEditingController _titleController;
  late final TextEditingController _providerController;
  late final TextEditingController _confirmationController;
  late final TextEditingController _locationController;
  late final TextEditingController _addressController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late final TextEditingController _airlineController;
  late final TextEditingController _flightNumberController;
  late final TextEditingController _departureAirportController;
  late final TextEditingController _arrivalAirportController;

  BookingType _bookingType = BookingType.other;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedItineraryItemId;
  String _currency = 'PHP';
  bool _isSaving = false;
  bool _isLoadingItinerary = true;
  List<ItineraryItem> _itineraryItems = [];

  bool get _isEditing => widget.existingBooking != null;

  @override
  void initState() {
    super.initState();
    final booking = widget.existingBooking;
    _titleController = TextEditingController(text: booking?.title ?? '');
    _providerController = TextEditingController(text: booking?.provider ?? '');
    _confirmationController =
        TextEditingController(text: booking?.confirmationNumber ?? '');
    _locationController = TextEditingController(text: booking?.location ?? '');
    _addressController = TextEditingController(text: booking?.address ?? '');
    _startTimeController = TextEditingController(text: booking?.startTime ?? '');
    _endTimeController = TextEditingController(text: booking?.endTime ?? '');
    _amountController = TextEditingController(
      text: booking?.amount != null ? booking!.amount!.toStringAsFixed(2) : '',
    );
    _notesController = TextEditingController(text: booking?.notes ?? '');
    _airlineController =
        TextEditingController(text: booking?.detailAirline ?? '');
    _flightNumberController =
        TextEditingController(text: booking?.detailFlightNumber ?? '');
    _departureAirportController =
        TextEditingController(text: booking?.detailDepartureAirport ?? '');
    _arrivalAirportController =
        TextEditingController(text: booking?.detailArrivalAirport ?? '');

    _bookingType = booking?.bookingType ?? BookingType.other;
    _startDate = booking?.startDate;
    _endDate = booking?.endDate;
    _selectedItineraryItemId = booking?.itineraryItemId;
    _currency = booking?.currency ?? widget.trip?.currency ?? 'PHP';
    _loadItineraryItems();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _providerController.dispose();
    _confirmationController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _airlineController.dispose();
    _flightNumberController.dispose();
    _departureAirportController.dispose();
    _arrivalAirportController.dispose();
    super.dispose();
  }

  Future<void> _loadItineraryItems() async {
    try {
      final items = await _itineraryService.getItineraryItems(widget.tripId);
      if (!mounted) return;
      setState(() {
        _itineraryItems = items;
        _isLoadingItinerary = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingItinerary = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? widget.trip?.startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Map<String, dynamic> _buildDetails() {
    if (_bookingType == BookingType.flight) {
      return {
        'airline': _airlineController.text.trim().isEmpty
            ? null
            : _airlineController.text.trim(),
        'flight_number': _flightNumberController.text.trim().isEmpty
            ? null
            : _flightNumberController.text.trim(),
        'departure_airport': _departureAirportController.text.trim().isEmpty
            ? null
            : _departureAirportController.text.trim(),
        'arrival_airport': _arrivalAirportController.text.trim().isEmpty
            ? null
            : _arrivalAirportController.text.trim(),
      };
    }
    return widget.existingBooking?.details ?? {};
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amountText = _amountController.text.trim();
    final amount = amountText.isEmpty ? null : double.tryParse(amountText);
    if (amountText.isNotEmpty && amount == null) {
      SnackBarUtils.showError(context, 'Enter a valid amount');
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        final updated = widget.existingBooking!.copyWith(
          bookingType: _bookingType,
          title: _titleController.text,
          provider: _providerController.text.trim().isEmpty
              ? null
              : _providerController.text.trim(),
          confirmationNumber: _confirmationController.text.trim().isEmpty
              ? null
              : _confirmationController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          startTime: _startTimeController.text.trim().isEmpty
              ? null
              : _startTimeController.text.trim(),
          endTime: _endTimeController.text.trim().isEmpty
              ? null
              : _endTimeController.text.trim(),
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          amount: amount,
          currency: _currency,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          itineraryItemId: _selectedItineraryItemId,
          details: _buildDetails(),
          clearItineraryItemId: _selectedItineraryItemId == null,
        );
        final saved = await _bookingService.updateBooking(updated);
        if (!mounted) return;
        Navigator.pop(context, saved);
      } else {
        final saved = await _bookingService.createBooking(
          tripId: widget.tripId,
          title: _titleController.text.trim(),
          bookingType: _bookingType,
          provider: _providerController.text.trim().isEmpty
              ? null
              : _providerController.text.trim(),
          confirmationNumber: _confirmationController.text.trim().isEmpty
              ? null
              : _confirmationController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          startTime: _startTimeController.text.trim().isEmpty
              ? null
              : _startTimeController.text.trim(),
          endTime: _endTimeController.text.trim().isEmpty
              ? null
              : _endTimeController.text.trim(),
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          amount: amount,
          currency: _currency,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          itineraryItemId: _selectedItineraryItemId,
          details: _buildDetails(),
        );
        if (!mounted) return;
        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to save booking');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Booking' : 'Add Booking'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<BookingType>(
              value: _bookingType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: BookingType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text('${type.icon} ${type.displayName}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _bookingType = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Flight to Cebu, Hotel stay...',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _providerController,
              decoration: InputDecoration(
                labelText: _bookingType == BookingType.flight
                    ? 'Airline'
                    : _bookingType == BookingType.hotel
                        ? 'Hotel / Property'
                        : 'Provider',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmationController,
              decoration: const InputDecoration(
                labelText: 'Confirmation / PNR',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isStart: true),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _startDate == null
                          ? 'Start date'
                          : DateFormat.yMMMd().format(_startDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isStart: false),
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(
                      _endDate == null
                          ? 'End date'
                          : DateFormat.yMMMd().format(_endDate!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Start time',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _endTimeController,
                    decoration: const InputDecoration(
                      labelText: 'End time',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (_bookingType == BookingType.flight) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _flightNumberController,
                decoration: const InputDecoration(
                  labelText: 'Flight number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _departureAirportController,
                      decoration: const InputDecoration(
                        labelText: 'From',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _arrivalAirportController,
                      decoration: const InputDecoration(
                        labelText: 'To',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                    ),
                    items: const ['PHP', 'USD', 'EUR', 'SGD', 'THB', 'JPY']
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _currency = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingItinerary)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<String?>(
                value: _selectedItineraryItemId,
                decoration: const InputDecoration(
                  labelText: 'Link to itinerary activity',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ..._itineraryItems.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.id,
                      child: Text('Day ${item.dayNumber}: ${item.title}'),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedItineraryItemId = v),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
