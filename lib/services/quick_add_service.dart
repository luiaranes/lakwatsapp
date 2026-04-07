import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/parsed_expense.dart';

class TripMemberInfo {
  final String userId;
  final String name;

  TripMemberInfo({required this.userId, required this.name});

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
      };
}

class QuickAddService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<ParsedExpense> parseExpenseText({
    required String text,
    String? tripCurrency,
    List<TripMemberInfo>? tripMembers,
  }) async {
    try {
      debugPrint('QuickAddService: Parsing text: "$text"');

      final response = await _supabase.functions.invoke(
        'parse-expense-text',
        body: {
          'text': text,
          'trip_currency': tripCurrency,
          'trip_members': tripMembers?.map((m) => m.toJson()).toList(),
        },
      );

      if (response.status != 200) {
        debugPrint('QuickAddService: Edge function error: ${response.data}');
        throw Exception('Failed to parse expense: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;

      final error = data['error'];
      if (error != null && error.toString().isNotEmpty) {
        throw Exception(error.toString());
      }

      final parsedExpense = ParsedExpense.fromJson(data);

      debugPrint('QuickAddService: Parsed expense - '
          'description: ${parsedExpense.description}, '
          'amount: ${parsedExpense.amount}, '
          'confidence: ${parsedExpense.confidence}');

      return parsedExpense.copyWith(rawText: text);
    } catch (e) {
      debugPrint('QuickAddService: Error parsing expense: $e');
      return _fallbackParsing(text);
    }
  }

  ParsedExpense _fallbackParsing(String text) {
    final amount = _extractAmount(text);
    final currency = _extractCurrency(text);
    final description = _extractDescription(text);

    return ParsedExpense(
      description: description,
      amount: amount,
      currency: currency ?? 'PHP',
      confidence: 0.3,
      rawText: text,
    );
  }

  double? _extractAmount(String text) {
    final patterns = [
      RegExp(r'[₱P$€¥฿₩]\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'([\d,]+\.?\d*)\s*(?:pesos?|php|usd|dollars?|euros?)', caseSensitive: false),
      RegExp(r'\b([\d,]+\.?\d{0,2})\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        if (amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0 && amount < 10000000) {
            return amount;
          }
        }
      }
    }

    return null;
  }

  String? _extractCurrency(String text) {
    final lowerText = text.toLowerCase();

    if (lowerText.contains('₱') ||
        lowerText.contains('php') ||
        lowerText.contains('peso')) {
      return 'PHP';
    }
    if (lowerText.contains('\$') ||
        lowerText.contains('usd') ||
        lowerText.contains('dollar')) {
      return 'USD';
    }
    if (lowerText.contains('€') || lowerText.contains('eur')) {
      return 'EUR';
    }
    if (lowerText.contains('¥') ||
        lowerText.contains('jpy') ||
        lowerText.contains('yen')) {
      return 'JPY';
    }
    if (lowerText.contains('s\$') || lowerText.contains('sgd')) {
      return 'SGD';
    }
    if (lowerText.contains('฿') || lowerText.contains('thb')) {
      return 'THB';
    }
    if (lowerText.contains('₩') || lowerText.contains('krw')) {
      return 'KRW';
    }

    return null;
  }

  String? _extractDescription(String text) {
    var desc = text
        .replaceAll(RegExp(r'[₱P$€¥฿₩]\s*[\d,]+\.?\d*'), '')
        .replaceAll(RegExp(r'[\d,]+\.?\d*\s*(?:pesos?|php|usd|dollars?|euros?)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b\d+\b'), '')
        .trim();

    if (desc.length > 100) {
      desc = desc.substring(0, 100);
    }

    return desc.isNotEmpty ? desc : null;
  }
}
