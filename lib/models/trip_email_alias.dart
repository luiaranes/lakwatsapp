class TripEmailAlias {
  final String tripId;
  final String localPart;
  final String emailAddress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastRegeneratedAt;

  TripEmailAlias({
    required this.tripId,
    required this.localPart,
    required this.emailAddress,
    required this.createdAt,
    required this.updatedAt,
    this.lastRegeneratedAt,
  });

  factory TripEmailAlias.fromJson(Map<String, dynamic> json) {
    return TripEmailAlias(
      tripId: json['trip_id'] as String,
      localPart: json['local_part'] as String,
      emailAddress: json['email_address'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastRegeneratedAt: json['last_regenerated_at'] != null
          ? DateTime.parse(json['last_regenerated_at'] as String)
          : null,
    );
  }
}
