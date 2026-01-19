# Aloria

Feature-first Flutter skeleton (iOS/Android/Web) with Riverpod, go_router, Dio, Freezed, and layered domain/application/data/presentation setup.

## Stack

- Navigation: go_router with web URLs and deep links
- State: flutter_riverpod
- Networking: Dio + typed errors
- Models: freezed + json_serializable
- Storage: abstraction + secure storage/shared_prefs on mobile, shared_prefs on web
- Theming: Material 3 with tokens

## Setup

1. Install Flutter (stable) and run `flutter pub get`.
2. Generate code: `dart run build_runner build --delete-conflicting-outputs`
3. Run (examples):
   - Web (Chrome): `flutter run -d chrome --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=https://api.dev.example.com --dart-define=ENABLE_LOGGING=true`
   - iOS: `flutter run -d ios --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=https://api.dev.example.com --dart-define=ENABLE_LOGGING=true`
   - Android: `flutter run -d android --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=https://api.dev.example.com --dart-define=ENABLE_LOGGING=true`

## Testing

- `flutter test`

## Notes

- App config is provided via Riverpod override (`appConfigProvider`) in `main.dart`.
- Example feature shows repository → use case → providers → UI vertical slice.
- Auth: login via `/login` route; tokens stored via `Storage` abstraction; auto refresh every 10 minutes and on 401 using refresh endpoint.
