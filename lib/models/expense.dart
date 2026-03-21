enum ExpenseCategory {
  transport,
  accommodation,
  food,
  activities,
  shopping,
  fees,
  tips,
  other;

  static ExpenseCategory fromString(String value) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ExpenseCategory.other,
    );
  }

  String get displayName {
    switch (this) {
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.accommodation:
        return 'Accommodation';
      case ExpenseCategory.food:
        return 'Food & Drinks';
      case ExpenseCategory.activities:
        return 'Activities';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.fees:
        return 'Fees & Tickets';
      case ExpenseCategory.tips:
        return 'Tips';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case ExpenseCategory.transport:
        return '🚗';
      case ExpenseCategory.accommodation:
        return '🏨';
      case ExpenseCategory.food:
        return '🍽️';
      case ExpenseCategory.activities:
        return '🎯';
      case ExpenseCategory.shopping:
        return '🛍️';
      case ExpenseCategory.fees:
        return '🎟️';
      case ExpenseCategory.tips:
        return '💵';
      case ExpenseCategory.other:
        return '📝';
    }
  }
}

class Expense {
  final String id;
  final String tripId;
  final String paidByUserId;
  final double amount;
  final String currency;
  final ExpenseCategory category;
  final String description;
  final DateTime expenseDate;
  final String? receiptUrl;
  final String? notes;
  final bool isSettled;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.tripId,
    required this.paidByUserId,
    required this.amount,
    this.currency = 'PHP',
    this.category = ExpenseCategory.other,
    required this.description,
    required this.expenseDate,
    this.receiptUrl,
    this.notes,
    this.isSettled = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      paidByUserId: json['paid_by_user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'PHP',
      category:
          ExpenseCategory.fromString(json['category'] as String? ?? 'other'),
      description: json['description'] as String,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      receiptUrl: json['receipt_url'] as String?,
      notes: json['notes'] as String?,
      isSettled: json['is_settled'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'paid_by_user_id': paidByUserId,
      'amount': amount,
      'currency': currency,
      'category': category.name,
      'description': description,
      'expense_date': expenseDate.toIso8601String().split('T').first,
      'receipt_url': receiptUrl,
      'notes': notes,
      'is_settled': isSettled,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'trip_id': tripId,
      'paid_by_user_id': paidByUserId,
      'amount': amount,
      'currency': currency,
      'category': category.name,
      'description': description,
      'expense_date': expenseDate.toIso8601String().split('T').first,
      'receipt_url': receiptUrl,
      'notes': notes,
      'is_settled': isSettled,
    };
  }

  Expense copyWith({
    String? id,
    String? tripId,
    String? paidByUserId,
    double? amount,
    String? currency,
    ExpenseCategory? category,
    String? description,
    DateTime? expenseDate,
    String? receiptUrl,
    String? notes,
    bool? isSettled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      description: description ?? this.description,
      expenseDate: expenseDate ?? this.expenseDate,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      notes: notes ?? this.notes,
      isSettled: isSettled ?? this.isSettled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedAmount => '$currency ${amount.toStringAsFixed(2)}';
}
