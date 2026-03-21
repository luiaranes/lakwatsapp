class Post {
  final String id;
  final String userId;
  final String? tripId;
  final String? destinationId;
  final String? content;
  final List<String> photos;
  final int likesCount;
  final int commentsCount;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  Post({
    required this.id,
    required this.userId,
    this.tripId,
    this.destinationId,
    this.content,
    this.photos = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isPublic = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tripId: json['trip_id'] as String?,
      destinationId: json['destination_id'] as String?,
      content: json['content'] as String?,
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      isPublic: json['is_public'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'trip_id': tripId,
      'destination_id': destinationId,
      'content': content,
      'photos': photos,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'trip_id': tripId,
      'destination_id': destinationId,
      'content': content,
      'photos': photos,
      'is_public': isPublic,
    };
  }

  Post copyWith({
    String? id,
    String? userId,
    String? tripId,
    String? destinationId,
    String? content,
    List<String>? photos,
    int? likesCount,
    int? commentsCount,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tripId: tripId ?? this.tripId,
      destinationId: destinationId ?? this.destinationId,
      content: content ?? this.content,
      photos: photos ?? this.photos,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasPhotos => photos.isNotEmpty;
  bool get hasContent => content != null && content!.isNotEmpty;
}
