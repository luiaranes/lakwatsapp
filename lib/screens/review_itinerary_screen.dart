import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/destination.dart';
import 'package:larga/models/trip_preferences.dart';
import 'package:larga/models/draft_itinerary.dart';
import 'package:larga/services/trip_planning_service.dart';
import 'package:larga/services/draft_itinerary_service.dart';
import 'package:larga/screens/trip_detail_screen.dart';
import 'package:larga/utils/snackbar_utils.dart';

class ReviewableActivity {
  final GeneratedActivity original;
  GeneratedActivity current;
  ActivityReviewStatus status;

  ReviewableActivity({
    required this.original,
    required this.current,
    this.status = ActivityReviewStatus.pending,
  });

  bool get isAccepted => status == ActivityReviewStatus.accepted || status == ActivityReviewStatus.edited;
}

class ReviewableDay {
  final GeneratedDay day;
  final List<ReviewableActivity> activities;
  bool isExpanded;

  ReviewableDay({
    required this.day,
    required this.activities,
    this.isExpanded = false,
  });

  int get acceptedCount => activities.where((a) => a.isAccepted).length;
  int get totalCount => activities.length;
  bool get allReviewed => activities.every((a) => a.status != ActivityReviewStatus.pending);
}

class ReviewItineraryScreen extends StatefulWidget {
  // For new itinerary generation
  final Destination? destination;
  final TripPreferences? preferences;
  final GeneratedItinerary? generatedItinerary;
  
  // For resuming from draft
  final String? draftId;

  const ReviewItineraryScreen({
    super.key,
    this.destination,
    this.preferences,
    this.generatedItinerary,
    this.draftId,
  }) : assert(
         (destination != null && preferences != null && generatedItinerary != null) ||
         draftId != null,
         'Either provide destination/preferences/generatedItinerary or draftId',
       );

  // Named constructor for new itinerary
  const ReviewItineraryScreen.fromGeneration({
    super.key,
    required Destination destination,
    required TripPreferences preferences,
    required GeneratedItinerary generatedItinerary,
  })  : this.destination = destination,
        this.preferences = preferences,
        this.generatedItinerary = generatedItinerary,
        draftId = null;

  // Named constructor for resuming draft
  const ReviewItineraryScreen.fromDraft({
    super.key,
    required String draftId,
  })  : this.draftId = draftId,
        destination = null,
        preferences = null,
        generatedItinerary = null;

  @override
  State<ReviewItineraryScreen> createState() => _ReviewItineraryScreenState();
}

class _ReviewItineraryScreenState extends State<ReviewItineraryScreen> {
  final _tripPlanningService = TripPlanningService();
  final _draftService = DraftItineraryService();
  
  List<ReviewableDay>? _days;
  bool _isLoading = true;
  bool _isSaving = false;
  String _savingStatus = '';
  String? _error;
  
  // These will be populated either from widget or from loaded draft
  late Destination _destination;
  late TripPreferences _preferences;
  late GeneratedItinerary _generatedItinerary;
  String? _draftId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.draftId != null) {
      // Resume from draft
      await _loadDraft(widget.draftId!);
    } else {
      // New generation - save as draft first
      _destination = widget.destination!;
      _preferences = widget.preferences!;
      _generatedItinerary = widget.generatedItinerary!;
      await _createDraft();
      _initializeDays();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDraft(String draftId) async {
    try {
      final draft = await _draftService.getDraft(draftId);
      if (draft == null) {
        setState(() {
          _error = 'Draft not found or expired';
          _isLoading = false;
        });
        return;
      }

      _draftId = draft.id;
      _destination = draft.destination ?? 
        Destination(
          id: draft.destinationId,
          name: 'Unknown Destination',
          description: '',
          city: '',
          province: '',
          country: 'Philippines',
          category: DestinationCategory.other,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      _preferences = draft.preferences;
      _generatedItinerary = draft.generatedItinerary;

      _initializeDays();

      // Restore review state
      for (final day in _days!) {
        final dayKey = 'day_${day.day.dayNumber}';
        final dayState = draft.reviewState[dayKey] ?? {};
        
        for (int i = 0; i < day.activities.length; i++) {
          final status = dayState[i];
          if (status != null) {
            day.activities[i].status = status;
          }

          // Restore edited activity if exists
          final editKey = '${dayKey}_$i';
          final editedActivity = draft.editedActivities[editKey];
          if (editedActivity != null) {
            day.activities[i].current = editedActivity;
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load draft: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _createDraft() async {
    try {
      final draft = await _draftService.createDraft(
        destination: _destination,
        preferences: _preferences,
        generatedItinerary: _generatedItinerary,
      );
      _draftId = draft.id;
    } catch (e) {
      // Non-critical - continue without draft persistence
      debugPrint('Failed to create draft: $e');
    }
  }

  void _initializeDays() {
    _days = _generatedItinerary.days.map((day) {
      return ReviewableDay(
        day: day,
        activities: day.activities.map((activity) {
          return ReviewableActivity(
            original: activity,
            current: activity,
            status: ActivityReviewStatus.pending,
          );
        }).toList(),
        isExpanded: day.dayNumber == 1,
      );
    }).toList();
  }

  Future<void> _saveReviewState() async {
    if (_draftId == null || _days == null) return;

    final reviewState = <String, Map<int, ActivityReviewStatus>>{};
    final editedActivities = <String, GeneratedActivity>{};

    for (final day in _days!) {
      final dayKey = 'day_${day.day.dayNumber}';
      reviewState[dayKey] = {};
      
      for (int i = 0; i < day.activities.length; i++) {
        final activity = day.activities[i];
        reviewState[dayKey]![i] = activity.status;
        
        if (activity.status == ActivityReviewStatus.edited) {
          editedActivities['${dayKey}_$i'] = activity.current;
        }
      }
    }

    try {
      await _draftService.updateReviewState(
        draftId: _draftId!,
        reviewState: reviewState,
        editedActivities: editedActivities,
      );
    } catch (e) {
      debugPrint('Failed to save review state: $e');
    }
  }

  int get _totalActivities {
    if (_days == null) return 0;
    return _days!.fold(0, (sum, d) => sum + d.totalCount);
  }
  
  int get _acceptedActivities {
    if (_days == null) return 0;
    return _days!.fold(0, (sum, d) => sum + d.acceptedCount);
  }
  
  int get _reviewedActivities {
    if (_days == null) return 0;
    return _days!.fold(0, (sum, d) => sum + d.activities.where((a) => a.status != ActivityReviewStatus.pending).length);
  }

  bool get _hasAcceptedActivities => _acceptedActivities > 0;
  bool get _allReviewed => _reviewedActivities == _totalActivities;

  void _acceptActivity(ReviewableDay day, ReviewableActivity activity) {
    setState(() {
      activity.status = ActivityReviewStatus.accepted;
    });
    _saveReviewState();
  }

  void _skipActivity(ReviewableDay day, ReviewableActivity activity) {
    setState(() {
      activity.status = ActivityReviewStatus.skipped;
    });
    _saveReviewState();
  }

  void _acceptAllInDay(ReviewableDay day) {
    setState(() {
      for (final activity in day.activities) {
        if (activity.status == ActivityReviewStatus.pending) {
          activity.status = ActivityReviewStatus.accepted;
        }
      }
    });
    _saveReviewState();
  }

  void _skipAllInDay(ReviewableDay day) {
    setState(() {
      for (final activity in day.activities) {
        if (activity.status == ActivityReviewStatus.pending) {
          activity.status = ActivityReviewStatus.skipped;
        }
      }
    });
    _saveReviewState();
  }

  void _acceptAll() {
    setState(() {
      for (final day in _days!) {
        for (final activity in day.activities) {
          if (activity.status == ActivityReviewStatus.pending) {
            activity.status = ActivityReviewStatus.accepted;
          }
        }
      }
    });
    _saveReviewState();
  }

  void _resetActivity(ReviewableActivity activity) {
    setState(() {
      activity.status = ActivityReviewStatus.pending;
      activity.current = activity.original;
    });
    _saveReviewState();
  }

  Future<void> _editActivity(ReviewableDay day, ReviewableActivity activity) async {
    final result = await showModalBottomSheet<GeneratedActivity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditActivitySheet(activity: activity.current),
    );

    if (result != null) {
      setState(() {
        activity.current = result;
        activity.status = ActivityReviewStatus.edited;
      });
      _saveReviewState();
    }
  }

  Future<void> _createTrip() async {
    if (!_hasAcceptedActivities) {
      SnackBarUtils.showError(context, 'Accept at least one activity to create the trip');
      return;
    }

    setState(() {
      _isSaving = true;
      _savingStatus = 'Creating your trip...';
    });

    try {
      final acceptedDays = <GeneratedDay>[];
      for (final day in _days!) {
        final acceptedActivities = day.activities
            .where((a) => a.isAccepted)
            .map((a) => a.current)
            .toList();
        if (acceptedActivities.isNotEmpty) {
          acceptedDays.add(GeneratedDay(
            dayNumber: day.day.dayNumber,
            date: day.day.date,
            theme: day.day.theme,
            activities: acceptedActivities,
          ));
        }
      }

      final filteredItinerary = GeneratedItinerary(
        tripTitle: _generatedItinerary.tripTitle,
        tripDescription: _generatedItinerary.tripDescription,
        estimatedTotalBudget: _generatedItinerary.estimatedTotalBudget,
        currency: _generatedItinerary.currency,
        days: acceptedDays,
        packingSuggestions: _generatedItinerary.packingSuggestions,
        travelTips: _generatedItinerary.travelTips,
      );

      setState(() => _savingStatus = 'Adding activities...');

      final trip = await _tripPlanningService.createTripFromItinerary(
        destination: _destination,
        preferences: _preferences,
        generatedItinerary: filteredItinerary,
      );

      // Delete the draft after successful trip creation
      if (_draftId != null) {
        await _draftService.deleteDraft(_draftId!);
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => TripDetailScreen(
            tripId: trip.id,
            initialTrip: trip,
          ),
        ),
        (route) => route.isFirst,
      );

      SnackBarUtils.showSuccess(context, 'Trip created with $_acceptedActivities activities!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      SnackBarUtils.showError(
        context,
        'Failed to create trip: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  Future<void> _discardDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Draft?'),
        content: const Text(
          'Are you sure you want to discard this itinerary draft? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (_draftId != null) {
        await _draftService.deleteDraft(_draftId!);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Color _getCategoryColor(String category) {
    return switch (category.toLowerCase()) {
      'transport' => Colors.blue,
      'accommodation' => Colors.purple,
      'food' => Colors.orange,
      'activity' => Colors.green,
      'sightseeing' => Colors.teal,
      'shopping' => Colors.pink,
      'rest' => Colors.grey,
      _ => Colors.blueGrey,
    };
  }

  IconData _getCategoryIcon(String category) {
    return switch (category.toLowerCase()) {
      'transport' => Icons.directions_car,
      'accommodation' => Icons.hotel,
      'food' => Icons.restaurant,
      'activity' => Icons.hiking,
      'sightseeing' => Icons.photo_camera,
      'shopping' => Icons.shopping_bag,
      'rest' => Icons.bed,
      _ => Icons.event,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Itinerary')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Itinerary')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSaving) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Creating Your Trip',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_savingStatus, style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Itinerary'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Just go back - draft is auto-saved
            Navigator.pop(context);
          },
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'accept_all') {
                _acceptAll();
              } else if (value == 'discard') {
                _discardDraft();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'accept_all',
                child: Row(
                  children: [
                    Icon(Icons.done_all),
                    SizedBox(width: 8),
                    Text('Accept All'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'discard',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Discard Draft', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressHeader(theme),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _days!.length,
              itemBuilder: (context, index) => _buildDayCard(_days![index], theme),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  Widget _buildProgressHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _generatedItinerary.tripTitle,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_preferences.tripDays} days in ${_destination.name}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _allReviewed ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$_reviewedActivities/$_totalActivities reviewed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: Colors.amber[700]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Your progress is auto-saved. You can leave and resume anytime.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _totalActivities > 0 ? _reviewedActivities / _totalActivities : 0,
              backgroundColor: Colors.grey[300],
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(ReviewableDay day, ThemeData theme) {
    final date = DateTime.tryParse(day.day.date);
    final dateStr = date != null ? DateFormat('EEE, MMM d').format(date) : 'Day ${day.day.dayNumber}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => day.isExpanded = !day.isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${day.day.dayNumber}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (day.day.theme != null)
                          Text(
                            day.day.theme!,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: day.allReviewed
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${day.acceptedCount}/${day.totalCount}',
                      style: TextStyle(
                        color: day.allReviewed ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    day.isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (day.isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _acceptAllInDay(day),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Accept All'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _skipAllInDay(day),
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: const Text('Skip All'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...day.activities.map((activity) => _buildActivityTile(day, activity, theme)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityTile(ReviewableDay day, ReviewableActivity activity, ThemeData theme) {
    final categoryColor = _getCategoryColor(activity.current.category);
    final isAccepted = activity.status == ActivityReviewStatus.accepted || activity.status == ActivityReviewStatus.edited;
    final isSkipped = activity.status == ActivityReviewStatus.skipped;
    final isPending = activity.status == ActivityReviewStatus.pending;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSkipped
            ? Colors.grey[100]
            : isAccepted
                ? Colors.green.withValues(alpha: 0.05)
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSkipped
              ? Colors.grey[300]!
              : isAccepted
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSkipped
                        ? Colors.grey[200]
                        : categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(activity.current.category),
                    color: isSkipped ? Colors.grey : categoryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            activity.current.startTime,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isSkipped ? Colors.grey : theme.primaryColor,
                            ),
                          ),
                          if (activity.current.endTime != null) ...[
                            Text(
                              ' - ${activity.current.endTime}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isSkipped ? Colors.grey : Colors.grey[600],
                              ),
                            ),
                          ],
                          if (activity.status == ActivityReviewStatus.edited)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Edited',
                                style: TextStyle(fontSize: 10, color: Colors.blue),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.current.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          decoration: isSkipped ? TextDecoration.lineThrough : null,
                          color: isSkipped ? Colors.grey : null,
                        ),
                      ),
                      if (activity.current.location != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                activity.current.location!,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (activity.current.estimatedCost != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '₱${activity.current.estimatedCost!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSkipped ? Colors.grey : Colors.green[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isAccepted)
                  const Icon(Icons.check_circle, color: Colors.green, size: 24)
                else if (isSkipped)
                  Icon(Icons.remove_circle, color: Colors.grey[400], size: 24),
              ],
            ),
          ),
          if (isPending || isSkipped || isAccepted)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  if (isPending) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _acceptActivity(day, activity),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _editActivity(day, activity),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                      child: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _skipActivity(day, activity),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey[400]!),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                      child: const Text('Skip'),
                    ),
                  ] else ...[
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _resetActivity(activity),
                        icon: const Icon(Icons.undo, size: 16),
                        label: const Text('Reset'),
                      ),
                    ),
                    if (!isSkipped)
                      TextButton.icon(
                        onPressed: () => _editActivity(day, activity),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_acceptedActivities activities selected',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (_generatedItinerary.estimatedTotalBudget > 0)
                  Text(
                    'Est. ₱${_generatedItinerary.estimatedTotalBudget.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _hasAcceptedActivities ? _createTrip : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_hasAcceptedActivities
                    ? 'Create Trip with $_acceptedActivities Activities'
                    : 'Accept at least one activity'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditActivitySheet extends StatefulWidget {
  final GeneratedActivity activity;

  const _EditActivitySheet({required this.activity});

  @override
  State<_EditActivitySheet> createState() => _EditActivitySheetState();
}

class _EditActivitySheetState extends State<_EditActivitySheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _costController;
  late TextEditingController _notesController;
  late String _category;

  final _categories = [
    'transport',
    'accommodation',
    'food',
    'activity',
    'sightseeing',
    'shopping',
    'rest',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.activity.title);
    _descriptionController = TextEditingController(text: widget.activity.description ?? '');
    _locationController = TextEditingController(text: widget.activity.location ?? '');
    _startTimeController = TextEditingController(text: widget.activity.startTime);
    _endTimeController = TextEditingController(text: widget.activity.endTime ?? '');
    _costController = TextEditingController(
      text: widget.activity.estimatedCost?.toStringAsFixed(0) ?? '',
    );
    _notesController = TextEditingController(text: widget.activity.notes ?? '');
    _category = widget.activity.category;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      SnackBarUtils.showError(context, 'Title is required');
      return;
    }

    final edited = GeneratedActivity(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      startTime: _startTimeController.text.trim().isEmpty ? '09:00' : _startTimeController.text.trim(),
      endTime: _endTimeController.text.trim().isEmpty ? null : _endTimeController.text.trim(),
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      category: _category,
      estimatedCost: double.tryParse(_costController.text),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    Navigator.pop(context, edited);
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Edit Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title *',
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
                          controller: _startTimeController,
                          decoration: InputDecoration(
                            labelText: 'Start Time',
                            hintText: 'e.g., 09:00',
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
                          controller: _endTimeController,
                          decoration: InputDecoration(
                            labelText: 'End Time',
                            hintText: 'e.g., 11:00',
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
                  TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _categories.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c[0].toUpperCase() + c.substring(1)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _costController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Estimated Cost',
                      prefixText: '₱ ',
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
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description',
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
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes',
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
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save & Accept'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
