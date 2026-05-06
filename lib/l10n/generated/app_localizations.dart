import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Aloria'**
  String get appTitle;

  /// No description provided for @navLearn.
  ///
  /// In ru, this message translates to:
  /// **'Обучение'**
  String get navLearn;

  /// No description provided for @navPortfolio.
  ///
  /// In ru, this message translates to:
  /// **'Портфель'**
  String get navPortfolio;

  /// No description provided for @navMarket.
  ///
  /// In ru, this message translates to:
  /// **'Обзор рынка'**
  String get navMarket;

  /// No description provided for @commonCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get commonSave;

  /// No description provided for @commonClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get commonRetry;

  /// No description provided for @commonContinue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get commonContinue;

  /// No description provided for @commonBack.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get commonBack;

  /// No description provided for @commonError.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так'**
  String get commonError;

  /// No description provided for @commonLoading.
  ///
  /// In ru, this message translates to:
  /// **'Загружаем…'**
  String get commonLoading;

  /// No description provided for @settingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @settingsTheme.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageRu.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get settingsLanguageRu;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsLearningMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим обучения интерфейсу'**
  String get settingsLearningMode;

  /// No description provided for @settingsLearningModeHint.
  ///
  /// In ru, this message translates to:
  /// **'Подсветить элементы и показывать пояснения по тапу. Сделки в этом режиме не выполняются.'**
  String get settingsLearningModeHint;

  /// No description provided for @settingsAbout.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get settingsAbout;

  /// No description provided for @settingsLogout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get settingsLogout;

  /// No description provided for @portfolioTitle.
  ///
  /// In ru, this message translates to:
  /// **'Портфель'**
  String get portfolioTitle;

  /// No description provided for @portfolioEvaluationCaption.
  ///
  /// In ru, this message translates to:
  /// **'Оценка портфеля'**
  String get portfolioEvaluationCaption;

  /// No description provided for @portfolioInPositions.
  ///
  /// In ru, this message translates to:
  /// **'В ПОЗИЦИЯХ'**
  String get portfolioInPositions;

  /// No description provided for @portfolioBuyingPower.
  ///
  /// In ru, this message translates to:
  /// **'НА ПОКУПКУ'**
  String get portfolioBuyingPower;

  /// No description provided for @portfolioPnl.
  ///
  /// In ru, this message translates to:
  /// **'P/U'**
  String get portfolioPnl;

  /// No description provided for @portfolioDistribution.
  ///
  /// In ru, this message translates to:
  /// **'РАСПРЕДЕЛЕНИЕ ПОЗИЦИЙ'**
  String get portfolioDistribution;

  /// No description provided for @portfolioCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} ШТ'**
  String portfolioCount(int count);

  /// No description provided for @portfolioTopUp.
  ///
  /// In ru, this message translates to:
  /// **'Пополнить'**
  String get portfolioTopUp;

  /// No description provided for @portfolioActiveOrders.
  ///
  /// In ru, this message translates to:
  /// **'Активные заявки · {count}'**
  String portfolioActiveOrders(int count);

  /// No description provided for @portfolioActiveOrdersHint.
  ///
  /// In ru, this message translates to:
  /// **'Ожидают исполнения'**
  String get portfolioActiveOrdersHint;

  /// No description provided for @portfolioTabPositions.
  ///
  /// In ru, this message translates to:
  /// **'Позиции'**
  String get portfolioTabPositions;

  /// No description provided for @portfolioTabOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заявки'**
  String get portfolioTabOrders;

  /// No description provided for @portfolioEmptyPositions.
  ///
  /// In ru, this message translates to:
  /// **'Нет открытых позиций'**
  String get portfolioEmptyPositions;

  /// No description provided for @portfolioEmptyOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заявок нет'**
  String get portfolioEmptyOrders;

  /// No description provided for @learningTitle.
  ///
  /// In ru, this message translates to:
  /// **'Обучение'**
  String get learningTitle;

  /// No description provided for @learningContinue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get learningContinue;

  /// No description provided for @learningStart.
  ///
  /// In ru, this message translates to:
  /// **'Начать обучение'**
  String get learningStart;

  /// No description provided for @learningSectionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Раздел'**
  String get learningSectionLabel;

  /// No description provided for @learningLessonOf.
  ///
  /// In ru, this message translates to:
  /// **'Урок {current} из {total}'**
  String learningLessonOf(int current, int total);

  /// No description provided for @learningMarkRead.
  ///
  /// In ru, this message translates to:
  /// **'Отметить пройденным'**
  String get learningMarkRead;

  /// No description provided for @learningNextLesson.
  ///
  /// In ru, this message translates to:
  /// **'Следующий урок'**
  String get learningNextLesson;

  /// No description provided for @learningFinishSection.
  ///
  /// In ru, this message translates to:
  /// **'Завершить раздел'**
  String get learningFinishSection;

  /// No description provided for @learningCheckYourself.
  ///
  /// In ru, this message translates to:
  /// **'Проверь себя'**
  String get learningCheckYourself;

  /// No description provided for @learningCheckAnswers.
  ///
  /// In ru, this message translates to:
  /// **'Проверить ответы'**
  String get learningCheckAnswers;

  /// No description provided for @learningAnswerAll.
  ///
  /// In ru, this message translates to:
  /// **'Ответьте на все вопросы'**
  String get learningAnswerAll;

  /// No description provided for @learningAllCorrect.
  ///
  /// In ru, this message translates to:
  /// **'Все ответы верные.'**
  String get learningAllCorrect;

  /// No description provided for @learningCorrectOf.
  ///
  /// In ru, this message translates to:
  /// **'Правильных: {correct} из {total}.'**
  String learningCorrectOf(int correct, int total);

  /// No description provided for @learningTryAgain.
  ///
  /// In ru, this message translates to:
  /// **'Заново'**
  String get learningTryAgain;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
