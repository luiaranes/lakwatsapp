import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/utils/snackbar_utils.dart';

class EditTripScreen extends StatefulWidget {
  final Trip trip;

  const EditTripScreen({super.key, required this.trip});

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tripService = TripService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _budgetController;

  DateTime? _startDate;
  DateTime? _endDate;
  late String _currency;
  late bool _isPublic;
  bool _isLoading = false;
  bool _hasChanges = false;

  final List<String> _currencies = ['PHP', 'USD', 'EUR', 'JPY', 'SGD', 'THB', 'KRW'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.trip.title);
    _descriptionController = TextEditingController(text: widget.trip.description ?? '');
    _budgetController = TextEditingController(
      text: widget.trip.budget?.toStringAsFixed(0) ?? '',
    );
    _startDate = widget.trip.startDate;
    _endDate = widget.trip.endDate;
    _currency = widget.trip.currency;
    _isPublic = widget.trip.isPublic;

    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _budgetController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final initialDateRange = DateTimeRange(
      start: _startDate ?? now,
      end: _endDate ?? now.add(const Duration(days: 3)),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDateRange: _startDate != null && _endDate != null ? initialDateRange : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _hasChanges = true;
      });
    }
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _hasChanges = true;
    });
  }

  String _formatDateRange() {
    if (_startDate == null || _endDate == null) {
      return 'Select dates';
    }
    final dateFormat = DateFormat('MMM d');
    final yearFormat = DateFormat('MMM d, yyyy');

    if (_startDate!.year == _endDate!.year) {
      return '${dateFormat.format(_startDate!)} - ${yearFormat.format(_endDate!)}';
    }
    return '${yearFormat.format(_startDate!)} - ${yearFormat.format(_endDate!)}';
  }

  int? get _tripDays {
    if (_startDate == null || _endDate == null) return null;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final original = widget.trip;
      
      // Parse current budget
      double? budget;
      if (_budgetController.text.isNotEmpty) {
        budget = double.tryParse(_budgetController.text.replaceAll(',', ''));
      }

      final newTitle = _titleController.text.trim();
      final newDescription = _descriptionController.text.trim();
      final originalDescription = original.description ?? '';

      // Only pass values that have actually changed
      final updatedTrip = await _tripService.updateTrip(
        tripId: original.id,
        // Title: only if changed
        title: newTitle != original.title ? newTitle : null,
        // Description: only if changed
        description: newDescription != originalDescription 
            ? (newDescription.isEmpty ? null : newDescription) 
            : null,
        clearDescription: newDescription.isEmpty && originalDescription.isNotEmpty,
        // Start date: only if changed
        startDate: _startDate != original.startDate ? _startDate : null,
        clearStartDate: _startDate == null && original.startDate != null,
        // End date: only if changed
        endDate: _endDate != original.endDate ? _endDate : null,
        clearEndDate: _endDate == null && original.endDate != null,
        // Budget: only if changed
        budget: budget != original.budget ? budget : null,
        clearBudget: budget == null && original.budget != null,
        // Currency: only if changed
        currency: _currency != original.currency ? _currency : null,
        // Public: only if changed
        isPublic: _isPublic != original.isPublic ? _isPublic : null,
      );

      if (!mounted) return;

      SnackBarUtils.showSuccess(context, 'Trip updated!');
      Navigator.of(context).pop(updatedTrip);
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to save changes: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Trip'),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (_hasChanges) {
                final shouldPop = await _onWillPop();
                if (shouldPop && context.mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _isLoading || !_hasChanges ? null : _saveChanges,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trip Title
                Text(
                  'Trip Name *',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g., Siargao Surfing Trip',
                    prefixIcon: const Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a trip name';
                    }
                    if (value.trim().length < 3) {
                      return 'Trip name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Description
                Text(
                  'Description',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'What\'s this trip about?',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 48),
                      child: Icon(Icons.notes_outlined),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Date Range
                Row(
                  children: [
                    Text(
                      'Travel Dates',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_startDate != null || _endDate != null)
                      TextButton(
                        onPressed: _clearDates,
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectDateRange,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDateRange(),
                                style: TextStyle(
                                  color: _startDate == null
                                      ? Colors.grey[500]
                                      : theme.textTheme.bodyLarge?.color,
                                  fontSize: 16,
                                ),
                              ),
                              if (_tripDays != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '$_tripDays ${_tripDays == 1 ? 'day' : 'days'}',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Budget Section
                Text(
                  'Budget',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Currency Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _currency,
                          items: _currencies.map((currency) {
                            return DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _currency = value;
                                _hasChanges = true;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Budget Input
                    Expanded(
                      child: TextFormField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final number = double.tryParse(value.replaceAll(',', ''));
                            if (number == null || number < 0) {
                              return 'Invalid amount';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Visibility
                Text(
                  'Visibility',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        value: false,
                        groupValue: _isPublic,
                        onChanged: (value) {
                          setState(() {
                            _isPublic = value!;
                            _hasChanges = true;
                          });
                        },
                        title: const Text('Private'),
                        subtitle: const Text('Only visible to trip members'),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                      ),
                      const Divider(height: 1),
                      RadioListTile<bool>(
                        value: true,
                        groupValue: _isPublic,
                        onChanged: (value) {
                          setState(() {
                            _isPublic = value!;
                            _hasChanges = true;
                          });
                        },
                        title: const Text('Public'),
                        subtitle: const Text('Anyone can view this trip'),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
