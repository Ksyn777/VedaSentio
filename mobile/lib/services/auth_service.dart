import '../models/home.dart';
import '../models/session_data.dart';
import '../models/user_profile.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'token_storage.dart';

class AuthService {
  final ApiClient _api = ApiClient();
  final TokenStorage _tokens = TokenStorage();

  Future<SessionData> login(String email, String password) async {
    final login = await _api.post('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    final token = login['access_token'];
    if (token is! String || token.isEmpty) throw const ApiException('Brak tokena dostępu.');
    await _tokens.save(token);
    try { return await _load(token); }
    catch (_) { await _tokens.clear(); rethrow; }
  }

  Future<SessionData?> restore() async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) return null;
    try { return await _load(token); }
    on ApiException catch (e) {
      if (e.isUnauthorized) { await _tokens.clear(); return null; }
      rethrow;
    }
  }

  Future<SessionData> _load(String token) async {
    final me = UserProfile.fromJson(await _api.getObject('/api/me', token));
    final homesRaw = await _api.getList('/api/homes', token);
    final homes = homesRaw.whereType<Map<String, dynamic>>().map(Home.fromJson).toList(growable: false);
    return SessionData(user: me, homes: homes);
  }

  Future<void> logout() => _tokens.clear();
  void dispose() => _api.close();
}
