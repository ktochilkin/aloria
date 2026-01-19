import 'package:aloria/core/storage/storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IOMixedStorage implements Storage {
  final FlutterSecureStorage secure;
  final SharedPreferences prefs;

  IOMixedStorage({required this.secure, required this.prefs});

  @override
  Future<void> write(String key, String value) async {
    await secure.write(key: key, value: value);
    await prefs.setString(key, value);
  }

  @override
  Future<String?> read(String key) async {
    return await secure.read(key: key) ?? prefs.getString(key);
  }

  @override
  Future<void> delete(String key) async {
    await secure.delete(key: key);
    await prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    await secure.deleteAll();
    await prefs.clear();
  }
}
