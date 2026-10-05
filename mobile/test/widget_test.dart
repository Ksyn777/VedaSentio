import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/home.dart';

void main() {
  test('Home model parses dashboard API data', () {
    final home = Home.fromJson({
      'id': 'home_001',
      'name': 'Dom testowy',
      'role': 'owner',
      'created_at': '2026-10-04 12:18:14+00',
    });

    expect(home.id, 'home_001');
    expect(home.name, 'Dom testowy');
    expect(home.role, 'owner');
  });
}
