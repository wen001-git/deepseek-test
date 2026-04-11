import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';

// flutter_secure_storage with hardware-backed EncryptedSharedPreferences on Android.
// Note: Hangs on Android API 36 *emulators* due to a known Keystore init bug.
// Test on physical devices or API ≤ 35 emulators. API 36 physical devices are unaffected.
//
// Token and deviceId are cached in memory after the first Keystore read.
// The JWT does not change mid-session (set on login, cleared on logout), so
// subsequent calls to getToken() return immediately without hitting the Keystore.
class LocalDataSource {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cachedToken;
  String? _cachedDeviceId;

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: AppConstants.jwtKey, value: token);
  }

  Future<String?> getToken() async {
    _cachedToken ??= await _storage.read(key: AppConstants.jwtKey);
    return _cachedToken;
  }

  Future<void> deleteToken() async {
    _cachedToken = null;
    await _storage.delete(key: AppConstants.jwtKey);
  }

  Future<void> saveDeviceId(String id) async {
    _cachedDeviceId = id;
    await _storage.write(key: AppConstants.deviceIdKey, value: id);
  }

  Future<String?> getDeviceId() async {
    _cachedDeviceId ??= await _storage.read(key: AppConstants.deviceIdKey);
    return _cachedDeviceId;
  }

  Future<void> saveString(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> getString(String key) => _storage.read(key: key);
}
