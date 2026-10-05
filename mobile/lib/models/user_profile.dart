class HomeMembership {
  const HomeMembership({required this.homeId, required this.role});
  final String homeId;
  final String role;

  factory HomeMembership.fromJson(Map<String, dynamic> json) => HomeMembership(
    homeId: json['home_id'] as String? ?? '',
    role: json['role'] as String? ?? '',
  );
}

class UserProfile {
  const UserProfile({
    required this.id, required this.email, required this.firstName,
    required this.lastName, required this.phone, required this.isActive,
    required this.createdAt, required this.homes,
  });

  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final bool isActive;
  final String createdAt;
  final List<HomeMembership> homes;

  String get displayName {
    final v = '$firstName $lastName'.trim();
    return v.isEmpty ? email : v;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawHomes = json['homes'];
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
      homes: rawHomes is List
        ? rawHomes.whereType<Map<String, dynamic>>().map(HomeMembership.fromJson).toList(growable: false)
        : const [],
    );
  }
}
