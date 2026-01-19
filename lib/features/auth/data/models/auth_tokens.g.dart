// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_tokens.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AuthTokensImpl _$$AuthTokensImplFromJson(Map<String, dynamic> json) =>
    _$AuthTokensImpl(
      jwt: json['jwt'] as String,
      refreshToken: json['refreshToken'] as String,
      refreshExpiresAt: _parseExpires(json['refreshExpiresAt']),
    );

Map<String, dynamic> _$$AuthTokensImplToJson(_$AuthTokensImpl instance) =>
    <String, dynamic>{
      'jwt': instance.jwt,
      'refreshToken': instance.refreshToken,
      'refreshExpiresAt': _toJson(instance.refreshExpiresAt),
    };
