import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/parsed_receipt.dart';

class ReceiptScanningService {
  final SupabaseClient _supabase = Supabase.instance.client;
  TextRecognizer? _textRecognizer;

  TextRecognizer get textRecognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }

  Future<String> extractTextFromImage(File imageFile) async {
    if (kIsWeb) {
      throw UnsupportedError('ML Kit text recognition is not supported on web');
    }

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await textRecognizer.processImage(inputImage);

      debugPrint('ReceiptScanningService: Extracted ${recognizedText.text.length} characters');
      return recognizedText.text;
    } catch (e) {
      debugPrint('ReceiptScanningService: Error extracting text: $e');
      rethrow;
    }
  }

  Future<String> uploadReceiptImage(File imageFile, String tripId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();
      final fileName = 'receipts/$tripId/${userId}_$timestamp.$extension';

      await _supabase.storage.from('receipts').upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      final publicUrl = _supabase.storage.from('receipts').getPublicUrl(fileName);
      debugPrint('ReceiptScanningService: Uploaded receipt to $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('ReceiptScanningService: Error uploading receipt: $e');
      rethrow;
    }
  }

  Future<ParsedReceipt> parseReceiptWithAI({
    required String rawText,
    String? imageUrl,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'parse-receipt',
        body: {
          'raw_text': rawText,
          'image_url': imageUrl,
        },
      );

      if (response.status != 200) {
        debugPrint('ReceiptScanningService: Edge function error: ${response.data}');
        throw Exception('Failed to parse receipt: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;
      final receipt = ParsedReceipt.fromJson(data);

      debugPrint('ReceiptScanningService: Parsed receipt - '
          'merchant: ${receipt.merchant}, '
          'amount: ${receipt.amount}, '
          'confidence: ${receipt.confidence}');

      return receipt.copyWith(
        receiptUrl: imageUrl,
        rawText: rawText,
      );
    } catch (e) {
      debugPrint('ReceiptScanningService: Error parsing receipt with AI: $e');
      return _fallbackParsing(rawText, imageUrl);
    }
  }

  ParsedReceipt _fallbackParsing(String rawText, String? imageUrl) {
    final amount = _extractAmount(rawText);
    final date = _extractDate(rawText);
    final merchant = _extractMerchant(rawText);

    return ParsedReceipt(
      merchant: merchant,
      date: date,
      amount: amount,
      currency: 'PHP',
      confidence: 0.3,
      receiptUrl: imageUrl,
      rawText: rawText,
    );
  }

  double? _extractAmount(String text) {
    final patterns = [
      RegExp(r'(?:TOTAL|GRAND TOTAL|AMOUNT DUE|TOTAL DUE|CASH|SUBTOTAL)[:\s]*[₱P]?\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'[₱P]\s*([\d,]+\.?\d*)'),
      RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)\s*$', multiLine: true),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      double? maxAmount;
      for (final match in matches) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        if (amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0) {
            if (maxAmount == null || amount > maxAmount) {
              maxAmount = amount;
            }
          }
        }
      }
      if (maxAmount != null) return maxAmount;
    }

    return null;
  }

  DateTime? _extractDate(String text) {
    final patterns = [
      RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})'),
      RegExp(r'(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})'),
      RegExp(r'(\w{3,9})\s+(\d{1,2}),?\s+(\d{4})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          if (pattern.pattern.startsWith(r'(\w{3,9})')) {
            final monthStr = match.group(1)!;
            final day = int.parse(match.group(2)!);
            final year = int.parse(match.group(3)!);
            final month = _parseMonth(monthStr);
            if (month != null) {
              return DateTime(year, month, day);
            }
          } else if (pattern.pattern.startsWith(r'(\d{4})')) {
            final year = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final day = int.parse(match.group(3)!);
            return DateTime(year, month, day);
          } else {
            final first = int.parse(match.group(1)!);
            final second = int.parse(match.group(2)!);
            var year = int.parse(match.group(3)!);
            if (year < 100) year += 2000;

            if (first > 12) {
              return DateTime(year, second, first);
            } else {
              return DateTime(year, first, second);
            }
          }
        } catch (_) {
          continue;
        }
      }
    }

    return null;
  }

  int? _parseMonth(String monthStr) {
    const months = {
      'jan': 1, 'january': 1,
      'feb': 2, 'february': 2,
      'mar': 3, 'march': 3,
      'apr': 4, 'april': 4,
      'may': 5,
      'jun': 6, 'june': 6,
      'jul': 7, 'july': 7,
      'aug': 8, 'august': 8,
      'sep': 9, 'sept': 9, 'september': 9,
      'oct': 10, 'october': 10,
      'nov': 11, 'november': 11,
      'dec': 12, 'december': 12,
    };
    return months[monthStr.toLowerCase()];
  }

  String? _extractMerchant(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return null;

    for (var i = 0; i < lines.length && i < 5; i++) {
      final line = lines[i].trim();
      if (line.length >= 3 &&
          line.length <= 50 &&
          !RegExp(r'^[\d\s\-/:.]+$').hasMatch(line) &&
          !RegExp(r'(receipt|invoice|tin|vat|address|tel|phone)', caseSensitive: false).hasMatch(line)) {
        return line;
      }
    }

    return lines.isNotEmpty ? lines.first.trim() : null;
  }

  Future<ParsedReceipt> scanReceipt({
    required File imageFile,
    required String tripId,
  }) async {
    final rawText = await extractTextFromImage(imageFile);

    final imageUrl = await uploadReceiptImage(imageFile, tripId);

    final parsedReceipt = await parseReceiptWithAI(
      rawText: rawText,
      imageUrl: imageUrl,
    );

    return parsedReceipt;
  }

  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}
