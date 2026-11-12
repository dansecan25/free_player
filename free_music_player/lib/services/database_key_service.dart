import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provides the SQLCipher key for the library database.
///
/// A random 256-bit key is created on first launch and kept in the platform's
/// secure storage (Android Keystore / iOS Keychain), never in the database or
/// in shared preferences.
class DatabaseKeyService {
  static const String _keyName = 'library_database_key';
  static const int _keyBytes = 32;

  final FlutterSecureStorage _storage;

  DatabaseKeyService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(_keyBytes, (_) => random.nextInt(256));
    final key = base64Encode(bytes);
    await _storage.write(key: _keyName, value: key);
    return key;
  }
}
