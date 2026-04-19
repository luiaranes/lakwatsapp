import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/destination.dart';
import 'package:larga/models/trip_preferences.dart';
import 'package:larga/services/trip_planning_service.dart';
import 'package:larga/screens/review_itinerary_screen.dart';
import 'package:larga/utils/snackbar_utils.dart';

class PlanTripScreen extends StatefulWidget {
  final Destination destination;

  const PlanTripScreen({
    super.key,
    required this.destination,
  });

  @override
  State<PlanTripScreen> createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends State<PlanTripScreen> {
  final _tripPlanningService = TripPlanningService();
  final _pageController = PageController();
  final _specialRequestsController = TextEditingController();

  int _currentStep = 0;
  static const int _totalSteps = 6;

  // Step 1: Dates
  DateTime? _startDate;
  DateTime? _endDate;

  // Step 2: Travelers
  int _adults = 1;
  int _children = 0;
  int _infants = 0;

  // Step 3: Transportation & Bookings
  TransportMode _transportMode = TransportMode.publicTransport;
  bool _hasFlightBooking = false;
  final _airlineController = TextEditingController();
  final _flightNumberController = TextEditingController();
  final _departureTimeController = TextEditingController();
  final _arrivalTimeController = TextEditingController();
  bool _hasReturnFlight = false;
  final _returnDepartureTimeController = TextEditingController();
  final _returnArrivalTimeController = TextEditingController();
  bool _hasHotelBooking = false;
  final _hotelNameController = TextEditingController();
  final _hotelAddressController = TextEditingController();
  final _checkInTimeController = TextEditingController();
  final _checkOutTimeController = TextEditingController();

  // Step 4: Budget
  BudgetLevel _budgetLevel = BudgetLevel.moderate;
  final _specificBudgetController = TextEditingController();

  // Step 5: Style & Pace
  List<TravelStyle> _selectedStyles = [];
  TravelPace _pace = TravelPace.moderate;
  AccommodationType? _accommodation;

  // Step 6: Interests
  List<TravelInterest> _selectedInterests = [];

  // Generation state
  bool _isGenerating = false;
  String _generationStatus = '';

  @override
  void initState() {
    super.initState();
    // Default to tomorrow and 3 days later
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _startDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _endDate = _startDate!.add(const Duration(days: 2));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _specialRequestsController.dispose();
    _specificBudgetController.dispose();
    _airlineController.dispose();
    _flightNumberController.dispose();
    _departureTimeController.dispose();
    _arrivalTimeController.dispose();
    _returnDepartureTimeController.dispose();
    _returnArrivalTimeController.dispose();
    _hotelNameController.dispose();
    _hotelAddressController.dispose();
    _checkInTimeController.dispose();
    _checkOutTimeController.dispose();
    super.dispose();
  }

  int get _tripDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  bool get _canProceed {
    return switch (_currentStep) {
      0 => _startDate != null && _endDate != null && _tripDays >= 1 && _tripDays <= 14,
      1 => _adults >= 1,
      2 => true, // Transportation step - always can proceed
      3 => true, // Budget step
      4 => _selectedStyles.isNotEmpty,
      5 => true, // Interests step
      _ => false,
    };
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _generateTrip();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _generateTrip() async {
    if (_startDate == null || _endDate == null) return;

    FlightBooking? flightBooking;
    if (_hasFlightBooking && _transportMode == TransportMode.plane) {
      flightBooking = FlightBooking(
        airline: _airlineController.text.trim().isEmpty ? null : _airlineController.text.trim(),
        flightNumber: _flightNumberController.text.trim().isEmpty ? null : _flightNumberController.text.trim(),
        departureTime: _departureTimeController.text.trim().isEmpty ? null : _departureTimeController.text.trim(),
        arrivalTime: _arrivalTimeController.text.trim().isEmpty ? null : _arrivalTimeController.text.trim(),
      );
    }

    FlightBooking? returnFlightBooking;
    if (_hasFlightBooking && _hasReturnFlight && _transportMode == TransportMode.plane) {
      returnFlightBooking = FlightBooking(
        departureTime: _returnDepartureTimeController.text.trim().isEmpty ? null : _returnDepartureTimeController.text.trim(),
        arrivalTime: _returnArrivalTimeController.text.trim().isEmpty ? null : _returnArrivalTimeController.text.trim(),
      );
    }

    HotelBooking? hotelBooking;
    if (_hasHotelBooking) {
      hotelBooking = HotelBooking(
        hotelName: _hotelNameController.text.trim().isEmpty ? null : _hotelNameController.text.trim(),
        address: _hotelAddressController.text.trim().isEmpty ? null : _hotelAddressController.text.trim(),
        checkInTime: _checkInTimeController.text.trim().isEmpty ? null : _checkInTimeController.text.trim(),
        checkOutTime: _checkOutTimeController.text.trim().isEmpty ? null : _checkOutTimeController.text.trim(),
      );
    }

    final preferences = TripPreferences(
      startDate: _startDate!,
      endDate: _endDate!,
      adults: _adults,
      children: _children,
      infants: _infants,
      budgetLevel: _budgetLevel,
      specificBudget: double.tryParse(_specificBudgetController.text),
      currency: 'PHP',
      travelStyles: _selectedStyles,
      pace: _pace,
      interests: _selectedInterests,
      accommodation: _accommodation,
      specialRequests: _specialRequestsController.text.trim().isEmpty
          ? null
          : _specialRequestsController.text.trim(),
      transportMode: _transportMode,
      flightBooking: flightBooking,
      returnFlightBooking: returnFlightBooking,
      hasHotelBooking: _hasHotelBooking,
      hotelBooking: hotelBooking,
    );

    setState(() {
      _isGenerating = true;
      _generationStatus = 'Generating your personalized itinerary...';
    });

    try {
      final generatedItinerary = await _tripPlanningService.generateItinerary(
        destination: widget.destination,
        preferences: preferences,
      );

      if (!mounted) return;

      // Navigate to review screen instead of directly creating the trip
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ReviewItineraryScreen(
            destination: widget.destination,
            preferences: preferences,
            generatedItinerary: generatedItinerary,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      SnackBarUtils.showError(
        context,
        'Failed to generate itinerary: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked.add(const Duration(days: 2));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!.add(const Duration(days: 2)),
      firstDate: _startDate!,
      lastDate: _startDate!.add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Plan Trip to ${widget.destination.name}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.grey[200],
          ),
        ),
      ),
      body: _isGenerating
          ? _buildGeneratingView(theme)
          : Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildDatesStep(theme),
                      _buildTravelersStep(theme),
                      _buildTransportStep(theme),
                      _buildBudgetStep(theme),
                      _buildStyleStep(theme),
                      _buildInterestsStep(theme),
                    ],
                  ),
                ),
                _buildNavigationButtons(theme),
              ],
            ),
    );
  }

  Widget _buildGeneratingView(ThemeData theme) {
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
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Creating Your Trip',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _generationStatus,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a moment...',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatesStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            theme,
            icon: Icons.calendar_month,
            title: 'When are you traveling?',
            subtitle: 'Select your travel dates',
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildDateCard(
                  label: 'Start Date',
                  date: _startDate,
                  onTap: _selectStartDate,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateCard(
                  label: 'End Date',
                  date: _endDate,
                  onTap: _selectEndDate,
                ),
              ),
            ],
          ),
          if (_startDate != null && _endDate != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    '$_tripDays ${_tripDays == 1 ? 'day' : 'days'} trip',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_tripDays > 14) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Trips longer than 14 days are not supported yet.',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateCard({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null ? Colors.blue : Colors.grey[300]!,
            width: date != null ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              date != null
                  ? DateFormat('MMM d, y').format(date)
                  : 'Select date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: date != null ? Colors.black : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelersStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            theme,
            icon: Icons.people,
            title: 'Who\'s traveling?',
            subtitle: 'Tell us about your group',
          ),
          const SizedBox(height: 32),
          _buildTravelerCounter(
            label: 'Adults',
            subtitle: 'Age 13+',
            value: _adults,
            minValue: 1,
            onChanged: (v) => setState(() => _adults = v),
          ),
          const SizedBox(height: 16),
          _buildTravelerCounter(
            label: 'Children',
            subtitle: 'Age 2-12',
            value: _children,
            onChanged: (v) => setState(() => _children = v),
          ),
          const SizedBox(height: 16),
          _buildTravelerCounter(
            label: 'Infants',
            subtitle: 'Under 2',
            value: _infants,
            onChanged: (v) => setState(() => _infants = v),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.group, color: Colors.grey),
                const SizedBox(width: 12),
                Text(
                  'Total: ${_adults + _children + _infants} ${(_adults + _children + _infants) == 1 ? 'traveler' : 'travelers'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelerCounter({
    required String label,
    required String subtitle,
    required int value,
    int minValue = 0,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: value > minValue ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: value > minValue ? Colors.blue : Colors.grey[300],
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: value < 10 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: value < 10 ? Colors.blue : Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildTransportStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            theme,
            icon: Icons.directions_car,
            title: 'How are you getting there?',
            subtitle: 'Tell us about your transportation',
          ),
          const SizedBox(height: 24),
          ...TransportMode.values.map((mode) {
            final isSelected = _transportMode == mode;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => setState(() {
                  _transportMode = mode;
                  if (mode != TransportMode.plane) {
                    _hasFlightBooking = false;
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primaryColor.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? theme.primaryColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(mode.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              mode.description,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: theme.primaryColor),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Flight booking details
          if (_transportMode == TransportMode.plane) ...[
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('I have a flight booked'),
              subtitle: const Text('Add your flight details for a better itinerary'),
              value: _hasFlightBooking,
              onChanged: (v) => setState(() => _hasFlightBooking = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_hasFlightBooking) ...[
              const SizedBox(height: 16),
              Text(
                'Outbound Flight',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _airlineController,
                      decoration: InputDecoration(
                        labelText: 'Airline',
                        hintText: 'e.g., Cebu Pacific',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _flightNumberController,
                      decoration: InputDecoration(
                        labelText: 'Flight #',
                        hintText: 'e.g., 5J 123',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _departureTimeController,
                      decoration: InputDecoration(
                        labelText: 'Departure',
                        hintText: 'e.g., 8:00 AM',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _arrivalTimeController,
                      decoration: InputDecoration(
                        labelText: 'Arrival',
                        hintText: 'e.g., 9:30 AM',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('I have a return flight'),
                value: _hasReturnFlight,
                onChanged: (v) => setState(() => _hasReturnFlight = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (_hasReturnFlight) ...[
                const SizedBox(height: 12),
                Text(
                  'Return Flight',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _returnDepartureTimeController,
                        decoration: InputDecoration(
                          labelText: 'Departure',
                          hintText: 'e.g., 6:00 PM',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _returnArrivalTimeController,
                        decoration: InputDecoration(
                          labelText: 'Arrival',
                          hintText: 'e.g., 7:30 PM',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],

          // Hotel booking details
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('I already have a hotel booked'),
            subtitle: const Text('We won\'t suggest accommodation if you do'),
            value: _hasHotelBooking,
            onChanged: (v) => setState(() => _hasHotelBooking = v),
            contentPadding: EdgeInsets.zero,
          ),
          if (_hasHotelBooking) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _hotelNameController,
              decoration: InputDecoration(
                labelText: 'Hotel Name',
                hintText: 'e.g., Shangri-La Resort',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hotelAddressController,
              decoration: InputDecoration(
                labelText: 'Address (optional)',
                hintText: 'e.g., Station 1, Boracay',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _checkInTimeController,
                    decoration: InputDecoration(
                      labelText: 'Check-in',
                      hintText: 'e.g., 2:00 PM',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _checkOutTimeController,
                    decoration: InputDecoration(
                      labelText: 'Check-out',
                      hintText: 'e.g., 12:00 PM',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            theme,
            icon: Icons.account_balance_wallet,
            title: 'What\'s your budget?',
            subtitle: 'This helps us suggest appropriate activities',
          ),
          const SizedBox(height: 32),
          ...BudgetLevel.values.map((level) {
            final isSelected = _budgetLevel == level;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => setState(() => _budgetLevel = level),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primaryColor.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? theme.primaryColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(level.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              level.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              level.description,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: theme.primaryColor),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Text(
            'Specific budget per person (optional)',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _specificBudgetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'e.g., 15000',
              prefixText: '₱ ',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            theme,
            icon: Icons.style,
            title: 'How do you like to travel?',
            subtitle: 'Select your travel styles (pick at least one)',
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TravelStyle.values.map((style) {
              final isSelected = _selectedStyles.contains(style);
              return FilterChip(
                label: Text('${style.icon} ${style.displayName}'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedStyles.add(style);
                    } else {
                      _selectedStyles.remove(style);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Text(
            'Trip pace',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...TravelPace.values.map((pace) {
            final isSelected = _pace == pace;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => setState(() => _pace = pace),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primaryColor.withValues(alpha: 0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? theme.primaryColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Radio<TravelPace>(
                        value: pace,
                        groupValue: _pace,
                        onChanged: (v) => setState(() => _pace = v!),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pace.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              pace.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
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
          }),
          const SizedBox(height: 24),
          Text(
            'Accommodation preference (optional)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AccommodationType.values.map((type) {
              final isSelected = _accommodation == type;
              return FilterChip(
                label: Text('${type.icon} ${type.displayName}'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _accommodation = selected ? type : null;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            theme,
            icon: Icons.interests,
            title: 'What interests you?',
            subtitle: 'Select activities you\'d like to include',
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TravelInterest.values.map((interest) {
              final isSelected = _selectedInterests.contains(interest);
              return FilterChip(
                label: Text('${interest.icon} ${interest.displayName}'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedInterests.add(interest);
                    } else {
                      _selectedInterests.remove(interest);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Text(
            'Special requests (optional)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dietary restrictions, accessibility needs, must-visit places, etc.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _specialRequestsController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'e.g., "We\'re vegetarian", "Need wheelchair access", "Must visit Chocolate Hills"',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.primaryColor, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(ThemeData theme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: _currentStep > 0 ? 2 : 1,
              child: FilledButton(
                onPressed: _canProceed ? _nextStep : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentStep == _totalSteps - 1
                      ? 'Generate Itinerary'
                      : 'Continue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
