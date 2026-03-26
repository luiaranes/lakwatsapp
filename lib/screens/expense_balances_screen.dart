import 'package:flutter/material.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/user_profile.dart';
import 'package:larga/services/expense_split_service.dart';
import 'package:larga/services/expense_service.dart';
import 'package:larga/services/currency_service.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/services/profile_service.dart';
import 'package:larga/utils/snackbar_utils.dart';

class ExpenseBalancesScreen extends StatefulWidget {
  final String tripId;
  final Trip? trip;

  const ExpenseBalancesScreen({
    super.key,
    required this.tripId,
    this.trip,
  });

  @override
  State<ExpenseBalancesScreen> createState() => _ExpenseBalancesScreenState();
}

class _ExpenseBalancesScreenState extends State<ExpenseBalancesScreen>
    with SingleTickerProviderStateMixin {
  final _expenseSplitService = ExpenseSplitService();
  final _expenseService = ExpenseService();
  final _currencyService = CurrencyService();
  final _tripService = TripService();
  final _profileService = ProfileService();

  late TabController _tabController;

  bool _isLoading = true;
  bool _isLoadingRates = false;
  Trip? _trip;
  Map<String, MemberBalance> _balances = {};
  Map<String, Map<String, double>> _detailedDebts = {};
  List<DebtSettlement> _settlements = [];
  Map<String, UserProfile> _profiles = {};
  Map<String, double>? _exchangeRates;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _trip = widget.trip;
    _currentUserId = _tripService.currentUserId;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _trip ??= await _tripService.getTripById(widget.tripId);
      final tripCurrency = _trip?.currency ?? 'PHP';

      final members = await _tripService.getTripMembers(widget.tripId);
      final authIds = members.map((m) => m.userId).toList();
      final profiles = await _profileService.getProfilesByAuthIds(authIds);
      _profiles = {for (var p in profiles) p.authId: p};

      final expenses = await _expenseService.getExpenses(widget.tripId);
      final currencies = expenses.map((e) => e.currency).toSet();
      final hasDifferentCurrency = currencies.any((c) => c != tripCurrency);

      if (hasDifferentCurrency) {
        setState(() => _isLoadingRates = true);
        _exchangeRates = await _currencyService.getExchangeRates(tripCurrency);
        if (mounted) setState(() => _isLoadingRates = false);
      }

      _balances = await _expenseSplitService.calculateMemberBalances(
        widget.tripId,
        targetCurrency: tripCurrency,
        exchangeRates: _exchangeRates,
      );
      _detailedDebts = await _expenseSplitService.calculateDetailedDebts(
        widget.tripId,
        targetCurrency: tripCurrency,
        exchangeRates: _exchangeRates,
      );
      _settlements = await _expenseSplitService.getSettlementSuggestions(
        widget.tripId,
        targetCurrency: tripCurrency,
        exchangeRates: _exchangeRates,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarUtils.showError(context, 'Failed to load balances');
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = _trip?.currency ?? 'PHP';
    final symbol = _getCurrencySymbol(currency);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Balances'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Balances'),
            Tab(text: 'Settle Up'),
          ],
        ),
      ),
      body: _isLoading || _isLoadingRates
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBalancesTab(theme, symbol),
                _buildSettleUpTab(theme, symbol),
              ],
            ),
    );
  }

  Widget _buildBalancesTab(ThemeData theme, String symbol) {
    if (_balances.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No expense splits yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add expenses and enable "Split this expense" to track balances between trip members.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to expenses'),
              ),
            ],
          ),
        ),
      );
    }

    final sortedBalances = _balances.entries.toList()
      ..sort((a, b) => b.value.netBalance.compareTo(a.value.netBalance));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(theme, symbol),
          const SizedBox(height: 24),
          Text(
            'Member Balances',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...sortedBalances.map((entry) => _buildBalanceCard(
            entry.key,
            entry.value,
            symbol,
            theme,
          )),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, String symbol) {
    double totalExpenses = 0;
    for (final balance in _balances.values) {
      totalExpenses += balance.totalPaid;
    }

    final hasConversion = _exchangeRates != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withAlpha(179),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withAlpha(77),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total Group Expenses',
            style: TextStyle(
              color: Colors.white.withAlpha(204),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$symbol${totalExpenses.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (hasConversion) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(38),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.currency_exchange,
                    size: 12,
                    color: Colors.white.withAlpha(204),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Converted to ${_trip?.currency ?? 'PHP'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withAlpha(204),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryItem(
                'Members',
                '${_balances.length}',
                Icons.group_outlined,
              ),
              _buildSummaryItem(
                'Settlements',
                '${_settlements.length}',
                Icons.swap_horiz,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withAlpha(204), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(179),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(
    String userId,
    MemberBalance balance,
    String symbol,
    ThemeData theme,
  ) {
    final profile = _profiles[userId];
    final isCurrentUser = userId == _currentUserId;
    final netBalance = balance.netBalance;
    final isOwed = netBalance > 0.01;
    final owes = netBalance < -0.01;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser
              ? theme.colorScheme.primary.withAlpha(77)
              : Colors.grey[200]!,
          width: isCurrentUser ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage:
                  profile?.avatarUrl != null ? NetworkImage(profile!.avatarUrl!) : null,
              backgroundColor: Colors.grey[300],
              child: profile?.avatarUrl == null
                  ? Text(
                      _getInitials(profile?.displayName ?? 'Unknown'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        profile?.displayName ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'You',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paid $symbol${balance.totalPaid.toStringAsFixed(2)} • Owes $symbol${balance.totalOwed.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOwed
                        ? Colors.green.withAlpha(25)
                        : owes
                            ? Colors.red.withAlpha(25)
                            : Colors.grey.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${netBalance >= 0 ? '+' : ''}$symbol${netBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isOwed
                          ? Colors.green[700]
                          : owes
                              ? Colors.red[700]
                              : Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOwed
                      ? 'gets back'
                      : owes
                          ? 'owes'
                          : 'settled',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettleUpTab(ThemeData theme, String symbol) {
    if (_settlements.isEmpty) {
      final hasBalances = _balances.isNotEmpty;
      final hasDebts = _balances.values.any((b) => b.netBalance.abs() > 0.01);

      if (!hasBalances) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No expense splits yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'When adding expenses, enable "Split this expense" to track who owes whom.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add expenses with splits'),
                ),
              ],
            ),
          ),
        );
      }

      if (!hasDebts) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.green[400],
              ),
              const SizedBox(height: 16),
              Text(
                'All settled up!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Everyone has paid their fair share',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green[400],
            ),
            const SizedBox(height: 16),
            Text(
              'All settled up!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No payments needed',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withAlpha(51)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These suggestions minimize the number of transactions needed to settle all debts.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Suggested Settlements',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._settlements.asMap().entries.map((entry) {
            final index = entry.key;
            final settlement = entry.value;
            return _buildSettlementCard(settlement, symbol, theme, index + 1);
          }),
          const SizedBox(height: 24),
          _buildDetailedDebtsSection(theme, symbol),
        ],
      ),
    );
  }

  Widget _buildSettlementCard(
    DebtSettlement settlement,
    String symbol,
    ThemeData theme,
    int index,
  ) {
    final fromProfile = _profiles[settlement.fromUserId];
    final toProfile = _profiles[settlement.toUserId];
    final isFromCurrentUser = settlement.fromUserId == _currentUserId;
    final isToCurrentUser = settlement.toUserId == _currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      _buildMiniAvatar(fromProfile, isFromCurrentUser, theme),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFromCurrentUser
                                  ? 'You'
                                  : fromProfile?.displayName ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'pays',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isToCurrentUser
                                  ? 'You'
                                  : toProfile?.displayName ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'receives',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildMiniAvatar(toProfile, isToCurrentUser, theme),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${_getCurrencySymbol(settlement.currency)}${settlement.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _markAsSettled(settlement),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Mark as Settled'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAvatar(UserProfile? profile, bool isCurrentUser, ThemeData theme) {
    return CircleAvatar(
      radius: 18,
      backgroundImage:
          profile?.avatarUrl != null ? NetworkImage(profile!.avatarUrl!) : null,
      backgroundColor:
          isCurrentUser ? theme.colorScheme.primaryContainer : Colors.grey[300],
      child: profile?.avatarUrl == null
          ? Text(
              _getInitials(profile?.displayName ?? 'Unknown'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isCurrentUser ? theme.colorScheme.primary : Colors.grey[700],
              ),
            )
          : null,
    );
  }

  Widget _buildDetailedDebtsSection(ThemeData theme, String symbol) {
    if (_detailedDebts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Breakdown',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Who owes whom (before simplification)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: _detailedDebts.entries.map((debtorEntry) {
              final debtorProfile = _profiles[debtorEntry.key];
              final debtorName = debtorEntry.key == _currentUserId
                  ? 'You'
                  : debtorProfile?.displayName ?? 'Unknown';

              return Column(
                children: debtorEntry.value.entries.map((creditorEntry) {
                  final creditorProfile = _profiles[creditorEntry.key];
                  final creditorName = creditorEntry.key == _currentUserId
                      ? 'You'
                      : creditorProfile?.displayName ?? 'Unknown';

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.subdirectory_arrow_right,
                      size: 18,
                      color: Colors.grey[400],
                    ),
                    title: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                        children: [
                          TextSpan(
                            text: debtorName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' owes '),
                          TextSpan(
                            text: creditorName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    trailing: Text(
                      '$symbol${creditorEntry.value.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _markAsSettled(DebtSettlement settlement) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Settled?'),
        content: Text(
          'This will mark all debts from ${_profiles[settlement.fromUserId]?.displayName ?? "Unknown"} '
          'to ${_profiles[settlement.toUserId]?.displayName ?? "Unknown"} as settled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Settle'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _expenseSplitService.settleDebtBetweenUsers(
        tripId: widget.tripId,
        fromUserId: settlement.fromUserId,
        toUserId: settlement.toUserId,
      );

      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'Debt settled!');
      _loadData();
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to settle debt');
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}
