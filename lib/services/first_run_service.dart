import 'package:shared_preferences/shared_preferences.dart';

class FirstRunService {
  static const String _firstRunKey = 'is_first_run';
  static const String _ppiKey = 'screen_ppi';

  static Future<bool> isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.containsKey(_ppiKey) || (prefs.getBool(_firstRunKey) ?? true);
  }

  static Future<void> setFirstRunComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstRunKey, false);
  }
}