import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_tokens.freezed.dart';
part 'auth_tokens.g.dart';

DateTime _parseExpires(dynamic raw) {
  if (raw == null) return DateTime.now();
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(
      raw * 1000,
      isUtc: true,
    ).toLocal();
  }
  if (raw is String) {
    return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
  }
  return DateTime.now();
}

@freezed
class AuthTokens with _$AuthTokens {
  const factory AuthTokens({
    required String jwt,
    required String refreshToken,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _parseExpires, toJson: _toJson)
    required DateTime refreshExpiresAt,
  }) = _AuthTokens;

  factory AuthTokens.fromJson(Map<String, dynamic> json) =>
      _$AuthTokensFromJson(json);

  factory AuthTokens.fromLogin(Map<String, dynamic> json) {
    final mapped = {
      'jwt': json['jwt'],
      'refreshToken': json['refreshToken'],
      'refreshExpiresAt':
          json['refreshExpirationAt'] ?? json['refreshExpiresAt'],
    };
    return AuthTokens.fromJson(mapped);
  }

  factory AuthTokens.fromRefresh(Map<String, dynamic> json) {
    final mapped = {
      'jwt': json['jwt'],
      'refreshToken': json['refreshToken'] ?? '',
      'refreshExpiresAt':
          json['refreshExpiresAt'] ?? json['refreshExpirationAt'],
    };
    return AuthTokens.fromJson(mapped);
  }
}

String _toJson(DateTime value) => value.toUtc().toIso8601String();
