import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/expense.dart';
import 'package:larga/models/itinerary_item.dart';
import 'package:larga/services/activity_log_service.dart';
import 'package:larga/services/profile_service.dart';
import 'package:larga/services/itinerary_service.dart';
import 'package:larga/models/activity_log.dart';

class ExpenseService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLogService = ActivityLogService();
  final ProfileService _profileService = ProfileService();
  final ItineraryService _itineraryService = ItineraryService();

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Fetch all expenses for a trip, sorted by date descending
  Future<List<Expense>> getExpenses(String tripId) async {
    try {
      final response = await _supabase
          .from('expenses')
          .select()
          .eq('trip_id', tripId)
          .order('expense_date', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => Expense.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ExpenseService: Error getting expenses: $e');
      rethrow;
    }
  }

  /// Fetch expenses for a specific category
  Future<List<Expense>> getExpensesByCategory(
    String tripId,
    ExpenseCategory category,
  ) async {
    try {
      final response = await _supabase
          .from('expenses')
          .select()
          .eq('trip_id', tripId)
          .eq('category', category.name)
          .order('expense_date', ascending: false);

      return (response as List)
          .map((item) => Expense.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ExpenseService: Error getting expenses by category: $e');
      rethrow;
    }
  }

  /// Get a single expense by ID
  Future<Expense?> getExpenseById(String expenseId) async {
    try {
      final response = await _supabase
          .from('expenses')
          .select()
          .eq('id', expenseId)
          .maybeSingle();

      if (response == null) return null;
      return Expense.fromJson(response);
    } catch (e) {
      debugPrint('ExpenseService: Error getting expense: $e');
      rethrow;
    }
  }

  /// Create a new expense
  Future<Expense> createExpense({
    required String tripId,
    required double amount,
    required String description,
    required DateTime expenseDate,
    String? paidByUserId,
    String currency = 'PHP',
    ExpenseCategory category = ExpenseCategory.other,
    String? receiptUrl,
    String? notes,
    String? itineraryItemId,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final payerId = paidByUserId ?? _currentUserId!;
      final response = await _supabase
          .from('expenses')
          .insert({
            'trip_id': tripId,
            'paid_by_user_id': payerId,
            'amount': amount,
            'currency': currency,
            'category': category.name,
            'description': description.trim(),
            'expense_date': expenseDate.toIso8601String().split('T').first,
            'receipt_url': receiptUrl,
            'notes': notes?.trim(),
            'itinerary_item_id': itineraryItemId,
            'is_settled': false,
          })
          .select()
          .single();

      debugPrint('ExpenseService: Expense created');
      final expense = Expense.fromJson(response);

      // Log the activity
      await _activityLogService.logActivity(
        entityType: ActivityEntityType.expense,
        entityId: expense.id,
        tripId: tripId,
        action: ActivityAction.created,
        details: {
          'title': description.trim(),
          'amount': amount,
          'currency': currency,
          'category': category.name,
          if (itineraryItemId != null) 'itinerary_item_id': itineraryItemId,
        },
      );

      return expense;
    } catch (e) {
      debugPrint('ExpenseService: Error creating expense: $e');
      rethrow;
    }
  }

  /// Update an existing expense
  Future<Expense> updateExpense({
    required String expenseId,
    double? amount,
    String? currency,
    ExpenseCategory? category,
    String? description,
    DateTime? expenseDate,
    String? paidByUserId,
    String? receiptUrl,
    String? notes,
    String? itineraryItemId,
    bool? isSettled,
    bool clearReceiptUrl = false,
    bool clearNotes = false,
    bool clearItineraryItem = false,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final original = await getExpenseById(expenseId);
      if (original == null) throw Exception('Expense not found');

      final updates = <String, dynamic>{};
      final changes = <String, Map<String, dynamic>>{};

      if (paidByUserId != null && paidByUserId != original.paidByUserId) {
        updates['paid_by_user_id'] = paidByUserId;
        // Fetch user names for better activity log display
        final profiles = await _profileService.getProfilesByAuthIds([original.paidByUserId, paidByUserId]);
        final profileMap = {for (var p in profiles) p.authId: p};
        final fromName = profileMap[original.paidByUserId]?.displayName ?? 'Unknown';
        final toName = profileMap[paidByUserId]?.displayName ?? 'Unknown';
        changes['paid_by_user_id'] = {'from': fromName, 'to': toName};
      }
      if (amount != null && amount != original.amount) {
        updates['amount'] = amount;
        changes['amount'] = {'from': original.amount, 'to': amount};
      }
      if (currency != null && currency != original.currency) {
        updates['currency'] = currency;
        changes['currency'] = {'from': original.currency, 'to': currency};
      }
      if (category != null && category != original.category) {
        updates['category'] = category.name;
        changes['category'] = {'from': original.category.name, 'to': category.name};
      }
      if (description != null) {
        final newDesc = description.trim();
        if (newDesc != original.description) {
          updates['description'] = newDesc;
          changes['description'] = {'from': original.description, 'to': newDesc};
        }
      }
      if (expenseDate != null) {
        final newDate = expenseDate.toIso8601String().split('T').first;
        final oldDate = original.expenseDate.toIso8601String().split('T').first;
        if (newDate != oldDate) {
          updates['expense_date'] = newDate;
          changes['expense_date'] = {'from': oldDate, 'to': newDate};
        }
      }

      if (clearReceiptUrl) {
        updates['receipt_url'] = null;
        if (original.receiptUrl != null) {
          changes['receipt_url'] = {'from': original.receiptUrl, 'to': null};
        }
      } else if (receiptUrl != null && receiptUrl != original.receiptUrl) {
        updates['receipt_url'] = receiptUrl;
        changes['receipt_url'] = {'from': original.receiptUrl, 'to': receiptUrl};
      }

      if (clearNotes) {
        updates['notes'] = null;
        if (original.notes != null) {
          changes['notes'] = {'from': original.notes, 'to': null};
        }
      } else if (notes != null) {
        final newNotes = notes.trim().isNotEmpty ? notes.trim() : null;
        if (newNotes != original.notes) {
          updates['notes'] = newNotes;
          changes['notes'] = {'from': original.notes, 'to': newNotes};
        }
      }

      if (isSettled != null && isSettled != original.isSettled) {
        updates['is_settled'] = isSettled;
        changes['is_settled'] = {'from': original.isSettled, 'to': isSettled};
      }

      if (clearItineraryItem) {
        updates['itinerary_item_id'] = null;
        if (original.itineraryItemId != null) {
          // Fetch original itinerary item title for activity log
          final oldItem = await _itineraryService.getItemById(original.itineraryItemId!);
          final fromTitle = oldItem?.title ?? 'Unknown';
          changes['itinerary_item_id'] = {'from': fromTitle, 'to': null};
        }
      } else if (itineraryItemId != null && itineraryItemId != original.itineraryItemId) {
        updates['itinerary_item_id'] = itineraryItemId;
        // Fetch itinerary item titles for activity log
        final idsToFetch = <String>[itineraryItemId];
        if (original.itineraryItemId != null) {
          idsToFetch.add(original.itineraryItemId!);
        }
        final items = await Future.wait(
          idsToFetch.map((id) => _itineraryService.getItemById(id)),
        );
        final itemMap = <String, ItineraryItem>{};
        for (var i = 0; i < idsToFetch.length; i++) {
          if (items[i] != null) {
            itemMap[idsToFetch[i]] = items[i]!;
          }
        }
        final fromTitle = original.itineraryItemId != null 
            ? (itemMap[original.itineraryItemId]?.title ?? 'None')
            : null;
        final toTitle = itemMap[itineraryItemId]?.title ?? 'Unknown';
        changes['itinerary_item_id'] = {'from': fromTitle, 'to': toTitle};
      }

      if (updates.isEmpty) {
        return original;
      }

      final response = await _supabase
          .from('expenses')
          .update(updates)
          .eq('id', expenseId)
          .select()
          .single();

      debugPrint('ExpenseService: Expense updated: $expenseId');
      final expense = Expense.fromJson(response);

      // Log the activity
      await _activityLogService.logActivity(
        entityType: ActivityEntityType.expense,
        entityId: expense.id,
        tripId: expense.tripId,
        action: ActivityAction.updated,
        details: {
          'title': expense.description,
          'changed_fields': updates.keys.toList(),
          'changes': changes,
        },
      );

      return expense;
    } catch (e) {
      debugPrint('ExpenseService: Error updating expense: $e');
      rethrow;
    }
  }

  /// Delete an expense
  Future<void> deleteExpense(String expenseId, {String? tripId, String? description}) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      String? logTripId = tripId;
      String? logDescription = description;

      if (logTripId == null || logDescription == null) {
        final expense = await getExpenseById(expenseId);
        logTripId ??= expense?.tripId;
        logDescription ??= expense?.description;
      }

      await _supabase.from('expenses').delete().eq('id', expenseId);
      debugPrint('ExpenseService: Expense deleted: $expenseId');

      // Log the activity
      if (logTripId != null && logDescription != null) {
        await _activityLogService.logActivity(
          entityType: ActivityEntityType.expense,
          entityId: expenseId,
          tripId: logTripId,
          action: ActivityAction.deleted,
          details: {'title': logDescription},
        );
      }
    } catch (e) {
      debugPrint('ExpenseService: Error deleting expense: $e');
      rethrow;
    }
  }

  /// Get total expenses for a trip
  Future<double> getTotalExpenses(String tripId) async {
    final expenses = await getExpenses(tripId);
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Get expense count for a trip
  Future<int> getExpenseCount(String tripId) async {
    try {
      final response = await _supabase
          .from('expenses')
          .select('id')
          .eq('trip_id', tripId);

      return (response as List).length;
    } catch (e) {
      debugPrint('ExpenseService: Error getting expense count: $e');
      return 0;
    }
  }

  /// Get expenses grouped by category with totals
  Future<Map<ExpenseCategory, double>> getExpensesByGroupedCategory(String tripId) async {
    final expenses = await getExpenses(tripId);
    final grouped = <ExpenseCategory, double>{};

    for (final expense in expenses) {
      grouped[expense.category] = (grouped[expense.category] ?? 0) + expense.amount;
    }

    return grouped;
  }

  /// Get expenses for a specific date range
  Future<List<Expense>> getExpensesInDateRange(
    String tripId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await _supabase
          .from('expenses')
          .select()
          .eq('trip_id', tripId)
          .gte('expense_date', startDate.toIso8601String().split('T').first)
          .lte('expense_date', endDate.toIso8601String().split('T').first)
          .order('expense_date', ascending: false);

      return (response as List)
          .map((item) => Expense.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ExpenseService: Error getting expenses in date range: $e');
      rethrow;
    }
  }

  /// Get expenses paid by a specific user
  Future<List<Expense>> getExpensesByUser(String tripId, String userId) async {
    try {
      final response = await _supabase
          .from('expenses')
          .select()
          .eq('trip_id', tripId)
          .eq('paid_by_user_id', userId)
          .order('expense_date', ascending: false);

      return (response as List)
          .map((item) => Expense.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ExpenseService: Error getting expenses by user: $e');
      rethrow;
    }
  }

  /// Get expenses linked to a specific itinerary item
  Future<List<Expense>> getExpensesByItineraryItem(String itineraryItemId) async {
    try {
      final response = await _supabase
          .from('expenses')
          .select()
          .eq('itinerary_item_id', itineraryItemId)
          .order('expense_date', ascending: false);

      return (response as List)
          .map((item) => Expense.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ExpenseService: Error getting expenses by itinerary item: $e');
      rethrow;
    }
  }

  /// Check if current user can edit an expense
  /// Only the person who paid can edit the expense
  Future<bool> canEditExpense(String expenseId) async {
    try {
      final expense = await getExpenseById(expenseId);
      if (expense == null) return false;
      return expense.paidByUserId == _currentUserId;
    } catch (e) {
      return false;
    }
  }

  /// Mark expense as settled
  Future<Expense> markAsSettled(String expenseId) async {
    return updateExpense(expenseId: expenseId, isSettled: true);
  }

  /// Mark expense as unsettled
  Future<Expense> markAsUnsettled(String expenseId) async {
    return updateExpense(expenseId: expenseId, isSettled: false);
  }
}
