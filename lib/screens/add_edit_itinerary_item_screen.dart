import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/itinerary_item.dart';
import 'package:larga/services/itinerary_service.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/widgets/lakwa_map_view.dart';
import 'package:larga/screens/single_location_map_screen.dart';

class AddEditItineraryItemScreen extends StatefulWidget {
  final String tripId;
  final int dayNumber;
  final ItineraryItem? existingItem;
  final Trip? trip;

  const AddEditItineraryItemScreen({
    super.key,
    required this.tripId,
    required this.dayNumber,
    this.existingItem,
    this.trip,
  });

  @override
  State<AddEditItineraryItemScreen> createState() => _AddEditItineraryItemScreenState();
}

class _AddEditItineraryItemScreenState extends State<AddEditItineraryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itineraryService = ItineraryService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;
  late TextEditingController _estimatedCostController;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  ItineraryCategory _selectedCategory = ItineraryCategory.activity;
  String _selectedCurrency = 'PHP';
  int _selectedDayNumber = 1;
  bool _isSaving = false;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;

    _titleController = TextEditingController(text: item?.title ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _locationController = TextEditingController(text: item?.location ?? '');
    _notesController = TextEditingController(text: item?.notes ?? '');
    _estimatedCostController = TextEditingController(
      text: item?.estimatedCost?.toStringAsFixed(0) ?? '',
    );

    _startTime = _parseTime(item?.startTime);
    _endTime = _parseTime(item?.endTime);
    _selectedCategory = item?.category ?? ItineraryCategory.activity;
    _selectedCurrency = item?.currency ?? 'PHP';
    _selectedDayNumber = item?.dayNumber ?? widget.dayNumber;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _estimatedCostController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? time) {
    if (time == null || time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String? _formatTimeForDb(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }

  String _formatTimeDisplay(TimeOfDay? time) {
    if (time == null) return 'Not set';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  Future<void> _pickTime(bool isStart) async {
    final initialTime = isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now());

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final cost = _estimatedCostController.text.trim().isNotEmpty
          ? double.tryParse(_estimatedCostController.text.trim())
          : null;

      ItineraryItem result;

      if (_isEditing) {
        final original = widget.existingItem!;
        final newTitle = _titleController.text.trim();
        final newDescription = _descriptionController.text.trim();
        final newLocation = _locationController.text.trim();
        final newNotes = _notesController.text.trim();
        final newStartTime = _formatTimeForDb(_startTime);
        final newEndTime = _formatTimeForDb(_endTime);

        // Only pass values that have actually changed
        result = await _itineraryService.updateItem(
          itemId: original.id,
          // Day number: only if changed
          dayNumber: _selectedDayNumber != original.dayNumber ? _selectedDayNumber : null,
          // Title: only if changed
          title: newTitle != original.title ? newTitle : null,
          // Description: only if changed
          description: newDescription != (original.description ?? '')
              ? (newDescription.isEmpty ? null : newDescription)
              : null,
          clearDescription: newDescription.isEmpty && original.description != null,
          // Start time: only if changed
          startTime: newStartTime != original.startTime ? newStartTime : null,
          clearStartTime: _startTime == null && original.startTime != null,
          // End time: only if changed
          endTime: newEndTime != original.endTime ? newEndTime : null,
          clearEndTime: _endTime == null && original.endTime != null,
          // Location: only if changed
          location: newLocation != (original.location ?? '')
              ? (newLocation.isEmpty ? null : newLocation)
              : null,
          clearLocation: newLocation.isEmpty && original.location != null,
          // Category: only if changed
          category: _selectedCategory != original.category ? _selectedCategory : null,
          // Estimated cost: only if changed
          estimatedCost: cost != original.estimatedCost ? cost : null,
          clearEstimatedCost: cost == null && original.estimatedCost != null,
          // Currency: only if changed (and cost is set)
          currency: (cost != null && _selectedCurrency != original.currency) ? _selectedCurrency : null,
          // Notes: only if changed
          notes: newNotes != (original.notes ?? '')
              ? (newNotes.isEmpty ? null : newNotes)
              : null,
          clearNotes: newNotes.isEmpty && original.notes != null,
        );
      } else {
        result = await _itineraryService.createItem(
          tripId: widget.tripId,
          dayNumber: _selectedDayNumber,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          startTime: _formatTimeForDb(_startTime),
          endTime: _formatTimeForDb(_endTime),
          location: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          category: _selectedCategory,
          estimatedCost: cost,
          currency: cost != null ? _selectedCurrency : null,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );
      }

      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        _isEditing ? 'Activity updated!' : 'Activity added!',
      );
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      SnackBarUtils.showError(context, 'Failed to save activity');
    }
  }

  String _getDayLabel(int dayNumber) {
    if (widget.trip?.startDate == null) {
      return 'Day $dayNumber';
    }
    final date = widget.trip!.startDate!.add(Duration(days: dayNumber - 1));
    return 'Day $dayNumber - ${DateFormat('EEE, MMM d').format(date)}';
  }

  int get _totalDays {
    if (widget.trip?.tripDurationDays != null && widget.trip!.tripDurationDays! > 0) {
      return widget.trip!.tripDurationDays!;
    }
    return widget.dayNumber.clamp(1, 365);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Activity' : 'Add Activity'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
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
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Activity Title',
                hintText: 'e.g., Visit Chocolate Hills',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category selection
            Text(
              'Category',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ItineraryCategory.values.map((category) {
                final isSelected = _selectedCategory == category;
                final color = _getCategoryColor(category);
                return FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(category.icon),
                      const SizedBox(width: 6),
                      Text(category.displayName),
                    ],
                  ),
                  selectedColor: color.withValues(alpha: 0.2),
                  checkmarkColor: color,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = category);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Day selection (if editing or trip has multiple days)
            if (_totalDays > 1) ...[
              Text(
                'Day',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedDayNumber.clamp(1, _totalDays),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                ),
                items: List.generate(
                  _totalDays,
                  (index) {
                    final dayNumber = index + 1;
                    return DropdownMenuItem(
                      value: dayNumber,
                      child: Text(_getDayLabel(dayNumber)),
                    );
                  },
                ),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDayNumber = value);
                  }
                },
              ),
              const SizedBox(height: 24),
            ],

            // Time pickers
            Text(
              'Time',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimePickerCard(
                    label: 'Start',
                    value: _formatTimeDisplay(_startTime),
                    hasValue: _startTime != null,
                    onTap: () => _pickTime(true),
                    onClear: _startTime != null
                        ? () => setState(() => _startTime = null)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePickerCard(
                    label: 'End',
                    value: _formatTimeDisplay(_endTime),
                    hasValue: _endTime != null,
                    onTap: () => _pickTime(false),
                    onClear: _endTime != null
                        ? () => setState(() => _endTime = null)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'e.g., Carmen, Bohol',
                prefixIcon: Icon(Icons.place_outlined),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Map preview when this activity was saved with coordinates (e.g. AI quick add)
            if (widget.existingItem != null && widget.existingItem!.hasLocation) ...[
              Text(
                'Map',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              LakwaMapView(
                height: 200,
                pins: [
                  LakwaMapMarker(
                    id: widget.existingItem!.id,
                    latitude: widget.existingItem!.latitude!,
                    longitude: widget.existingItem!.longitude!,
                    title: _titleController.text.trim().isEmpty
                        ? widget.existingItem!.title
                        : _titleController.text.trim(),
                    snippet: _locationController.text.trim().isEmpty
                        ? widget.existingItem!.location
                        : _locationController.text.trim(),
                  ),
                ],
                showMyLocation: true,
                initialZoom: 15,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final item = widget.existingItem!;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => SingleLocationMapScreen(
                          title: _titleController.text.trim().isEmpty
                              ? item.title
                              : _titleController.text.trim(),
                          subtitle: _locationController.text.trim().isEmpty
                              ? item.location
                              : _locationController.text.trim(),
                          latitude: item.latitude!,
                          longitude: item.longitude!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_full, size: 18),
                  label: const Text('Open full screen'),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Estimated cost
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'PHP', child: Text('₱')),
                      DropdownMenuItem(value: 'USD', child: Text('\$')),
                      DropdownMenuItem(value: 'EUR', child: Text('€')),
                      DropdownMenuItem(value: 'JPY', child: Text('¥')),
                      DropdownMenuItem(value: 'SGD', child: Text('S\$')),
                      DropdownMenuItem(value: 'THB', child: Text('฿')),
                      DropdownMenuItem(value: 'KRW', child: Text('₩')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCurrency = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _estimatedCostController,
                    decoration: const InputDecoration(
                      labelText: 'Estimated Cost (optional)',
                      hintText: '0',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add more details about this activity',
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Reminders, tips, or things to bring',
                prefixIcon: Icon(Icons.note_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            // Save button
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(_isEditing ? Icons.check : Icons.add),
              label: Text(_isEditing ? 'Save Changes' : 'Add Activity'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(ItineraryCategory category) {
    return switch (category) {
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
}

class _TimePickerCard extends StatelessWidget {
  final String label;
  final String value;
  final bool hasValue;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _TimePickerCard({
    required this.label,
    required this.value,
    required this.hasValue,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              color: hasValue ? Theme.of(context).colorScheme.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                      color: hasValue ? null : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.grey[400],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
