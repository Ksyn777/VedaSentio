import 'home.dart';
import 'user_profile.dart';

class SessionData {
  const SessionData({required this.user, required this.homes});
  final UserProfile user;
  final List<Home> homes;
}
