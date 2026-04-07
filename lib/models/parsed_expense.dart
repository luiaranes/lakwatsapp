import 'package:larga/models/expense.dart';

class ParsedExpense {
  final String? description;
  final double? amount;
  final String? currency;
  final ExpenseCategory? suggestedCategory;
  final DateTime? date;
  final List<String>? splitWith;
  final String? notes;
  final double confidence;
  final String? rawText;

  ParsedExpense({
    this.description,
    this.amount,
    this.currency,
    this.suggestedCategory,
    this.date,
    this.splitWith,
    this.notes,
    this.confidence = 0.0,
    this.rawText,
  });

  factory ParsedExpense.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['date'] != null) {
      try {
        parsedDate = DateTime.parse(json['date'] as String);
      } catch (_) {
        parsedDate = null;
      }
    }

    ExpenseCategory? category;
    if (json['category'] != null) {
      category = ExpenseCategory.fromString(json['category'] as String);
    }

    List<String>? splitWith;
    if (json['split_with'] != null) {
      splitWith = (json['split_with'] as List).map((e) => e.toString()).toList();
    }

    return ParsedExpense(
      description: json['description'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'PHP',
      suggestedCategory: category,
      date: parsedDate,
      splitWith: splitWith,
      notes: json['notes'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      rawText: json['raw_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount,
      'currency': currency,
      'category': suggestedCategory?.name,
      'date': date?.toIso8601String().split('T').first,
      'split_with': splitWith,
      'notes': notes,
      'confidence': confidence,
      'raw_text': rawText,
    };
  }

  ParsedExpense copyWith({
    String? description,
    double? amount,
    String? currency,
    ExpenseCategory? suggestedCategory,
    DateTime? date,
    List<String>? splitWith,
    String? notes,
    double? confidence,
    String? rawText,
  }) {
    return ParsedExpense(
      description: description ?? this.description,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      date: date ?? this.date,
      splitWith: splitWith ?? this.splitWith,
      notes: notes ?? this.notes,
      confidence: confidence ?? this.confidence,
      rawText: rawText ?? this.rawText,
    );
  }

  bool get hasValidAmount => amount != null && amount! > 0;
  bool get hasValidDescription => description != null && description!.isNotEmpty;
  bool get hasSplitInfo => splitWith != null && splitWith!.isNotEmpty;

  String get displayAmount {
    if (amount == null) return 'Unknown';
    final curr = currency ?? 'PHP';
    final symbol = _currencySymbol(curr);
    return '$symbol${amount!.toStringAsFixed(2)}';
  }

  String _currencySymbol(String currency) {
    return switch (currency.toUpperCase()) {
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
}
