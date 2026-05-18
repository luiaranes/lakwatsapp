enum BookingType {
  flight,
  hotel,
  activity,
  transport,
  other;

  static BookingType fromString(String value) {
    return BookingType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BookingType.other,
    );
  }

  String get displayName {
    switch (this) {
      case BookingType.flight:
        return 'Flight';
      case BookingType.hotel:
        return 'Hotel';
      case BookingType.activity:
        return 'Activity';
      case BookingType.transport:
        return 'Transport';
      case BookingType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case BookingType.flight:
        return '✈️';
      case BookingType.hotel:
        return '🏨';
      case BookingType.activity:
        return '🎯';
      case BookingType.transport:
        return '🚗';
      case BookingType.other:
        return '📋';
    }
  }
}

enum BookingSource {
  manual,
  email;

  static BookingSource fromString(String value) {
    return BookingSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BookingSource.manual,
    );
  }
}

class Booking {
  final String id;
  final String tripId;
  final String createdByUserId;
  final BookingType bookingType;
  final BookingSource source;
  final String title;
  final String? provider;
  final String? confirmationNumber;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? startTime;
  final String? endTime;
  final String? location;
  final String? address;
  final double? amount;
  final String? currency;
  final String? notes;
  final String? itineraryItemId;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final DateTime updatedAt;

  Booking({
    required this.id,
    required this.tripId,
    required this.createdByUserId,
    this.bookingType = BookingType.other,
    this.source = BookingSource.manual,
    required this.title,
    this.provider,
    this.confirmationNumber,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.location,
    this.address,
    this.amount,
    this.currency,
    this.notes,
    this.itineraryItemId,
    this.details = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      createdByUserId: json['created_by_user_id'] as String,
      bookingType: BookingType.fromString(json['booking_type'] as String? ?? 'other'),
      source: BookingSource.fromString(json['source'] as String? ?? 'manual'),
      title: json['title'] as String,
      provider: json['provider'] as String?,
      confirmationNumber: json['confirmation_number'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      location: json['location'] as String?,
      address: json['address'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      notes: json['notes'] as String?,
      itineraryItemId: json['itinerary_item_id'] as String?,
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'] as Map)
          : {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'trip_id': tripId,
      'created_by_user_id': createdByUserId,
      'booking_type': bookingType.name,
      'source': source.name,
      'title': title.trim(),
      'provider': provider?.trim(),
      'confirmation_number': confirmationNumber?.trim(),
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'start_time': startTime?.trim(),
      'end_time': endTime?.trim(),
      'location': location?.trim(),
      'address': address?.trim(),
      'amount': amount,
      'currency': currency,
      'notes': notes?.trim(),
      'itinerary_item_id': itineraryItemId,
      'details': details,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'booking_type': bookingType.name,
      'title': title.trim(),
      'provider': provider?.trim(),
      'confirmation_number': confirmationNumber?.trim(),
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'start_time': startTime?.trim(),
      'end_time': endTime?.trim(),
      'location': location?.trim(),
      'address': address?.trim(),
      'amount': amount,
      'currency': currency,
      'notes': notes?.trim(),
      'itinerary_item_id': itineraryItemId,
      'details': details,
    };
  }

  Booking copyWith({
    String? id,
    String? tripId,
    String? createdByUserId,
    BookingType? bookingType,
    BookingSource? source,
    String? title,
    String? provider,
    String? confirmationNumber,
    DateTime? startDate,
    DateTime? endDate,
    String? startTime,
    String? endTime,
    String? location,
    String? address,
    double? amount,
    String? currency,
    String? notes,
    String? itineraryItemId,
    Map<String, dynamic>? details,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearItineraryItemId = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearAmount = false,
  }) {
    return Booking(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      bookingType: bookingType ?? this.bookingType,
      source: source ?? this.source,
      title: title ?? this.title,
      provider: provider ?? this.provider,
      confirmationNumber: confirmationNumber ?? this.confirmationNumber,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      address: address ?? this.address,
      amount: clearAmount ? null : (amount ?? this.amount),
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      itineraryItemId: clearItineraryItemId
          ? null
          : (itineraryItemId ?? this.itineraryItemId),
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String? get detailAirline => details['airline'] as String?;
  String? get detailFlightNumber => details['flight_number'] as String?;
  String? get detailDepartureAirport => details['departure_airport'] as String?;
  String? get detailArrivalAirport => details['arrival_airport'] as String?;

  String? get formattedAmount {
    if (amount == null) return null;
    return '${currency ?? 'PHP'} ${amount!.toStringAsFixed(2)}';
  }
}
