import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

// Who is logged in. The token is kept on the phone so people stay logged in.
class Session extends ChangeNotifier {
  String? token;
  String? role;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      token = p.getString('token');
      role = p.getString('role');
    } catch (_) {}
    Api.token = token;
  }

  Future<void> login(String newToken, String newRole) async {
    token = newToken;
    role = newRole;
    Api.token = newToken;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('token', newToken);
      await p.setString('role', newRole);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    role = null;
    Api.token = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('token');
      await p.remove('role');
    } catch (_) {}
    notifyListeners();
  }
}

final Session session = Session();

// Which tab of the bottom bar is open: 0 Search, 1 Bookings, 2 Account.
final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);
