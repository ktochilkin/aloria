import 'package:aloria/core/storage/storage.dart';
import 'package:aloria/core/storage/storage_io.dart';
import 'package:aloria/core/storage/storage_web.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Storage> createStorage() async {
  final prefs = await SharedPreferences.getInstance();
  if (kIsWeb) {
    return WebStorage(prefs: prefs);
  }
  const secure = FlutterSecureStorage();
  return IOMixedStorage(secure: secure, prefs: prefs);
}

final storageProvider = FutureProvider<Storage>((ref) => createStorage());
