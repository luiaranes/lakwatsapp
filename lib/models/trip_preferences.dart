enum TravelStyle {
  adventure,
  relaxation,
  cultural,
  foodie,
  nature,
  photography,
  familyFriendly,
  romantic;

  String get displayName {
    return switch (this) {
      TravelStyle.adventure => 'Adventure',
      TravelStyle.relaxation => 'Relaxation',
      TravelStyle.cultural => 'Cultural',
      TravelStyle.foodie => 'Foodie',
      TravelStyle.nature => 'Nature',
      TravelStyle.photography => 'Photography',
      TravelStyle.familyFriendly => 'Family-Friendly',
      TravelStyle.romantic => 'Romantic',
    };
  }

  String get icon {
    return switch (this) {
      TravelStyle.adventure => '🏔️',
      TravelStyle.relaxation => '🧘',
      TravelStyle.cultural => '🏛️',
      TravelStyle.foodie => '🍜',
      TravelStyle.nature => '🌿',
      TravelStyle.photography => '📷',
      TravelStyle.familyFriendly => '👨‍👩‍👧‍👦',
      TravelStyle.romantic => '💕',
    };
  }
}

enum TravelPace {
  relaxed,
  moderate,
  packed;

  String get displayName {
    return switch (this) {
      TravelPace.relaxed => 'Relaxed',
      TravelPace.moderate => 'Moderate',
      TravelPace.packed => 'Packed',
    };
  }

  String get description {
    return switch (this) {
      TravelPace.relaxed => '2-3 activities per day, lots of free time',
      TravelPace.moderate => '4-5 activities per day, balanced schedule',
      TravelPace.packed => '6+ activities per day, maximize experiences',
    };
  }
}

enum BudgetLevel {
  budget,
  moderate,
  luxury;

  String get displayName {
    return switch (this) {
      BudgetLevel.budget => 'Budget',
      BudgetLevel.moderate => 'Moderate',
      BudgetLevel.luxury => 'Luxury',
    };
  }

  String get description {
    return switch (this) {
      BudgetLevel.budget => 'Hostels, street food, public transport',
      BudgetLevel.moderate => 'Hotels, restaurants, mixed transport',
      BudgetLevel.luxury => 'Resorts, fine dining, private transfers',
    };
  }

  String get icon {
    return switch (this) {
      BudgetLevel.budget => '💰',
      BudgetLevel.moderate => '💰💰',
      BudgetLevel.luxury => '💰💰💰',
    };
  }
}

enum TravelInterest {
  beach,
  hiking,
  divingSnorkeling,
  historicSites,
  localFood,
  nightlife,
  shopping,
  wildlife,
  waterfalls,
  islands,
  sunsetViews,
  photography,
  wellness,
  watersports;

  String get displayName {
    return switch (this) {
      TravelInterest.beach => 'Beach',
      TravelInterest.hiking => 'Hiking',
      TravelInterest.divingSnorkeling => 'Diving/Snorkeling',
      TravelInterest.historicSites => 'Historic Sites',
      TravelInterest.localFood => 'Local Food',
      TravelInterest.nightlife => 'Nightlife',
      TravelInterest.shopping => 'Shopping',
      TravelInterest.wildlife => 'Wildlife',
      TravelInterest.waterfalls => 'Waterfalls',
      TravelInterest.islands => 'Island Hopping',
      TravelInterest.sunsetViews => 'Sunset Views',
      TravelInterest.photography => 'Photography Spots',
      TravelInterest.wellness => 'Wellness/Spa',
      TravelInterest.watersports => 'Water Sports',
    };
  }

  String get icon {
    return switch (this) {
      TravelInterest.beach => '🏖️',
      TravelInterest.hiking => '🥾',
      TravelInterest.divingSnorkeling => '🤿',
      TravelInterest.historicSites => '🏛️',
      TravelInterest.localFood => '🍲',
      TravelInterest.nightlife => '🎉',
      TravelInterest.shopping => '🛍️',
      TravelInterest.wildlife => '🦎',
      TravelInterest.waterfalls => '💧',
      TravelInterest.islands => '🏝️',
      TravelInterest.sunsetViews => '🌅',
      TravelInterest.photography => '📸',
      TravelInterest.wellness => '💆',
      TravelInterest.watersports => '🏄',
    };
  }
}

enum AccommodationType {
  hostel,
  hotel,
  resort,
  airbnb,
  glamping;

  String get displayName {
    return switch (this) {
      AccommodationType.hostel => 'Hostel',
      AccommodationType.hotel => 'Hotel',
      AccommodationType.resort => 'Resort',
      AccommodationType.airbnb => 'Airbnb/Vacation Rental',
      AccommodationType.glamping => 'Glamping',
    };
  }

  String get icon {
    return switch (this) {
      AccommodationType.hostel => '🛏️',
      AccommodationType.hotel => '🏨',
      AccommodationType.resort => '🏝️',
      AccommodationType.airbnb => '🏠',
      AccommodationType.glamping => '⛺',
    };
  }
}

enum TransportMode {
  car,
  publicTransport,
  plane,
  mixed;

  String get displayName {
    return switch (this) {
      TransportMode.car => 'Private Car/Rental',
      TransportMode.publicTransport => 'Public Transport',
      TransportMode.plane => 'Flying In',
      TransportMode.mixed => 'Mixed/Combination',
    };
  }

  String get description {
    return switch (this) {
      TransportMode.car => 'Driving or renting a car',
      TransportMode.publicTransport => 'Bus, train, ferry, jeepney',
      TransportMode.plane => 'Have a flight booked',
      TransportMode.mixed => 'Using different modes',
    };
  }

  String get icon {
    return switch (this) {
      TransportMode.car => '🚗',
      TransportMode.publicTransport => '🚌',
      TransportMode.plane => '✈️',
      TransportMode.mixed => '🚐',
    };
  }
}

class FlightBooking {
  final String? airline;
  final String? flightNumber;
  final String? departureTime;
  final String? arrivalTime;
  final String? departureAirport;
  final String? arrivalAirport;

  FlightBooking({
    this.airline,
    this.flightNumber,
    this.departureTime,
    this.arrivalTime,
    this.departureAirport,
    this.arrivalAirport,
  });

  Map<String, dynamic> toJson() {
    return {
      'airline': airline,
      'flight_number': flightNumber,
      'departure_time': departureTime,
      'arrival_time': arrivalTime,
      'departure_airport': departureAirport,
      'arrival_airport': arrivalAirport,
    };
  }

  factory FlightBooking.fromJson(Map<String, dynamic> json) {
    return FlightBooking(
      airline: json['airline'] as String?,
      flightNumber: json['flight_number'] as String?,
      departureTime: json['departure_time'] as String?,
      arrivalTime: json['arrival_time'] as String?,
      departureAirport: json['departure_airport'] as String?,
      arrivalAirport: json['arrival_airport'] as String?,
    );
  }

  bool get hasDetails => 
      airline != null || 
      flightNumber != null || 
      departureTime != null || 
      arrivalTime != null;
}

class HotelBooking {
  final String? hotelName;
  final String? address;
  final String? checkInTime;
  final String? checkOutTime;

  HotelBooking({
    this.hotelName,
    this.address,
    this.checkInTime,
    this.checkOutTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'hotel_name': hotelName,
      'address': address,
      'check_in_time': checkInTime,
      'check_out_time': checkOutTime,
    };
  }

  factory HotelBooking.fromJson(Map<String, dynamic> json) {
    return HotelBooking(
      hotelName: json['hotel_name'] as String?,
      address: json['address'] as String?,
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
    );
  }

  bool get hasDetails => hotelName != null || address != null;
}

class TripPreferences {
  final DateTime startDate;
  final DateTime endDate;
  final int adults;
  final int children;
  final int infants;
  final BudgetLevel budgetLevel;
  final double? specificBudget;
  final String currency;
  final List<TravelStyle> travelStyles;
  final TravelPace pace;
  final List<TravelInterest> interests;
  final AccommodationType? accommodation;
  final String? specialRequests;
  final TransportMode transportMode;
  final FlightBooking? flightBooking;
  final FlightBooking? returnFlightBooking;
  final bool hasHotelBooking;
  final HotelBooking? hotelBooking;

  TripPreferences({
    required this.startDate,
    required this.endDate,
    this.adults = 1,
    this.children = 0,
    this.infants = 0,
    this.budgetLevel = BudgetLevel.moderate,
    this.specificBudget,
    this.currency = 'PHP',
    this.travelStyles = const [],
    this.pace = TravelPace.moderate,
    this.interests = const [],
    this.accommodation,
    this.specialRequests,
    this.transportMode = TransportMode.publicTransport,
    this.flightBooking,
    this.returnFlightBooking,
    this.hasHotelBooking = false,
    this.hotelBooking,
  });

  int get totalTravelers => adults + children + infants;

  int get tripDays => endDate.difference(startDate).inDays + 1;

  factory TripPreferences.fromJson(Map<String, dynamic> json) {
    return TripPreferences(
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      adults: json['adults'] as int? ?? 1,
      children: json['children'] as int? ?? 0,
      infants: json['infants'] as int? ?? 0,
      budgetLevel: BudgetLevel.values.firstWhere(
        (e) => e.name == json['budget_level'],
        orElse: () => BudgetLevel.moderate,
      ),
      specificBudget: (json['specific_budget'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'PHP',
      travelStyles: (json['travel_styles'] as List<dynamic>?)
          ?.map((s) => TravelStyle.values.firstWhere(
                (e) => e.name == s,
                orElse: () => TravelStyle.adventure,
              ))
          .toList() ?? [],
      pace: TravelPace.values.firstWhere(
        (e) => e.name == json['pace'],
        orElse: () => TravelPace.moderate,
      ),
      interests: (json['interests'] as List<dynamic>?)
          ?.map((i) => TravelInterest.values.firstWhere(
                (e) => e.name == i,
                orElse: () => TravelInterest.beach,
              ))
          .toList() ?? [],
      accommodation: json['accommodation'] != null
          ? AccommodationType.values.firstWhere(
              (e) => e.name == json['accommodation'],
              orElse: () => AccommodationType.hotel,
            )
          : null,
      specialRequests: json['special_requests'] as String?,
      transportMode: TransportMode.values.firstWhere(
        (e) => e.name == json['transport_mode'],
        orElse: () => TransportMode.publicTransport,
      ),
      flightBooking: json['flight_booking'] != null
          ? FlightBooking.fromJson(json['flight_booking'] as Map<String, dynamic>)
          : null,
      returnFlightBooking: json['return_flight_booking'] != null
          ? FlightBooking.fromJson(json['return_flight_booking'] as Map<String, dynamic>)
          : null,
      hasHotelBooking: json['has_hotel_booking'] as bool? ?? false,
      hotelBooking: json['hotel_booking'] != null
          ? HotelBooking.fromJson(json['hotel_booking'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      'trip_days': tripDays,
      'adults': adults,
      'children': children,
      'infants': infants,
      'total_travelers': totalTravelers,
      'budget_level': budgetLevel.name,
      'specific_budget': specificBudget,
      'currency': currency,
      'travel_styles': travelStyles.map((s) => s.name).toList(),
      'pace': pace.name,
      'interests': interests.map((i) => i.name).toList(),
      'accommodation': accommodation?.name,
      'special_requests': specialRequests,
      'transport_mode': transportMode.name,
      'flight_booking': flightBooking?.toJson(),
      'return_flight_booking': returnFlightBooking?.toJson(),
      'has_hotel_booking': hasHotelBooking,
      'hotel_booking': hotelBooking?.toJson(),
    };
  }

  TripPreferences copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? adults,
    int? children,
    int? infants,
    BudgetLevel? budgetLevel,
    double? specificBudget,
    String? currency,
    List<TravelStyle>? travelStyles,
    TravelPace? pace,
    List<TravelInterest>? interests,
    AccommodationType? accommodation,
    String? specialRequests,
    TransportMode? transportMode,
    FlightBooking? flightBooking,
    FlightBooking? returnFlightBooking,
    bool? hasHotelBooking,
    HotelBooking? hotelBooking,
    bool clearSpecificBudget = false,
    bool clearSpecialRequests = false,
    bool clearAccommodation = false,
    bool clearFlightBooking = false,
    bool clearReturnFlightBooking = false,
    bool clearHotelBooking = false,
  }) {
    return TripPreferences(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      adults: adults ?? this.adults,
      children: children ?? this.children,
      infants: infants ?? this.infants,
      budgetLevel: budgetLevel ?? this.budgetLevel,
      specificBudget: clearSpecificBudget ? null : (specificBudget ?? this.specificBudget),
      currency: currency ?? this.currency,
      travelStyles: travelStyles ?? this.travelStyles,
      pace: pace ?? this.pace,
      interests: interests ?? this.interests,
      accommodation: clearAccommodation ? null : (accommodation ?? this.accommodation),
      specialRequests: clearSpecialRequests ? null : (specialRequests ?? this.specialRequests),
      transportMode: transportMode ?? this.transportMode,
      flightBooking: clearFlightBooking ? null : (flightBooking ?? this.flightBooking),
      returnFlightBooking: clearReturnFlightBooking ? null : (returnFlightBooking ?? this.returnFlightBooking),
      hasHotelBooking: hasHotelBooking ?? this.hasHotelBooking,
      hotelBooking: clearHotelBooking ? null : (hotelBooking ?? this.hotelBooking),
    );
  }
}
