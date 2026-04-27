import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/trip_member.dart';
import 'package:larga/models/user_profile.dart';
import 'package:larga/models/itinerary_item.dart';
import 'package:larga/models/expense.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/services/storage_service.dart';
import 'package:larga/services/profile_service.dart';
import 'package:larga/services/itinerary_service.dart';
import 'package:larga/services/expense_service.dart';
import 'package:larga/services/currency_service.dart';
import 'package:larga/services/activity_log_service.dart';
import 'package:larga/services/trip_destination_service.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/screens/edit_trip_screen.dart';
import 'package:larga/screens/trip_members_screen.dart';
import 'package:larga/screens/invite_member_sheet.dart';
import 'package:larga/screens/itinerary_screen.dart';
import 'package:larga/screens/expenses_screen.dart';
import 'package:larga/screens/trip_map_screen.dart';
import 'package:larga/widgets/activity_log_list.dart';
import 'package:larga/widgets/skeleton_widgets.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  final Trip? initialTrip;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.initialTrip,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _tripService = TripService();
  final _storageService = StorageService();
  final _profileService = ProfileService();
  final _itineraryService = ItineraryService();
  final _expenseService = ExpenseService();
  final _currencyService = CurrencyService();
  final _activityLogService = ActivityLogService();
  final _tripDestinationService = TripDestinationService();

  Trip? _trip;
  bool _isLoading = true;
  bool _canEdit = false;
  bool _isOwner = false;
  bool _hasChanges = false;
  int _memberCount = 1;
  int _itineraryCount = 0;
  int _expenseCount = 0;
  double _totalExpenses = 0;
  List<ItineraryItem> _recentItineraryItems = [];
  List<Expense> _recentExpenses = [];
  List<_MemberPreview> _memberPreviews = [];
  Map<String, UserProfile> _expensePayerProfiles = {};
  Map<String, double>? _exchangeRates;
  double? _convertedTotalExpenses;
  List<TripDestinationWithDetails> _tripDestinations = const [];

  StreamSubscription<void>? _tripSubscription;
  StreamSubscription<void>? _membersSubscription;
  StreamSubscription<void>? _expensesSubscription;
  StreamSubscription<void>? _itinerarySubscription;
  StreamSubscription<void>? _activitySubscription;

  @override
  void initState() {
    super.initState();
    _trip = widget.initialTrip;
    _loadTrip();
    _setupRealtimeSubscriptions();
  }

  void _setupRealtimeSubscriptions() {
    _tripSubscription = _tripService.subscribeToTripChanges(
      tripId: widget.tripId,
      onUpdate: () {
        if (mounted) _loadTrip();
      },
    );

    _membersSubscription = _tripService.subscribeToTripMembersChanges(
      tripId: widget.tripId,
      onUpdate: () {
        if (mounted) _loadTrip();
      },
    );

    _expensesSubscription = _expenseService.subscribeToExpensesChanges(
      tripId: widget.tripId,
      onUpdate: () {
        if (mounted) _loadTrip();
      },
    );

    _itinerarySubscription = _itineraryService.subscribeToItineraryChanges(
      tripId: widget.tripId,
      onUpdate: () {
        if (mounted) _loadTrip();
      },
    );

    _activitySubscription = _activityLogService.subscribeToActivityLogChanges(
      tripId: widget.tripId,
      onUpdate: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _cleanupSubscriptions() {
    _tripSubscription?.cancel();
    _membersSubscription?.cancel();
    _expensesSubscription?.cancel();
    _itinerarySubscription?.cancel();
    _activitySubscription?.cancel();
    _tripService.unsubscribeFromTrip(widget.tripId);
    _tripService.unsubscribeFromTripMembers(widget.tripId);
    _expenseService.unsubscribeFromExpenses(widget.tripId);
    _itineraryService.unsubscribeFromItinerary(widget.tripId);
    _activityLogService.unsubscribeFromActivityLogs(widget.tripId);
  }

  @override
  void dispose() {
    _cleanupSubscriptions();
    super.dispose();
  }

  Future<void> _loadTrip() async {
    try {
      final results = await Future.wait([
        _tripService.getTripById(widget.tripId),
        _tripService.canEdit(widget.tripId),
        _tripService.isOwner(widget.tripId),
        _tripService.getTripMembers(widget.tripId),
        _itineraryService.getItineraryItems(widget.tripId),
        _expenseService.getExpenses(widget.tripId),
      ]);

      if (!mounted) return;

      final members = results[3] as List<TripMember>;
      final itineraryItems = results[4] as List<ItineraryItem>;
      final expenses = results[5] as List<Expense>;

      // Load member profiles for preview (up to 4)
      final previewMembers = members.take(4).toList();
      final memberAuthIds = previewMembers.map((m) => m.userId).toList();
      
      // Load expense payer profiles
      final expensePayerIds = expenses.map((e) => e.paidByUserId).toSet().toList();
      
      // Combine and dedupe auth IDs
      final allAuthIds = {...memberAuthIds, ...expensePayerIds}.toList();
      final profiles = await _profileService.getProfilesByAuthIds(allAuthIds);
      final profileMap = {for (var p in profiles) p.authId: p};

      var memberPreviews = previewMembers.map((m) {
        return _MemberPreview(
          member: m,
          profile: profileMap[m.userId],
        );
      }).toList();

      // Sort: owner first
      memberPreviews.sort((a, b) {
        if (a.member.isOwner) return -1;
        if (b.member.isOwner) return 1;
        return 0;
      });

      setState(() {
        _trip = results[0] as Trip?;
        _canEdit = results[1] as bool;
        _isOwner = results[2] as bool;
        _memberCount = members.length;
        _itineraryCount = itineraryItems.length;
        _recentItineraryItems = itineraryItems.take(3).toList();
        _expenseCount = expenses.length;
        _totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);
        _recentExpenses = expenses.take(3).toList();
        _memberPreviews = memberPreviews;
        _expensePayerProfiles = profileMap;
        _isLoading = false;
      });

      _loadExchangeRates(expenses);
      _loadTripDestinations();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarUtils.showError(context, 'Failed to load trip');
    }
  }

  Future<void> _loadExchangeRates(List<Expense> expenses) async {
    final tripCurrency = _trip?.currency ?? 'PHP';
    final currencies = expenses.map((e) => e.currency).toSet();
    
    // Only load rates if there are expenses in other currencies
    final hasDifferentCurrency = currencies.any((c) => c != tripCurrency);
    if (!hasDifferentCurrency) {
      // All expenses in trip currency, converted total equals raw total
      setState(() {
        _convertedTotalExpenses = _totalExpenses;
      });
      return;
    }

    try {
      final rates = await _currencyService.getExchangeRates(tripCurrency);
      if (rates != null && mounted) {
        // Calculate converted total
        double convertedTotal = 0;
        for (final expense in expenses) {
          if (expense.currency == tripCurrency) {
            convertedTotal += expense.amount;
          } else {
            final rate = rates[expense.currency];
            if (rate != null && rate > 0) {
              convertedTotal += expense.amount / rate;
            }
          }
        }
        
        setState(() {
          _exchangeRates = rates;
          _convertedTotalExpenses = convertedTotal;
        });
      }
    } catch (e) {
      // Silently fail - conversion is optional
    }
  }

  /// Trip destinations only feed the optional map; failures must not block trip UI.
  Future<void> _loadTripDestinations() async {
    try {
      final list = await _tripDestinationService.getTripDestinations(widget.tripId);
      if (!mounted) return;
      setState(() => _tripDestinations = list);
    } catch (e) {
      debugPrint('TripDetailScreen: trip destinations unavailable (map may be empty): $e');
      if (!mounted) return;
      setState(() => _tripDestinations = const []);
    }
  }

  Future<void> _uploadCoverImage() async {
    if (_trip == null || !_canEdit) return;

    try {
      final image = await _storageService.pickImageFromGallery();
      if (image == null) return;

      if (!mounted) return;
      SnackBarUtils.showInfo(context, 'Uploading cover image...');

      final coverUrl = await _storageService.uploadTripCover(_trip!.id, image);
      if (coverUrl == null) throw Exception('Upload failed');

      final updatedTrip = await _tripService.updateTrip(
        tripId: _trip!.id,
        coverImageUrl: coverUrl,
      );

      if (!mounted) return;
      setState(() {
        _trip = updatedTrip;
        _hasChanges = true;
      });
      SnackBarUtils.showSuccess(context, 'Cover image updated!');
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to upload image');
    }
  }

  Future<void> _updateStatus(TripStatus status) async {
    if (_trip == null || !_canEdit) return;

    try {
      final updatedTrip = await _tripService.updateTripStatus(_trip!.id, status);
      if (!mounted) return;
      setState(() {
        _trip = updatedTrip;
        _hasChanges = true;
      });
      SnackBarUtils.showSuccess(context, 'Status updated!');
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to update status');
    }
  }

  Future<void> _deleteTrip() async {
    if (_trip == null || !_isOwner) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: Text(
          'Are you sure you want to delete "${_trip!.title}"?\n\n'
          'This action cannot be undone. All itineraries, expenses, and member data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _tripService.deleteTrip(_trip!.id);
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'Trip deleted');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to delete trip');
    }
  }

  Future<void> _editTrip() async {
    if (_trip == null || !_canEdit) return;

    final updatedTrip = await Navigator.of(context).push<Trip>(
      MaterialPageRoute(
        builder: (context) => EditTripScreen(trip: _trip!),
      ),
    );

    if (updatedTrip != null && mounted) {
      setState(() {
        _trip = updatedTrip;
        _hasChanges = true;
      });
    }
  }

  String _formatDateRange(Trip trip) {
    if (trip.startDate == null || trip.endDate == null) {
      return 'Dates not set';
    }
    final dateFormat = DateFormat('MMM d');
    final yearFormat = DateFormat('MMM d, yyyy');

    if (trip.startDate!.year == trip.endDate!.year) {
      return '${dateFormat.format(trip.startDate!)} - ${yearFormat.format(trip.endDate!)}';
    }
    return '${yearFormat.format(trip.startDate!)} - ${yearFormat.format(trip.endDate!)}';
  }

  String _formatBudget(Trip trip) {
    if (trip.budget == null) return 'No budget set';
    final formatter = NumberFormat.currency(
      symbol: _getCurrencySymbol(trip.currency),
      decimalDigits: 0,
    );
    return formatter.format(trip.budget);
  }

  String _getCurrencySymbol(String currency) {
    return switch (currency) {
      'PHP' => '₱',
      'USD' => '\$',
      'EUR' => '€',
      'JPY' => '¥',
      'SGD' => 'S\$',
      'THB' => '฿',
      'KRW' => '₩',
      _ => currency,
    };
  }

  String _formatExpenseTotal() {
    // Use converted total if available, otherwise use raw total
    final total = _convertedTotalExpenses ?? _totalExpenses;
    if (total == 0) return '${_getCurrencySymbol(_trip?.currency ?? 'PHP')}0';
    final formatter = NumberFormat.compactCurrency(
      symbol: _getCurrencySymbol(_trip?.currency ?? 'PHP'),
      decimalDigits: 0,
    );
    return formatter.format(total);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show skeleton only when we don't have any trip data yet
    if (_isLoading && _trip == null) {
      return const TripDetailSkeleton();
    }

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Trip not found')),
      );
    }

    final daysUntil = _tripService.getDaysUntil(_trip!);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            stretch: true,
            backgroundColor: _getTripColor(),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).pop(_hasChanges),
            ),
            actions: [
              if (!_isLoading)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.map_outlined, color: Colors.white, size: 20),
                  ),
                  onPressed: _openTripMap,
                  tooltip: 'Trip map',
                ),
              if (_canEdit)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                  onPressed: _editTrip,
                ),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'change_cover':
                      _uploadCoverImage();
                      break;
                    case 'delete':
                      _deleteTrip();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (_canEdit)
                    const PopupMenuItem(
                      value: 'change_cover',
                      child: Row(
                        children: [
                          Icon(Icons.image_outlined),
                          SizedBox(width: 12),
                          Text('Change Cover'),
                        ],
                      ),
                    ),
                  if (_isOwner)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Delete Trip', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover Image or Gradient
                  if (_trip!.coverImageUrl != null)
                    Image.network(
                      key: ValueKey(_trip!.coverImageUrl),
                      _trip!.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildGradientCover(theme),
                    )
                  else
                    _buildGradientCover(theme),
                  // Gradient Overlay
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
                  // Status Badge & Days Until
                  Positioned(
                    top: 100,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        _StatusChip(status: _trip!.status, onTap: _canEdit ? _showStatusPicker : null),
                        const Spacer(),
                        if (daysUntil != null && daysUntil >= 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              daysUntil == 0 
                                  ? 'Today!' 
                                  : '$daysUntil day${daysUntil == 1 ? '' : 's'} away',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Title
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _trip!.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_trip!.startDate != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                _formatDateRange(_trip!),
                                style: const TextStyle(color: Colors.white70, fontSize: 15),
                              ),
                              if (_trip!.tripDurationDays != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_trip!.tripDurationDays} days',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                if (_trip!.description != null && _trip!.description!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _trip!.description!,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ),
                  const Divider(),
                ],

                // Quick Stats
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _StatCard(
                        icon: Icons.people_outline,
                        label: 'Members',
                        value: _isLoading ? '-' : '$_memberCount',
                        color: Colors.blue,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Budget',
                        value: _formatBudget(_trip!),
                        color: Colors.green,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.receipt_long_outlined,
                        label: 'Expenses',
                        value: _isLoading ? '-' : _formatExpenseTotal(),
                        color: Colors.orange,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Sections
                _buildSectionHeader(context, 'Itinerary', Icons.map_outlined),
                _buildItinerarySection(),

                _buildSectionHeader(context, 'Expenses', Icons.receipt_outlined),
                _buildExpensesSection(),

                _buildSectionHeader(context, 'Members', Icons.group_outlined),
                _buildMembersPreview(),

                _buildSectionHeader(context, 'Activity', Icons.history_outlined),
                _buildActivitySection(),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTripIcon() {
    if (_trip == null) return Icons.flight;
    final icons = [
      Icons.flight,
      Icons.beach_access,
      Icons.landscape,
      Icons.location_city,
      Icons.surfing,
      Icons.hiking,
      Icons.restaurant,
      Icons.attractions,
      Icons.directions_boat,
      Icons.forest,
    ];
    final hash = _trip!.id.hashCode.abs();
    return icons[hash % icons.length];
  }

  Color _getTripColor() {
    if (_trip == null) return Colors.blue;
    final colors = [
      const Color(0xFF1E88E5), // Blue
      const Color(0xFF43A047), // Green
      const Color(0xFF8E24AA), // Purple
      const Color(0xFFFF7043), // Deep Orange
      const Color(0xFF00ACC1), // Cyan
      const Color(0xFFE91E63), // Pink
      const Color(0xFF5C6BC0), // Indigo
      const Color(0xFF26A69A), // Teal
      const Color(0xFFFF5722), // Orange
      const Color(0xFF7B1FA2), // Deep Purple
    ];
    final hash = _trip!.id.hashCode.abs();
    return colors[hash % colors.length];
  }

  Widget _buildGradientCover(ThemeData theme) {
    final tripColor = _getTripColor();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tripColor,
            tripColor.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _getTripIcon(),
          size: 80,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openItinerary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ItineraryScreen(
          tripId: widget.tripId,
          trip: _trip,
        ),
      ),
    );
    _loadTrip();
  }

  Future<void> _openExpenses() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpensesScreen(
          tripId: widget.tripId,
          trip: _trip,
        ),
      ),
    );
    _loadTrip();
  }

  Future<void> _openTripMap() async {
    if (_trip == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => TripMapScreen(
          tripTitle: _trip!.title,
          destinations: _tripDestinations,
        ),
      ),
    );
  }

  Widget _buildItinerarySection() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const SizedBox(width: 24, height: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 180,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
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

    if (_itineraryCount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InkWell(
          onTap: _openItinerary,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add_location_alt_outlined, color: Colors.blue[600]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No itinerary yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add activities and places to visit',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: _openItinerary,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              // Preview items
              ...List.generate(
                _recentItineraryItems.length,
                (index) {
                  final item = _recentItineraryItems[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < _recentItineraryItems.length - 1 ? 12 : 0,
                    ),
                    child: _ItineraryItemPreview(item: item),
                  );
                },
              ),
              if (_itineraryCount > 3) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View all $_itineraryCount activities',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesSection() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const SizedBox(width: 24, height: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 180,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
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

    if (_expenseCount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InkWell(
          onTap: _openExpenses,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add_card_outlined, color: Colors.orange[600]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No expenses yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track your trip spending',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: _openExpenses,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              // Preview items
              ...List.generate(
                _recentExpenses.length,
                (index) {
                  final expense = _recentExpenses[index];
                  final payerProfile = _expensePayerProfiles[expense.paidByUserId];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < _recentExpenses.length - 1 ? 12 : 0,
                    ),
                    child: _ExpenseItemPreview(
                      expense: expense,
                      payerProfile: payerProfile,
                      currentUserId: _tripService.currentUserId,
                      tripCurrency: _trip?.currency ?? 'PHP',
                      exchangeRates: _exchangeRates,
                    ),
                  );
                },
              ),
              if (_expenseCount > 3) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View all $_expenseCount expenses',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMembersScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => TripMembersScreen(
          tripId: widget.tripId,
          trip: _trip,
        ),
      ),
    );

    // If user left or trip was deleted, pop back to trips list
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    } else {
      // Reload trip data in case members changed
      _loadTrip();
    }
  }

  Future<void> _inviteMember() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => InviteMemberSheet(tripId: widget.tripId),
    );

    if (result == true) {
      _loadTrip();
    }
  }

  Widget _buildMembersPreview() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 140,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
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

    final displayCount = _memberPreviews.isNotEmpty 
        ? _memberPreviews.length.clamp(1, 4) 
        : 1;
    final hasMembers = _memberPreviews.isNotEmpty;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: _openMembersScreen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              // Member avatars
              if (hasMembers)
                SizedBox(
                  width: (displayCount - 1) * 20.0 + 36,
                  height: 36,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: List.generate(
                      displayCount,
                      (i) {
                        final preview = _memberPreviews[i];
                        return Positioned(
                          left: i * 20.0,
                          child: _MemberAvatar(
                            avatarUrl: preview.profile?.avatarUrl,
                            displayName: preview.profile?.displayName,
                            isOwner: preview.member.isOwner,
                          ),
                        );
                      },
                    ),
                  ),
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.group_outlined,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_memberCount.clamp(1, 999)} member${_memberCount <= 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _memberCount <= 1
                          ? 'Invite friends to join'
                          : _getMemberNames(),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_canEdit) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _inviteMember,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Invite'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ] else
                Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  String _getMemberNames() {
    if (_memberPreviews.isEmpty) return 'Invite friends to join';
    
    final names = _memberPreviews
        .take(2)
        .map((m) => m.profile?.displayName?.split(' ').first ?? 'Member')
        .toList();
    
    if (_memberCount > 2) {
      return '${names.join(', ')} +${_memberCount - 2} more';
    }
    return names.join(', ');
  }

  void _openActivityLog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ActivityLogScreen(
          tripId: widget.tripId,
          tripTitle: _trip?.title,
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            ActivityLogList(
              tripId: widget.tripId,
              maxItems: 5,
              showHeader: false,
              onViewAll: _openActivityLog,
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Change Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ...TripStatus.values.map((status) => ListTile(
              leading: Icon(_getStatusIcon(status)),
              title: Text(_getStatusLabel(status)),
              trailing: _trip!.status == status 
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _updateStatus(status);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(TripStatus status) {
    return switch (status) {
      TripStatus.planning => Icons.edit_note,
      TripStatus.ongoing => Icons.flight_takeoff,
      TripStatus.completed => Icons.check_circle,
    };
  }

  String _getStatusLabel(TripStatus status) {
    return switch (status) {
      TripStatus.planning => 'Planning',
      TripStatus.ongoing => 'Ongoing',
      TripStatus.completed => 'Completed',
    };
  }
}

class _StatusChip extends StatelessWidget {
  final TripStatus status;
  final VoidCallback? onTap;

  const _StatusChip({required this.status, this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (status) {
      TripStatus.planning => ('Planning', Icons.edit_note),
      TripStatus.ongoing => ('Ongoing', Icons.flight_takeoff),
      TripStatus.completed => ('Completed', Icons.check_circle),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isLoading;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            isLoading
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberPreview {
  final TripMember member;
  final UserProfile? profile;

  _MemberPreview({required this.member, this.profile});
}

class _MemberAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? displayName;
  final bool isOwner;

  const _MemberAvatar({
    this.avatarUrl,
    this.displayName,
    this.isOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isOwner ? Colors.amber : Colors.white,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 16,
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
        backgroundColor: Colors.grey[300],
        child: avatarUrl == null
            ? Text(
                _getInitials(displayName),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
            : null,
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}

class _ItineraryItemPreview extends StatelessWidget {
  final ItineraryItem item;

  const _ItineraryItemPreview({required this.item});

  Color _getCategoryColor() {
    return switch (item.category) {
      ItineraryCategory.transport => Colors.blue,
      ItineraryCategory.accommodation => Colors.purple,
      ItineraryCategory.food => Colors.orange,
      ItineraryCategory.activity => Colors.green,
      ItineraryCategory.sightseeing => Colors.pink,
      ItineraryCategory.shopping => Colors.teal,
      ItineraryCategory.rest => Colors.indigo,
      ItineraryCategory.other => Colors.grey,
    };
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.length < 2) return time;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor();

    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          item.category.icon,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Wrap(
                spacing: 0,
                children: [
                  Text(
                    'Day ${item.dayNumber}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (item.startTime != null) ...[
                    Text(
                      ' • ',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    Text(
                      _formatTime(item.startTime),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpenseItemPreview extends StatelessWidget {
  final Expense expense;
  final UserProfile? payerProfile;
  final String? currentUserId;
  final String tripCurrency;
  final Map<String, double>? exchangeRates;

  const _ExpenseItemPreview({
    required this.expense,
    this.payerProfile,
    this.currentUserId,
    required this.tripCurrency,
    this.exchangeRates,
  });

  Color _getCategoryColor() {
    return switch (expense.category) {
      ExpenseCategory.transport => Colors.blue,
      ExpenseCategory.accommodation => Colors.purple,
      ExpenseCategory.food => Colors.orange,
      ExpenseCategory.activities => Colors.teal,
      ExpenseCategory.shopping => Colors.pink,
      ExpenseCategory.fees => Colors.indigo,
      ExpenseCategory.tips => Colors.green,
      ExpenseCategory.other => Colors.grey,
    };
  }

  String _formatCurrency(double amount, String currency) {
    final symbol = switch (currency) {
      'PHP' => '₱',
      'USD' => '\$',
      'EUR' => '€',
      'JPY' => '¥',
      'SGD' => 'S\$',
      'THB' => '฿',
      'KRW' => '₩',
      _ => currency,
    };
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  String _getPayerText() {
    if (expense.paidByUserId == currentUserId) {
      return 'You paid';
    }
    final firstName = payerProfile?.displayName?.split(' ').first ?? 'Someone';
    return '$firstName paid';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor();

    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          expense.category.icon,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expense.description,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Text(
                    expense.category.displayName,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    ' • ',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  Flexible(
                    child: Text(
                      _getPayerText(),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatCurrency(expense.amount, expense.currency),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            // Show converted amount if expense is in different currency
            if (expense.currency != tripCurrency &&
                exchangeRates != null &&
                exchangeRates!.containsKey(expense.currency))
              Builder(builder: (context) {
                final rate = exchangeRates![expense.currency]!;
                final convertedAmount = rate > 0 ? expense.amount / rate : 0.0;
                return Text(
                  '≈ ${_formatCurrency(convertedAmount, tripCurrency)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }
}
