import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/expense.dart';
import 'package:larga/models/expense_split.dart';
import 'package:larga/models/itinerary_item.dart';
import 'package:larga/models/parsed_receipt.dart';
import 'package:larga/services/expense_service.dart';
import 'package:larga/services/expense_split_service.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/services/profile_service.dart';
import 'package:larga/services/itinerary_service.dart';
import 'package:larga/screens/scan_receipt_screen.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/widgets/expense_split_selector.dart';

class AddEditExpenseScreen extends StatefulWidget {
  final String tripId;
  final Expense? existingExpense;
  final Trip? trip;

  const AddEditExpenseScreen({
    super.key,
    required this.tripId,
    this.existingExpense,
    this.trip,
  });

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _expenseService = ExpenseService();
  final _expenseSplitService = ExpenseSplitService();
  final _tripService = TripService();
  final _profileService = ProfileService();
  final _itineraryService = ItineraryService();

  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  DateTime _selectedDate = DateTime.now();
  ExpenseCategory _selectedCategory = ExpenseCategory.other;
  String _selectedCurrency = 'PHP';
  String? _selectedPayerId;
  String? _selectedItineraryItemId;
  String? _receiptUrl;
  List<ExpenseLineItem>? _lineItems;
  bool _isSaving = false;
  bool _isLoadingMembers = true;
  bool _isLoadingItinerary = true;
  bool _isLoadingSplits = true;
  List<_MemberOption> _memberOptions = [];
  List<ItineraryItem> _itineraryItems = [];
  ExpenseSplitData? _splitData;
  List<ExpenseSplit>? _existingSplits;

  bool get _isEditing => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.existingExpense;

    _descriptionController = TextEditingController(text: expense?.description ?? '');
    _amountController = TextEditingController(
      text: expense?.amount.toStringAsFixed(2) ?? '',
    );
    _notesController = TextEditingController(text: expense?.notes ?? '');

    _selectedDate = expense?.expenseDate ?? DateTime.now();
    _selectedCategory = expense?.category ?? ExpenseCategory.other;
    _selectedCurrency = expense?.currency ?? widget.trip?.currency ?? 'PHP';
    _selectedPayerId = expense?.paidByUserId;
    _selectedItineraryItemId = expense?.itineraryItemId;
    _receiptUrl = expense?.receiptUrl;
    _lineItems = expense?.lineItems;

    _loadMembers();
    _loadItineraryItems();
    _loadExistingSplits();
  }

  Future<void> _loadExistingSplits() async {
    if (!_isEditing) {
      setState(() => _isLoadingSplits = false);
      return;
    }

    try {
      final splits = await _expenseSplitService.getSplitsForExpense(widget.existingExpense!.id);
      if (!mounted) return;

      if (splits.isNotEmpty) {
        final splitType = splits.first.splitType;
        final memberIds = splits.map((s) => s.userId).toList();
        Map<String, double>? percentages;
        Map<String, double>? amounts;

        if (splitType == SplitType.percentage) {
          percentages = {for (var s in splits) s.userId: s.percentage ?? 0};
        } else if (splitType == SplitType.exact) {
          amounts = {for (var s in splits) s.userId: s.amount};
        }

        setState(() {
          _existingSplits = splits;
          _splitData = ExpenseSplitData(
            splitType: splitType,
            memberIds: memberIds,
            percentages: percentages,
            amounts: amounts,
          );
          _isLoadingSplits = false;
        });
      } else {
        setState(() => _isLoadingSplits = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSplits = false);
    }
  }

  Future<void> _loadMembers() async {
    try {
      final members = await _tripService.getTripMembers(widget.tripId);
      final authIds = members.map((m) => m.userId).toList();
      final profiles = await _profileService.getProfilesByAuthIds(authIds);
      final profileMap = {for (var p in profiles) p.authId: p};

      final currentUserId = _tripService.currentUserId;
      final options = members.map((m) {
        final profile = profileMap[m.userId];
        return _MemberOption(
          userId: m.userId,
          displayName: profile?.displayName ?? 'Unknown',
          avatarUrl: profile?.avatarUrl,
          isCurrentUser: m.userId == currentUserId,
        );
      }).toList();

      // Sort: current user first, then alphabetically
      options.sort((a, b) {
        if (a.isCurrentUser) return -1;
        if (b.isCurrentUser) return 1;
        return a.displayName.compareTo(b.displayName);
      });

      if (!mounted) return;

      setState(() {
        _memberOptions = options;
        _isLoadingMembers = false;
        // Default to current user if not editing
        if (_selectedPayerId == null && options.isNotEmpty) {
          _selectedPayerId = options.firstWhere(
            (o) => o.isCurrentUser,
            orElse: () => options.first,
          ).userId;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _loadItineraryItems() async {
    try {
      final items = await _itineraryService.getItineraryItems(widget.tripId);
      // Sort by day number, then by sort order
      items.sort((a, b) {
        final dayCompare = a.dayNumber.compareTo(b.dayNumber);
        if (dayCompare != 0) return dayCompare;
        return a.sortOrder.compareTo(b.sortOrder);
      });

      if (!mounted) return;
      setState(() {
        _itineraryItems = items;
        _isLoadingItinerary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingItinerary = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  bool get _canScanReceipt {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS || Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  Future<void> _scanReceipt() async {
    final result = await Navigator.of(context).push<ParsedReceipt>(
      MaterialPageRoute(
        builder: (_) => ScanReceiptScreen(tripId: widget.tripId),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (result.hasValidAmount) {
        _amountController.text = result.amount!.toStringAsFixed(2);
      }
      if (result.hasValidMerchant) {
        _descriptionController.text = result.merchant!;
      }
      if (result.hasValidDate) {
        _selectedDate = result.date!;
      }
      if (result.suggestedCategory != null) {
        _selectedCategory = result.suggestedCategory!;
      }
      if (result.currency != null) {
        _selectedCurrency = result.currency!;
      }
      if (result.receiptUrl != null) {
        _receiptUrl = result.receiptUrl;
      }
      if (result.lineItems != null && result.lineItems!.isNotEmpty) {
        _lineItems = result.lineItems!
            .map((item) => ExpenseLineItem(
                  description: item.description,
                  quantity: item.quantity,
                  price: item.price,
                ))
            .toList();
      }
    });

    SnackBarUtils.showSuccess(context, 'Receipt scanned! Review and save.');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final amount = double.parse(_amountController.text.trim().replaceAll(',', ''));

      Expense result;

      if (_isEditing) {
        final original = widget.existingExpense!;
        
        result = await _expenseService.updateExpense(
          expenseId: original.id,
          amount: amount != original.amount ? amount : null,
          currency: _selectedCurrency != original.currency ? _selectedCurrency : null,
          category: _selectedCategory != original.category ? _selectedCategory : null,
          description: _descriptionController.text.trim() != original.description
              ? _descriptionController.text.trim()
              : null,
          expenseDate: !_isSameDate(_selectedDate, original.expenseDate)
              ? _selectedDate
              : null,
          paidByUserId: _selectedPayerId != original.paidByUserId
              ? _selectedPayerId
              : null,
          notes: _notesController.text.trim() != (original.notes ?? '')
              ? (_notesController.text.trim().isEmpty ? null : _notesController.text.trim())
              : null,
          clearNotes: _notesController.text.trim().isEmpty && original.notes != null,
          itineraryItemId: _selectedItineraryItemId != original.itineraryItemId
              ? _selectedItineraryItemId
              : null,
          clearItineraryItem: _selectedItineraryItemId == null && original.itineraryItemId != null,
        );

        await _saveSplits(result.id, amount);
      } else {
        result = await _expenseService.createExpense(
          tripId: widget.tripId,
          amount: amount,
          description: _descriptionController.text.trim(),
          expenseDate: _selectedDate,
          paidByUserId: _selectedPayerId,
          currency: _selectedCurrency,
          category: _selectedCategory,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          itineraryItemId: _selectedItineraryItemId,
          receiptUrl: _receiptUrl,
          lineItems: _lineItems,
        );

        await _saveSplits(result.id, amount);
      }

      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        _isEditing ? 'Expense updated!' : 'Expense added!',
      );
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      SnackBarUtils.showError(context, 'Failed to save expense');
    }
  }

  Future<void> _saveSplits(String expenseId, double amount) async {
    if (_splitData == null) {
      if (_existingSplits != null && _existingSplits!.isNotEmpty) {
        await _expenseSplitService.deleteSplitsForExpense(expenseId);
      }
      return;
    }

    await _expenseSplitService.updateSplits(
      expenseId: expenseId,
      totalAmount: amount,
      splitType: _splitData!.splitType,
      memberIds: _splitData!.memberIds,
      memberPercentages: _splitData!.percentages,
      memberAmounts: _splitData!.amounts,
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
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
            // Scan Receipt button (mobile only, not when editing)
            if (_canScanReceipt && !_isEditing) ...[
              _buildScanReceiptButton(theme),
              const SizedBox(height: 16),
            ],
            // Receipt preview if scanned
            if (_receiptUrl != null) ...[
              _buildReceiptPreview(theme),
              const SizedBox(height: 16),
            ],
            // Amount input with currency
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
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter amount';
                      }
                      final amount = double.tryParse(value.trim().replaceAll(',', ''));
                      if (amount == null || amount <= 0) {
                        return 'Invalid amount';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Lunch at Jollibee',
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Paid by selector
            Text(
              'Paid by',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildPayerSelector(),
            const SizedBox(height: 24),

            // Itinerary item selector (optional)
            Text(
              'Link to Itinerary (optional)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildItinerarySelector(),
            const SizedBox(height: 24),

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
              children: ExpenseCategory.values.map((category) {
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

            // Date picker
            Text(
              'Date',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (_isToday(_selectedDate))
                            Text(
                              'Today',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                              ),
                            ),
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

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Additional details about this expense',
                prefixIcon: Icon(Icons.note_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Expense Split
            if (!_isLoadingMembers && !_isLoadingSplits) ...[
              _buildSplitSection(),
              const SizedBox(height: 24),
            ],

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
              label: Text(_isEditing ? 'Save Changes' : 'Add Expense'),
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Color _getCategoryColor(ExpenseCategory category) {
    return switch (category) {
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

  Widget _buildScanReceiptButton(ThemeData theme) {
    return OutlinedButton.icon(
      onPressed: _scanReceipt,
      icon: const Icon(Icons.document_scanner_outlined),
      label: const Text('Scan Receipt'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildReceiptPreview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _receiptUrl!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: const Icon(Icons.receipt_long, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Receipt attached',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Data extracted from scan',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() => _receiptUrl = null);
            },
            icon: Icon(
              Icons.close,
              size: 20,
              color: Colors.grey[600],
            ),
            tooltip: 'Remove receipt',
          ),
        ],
      ),
    );
  }

  Widget _buildPayerSelector() {
    if (_isLoadingMembers) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading members...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_memberOptions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.person_outline, color: Colors.grey[400]),
            const SizedBox(width: 12),
            Text(
              'No members found',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final selectedMember = _memberOptions.firstWhere(
      (m) => m.userId == _selectedPayerId,
      orElse: () => _memberOptions.first,
    );

    return DropdownButtonFormField<String>(
      value: _selectedPayerId ?? selectedMember.userId,
      decoration: InputDecoration(
        prefixIcon: _buildAvatar(selectedMember, small: true),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      isExpanded: true,
      items: _memberOptions.map((member) {
        return DropdownMenuItem<String>(
          value: member.userId,
          child: Row(
            children: [
              _buildAvatar(member),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.isCurrentUser ? '${member.displayName} (You)' : member.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      selectedItemBuilder: (context) {
        return _memberOptions.map((member) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              member.isCurrentUser ? '${member.displayName} (You)' : member.displayName,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList();
      },
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedPayerId = value);
        }
      },
    );
  }

  Widget _buildItinerarySelector() {
    if (_isLoadingItinerary) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading itinerary...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_itineraryItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Icon(Icons.event_busy_outlined, color: Colors.grey[400]),
            const SizedBox(width: 12),
            Text(
              'No itinerary items available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Group items by day number
    final groupedItems = <int, List<ItineraryItem>>{};
    for (final item in _itineraryItems) {
      groupedItems.putIfAbsent(item.dayNumber, () => []).add(item);
    }

    return DropdownButtonFormField<String?>(
      value: _selectedItineraryItemId,
      decoration: InputDecoration(
        prefixIcon: Icon(
          _selectedItineraryItemId != null
              ? Icons.event_available_outlined
              : Icons.event_outlined,
          color: _selectedItineraryItemId != null
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        suffixIcon: _selectedItineraryItemId != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  setState(() => _selectedItineraryItemId = null);
                },
              )
            : null,
      ),
      isExpanded: true,
      hint: const Text('Select an itinerary item'),
      items: [
        ...groupedItems.entries.expand((entry) {
          final dayNumber = entry.key;
          final items = entry.value;
          return [
            DropdownMenuItem<String?>(
              enabled: false,
              value: null,
              child: Text(
                'Day $dayNumber',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ),
            ...items.map((item) {
              return DropdownMenuItem<String?>(
                value: item.id,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      Icon(
                        _getItineraryIcon(item.category),
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (item.startTime != null)
                              Text(
                                _formatTime(item.startTime!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ];
        }),
      ],
      selectedItemBuilder: (context) {
        final allItems = [
          null,
          ...groupedItems.values.expand((items) => items),
        ];
        return allItems.map((item) {
          if (item == null) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: Text('Select an itinerary item'),
            );
          }
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.title,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList();
      },
      onChanged: (value) {
        setState(() {
          _selectedItineraryItemId = value;
          // Update the expense date to match the itinerary item's date
          if (value != null) {
            final item = _itineraryItems.firstWhere(
              (i) => i.id == value,
              orElse: () => _itineraryItems.first,
            );
            final tripStartDate = widget.trip?.startDate;
            if (tripStartDate != null) {
              // Calculate date: trip start date + (dayNumber - 1)
              _selectedDate = tripStartDate.add(Duration(days: item.dayNumber - 1));
            }
          }
        });
      },
    );
  }

  IconData _getItineraryIcon(ItineraryCategory category) {
    return switch (category) {
      ItineraryCategory.transport => Icons.directions_car_outlined,
      ItineraryCategory.accommodation => Icons.hotel_outlined,
      ItineraryCategory.activity => Icons.attractions_outlined,
      ItineraryCategory.food => Icons.restaurant_outlined,
      ItineraryCategory.sightseeing => Icons.camera_alt_outlined,
      ItineraryCategory.shopping => Icons.shopping_bag_outlined,
      ItineraryCategory.rest => Icons.bed_outlined,
      ItineraryCategory.other => Icons.event_outlined,
    };
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dt = DateTime(2000, 1, 1, hour, minute);
      return DateFormat.jm().format(dt);
    } catch (_) {
      return time;
    }
  }

  Widget _buildAvatar(_MemberOption member, {bool small = false}) {
    final size = small ? 24.0 : 32.0;
    final fontSize = small ? 10.0 : 12.0;

    return CircleAvatar(
      radius: size / 2,
      backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
      backgroundColor: Colors.grey[300],
      child: member.avatarUrl == null
          ? Text(
              _getInitials(member.displayName),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            )
          : null,
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  Widget _buildSplitSection() {
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', '')) ?? 0;

    final splitMembers = _memberOptions.map((m) => SplitMember(
      userId: m.userId,
      displayName: m.displayName,
      avatarUrl: m.avatarUrl,
      isCurrentUser: m.isCurrentUser,
    )).toList();

    return ExpenseSplitSelector(
      members: splitMembers,
      totalAmount: amount,
      currency: _selectedCurrency,
      paidByUserId: _selectedPayerId,
      initialData: _splitData,
      onChanged: (data) {
        setState(() {
          _splitData = data;
        });
      },
    );
  }
}

class _MemberOption {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool isCurrentUser;

  _MemberOption({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.isCurrentUser = false,
  });
}
