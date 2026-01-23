import 'package:aloria/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides JWT tokens to data-layer services without coupling them to Riverpod.
abstract class TokenProvider {
  /// Returns the current JWT; when [forceRefresh] true tries to refresh first.
  Future<String?> accessToken({bool forceRefresh = false});
}

class RiverpodTokenProvider implements TokenProvider {
  RiverpodTokenProvider(this._ref);

  final Ref _ref;

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async {
    final notifier = _ref.read(authControllerProvider.notifier);
    if (forceRefresh) {
      await notifier.refresh(force: true);
    }
    return _ref.read(authControllerProvider).tokens?.jwt;
  }
}
