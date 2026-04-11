import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/api_data_source.dart';
import '../data/datasources/local_data_source.dart';

// ── Shared datasource providers ──────────────────────────────────────────────

final localDataSourceProvider = Provider<LocalDataSource>((_) => LocalDataSource());

final apiDataSourceProvider = Provider<ApiDataSource>((ref) {
  return ApiDataSource(ref.read(localDataSourceProvider));
});

// ── Auth state ────────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoading;
  final bool isInitialized; // true after init() completes; drives splash redirect
  final bool isAuthenticated;
  final Map<String, dynamic>? user;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isInitialized = false,
    this.isAuthenticated = false,
    this.user,
    this.error,
  });

  String get username => user?['username'] ?? '';
  String get role => user?['role'] ?? 'user';
  String get tier => user?['subscription_tier'] ?? 'free';
  int get dailyLimit => user?['daily_limit'] ?? 3;
  String? get expiresAt => user?['expires_at'];
  bool get isAdmin => role == 'admin';

  AuthState copyWith({
    bool? isLoading,
    bool? isInitialized,
    bool? isAuthenticated,
    Map<String, dynamic>? user,
    String? error,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        isInitialized: isInitialized ?? this.isInitialized,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        user: user ?? this.user,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiDataSource _api;
  final LocalDataSource _local;

  AuthNotifier(this._api, this._local) : super(const AuthState());

  Future<void> init() async {
    try {
      final token = await _local.getToken();
      if (token == null) {
        state = const AuthState(isInitialized: true);
        return;
      }
      final data = await _api.getMe();
      state = AuthState(
        isInitialized: true,
        isAuthenticated: true,
        user: data['user'] as Map<String, dynamic>,
      );
    } catch (_) {
      await _local.deleteToken();
      state = const AuthState(isInitialized: true);
    }
  }

  Future<String?> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final deviceId = await _getDeviceId();
      final data = await _api.login(username, password, deviceId);
      final token = data['token'] as String;
      await _local.saveToken(token);
      state = AuthState(
        isAuthenticated: true,
        user: data['user'] as Map<String, dynamic>,
      );
      return null; // success
    } catch (e) {
      final msg = _parseError(e);
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    }
  }

  Future<void> logout() async {
    final deviceId = await _local.getDeviceId() ?? '';
    await _api.logout(deviceId);
    await _local.deleteToken();
    state = const AuthState();
  }

  Future<void> refreshUser() async {
    try {
      final data = await _api.getMe();
      state = state.copyWith(user: data['user'] as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<String> _getDeviceId() async {
    var id = await _local.getDeviceId();
    if (id != null) return id;
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    id = android.id;
    await _local.saveDeviceId(id);
    return id;
  }

  String _parseError(dynamic e) {
    final str = e.toString();
    // Extract message from DioException
    if (str.contains('"error"')) {
      final match = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(str);
      if (match != null) return match.group(1)!;
    }
    if (str.contains('Exception:')) {
      return str.split('Exception:').last.trim();
    }
    return '登录失败，请检查网络连接';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(apiDataSourceProvider),
    ref.read(localDataSourceProvider),
  );
});
