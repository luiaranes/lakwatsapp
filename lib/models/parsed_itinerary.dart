import 'package:larga/models/itinerary_item.dart';

class ParsedItinerary {
  final String? title;
  final String? description;
  final String? startTime;
  final String? endTime;
  final String? location;
  final ItineraryCategory? suggestedCategory;
  final double? estimatedCost;
  final String? currency;
  final String? notes;
  final double confidence;
  final String rawText;

  ParsedItinerary({
    this.title,
    this.description,
    this.startTime,
    this.endTime,
    this.location,
    this.suggestedCategory,
    this.estimatedCost,
    this.currency,
    this.notes,
    this.confidence = 0.0,
    required this.rawText,
  });

  factory ParsedItinerary.fromJson(Map<String, dynamic> json, String rawText) {
    ItineraryCategory? category;
    if (json['category'] != null) {
      category = ItineraryCategory.fromString(json['category'] as String);
    }

    return ParsedItinerary(
      title: json['title'] as String?,
      description: json['description'] as String?,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      location: json['location'] as String?,
      suggestedCategory: category,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'PHP',
      notes: json['notes'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      rawText: rawText,
    );
  }

  bool get hasValidTitle => title != null && title!.isNotEmpty;
  bool get hasValidTime => startTime != null && startTime!.isNotEmpty;
  bool get hasValidLocation => location != null && location!.isNotEmpty;
  bool get hasValidCost => estimatedCost != null && estimatedCost! > 0;

  String get displayCost {
    if (!hasValidCost) return '';
    final symbol = _currencySymbol(currency ?? 'PHP');
    return '$symbol${estimatedCost!.toStringAsFixed(0)}';
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

  @override
  String toString() {
    return 'ParsedItinerary(title: $title, startTime: $startTime, location: $location, category: $suggestedCategory, confidence: $confidence)';
  }
}
