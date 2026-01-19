import 'package:aloria/features/auth/data/models/auth_tokens.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    @Default(false) bool loading,
    AuthTokens? tokens,
    String? error,
  }) = _AuthState;
}
