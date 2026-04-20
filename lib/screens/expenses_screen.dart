import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/expense.dart';
import 'package:larga/models/expense_split.dart';
import 'package:larga/models/user_profile.dart';
import 'package:larga/models/itinerary_item.dart';
import 'package:larga/services/expense_service.dart';
import 'package:larga/services/expense_split_service.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/services/profile_service.dart';
import 'package:larga/services/itinerary_service.dart';
import 'package:larga/services/currency_service.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/screens/add_edit_expense_screen.dart';
import 'package:larga/screens/expense_balances_screen.dart';
import 'package:larga/screens/quick_add_expense_screen.dart';
import 'package:larga/widgets/skeleton_widgets.dart';

class ExpensesScreen extends StatefulWidget {
  final String tripId;
  final Trip? trip;

  const ExpensesScreen({
    super.key,
    required this.tripId,
    this.trip,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _expenseService = ExpenseService();
  final _expenseSplitService = ExpenseSplitService();
  final _tripService = TripService();
  final _profileService = ProfileService();
  final _itineraryService = ItineraryService();
  final _currencyService = CurrencyService();

  Trip? _trip;
  List<Expense> _expenses = [];
  Map<String, UserProfile> _userProfiles = {};
  Map<String, ItineraryItem> _itineraryItems = {};
  Map<String, List<ExpenseSplit>> _expenseSplits = {};
  Map<String, double>? _exchangeRates;
  double? _convertedTotal;
  bool _isLoading = true;
  bool _isLoadingRates = false;
  bool _canEdit = false;

  StreamSubscription<void>? _expensesSubscription;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _loadData();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _expensesSubscription = _expenseService.subscribeToExpensesChanges(
      tripId: widget.tripId,
      onUpdate: () {
        if (mounted) _loadData();
      },
    );
  }

  @override
  void dispose() {
    _expensesSubscription?.cancel();
    _expenseService.unsubscribeFromExpenses(widget.tripId);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _tripService.getTripById(widget.tripId),
        _tripService.canEdit(widget.tripId),
        _expenseService.getExpenses(widget.tripId),
        _itineraryService.getItineraryItems(widget.tripId),
      ]);

      if (!mounted) return;

      final trip = results[0] as Trip?;
      final canEdit = results[1] as bool;
      final expenses = results[2] as List<Expense>;
      final itineraryItems = results[3] as List<ItineraryItem>;

      // Fetch profiles for all payers
      final payerIds = expenses.map((e) => e.paidByUserId).toSet().toList();
      final profiles = await _profileService.getProfilesByAuthIds(payerIds);
      final profileMap = {for (var p in profiles) p.authId: p};
      
      // Create a map of itinerary items
      final itineraryMap = {for (var item in itineraryItems) item.id: item};

      // Load expense splits
      final allSplits = await _expenseSplitService.getSplitsForTrip(widget.tripId);
      final splitsMap = <String, List<ExpenseSplit>>{};
      for (final split in allSplits) {
        splitsMap.putIfAbsent(split.expenseId, () => []).add(split);
      }

      if (!mounted) return;

      setState(() {
        _trip = trip;
        _canEdit = canEdit;
        _expenses = expenses;
        _userProfiles = profileMap;
        _itineraryItems = itineraryMap;
        _expenseSplits = splitsMap;
        _isLoading = false;
      });

      // Load exchange rates if there are expenses in different currencies
      _loadExchangeRates();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarUtils.showError(context, 'Failed to load expenses');
    }
  }

  Future<void> _loadExchangeRates() async {
    final tripCurrency = _trip?.currency ?? 'PHP';
    final currencies = _expenses.map((e) => e.currency).toSet();
    
    debugPrint('ExpensesScreen: Trip currency: $tripCurrency');
    debugPrint('ExpensesScreen: Expense currencies: $currencies');
    
    // Check if any expense is in a different currency
    final hasDifferentCurrency = currencies.any((c) => c != tripCurrency);
    
    // If no expenses or all expenses are in trip currency, no conversion needed
    if (!hasDifferentCurrency) {
      debugPrint('ExpensesScreen: All expenses in trip currency, no conversion needed');
      setState(() {
        _convertedTotal = _expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
      });
      return;
    }

    // If expenses exist in other currencies, load exchange rates
    debugPrint('ExpensesScreen: Loading exchange rates...');
    setState(() => _isLoadingRates = true);

    try {
      // Get exchange rates from trip currency
      final rates = await _currencyService.getExchangeRates(tripCurrency);
      
      if (rates != null && mounted) {
        debugPrint('ExpensesScreen: Got ${rates.length} exchange rates');
        
        // Calculate converted total
        double total = 0;
        for (final expense in _expenses) {
          if (expense.currency == tripCurrency) {
            total += expense.amount;
            debugPrint('ExpensesScreen: ${expense.currency} ${expense.amount} (no conversion)');
          } else {
            // Convert from expense currency to trip currency
            // We need rates FROM the expense currency TO trip currency
            // Since we have rates FROM trip currency, we need to invert
            final rateToExpenseCurrency = rates[expense.currency];
            if (rateToExpenseCurrency != null && rateToExpenseCurrency > 0) {
              final converted = expense.amount / rateToExpenseCurrency;
              total += converted;
              debugPrint('ExpensesScreen: ${expense.currency} ${expense.amount} -> $tripCurrency $converted (rate: $rateToExpenseCurrency)');
            } else {
              debugPrint('ExpensesScreen: No rate found for ${expense.currency}');
            }
          }
        }

        debugPrint('ExpensesScreen: Total converted: $total $tripCurrency');
        setState(() {
          _exchangeRates = rates;
          _convertedTotal = total;
          _isLoadingRates = false;
        });
      } else {
        debugPrint('ExpensesScreen: Failed to get exchange rates');
        setState(() => _isLoadingRates = false);
      }
    } catch (e) {
      debugPrint('ExpensesScreen: Error loading exchange rates: $e');
      if (mounted) {
        setState(() => _isLoadingRates = false);
      }
    }
  }

  void _showAddExpenseOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text('AI Quick Add'),
                subtitle: const Text('Describe expense in natural language'),
                onTap: () {
                  Navigator.pop(context);
                  _quickAddExpense();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                title: const Text('Manual Entry'),
                subtitle: const Text('Fill in expense details'),
                onTap: () {
                  Navigator.pop(context);
                  _addExpense();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickAddExpense() async {
    final result = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(
        builder: (context) => QuickAddExpenseScreen(
          tripId: widget.tripId,
          trip: _trip,
        ),
      ),
    );

    if (result != null) {
      _loadData();
    }
  }

  Future<void> _addExpense() async {
    final result = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(
        builder: (context) => AddEditExpenseScreen(
          tripId: widget.tripId,
          trip: _trip,
        ),
      ),
    );

    if (result != null) {
      _loadData();
    }
  }

  Future<void> _editExpense(Expense expense) async {
    // Show confirmation if editing someone else's expense
    if (expense.paidByUserId != _tripService.currentUserId) {
      final payerName = _getPayerName(expense.paidByUserId).replaceAll(' paid', '');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit Expense'),
          content: Text(
            'This expense was paid by $payerName. Are you sure you want to edit it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Edit'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    final result = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(
        builder: (context) => AddEditExpenseScreen(
          tripId: widget.tripId,
          existingExpense: expense,
          trip: _trip,
        ),
      ),
    );

    if (result != null) {
      _loadData();
    }
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
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  String _getPayerName(String userId) {
    final profile = _userProfiles[userId];
    if (profile == null) return 'Unknown';
    
    // Check if this is the current user
    if (userId == _tripService.currentUserId) {
      return 'You paid';
    }
    
    final firstName = profile.displayName?.split(' ').first ?? 'Someone';
    return '$firstName paid';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_trip?.title ?? 'Expenses'),
        ),
        body: const ExpenseListSkeleton(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_trip?.title ?? 'Expenses'),
        actions: [
          if (_expenses.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              tooltip: 'View Balances',
              onPressed: _openBalances,
            ),
        ],
      ),
      body: _expenses.isEmpty ? _buildEmptyState() : _buildExpensesList(),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: _showAddExpenseOptions,
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            )
          : null,
    );
  }

  void _openBalances() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpenseBalancesScreen(
          tripId: widget.tripId,
          trip: _trip,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No expenses yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your trip spending by adding expenses',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_canEdit)
              FilledButton.icon(
                onPressed: _addExpense,
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesList() {
    // Group expenses by date
    final groupedExpenses = <String, List<Expense>>{};
    for (final expense in _expenses) {
      final dateKey = DateFormat('yyyy-MM-dd').format(expense.expenseDate);
      groupedExpenses.putIfAbsent(dateKey, () => []);
      groupedExpenses[dateKey]!.add(expense);
    }

    final sortedDates = groupedExpenses.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return CustomScrollView(
      slivers: [
        // Budget summary card
        SliverToBoxAdapter(
          child: _buildBudgetSummary(),
        ),

        // Expenses list grouped by date
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final dateKey = sortedDates[index];
                final dateExpenses = groupedExpenses[dateKey]!;
                final date = DateTime.parse(dateKey);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateHeader(date, dateExpenses),
                    ...dateExpenses.map((expense) => _buildExpenseCard(expense)),
                  ],
                );
              },
              childCount: sortedDates.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetSummary() {
    final hasBudget = _trip?.budget != null && _trip!.budget! > 0;
    final tripCurrency = _trip?.currency ?? 'PHP';
    
    // Group expenses by currency
    final currencyTotals = <String, double>{};
    for (final expense in _expenses) {
      currencyTotals[expense.currency] = 
          (currencyTotals[expense.currency] ?? 0) + expense.amount;
    }
    
    // Use converted total if available, otherwise use trip currency total
    final totalForBudget = _convertedTotal ?? (currencyTotals[tripCurrency] ?? 0.0);
    final remainingBudget = hasBudget ? _trip!.budget! - totalForBudget : 0.0;
    final isOverBudget = hasBudget && remainingBudget < 0;
    final hasMixedCurrencies = currencyTotals.length > 1;
    // Check if any expense currency is different from trip currency
    final hasDifferentCurrency = currencyTotals.keys.any((c) => c != tripCurrency);
    // Show converted total if we have conversion data AND currencies differ from trip
    final hasConvertedTotal = _convertedTotal != null && hasDifferentCurrency;
    // Need to show currency conversion info (loading or results)
    final needsConversion = hasDifferentCurrency;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOverBudget
              ? [Colors.red[400]!, Colors.red[600]!]
              : [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isOverBudget ? Colors.red : Theme.of(context).colorScheme.primary).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Spent',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_expenses.length} ${_expenses.length == 1 ? 'expense' : 'expenses'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Show converted total in trip currency
          if (_isLoadingRates && needsConversion)
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Converting currencies...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            )
          else if (hasConvertedTotal)
            // Show converted total with breakdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatCurrency(_convertedTotal!, tripCurrency),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasMixedCurrencies) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Converted from ${currencyTotals.length} currencies',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Show breakdown by currency
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: currencyTotals.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatCurrency(entry.value, entry.key),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  // Single different currency - show original amount
                  const SizedBox(height: 4),
                  Text(
                    'Original: ${_formatCurrency(currencyTotals.values.first, currencyTotals.keys.first)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            )
          else if (currencyTotals.isEmpty)
            Text(
              _formatCurrency(0, tripCurrency),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            // Single currency same as trip - show directly
            Text(
              _formatCurrency(
                currencyTotals.values.first,
                tripCurrency,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (hasBudget) ...[
            const SizedBox(height: 16),
            // Progress bar (based on converted total)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _trip!.budget! > 0 
                    ? (totalForBudget / _trip!.budget!).clamp(0.0, 1.0)
                    : 0.0,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(
                  isOverBudget ? Colors.white : Colors.white.withValues(alpha: 0.9),
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOverBudget ? 'Over budget' : 'Remaining',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
                Text(
                  _formatCurrency(remainingBudget.abs(), tripCurrency),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatCurrency(_trip!.budget!, tripCurrency),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (needsConversion && _convertedTotal == null && !_isLoadingRates)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Note: Could not convert currencies. Budget tracking only includes $tripCurrency expenses.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date, List<Expense> expenses) {
    final tripCurrency = _trip?.currency ?? 'PHP';
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final isYesterday = DateUtils.isSameDay(date, DateTime.now().subtract(const Duration(days: 1)));

    String dateText;
    if (isToday) {
      dateText = 'Today';
    } else if (isYesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('EEEE, MMMM d').format(date);
    }

    // Group expenses by currency for the day total
    final currencyTotals = <String, double>{};
    for (final expense in expenses) {
      currencyTotals[expense.currency] = 
          (currencyTotals[expense.currency] ?? 0) + expense.amount;
    }

    // Check if any currency is different from trip currency
    final hasDifferentCurrency = currencyTotals.keys.any((c) => c != tripCurrency);

    // Calculate converted total for the day if we have exchange rates
    String dayTotalText;
    String? originalText;
    
    if (!hasDifferentCurrency) {
      // All expenses are in trip currency
      final total = currencyTotals[tripCurrency] ?? 0.0;
      dayTotalText = _formatCurrency(total, tripCurrency);
    } else if (_exchangeRates != null) {
      // Convert all amounts to trip currency
      double convertedTotal = 0;
      for (final entry in currencyTotals.entries) {
        if (entry.key == tripCurrency) {
          convertedTotal += entry.value;
        } else {
          final rate = _exchangeRates![entry.key];
          if (rate != null && rate > 0) {
            convertedTotal += entry.value / rate;
          }
        }
      }
      dayTotalText = _formatCurrency(convertedTotal, tripCurrency);
      
      // Show original amounts if there's only one different currency
      if (currencyTotals.length == 1) {
        final original = currencyTotals.entries.first;
        originalText = _formatCurrency(original.value, original.key);
      }
    } else if (_isLoadingRates) {
      // Still loading rates
      dayTotalText = 'Converting...';
    } else {
      // No exchange rates - show original amounts
      dayTotalText = currencyTotals.entries
          .map((e) => _formatCurrency(e.value, e.key))
          .join(' + ');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dateText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dayTotalText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.right,
                ),
                if (originalText != null)
                  Text(
                    originalText,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.right,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    return Dismissible(
      key: ValueKey(expense.id),
      direction: _canEdit ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final isOwnExpense = expense.paidByUserId == _tripService.currentUserId;
        final payerName = _getPayerName(expense.paidByUserId).replaceAll(' paid', '');
        
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Expense'),
            content: Text(
              isOwnExpense
                  ? 'Are you sure you want to delete "${expense.description}"?'
                  : 'This expense was paid by $payerName. Are you sure you want to delete "${expense.description}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirmed != true) return false;

        try {
          await _expenseService.deleteExpense(expense.id);
          return true;
        } catch (e) {
          if (mounted) {
            SnackBarUtils.showError(context, 'Failed to delete expense');
          }
          return false;
        }
      },
      onDismissed: (_) {
        setState(() {
          _expenses.removeWhere((e) => e.id == expense.id);
        });
        SnackBarUtils.showSuccess(context, 'Expense deleted');
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          onTap: _canEdit ? () => _editExpense(expense) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(expense.category).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      expense.category.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Description, category, payer, and linked itinerary
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            expense.category.displayName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            ' • ',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          Flexible(
                            child: Text(
                              _getPayerName(expense.paidByUserId),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (expense.itineraryItemId != null && _itineraryItems[expense.itineraryItemId] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.event_outlined,
                                size: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _itineraryItems[expense.itineraryItemId]!.title,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Show split info
                      if (_expenseSplits[expense.id] != null && _expenseSplits[expense.id]!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _buildSplitInfo(expense, _expenseSplits[expense.id]!),
                        ),
                      // Show line items preview
                      if (expense.lineItems != null && expense.lineItems!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _buildLineItemsPreview(expense),
                        ),
                    ],
                  ),
                ),
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(expense.amount, expense.currency),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    // Show converted amount if expense is in different currency
                    Builder(builder: (context) {
                      final tripCurrency = _trip?.currency ?? 'PHP';
                      if (expense.currency == tripCurrency) {
                        return const SizedBox.shrink();
                      }
                      
                      // Try to get conversion rate
                      double? convertedAmount;
                      if (_exchangeRates != null && _exchangeRates!.containsKey(expense.currency)) {
                        final rate = _exchangeRates![expense.currency]!;
                        if (rate > 0) {
                          convertedAmount = expense.amount / rate;
                        }
                      }
                      
                      if (convertedAmount != null) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '≈ ${_formatCurrency(convertedAmount, tripCurrency)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      } else if (_isLoadingRates) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Converting...',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
                    if (expense.isSettled)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Settled',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (expense.receiptUrl != null)
                      GestureDetector(
                        onTap: () => _showReceiptImage(expense),
                        child: Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_outlined, size: 10, color: Colors.blue),
                              SizedBox(width: 2),
                              Text(
                                'Receipt',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReceiptImage(Expense expense) {
    if (expense.receiptUrl == null) return;
    
    final hasLineItems = expense.lineItems != null && expense.lineItems!.isNotEmpty;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            expense.description,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Line items section
                  if (hasLineItems) ...[
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: expense.lineItems!.length,
                        itemBuilder: (context, index) {
                          final item = expense.lineItems![index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                if (item.quantity != null) ...[
                                  Text(
                                    '${item.quantity!.toStringAsFixed(item.quantity! % 1 == 0 ? 0 : 1)}x ',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Text(
                                    item.description,
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.price != null)
                                  Text(
                                    _formatCurrency(item.price!, expense.currency),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                  Flexible(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.network(
                          expense.receiptUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 300,
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load receipt',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildLineItemsPreview(Expense expense) {
    final items = expense.lineItems!;
    final displayItems = items.take(3).toList();
    final hasMore = items.length > 3;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${items.length} item${items.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...displayItems.map((item) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.price != null)
                      Text(
                        _formatCurrency(item.price!, expense.currency),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              )),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+${items.length - 3} more',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSplitInfo(Expense expense, List<ExpenseSplit> splits) {
    final splitCount = splits.length;
    final settledCount = splits.where((s) => s.isSettled).length;
    final allSettled = settledCount == splitCount;
    final currentUserId = _tripService.currentUserId;
    final tripCurrency = _trip?.currency ?? 'PHP';
    
    final userSplit = splits.where((s) => s.userId == currentUserId).firstOrNull;
    final owesAmount = userSplit != null && !userSplit.isSettled && userSplit.userId != expense.paidByUserId
        ? userSplit.amount
        : null;

    double? convertedOwesAmount;
    if (owesAmount != null && expense.currency != tripCurrency && _exchangeRates != null) {
      final rate = _exchangeRates![expense.currency];
      if (rate != null && rate > 0) {
        convertedOwesAmount = owesAmount / rate;
      }
    }

    return Row(
      children: [
        Icon(
          allSettled ? Icons.check_circle : Icons.people_outline,
          size: 12,
          color: allSettled ? Colors.green : Colors.orange[700],
        ),
        const SizedBox(width: 4),
        Text(
          allSettled
              ? 'Split settled'
              : 'Split $splitCount ways',
          style: TextStyle(
            fontSize: 12,
            color: allSettled ? Colors.green : Colors.orange[700],
          ),
        ),
        if (owesAmount != null) ...[
          Text(
            ' • ',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          if (convertedOwesAmount != null)
            Text(
              'You owe ≈${_formatCurrency(convertedOwesAmount, tripCurrency)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              'You owe ${_formatCurrency(owesAmount, expense.currency)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ],
    );
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
}
