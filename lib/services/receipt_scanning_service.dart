import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/parsed_receipt.dart';

class ReceiptScanningService {
  final SupabaseClient _supabase = Supabase.instance.client;

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
    required String imageUrl,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'parse-receipt',
        body: {
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

      return receipt.copyWith(receiptUrl: imageUrl);
    } catch (e) {
      debugPrint('ReceiptScanningService: Error parsing receipt with AI: $e');
      return ParsedReceipt(
        confidence: 0.0,
        receiptUrl: imageUrl,
        currency: 'PHP',
      );
    }
  }

  Future<ParsedReceipt> scanReceipt({
    required File imageFile,
    required String tripId,
  }) async {
    final imageUrl = await uploadReceiptImage(imageFile, tripId);

    final parsedReceipt = await parseReceiptWithAI(imageUrl: imageUrl);

    return parsedReceipt;
  }
}
