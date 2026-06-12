# Чеклист публикации Aloria в App Store и Google Play

> Состояние на июнь 2026. Кодовая база к публикации готова (analyze чистый,
> монолиты распилены, цвета в токенах), но есть **блокеры конфигурации и
> инфраструктуры**, которые нужно закрыть до сабмита. Отмечай по мере
> выполнения; пункты с ⛔ — жёсткие блокеры, без них в стор не попасть
> или приложение не будет работать у пользователей.

---

## 1. Идентификатор приложения ⛔

Сейчас везде placeholder **`com.example.aloria`** — с ним Google Play и
App Store Connect не примут сборку. В Google Play applicationId **нельзя
изменить никогда** после первой публикации — решение надо принять один раз.

- [ ] Выбрать bundle ID (например `ru.alor.aloria` — если публикация с
      аккаунта Алора, или нейтральный `com.aloria.app` — если с личного).
- [ ] Android: заменить в `android/app/build.gradle.kts` —
      `namespace` (строка 9) и `applicationId` (строка 24).
- [ ] iOS: заменить `PRODUCT_BUNDLE_IDENTIFIER` в
      `ios/Runner.xcodeproj/project.pbxproj` (Runner — 3 конфигурации,
      RunnerTests — `<bundleId>.RunnerTests`).
- [ ] После замены — перерегистрировать приложения в Firebase под новым
      bundle ID и перегенерировать `lib/firebase_options.dart` через
      `flutterfire configure` (текущий конфиг привязан к старому ID,
      пуши перестанут работать).

## 2. Продовый бэкенд aloria-api ⛔

Дефолт `ALORIA_API_URL` — `http://Noutbuk-Kirill.local:5050`
(`lib/app_config.dart:54`), то есть ноутбук разработчика. Приложение из
стора без публичного бэкенда не сможет грузить уроки/прогресс.

- [ ] Задеплоить aloria-api на публичный HTTPS-домен.
- [ ] Передавать прод-URL через `--dart-define=ALORIA_API_URL=...` при
      сборке релиза (или зашить как дефолт для `AppEnv.prod`).
- [ ] Проверить, что торговый контур (`api.alor.dev`, `lk-api.alor.dev`)
      — это те окружения, которые должны видеть пользователи стора
      (сейчас это dev-контуры Алора).

## 3. Android: подпись и релизная сборка ⛔

Сейчас release подписывается **debug-ключом**
(`android/app/build.gradle.kts:37`) — Google Play такую сборку не примет.

- [ ] Сгенерировать keystore:
      `keytool -genkey -v -keystore ~/keystores/aloria-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias aloria`
- [ ] **Сделать бэкап keystore и паролей** (потеря = невозможность
      обновлять приложение).
- [ ] Создать `android/key.properties` (и добавить в `.gitignore`):
      `storeFile/storePassword/keyAlias/keyPassword`.
- [ ] Подключить в `build.gradle.kts`: `signingConfigs.release` из
      key.properties, `buildTypes.release.signingConfig = release`.
- [ ] Включить `isMinifyEnabled = true` + `isShrinkResources = true`
      для release (проверить, что Firebase Messaging работает после R8).
- [ ] `android:usesCleartextTraffic="true"` в `AndroidManifest.xml` —
      убрать из main-манифеста, оставить только в
      `android/app/src/debug/AndroidManifest.xml` (нужен лишь для
      локального HTTP-бэкенда в dev).
- [ ] `android:label="aloria"` → `"Aloria"`.
- [ ] Собрать `flutter build appbundle --release` и проверить установку.

## 4. iOS: конфигурация и подпись ⛔

- [ ] `ios/Podfile`: `platform :ios, '26.2'` — это минимальная версия ОС,
      отсекает почти все устройства. Поставить `13.0` (как
      `IPHONEOS_DEPLOYMENT_TARGET` в pbxproj) или минимум, который
      требуют Firebase-поды.
- [ ] `Info.plist`: убрать ATS-исключение для `192.168.1.21` и
      `NSLocalNetworkUsageDescription` из релизной сборки — это
      dev-артефакты, на ревью вызовут вопросы. `NSAllowsLocalNetworking`
      оставить можно, но лучше вынести dev-исключения в отдельную
      конфигурацию.
- [ ] `CFBundleName` `aloria` → `Aloria`.
- [ ] Ориентации: сейчас на iPhone разрешён landscape — проверить, что
      все экраны в нём живут, либо оставить только Portrait.
- [ ] `Runner.entitlements`: `aps-environment = development` — при
      сборке через Xcode Organizer/TestFlight автоматически станет
      `production`; убедиться, что в Apple Developer создан APNs-ключ
      и App ID с push-capability под новым bundle ID.
- [ ] Подпись: команда `X76WML57G4` прописана — проверить, что это
      аккаунт, с которого публикуем (личный/компании).
- [ ] Собрать `flutter build ipa` и выгрузить в TestFlight.

## 5. Метаданные и приватность ⛔

- [ ] **Privacy policy URL** — обязателен в обоих сторах (приложение
      использует аккаунты и сеть). Разместить на публичном домене.
- [ ] App Store: заполнить App Privacy (какие данные собираются:
      идентификаторы аккаунта, токены — не «не собираем»).
- [ ] Google Play: заполнить Data safety форму.
- [ ] Скриншоты (iPhone 6.7"/6.1", iPad если поддерживаем; телефон +
      планшет для Play), описание, ключевые слова, категория
      (Образование / Финансы), возрастной рейтинг.
- [ ] Учесть: приложение про биржевую торговлю (симулятор без реальных
      денег) — в анкетах ревью прямо указывать, что реальных денег и
      реальной торговли нет, это учебный симулятор. Это сильно влияет
      на прохождение ревью в категории Finance.

## 6. Чистка кода перед сабмитом

- [x] ~~Убрать временный переключатель холста~~ — сделано (июнь 2026):
      выбран белый #FFFFFF, canvas_switch.dart и debug-FAB удалены.
- [ ] `pubspec.yaml`: `description: Aloria Flutter app skeleton` →
      нормальное описание; проверить `version:` перед каждым сабмитом
      (`1.0.0+1`, build number инкрементировать).
- [ ] Релизные сборки запускать с `--dart-define=ENABLE_LOGGING=false`
      и `APP_ENV=prod`.
- [ ] `flutter_markdown` помечен как discontinued — запланировать
      миграцию на `flutter_markdown_plus` (не блокер, но дальше будет
      мешать обновлению Flutter).

## 7. Финальная верификация перед каждым сабмитом

- [ ] `flutter analyze` — чисто.
- [ ] `flutter test` — зелёный.
- [ ] `flutter build appbundle --release` + установка на устройство.
- [ ] `flutter build ipa` + TestFlight на устройстве.
- [ ] Смоук вручную: логин → обучение (урок с блоками, тест) →
      рынок (стакан, график, заявка limit/market, отмена) → портфель
      (вкладки, top-up, шторка позиции) → пуш-уведомление.
