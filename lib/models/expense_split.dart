enum SplitType {
  equal,
  percentage,
  exact;

  static SplitType fromString(String value) {
    return SplitType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SplitType.equal,
    );
  }
}

class ExpenseSplit {
  final String id;
  final String expenseId;
  final String userId;
  final double amount;
  final double? percentage;
  final SplitType splitType;
  final bool isSettled;
  final DateTime? settledAt;
  final DateTime createdAt;

  ExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.amount,
    this.percentage,
    this.splitType = SplitType.equal,
    this.isSettled = false,
    this.settledAt,
    required this.createdAt,
  });

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) {
    return ExpenseSplit(
      id: json['id'] as String,
      expenseId: json['expense_id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      percentage: (json['percentage'] as num?)?.toDouble(),
      splitType: SplitType.fromString(json['split_type'] as String? ?? 'equal'),
      isSettled: json['is_settled'] as bool? ?? false,
      settledAt: json['settled_at'] != null
          ? DateTime.parse(json['settled_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expense_id': expenseId,
      'user_id': userId,
      'amount': amount,
      'percentage': percentage,
      'split_type': splitType.name,
      'is_settled': isSettled,
      'settled_at': settledAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'expense_id': expenseId,
      'user_id': userId,
      'amount': amount,
      'percentage': percentage,
      'split_type': splitType.name,
      'is_settled': isSettled,
    };
  }

  ExpenseSplit copyWith({
    String? id,
    String? expenseId,
    String? userId,
    double? amount,
    double? percentage,
    SplitType? splitType,
    bool? isSettled,
    DateTime? settledAt,
    DateTime? createdAt,
  }) {
    return ExpenseSplit(
      id: id ?? this.id,
      expenseId: expenseId ?? this.expenseId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
      splitType: splitType ?? this.splitType,
      isSettled: isSettled ?? this.isSettled,
      settledAt: settledAt ?? this.settledAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
