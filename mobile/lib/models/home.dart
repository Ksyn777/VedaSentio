class Home {
  const Home({required this.id, required this.name, required this.role, required this.createdAt});
  final String id;
  final String name;
  final String role;
  final String createdAt;

  factory Home.fromJson(Map<String, dynamic> json) => Home(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    role: json['role'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
  );
}
