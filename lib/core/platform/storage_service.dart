import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String get _prefix => kDebugMode ? 'debug_' : 'release_';

  Future<void> write(String key, String value) async {
    await _storage.write(key: '$_prefix$key', value: value);
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: '$_prefix$key');
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: '$_prefix$key');
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
