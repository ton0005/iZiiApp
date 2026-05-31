import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _geminiApiKey = 'gemini_api_key';

  Future<void> saveGeminiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_geminiApiKey, key);
  }

  Future<String?> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_geminiApiKey);
  }
}
