import 'package:aloria/core/storage/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebStorage implements Storage {
  final SharedPreferences prefs;
  WebStorage({required this.prefs});

  @override
  Future<void> write(String key, String value) => prefs.setString(key, value);

  @override
  Future<String?> read(String key) => Future.value(prefs.getString(key));

  @override
  Future<void> delete(String key) => prefs.remove(key);

  @override
  Future<void> clear() => prefs.clear();
}
