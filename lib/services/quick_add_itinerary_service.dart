import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/models/parsed_itinerary.dart';
import 'package:larga/models/itinerary_item.dart';

class QuickAddItineraryService {
  final _supabase = Supabase.instance.client;

  Future<ParsedItinerary> parseItineraryText({
    required String text,
    int? dayNumber,
    String? tripCurrency,
    String? tripStartDate,
  }) async {
    try {
      debugPrint('QuickAddItineraryService: Parsing text: $text');

      final response = await _supabase.functions.invoke(
        'parse-itinerary-text',
        body: {
          'text': text,
          'day_number': dayNumber,
          'trip_currency': tripCurrency ?? 'PHP',
          'trip_start_date': tripStartDate,
        },
      );

      if (response.status != 200) {
        debugPrint(
            'QuickAddItineraryService: Error response: ${response.data}');
        throw Exception('Failed to parse itinerary text');
      }

      final data = response.data as Map<String, dynamic>;

      final error = data['error'];
      if (error != null && error.toString().isNotEmpty) {
        throw Exception(error.toString());
      }

      debugPrint('QuickAddItineraryService: Parsed result: $data');
      return ParsedItinerary.fromJson(data, text);
    } catch (e) {
      debugPrint('QuickAddItineraryService: Error parsing text: $e');
      return _fallbackParse(text, tripCurrency);
    }
  }

  ParsedItinerary _fallbackParse(String text, String? tripCurrency) {
    final lowerText = text.toLowerCase();

    String? title = _extractTitle(text);
    String? startTime = _extractTime(text);
    double? cost = _extractCost(text);
    ItineraryCategory? category = _inferCategory(lowerText);

    return ParsedItinerary(
      title: title,
      startTime: startTime,
      estimatedCost: cost,
      currency: tripCurrency ?? 'PHP',
      suggestedCategory: category,
      confidence: 0.3,
      rawText: text,
    );
  }

  String? _extractTitle(String text) {
    String cleaned = text
        .replaceAll(RegExp(r'\d+:\d+\s*(am|pm)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'\d+\s*(am|pm)', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\$₱€¥]?\d+\.?\d*\s*(php|pesos?|usd|dollars?)?',
            caseSensitive: false), '')
        .trim();

    if (cleaned.isEmpty) return text;

    if (cleaned.length > 50) {
      cleaned = cleaned.substring(0, 50);
    }

    return cleaned.isNotEmpty ? cleaned : null;
  }

  String? _extractTime(String text) {
    final timePattern = RegExp(
      r'(\d{1,2}):?(\d{2})?\s*(am|pm)?|(\d{1,2})\s*(am|pm)',
      caseSensitive: false,
    );

    final match = timePattern.firstMatch(text);
    if (match == null) {
      final lowerText = text.toLowerCase();
      if (lowerText.contains('morning') || lowerText.contains('breakfast')) {
        return '09:00';
      } else if (lowerText.contains('lunch') || lowerText.contains('noon')) {
        return '12:00';
      } else if (lowerText.contains('afternoon')) {
        return '14:00';
      } else if (lowerText.contains('evening') ||
          lowerText.contains('dinner')) {
        return '18:00';
      } else if (lowerText.contains('sunset')) {
        return '17:30';
      }
      return null;
    }

    String hourStr = match.group(1) ?? match.group(4) ?? '0';
    String minuteStr = match.group(2) ?? '00';
    String? ampm = match.group(3) ?? match.group(5);

    int hour = int.tryParse(hourStr) ?? 0;
    int minute = int.tryParse(minuteStr) ?? 0;

    if (ampm != null) {
      ampm = ampm.toLowerCase();
      if (ampm == 'pm' && hour < 12) {
        hour += 12;
      } else if (ampm == 'am' && hour == 12) {
        hour = 0;
      }
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  double? _extractCost(String text) {
    final costPattern = RegExp(
      r'[\$₱€¥]?\s*(\d+(?:,\d{3})*(?:\.\d{2})?)\s*(php|pesos?|usd|dollars?)?',
      caseSensitive: false,
    );

    final matches = costPattern.allMatches(text).toList();
    if (matches.isEmpty) return null;

    double? highestCost;
    for (final match in matches) {
      final amountStr = match.group(1)?.replaceAll(',', '') ?? '0';
      final amount = double.tryParse(amountStr);
      if (amount != null && (highestCost == null || amount > highestCost)) {
        highestCost = amount;
      }
    }

    return highestCost;
  }

  ItineraryCategory? _inferCategory(String lowerText) {
    if (RegExp(
            r'flight|taxi|grab|bus|train|ferry|boat|jeep|tricycle|drive|airport|terminal')
        .hasMatch(lowerText)) {
      return ItineraryCategory.transport;
    }
    if (RegExp(r'hotel|airbnb|hostel|resort|check.?in|check.?out|villa')
        .hasMatch(lowerText)) {
      return ItineraryCategory.accommodation;
    }
    if (RegExp(r'breakfast|lunch|dinner|eat|food|restaurant|cafe|coffee|meal')
        .hasMatch(lowerText)) {
      return ItineraryCategory.food;
    }
    if (RegExp(r'tour|dive|snorkel|hike|trek|kayak|surf|activity|adventure')
        .hasMatch(lowerText)) {
      return ItineraryCategory.activity;
    }
    if (RegExp(r'visit|museum|temple|church|landmark|view|sunset|sunrise|beach|explore')
        .hasMatch(lowerText)) {
      return ItineraryCategory.sightseeing;
    }
    if (RegExp(r'shop|mall|market|buy|souvenir').hasMatch(lowerText)) {
      return ItineraryCategory.shopping;
    }
    if (RegExp(r'rest|free|nap|relax|downtime').hasMatch(lowerText)) {
      return ItineraryCategory.rest;
    }

    return null;
  }
}
