import 'dart:async';

import 'package:aloria/core/logging/logger.dart';
import 'package:aloria/core/storage/storage.dart';
import 'package:aloria/core/storage/storage_factory.dart';
import 'package:aloria/features/auth/application/auth_state.dart';
import 'package:aloria/features/auth/data/auth_repository.dart';
import 'package:aloria/features/auth/data/models/auth_tokens.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 10),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-ALOR-ORIGINATOR': 'Astras',
      },
    ),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(authDioProvider);
  return AuthRepository(dio);
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final repo = ref.watch(authRepositoryProvider);
    final storage = ref.watch(storageProvider.future);
    return AuthController(ref, repo, storage);
  },
);

class AuthController extends StateNotifier<AuthState> {
  AuthController(this.ref, this._repository, this._storageFuture)
    : super(const AuthState()) {
    _init();
  }

  final Ref ref;
  final AuthRepository _repository;
  final Future<Storage> _storageFuture;

  static const _jwtKey = 'auth_jwt';
  static const _refreshKey = 'auth_refresh';
  static const _refreshExpKey = 'auth_refresh_exp';

  Timer? _refreshTimer;
  Future<AuthTokens?>? _refreshing;

  bool get isAuthenticated => state.tokens != null;

  Future<void> _init() async {
    final storage = await _storageFuture;
    final jwt = await storage.read(_jwtKey);
    final refresh = await storage.read(_refreshKey);
    final expRaw = await storage.read(_refreshExpKey);
    if (jwt != null && refresh != null && expRaw != null) {
      final exp = DateTime.tryParse(expRaw);
      if (exp != null) {
        final tokens = AuthTokens(
          jwt: jwt,
          refreshToken: refresh,
          refreshExpiresAt: exp,
        );
        state = state.copyWith(tokens: tokens);
        _scheduleRefresh();
      }
    }
  }

  Future<void> login({
    required String login,
    required String password,
    String? twoFactorPin,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final tokens = await _repository.login(
        login: login,
        password: password,
        twoFactorPin: twoFactorPin,
      );
      await _persist(tokens);
      state = state.copyWith(loading: false, tokens: tokens);
      _scheduleRefresh();
    } catch (e, st) {
      appLogger.e('Login failed', error: e, stackTrace: st);
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<AuthTokens?> refresh({bool force = false}) async {
    final current = state.tokens;
    if (current == null) return null;
    final now = DateTime.now();
    final willExpireSoon = current.refreshExpiresAt.isBefore(
      now.add(const Duration(minutes: 1)),
    );
    if (!force && !willExpireSoon) return current;

    if (_refreshing != null) return _refreshing;
    _refreshing = _doRefresh(current.refreshToken);
    final result = await _refreshing;
    _refreshing = null;
    return result;
  }

  Future<AuthTokens?> _doRefresh(String refreshToken) async {
    try {
      final tokens = await _repository.refresh(refreshToken);
      final merged = tokens.copyWith(
        refreshToken: tokens.refreshToken.isEmpty
            ? state.tokens?.refreshToken ?? refreshToken
            : tokens.refreshToken,
      );
      await _persist(merged);
      state = state.copyWith(tokens: merged, error: null);
      _scheduleRefresh();
      return merged;
    } catch (e, st) {
      appLogger.e('Refresh failed', error: e, stackTrace: st);
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> logout() async {
    _refreshTimer?.cancel();
    final storage = await _storageFuture;
    await storage.delete(_jwtKey);
    await storage.delete(_refreshKey);
    await storage.delete(_refreshExpKey);
    state = const AuthState();
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    final tokens = state.tokens;
    if (tokens == null) return;
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      refresh(force: true);
    });
  }

  Future<void> _persist(AuthTokens tokens) async {
    final storage = await _storageFuture;
    await storage.write(_jwtKey, tokens.jwt);
    await storage.write(_refreshKey, tokens.refreshToken);
    await storage.write(
      _refreshExpKey,
      tokens.refreshExpiresAt.toIso8601String(),
    );
  }
}
