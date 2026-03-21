class TripDestination {
  final String id;
  final String tripId;
  final String destinationId;
  final int? dayNumber;
  final int sortOrder;
  final String? notes;
  final DateTime? plannedDate;
  final DateTime createdAt;

  TripDestination({
    required this.id,
    required this.tripId,
    required this.destinationId,
    this.dayNumber,
    this.sortOrder = 0,
    this.notes,
    this.plannedDate,
    required this.createdAt,
  });

  factory TripDestination.fromJson(Map<String, dynamic> json) {
    return TripDestination(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      destinationId: json['destination_id'] as String,
      dayNumber: json['day_number'] as int?,
      sortOrder: json['sort_order'] as int? ?? 0,
      notes: json['notes'] as String?,
      plannedDate: json['planned_date'] != null
          ? DateTime.parse(json['planned_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'destination_id': destinationId,
      'day_number': dayNumber,
      'sort_order': sortOrder,
      'notes': notes,
      'planned_date': plannedDate?.toIso8601String().split('T').first,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'trip_id': tripId,
      'destination_id': destinationId,
      'day_number': dayNumber,
      'sort_order': sortOrder,
      'notes': notes,
      'planned_date': plannedDate?.toIso8601String().split('T').first,
    };
  }

  TripDestination copyWith({
    String? id,
    String? tripId,
    String? destinationId,
    int? dayNumber,
    int? sortOrder,
    String? notes,
    DateTime? plannedDate,
    DateTime? createdAt,
  }) {
    return TripDestination(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      destinationId: destinationId ?? this.destinationId,
      dayNumber: dayNumber ?? this.dayNumber,
      sortOrder: sortOrder ?? this.sortOrder,
      notes: notes ?? this.notes,
      plannedDate: plannedDate ?? this.plannedDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
