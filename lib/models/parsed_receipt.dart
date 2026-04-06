import 'package:larga/models/expense.dart';

class ReceiptLineItem {
  final String description;
  final double? quantity;
  final double? price;

  ReceiptLineItem({
    required this.description,
    this.quantity,
    this.price,
  });

  factory ReceiptLineItem.fromJson(Map<String, dynamic> json) {
    return ReceiptLineItem(
      description: json['description'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'price': price,
    };
  }
}

class ParsedReceipt {
  final String? merchant;
  final DateTime? date;
  final double? amount;
  final String? currency;
  final ExpenseCategory? suggestedCategory;
  final List<ReceiptLineItem>? lineItems;
  final double confidence;
  final String? receiptUrl;
  final String? rawText;

  ParsedReceipt({
    this.merchant,
    this.date,
    this.amount,
    this.currency,
    this.suggestedCategory,
    this.lineItems,
    this.confidence = 0.0,
    this.receiptUrl,
    this.rawText,
  });

  factory ParsedReceipt.fromJson(Map<String, dynamic> json) {
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

    List<ReceiptLineItem>? items;
    if (json['line_items'] != null) {
      items = (json['line_items'] as List)
          .map((item) => ReceiptLineItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return ParsedReceipt(
      merchant: json['merchant'] as String?,
      date: parsedDate,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'PHP',
      suggestedCategory: category,
      lineItems: items,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      receiptUrl: json['receipt_url'] as String?,
      rawText: json['raw_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchant': merchant,
      'date': date?.toIso8601String().split('T').first,
      'amount': amount,
      'currency': currency,
      'category': suggestedCategory?.name,
      'line_items': lineItems?.map((item) => item.toJson()).toList(),
      'confidence': confidence,
      'receipt_url': receiptUrl,
      'raw_text': rawText,
    };
  }

  ParsedReceipt copyWith({
    String? merchant,
    DateTime? date,
    double? amount,
    String? currency,
    ExpenseCategory? suggestedCategory,
    List<ReceiptLineItem>? lineItems,
    double? confidence,
    String? receiptUrl,
    String? rawText,
  }) {
    return ParsedReceipt(
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      lineItems: lineItems ?? this.lineItems,
      confidence: confidence ?? this.confidence,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      rawText: rawText ?? this.rawText,
    );
  }

  bool get hasValidAmount => amount != null && amount! > 0;
  bool get hasValidDate => date != null;
  bool get hasValidMerchant => merchant != null && merchant!.isNotEmpty;

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
