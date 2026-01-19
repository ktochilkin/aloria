import 'package:freezed_annotation/freezed_annotation.dart';

part 'error_types.freezed.dart';

@freezed
sealed class AppError with _$AppError implements Exception {
  const factory AppError.network(String message) = _Network;
  const factory AppError.server(String message) = _Server;
  const factory AppError.unauthorized() = _Unauthorized;
  const factory AppError.unexpected([String? message]) = _Unexpected;
}
