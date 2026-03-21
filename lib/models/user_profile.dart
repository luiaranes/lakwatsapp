class UserProfile {
  final String id;
  final String authId;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? homeCity;
  final String? homeCountry;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.authId,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.homeCity,
    this.homeCountry,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      authId: json['auth_id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      homeCity: json['home_city'] as String?,
      homeCountry: json['home_country'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_id': authId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'home_city': homeCity,
      'home_country': homeCountry,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? authId,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? homeCity,
    String? homeCountry,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      authId: authId ?? this.authId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      homeCity: homeCity ?? this.homeCity,
      homeCountry: homeCountry ?? this.homeCountry,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
