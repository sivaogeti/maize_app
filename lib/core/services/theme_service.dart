import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { blue, green }

class ThemeService extends ChangeNotifier {
  static const _kKey = 'maizemate_app_theme';
  AppTheme _current = AppTheme.green;

  AppTheme get current => _current;

  ThemeData get themeData {
    switch (_current) {
      case AppTheme.blue:
        return ThemeData(
          colorSchemeSeed: const Color(0xFF0B5ED7),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F7F9),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0B5ED7),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
        );
      case AppTheme.green:
      default:
        return ThemeData(
          colorSchemeSeed: const Color(0xFF2E7D32),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F7F9),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
        );
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kKey);
    if (name == 'blue') _current = AppTheme.blue;
    if (name == 'green') _current = AppTheme.green;
    notifyListeners();
  }

  Future<void> setTheme(AppTheme t) async {
    _current = t;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, t == AppTheme.blue ? 'blue' : 'green');
  }

  void toggle() {
    setTheme(_current == AppTheme.blue ? AppTheme.green : AppTheme.blue);
  }
}
