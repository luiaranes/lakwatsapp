import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/expense_split.dart';
import 'package:larga/models/expense.dart';
import 'package:larga/models/activity_log.dart';
import 'package:larga/services/expense_service.dart';
import 'package:larga/services/activity_log_service.dart';
import 'package:larga/services/profile_service.dart';

class MemberBalance {
  final String userId;
  final double totalPaid;
  final double totalOwed;
  final double netBalance;
  final String currency;

  MemberBalance({
    required this.userId,
    required this.totalPaid,
    required this.totalOwed,
    required this.netBalance,
    required this.currency,
  });
}

class DebtSettlement {
  final String fromUserId;
  final String toUserId;
  final double amount;
  final String currency;

  DebtSettlement({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.currency,
  });
}

class ExpenseSplitService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ExpenseService _expenseService = ExpenseService();
  final ActivityLogService _activityLogService = ActivityLogService();
  final ProfileService _profileService = ProfileService();

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Get all splits for an expense
  Future<List<ExpenseSplit>> getSplitsForExpense(String expenseId) async {
    try {
      final response = await _supabase
          .from('expense_splits')
          .select()
          .eq('expense_id', expenseId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((item) => ExpenseSplit.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ExpenseSplitService: Error getting splits: $e');
      rethrow;
    }
  }

  /// Get all splits for a trip (across all expenses)
  Future<List<ExpenseSplit>> getSplitsForTrip(String tripId) async {
    try {
      final expenses = await _expenseService.getExpenses(tripId);
      final expenseIds = expenses.map((e) => e.id).toList();

      if (expenseIds.isEmpty) return [];

      final response = await _supabase
          .from('expense_splits')
          .select()
          .inFilter('expense_id', expenseIds);

      return (response as List)
          .map((item) => ExpenseSplit.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ExpenseSplitService: Error getting splits for trip: $e');
      rethrow;
    }
  }

  /// Get splits for a specific user in a trip
  Future<List<ExpenseSplit>> getSplitsForUser(String tripId, String userId) async {
    try {
      final allSplits = await getSplitsForTrip(tripId);
      return allSplits.where((s) => s.userId == userId).toList();
    } catch (e) {
      debugPrint('ExpenseSplitService: Error getting splits for user: $e');
      rethrow;
    }
  }

  /// Create splits for an expense (equal split among selected members)
  Future<List<ExpenseSplit>> createEqualSplits({
    required String expenseId,
    required double totalAmount,
    required List<String> memberIds,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    if (memberIds.isEmpty) {
      throw Exception('At least one member must be selected');
    }

    try {
      final splitAmount = totalAmount / memberIds.length;
      final percentage = 100.0 / memberIds.length;

      final inserts = memberIds.map((userId) => {
        'expense_id': expenseId,
        'user_id': userId,
        'amount': double.parse(splitAmount.toStringAsFixed(2)),
        'percentage': double.parse(percentage.toStringAsFixed(2)),
        'split_type': SplitType.equal.name,
        'is_settled': false,
      }).toList();

      final response = await _supabase
          .from('expense_splits')
          .insert(inserts)
          .select();

      debugPrint('ExpenseSplitService: Created ${inserts.length} equal splits');

      return (response as List)
          .map((item) => ExpenseSplit.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ExpenseSplitService: Error creating equal splits: $e');
      rethrow;
    }
  }

  /// Create splits for an expense (percentage split)
  Future<List<ExpenseSplit>> createPercentageSplits({
    required String expenseId,
    required double totalAmount,
    required Map<String, double> memberPercentages,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    if (memberPercentages.isEmpty) {
      throw Exception('At least one member must be selected');
    }

    final totalPercentage = memberPercentages.values.fold<double>(0.0, (sum, p) => sum + p);
    if ((totalPercentage - 100.0).abs() > 0.01) {
      throw Exception('Percentages must add up to 100%');
    }

    try {
      final inserts = memberPercentages.entries.map((entry) {
        final amount = totalAmount * (entry.value / 100);
        return {
          'expense_id': expenseId,
          'user_id': entry.key,
          'amount': double.parse(amount.toStringAsFixed(2)),
          'percentage': entry.value,
          'split_type': SplitType.percentage.name,
          'is_settled': false,
        };
      }).toList();

      final response = await _supabase
          .from('expense_splits')
          .insert(inserts)
          .select();

      debugPrint('ExpenseSplitService: Created ${inserts.length} percentage splits');

      return (response as List)
          .map((item) => ExpenseSplit.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ExpenseSplitService: Error creating percentage splits: $e');
      rethrow;
    }
  }

  /// Create splits for an expense (exact amounts)
  Future<List<ExpenseSplit>> createExactSplits({
    required String expenseId,
    required double totalAmount,
    required Map<String, double> memberAmounts,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    if (memberAmounts.isEmpty) {
      throw Exception('At least one member must be selected');
    }

    final totalSplit = memberAmounts.values.fold<double>(0.0, (sum, a) => sum + a);
    if ((totalSplit - totalAmount).abs() > 0.01) {
      throw Exception('Split amounts must equal the total expense amount');
    }

    try {
      final inserts = memberAmounts.entries.map((entry) {
        final percentage = (entry.value / totalAmount) * 100;
        return {
          'expense_id': expenseId,
          'user_id': entry.key,
          'amount': entry.value,
          'percentage': double.parse(percentage.toStringAsFixed(2)),
          'split_type': SplitType.exact.name,
          'is_settled': false,
        };
      }).toList();

      final response = await _supabase
          .from('expense_splits')
          .insert(inserts)
          .select();

      debugPrint('ExpenseSplitService: Created ${inserts.length} exact splits');

      return (response as List)
          .map((item) => ExpenseSplit.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ExpenseSplitService: Error creating exact splits: $e');
      rethrow;
    }
  }

  /// Update splits for an expense (deletes existing and creates new)
  Future<List<ExpenseSplit>> updateSplits({
    required String expenseId,
    required double totalAmount,
    required SplitType splitType,
    required List<String>? memberIds,
    Map<String, double>? memberPercentages,
    Map<String, double>? memberAmounts,
    bool logActivity = true,
  }) async {
    try {
      final expense = await _expenseService.getExpenseById(expenseId);
      final existingSplits = await getSplitsForExpense(expenseId);
      final hadSplits = existingSplits.isNotEmpty;

      await deleteSplitsForExpense(expenseId);

      final splits = switch (splitType) {
        SplitType.equal => await createEqualSplits(
            expenseId: expenseId,
            totalAmount: totalAmount,
            memberIds: memberIds ?? [],
          ),
        SplitType.percentage => await createPercentageSplits(
            expenseId: expenseId,
            totalAmount: totalAmount,
            memberPercentages: memberPercentages ?? {},
          ),
        SplitType.exact => await createExactSplits(
            expenseId: expenseId,
            totalAmount: totalAmount,
            memberAmounts: memberAmounts ?? {},
          ),
      };

      if (logActivity && expense != null && splits.isNotEmpty) {
        final memberCount = splits.length;
        final profiles = await _profileService.getProfilesByAuthIds(
          splits.map((s) => s.userId).toList(),
        );
        final memberNames = profiles.map((p) => p.displayName ?? 'Unknown').toList();

        await _activityLogService.logActivity(
          entityType: ActivityEntityType.expenseSplit,
          entityId: expenseId,
          tripId: expense.tripId,
          action: hadSplits ? ActivityAction.updated : ActivityAction.created,
          details: {
            'title': expense.description,
            'expense_amount': totalAmount,
            'currency': expense.currency,
            'split_type': splitType.name,
            'member_count': memberCount,
            'member_names': memberNames,
          },
        );
      }

      return splits;
    } catch (e) {
      debugPrint('ExpenseSplitService: Error updating splits: $e');
      rethrow;
    }
  }

  /// Delete all splits for an expense
  Future<void> deleteSplitsForExpense(String expenseId) async {
    try {
      await _supabase
          .from('expense_splits')
          .delete()
          .eq('expense_id', expenseId);

      debugPrint('ExpenseSplitService: Deleted splits for expense: $expenseId');
    } catch (e) {
      debugPrint('ExpenseSplitService: Error deleting splits: $e');
      rethrow;
    }
  }

  /// Mark a split as settled
  Future<ExpenseSplit> markSplitAsSettled(String splitId) async {
    try {
      final response = await _supabase
          .from('expense_splits')
          .update({
            'is_settled': true,
            'settled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', splitId)
          .select()
          .single();

      debugPrint('ExpenseSplitService: Marked split as settled: $splitId');
      return ExpenseSplit.fromJson(response);
    } catch (e) {
      debugPrint('ExpenseSplitService: Error marking split as settled: $e');
      rethrow;
    }
  }

  /// Mark a split as unsettled
  Future<ExpenseSplit> markSplitAsUnsettled(String splitId) async {
    try {
      final response = await _supabase
          .from('expense_splits')
          .update({
            'is_settled': false,
            'settled_at': null,
          })
          .eq('id', splitId)
          .select()
          .single();

      debugPrint('ExpenseSplitService: Marked split as unsettled: $splitId');
      return ExpenseSplit.fromJson(response);
    } catch (e) {
      debugPrint('ExpenseSplitService: Error marking split as unsettled: $e');
      rethrow;
    }
  }

  /// Mark all splits between two users as settled for a trip
  Future<void> settleDebtBetweenUsers({
    required String tripId,
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      final expenses = await _expenseService.getExpenses(tripId);
      final paidByTarget = expenses.where((e) => e.paidByUserId == toUserId).toList();
      final expenseIds = paidByTarget.map((e) => e.id).toList();

      if (expenseIds.isEmpty) return;

      await _supabase
          .from('expense_splits')
          .update({
            'is_settled': true,
            'settled_at': DateTime.now().toIso8601String(),
          })
          .inFilter('expense_id', expenseIds)
          .eq('user_id', fromUserId)
          .eq('is_settled', false);

      debugPrint('ExpenseSplitService: Settled debt from $fromUserId to $toUserId');

      final profiles = await _profileService.getProfilesByAuthIds([fromUserId, toUserId]);
      final profileMap = {for (var p in profiles) p.authId: p};
      final fromName = profileMap[fromUserId]?.displayName ?? 'Unknown';
      final toName = profileMap[toUserId]?.displayName ?? 'Unknown';

      await _activityLogService.logActivity(
        entityType: ActivityEntityType.expenseSplit,
        entityId: tripId,
        tripId: tripId,
        action: ActivityAction.settled,
        details: {
          'title': 'Debt settlement',
          'from_user_id': fromUserId,
          'from_user_name': fromName,
          'to_user_id': toUserId,
          'to_user_name': toName,
        },
      );
    } catch (e) {
      debugPrint('ExpenseSplitService: Error settling debt: $e');
      rethrow;
    }
  }

  /// Convert an amount from one currency to another using provided rates
  double _convertAmount(
    double amount,
    String fromCurrency,
    String targetCurrency,
    Map<String, double>? exchangeRates,
  ) {
    if (fromCurrency == targetCurrency) return amount;
    if (exchangeRates == null) return amount;

    final rate = exchangeRates[fromCurrency];
    if (rate == null || rate <= 0) return amount;

    return amount / rate;
  }

  /// Calculate balances for all members in a trip with currency conversion
  Future<Map<String, MemberBalance>> calculateMemberBalances(
    String tripId, {
    String? targetCurrency,
    Map<String, double>? exchangeRates,
  }) async {
    try {
      final expenses = await _expenseService.getExpenses(tripId);
      final splits = await getSplitsForTrip(tripId);

      final balances = <String, MemberBalance>{};
      final currency = targetCurrency ?? 'PHP';

      final expenseMap = <String, Expense>{};
      for (final expense in expenses) {
        expenseMap[expense.id] = expense;
      }

      final paidByUser = <String, double>{};
      for (final expense in expenses) {
        final convertedAmount = _convertAmount(
          expense.amount,
          expense.currency,
          currency,
          exchangeRates,
        );
        paidByUser[expense.paidByUserId] =
            (paidByUser[expense.paidByUserId] ?? 0) + convertedAmount;
      }

      final owedByUser = <String, double>{};
      for (final split in splits) {
        if (!split.isSettled) {
          final expense = expenseMap[split.expenseId];
          final expenseCurrency = expense?.currency ?? currency;
          final convertedAmount = _convertAmount(
            split.amount,
            expenseCurrency,
            currency,
            exchangeRates,
          );
          owedByUser[split.userId] =
              (owedByUser[split.userId] ?? 0) + convertedAmount;
        }
      }

      final allUserIds = <String>{
        ...paidByUser.keys,
        ...owedByUser.keys,
      };

      for (final userId in allUserIds) {
        final paid = paidByUser[userId] ?? 0;
        final owed = owedByUser[userId] ?? 0;
        balances[userId] = MemberBalance(
          userId: userId,
          totalPaid: double.parse(paid.toStringAsFixed(2)),
          totalOwed: double.parse(owed.toStringAsFixed(2)),
          netBalance: double.parse((paid - owed).toStringAsFixed(2)),
          currency: currency,
        );
      }

      return balances;
    } catch (e) {
      debugPrint('ExpenseSplitService: Error calculating balances: $e');
      rethrow;
    }
  }

  /// Calculate detailed "who owes whom" breakdown with currency conversion
  Future<Map<String, Map<String, double>>> calculateDetailedDebts(
    String tripId, {
    String? targetCurrency,
    Map<String, double>? exchangeRates,
  }) async {
    try {
      final expenses = await _expenseService.getExpenses(tripId);
      final splits = await getSplitsForTrip(tripId);
      final currency = targetCurrency ?? 'PHP';

      final debts = <String, Map<String, double>>{};

      final expenseMap = <String, Expense>{};
      for (final expense in expenses) {
        expenseMap[expense.id] = expense;
      }

      final splitsByExpense = <String, List<ExpenseSplit>>{};
      for (final split in splits) {
        splitsByExpense.putIfAbsent(split.expenseId, () => []).add(split);
      }

      for (final expense in expenses) {
        final expenseSplits = splitsByExpense[expense.id] ?? [];
        final payerId = expense.paidByUserId;

        for (final split in expenseSplits) {
          if (split.isSettled) continue;
          if (split.userId == payerId) continue;

          final convertedAmount = _convertAmount(
            split.amount,
            expense.currency,
            currency,
            exchangeRates,
          );

          debts.putIfAbsent(split.userId, () => {});
          debts[split.userId]![payerId] =
              (debts[split.userId]![payerId] ?? 0) + convertedAmount;
        }
      }

      for (final debtorId in debts.keys) {
        for (final creditorId in debts[debtorId]!.keys) {
          debts[debtorId]![creditorId] =
              double.parse(debts[debtorId]![creditorId]!.toStringAsFixed(2));
        }
      }

      return debts;
    } catch (e) {
      debugPrint('ExpenseSplitService: Error calculating detailed debts: $e');
      rethrow;
    }
  }

  /// Get simplified settlement suggestions (minimize transactions) with currency conversion
  Future<List<DebtSettlement>> getSettlementSuggestions(
    String tripId, {
    String? targetCurrency,
    Map<String, double>? exchangeRates,
  }) async {
    try {
      final currency = targetCurrency ?? 'PHP';
      final balances = await calculateMemberBalances(
        tripId,
        targetCurrency: currency,
        exchangeRates: exchangeRates,
      );
      
      final creditors = <String, double>{};
      final debtors = <String, double>{};

      for (final entry in balances.entries) {
        if (entry.value.netBalance > 0.01) {
          creditors[entry.key] = entry.value.netBalance;
        } else if (entry.value.netBalance < -0.01) {
          debtors[entry.key] = -entry.value.netBalance;
        }
      }

      final settlements = <DebtSettlement>[];

      final sortedCreditors = creditors.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final sortedDebtors = debtors.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      var creditIdx = 0;
      var debtIdx = 0;

      while (creditIdx < sortedCreditors.length && debtIdx < sortedDebtors.length) {
        final creditor = sortedCreditors[creditIdx];
        final debtor = sortedDebtors[debtIdx];

        final amount = creditor.value < debtor.value ? creditor.value : debtor.value;

        if (amount > 0.01) {
          settlements.add(DebtSettlement(
            fromUserId: debtor.key,
            toUserId: creditor.key,
            amount: double.parse(amount.toStringAsFixed(2)),
            currency: currency,
          ));
        }

        sortedCreditors[creditIdx] = MapEntry(creditor.key, creditor.value - amount);
        sortedDebtors[debtIdx] = MapEntry(debtor.key, debtor.value - amount);

        if (sortedCreditors[creditIdx].value < 0.01) creditIdx++;
        if (sortedDebtors[debtIdx].value < 0.01) debtIdx++;
      }

      return settlements;
    } catch (e) {
      debugPrint('ExpenseSplitService: Error getting settlement suggestions: $e');
      rethrow;
    }
  }

  /// Get unsettled split count for a user in a trip
  Future<int> getUnsettledSplitCount(String tripId, String userId) async {
    try {
      final splits = await getSplitsForUser(tripId, userId);
      return splits.where((s) => !s.isSettled).length;
    } catch (e) {
      debugPrint('ExpenseSplitService: Error getting unsettled count: $e');
      return 0;
    }
  }

  /// Check if an expense has splits
  Future<bool> hasExpenseSplits(String expenseId) async {
    try {
      final splits = await getSplitsForExpense(expenseId);
      return splits.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
