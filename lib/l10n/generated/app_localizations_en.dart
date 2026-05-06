// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Aloria';

  @override
  String get navLearn => 'Learn';

  @override
  String get navPortfolio => 'Portfolio';

  @override
  String get navMarket => 'Market';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonBack => 'Back';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageRu => 'Russian';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsLearningMode => 'Interactive learning mode';

  @override
  String get settingsLearningModeHint =>
      'Highlights interface elements and shows explanations on tap. Trading is disabled in this mode.';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsLogout => 'Log out';

  @override
  String get portfolioTitle => 'Portfolio';

  @override
  String get portfolioEvaluationCaption => 'Portfolio value';

  @override
  String get portfolioInPositions => 'INVESTED';

  @override
  String get portfolioBuyingPower => 'BUYING POWER';

  @override
  String get portfolioPnl => 'P/L';

  @override
  String get portfolioDistribution => 'POSITION BREAKDOWN';

  @override
  String portfolioCount(int count) {
    return '$count';
  }

  @override
  String get portfolioTopUp => 'Top up';

  @override
  String portfolioActiveOrders(int count) {
    return 'Active orders · $count';
  }

  @override
  String get portfolioActiveOrdersHint => 'Pending execution';

  @override
  String get portfolioTabPositions => 'Positions';

  @override
  String get portfolioTabOrders => 'Orders';

  @override
  String get portfolioEmptyPositions => 'No open positions';

  @override
  String get portfolioEmptyOrders => 'No orders';

  @override
  String get learningTitle => 'Learn';

  @override
  String get learningContinue => 'Continue';

  @override
  String get learningStart => 'Start learning';

  @override
  String get learningSectionLabel => 'Section';

  @override
  String learningLessonOf(int current, int total) {
    return 'Lesson $current of $total';
  }

  @override
  String get learningMarkRead => 'Mark as read';

  @override
  String get learningNextLesson => 'Next lesson';

  @override
  String get learningFinishSection => 'Finish section';

  @override
  String get learningCheckYourself => 'Check yourself';

  @override
  String get learningCheckAnswers => 'Check answers';

  @override
  String get learningAnswerAll => 'Answer all questions';

  @override
  String get learningAllCorrect => 'All answers correct.';

  @override
  String learningCorrectOf(int correct, int total) {
    return 'Correct: $correct of $total.';
  }

  @override
  String get learningTryAgain => 'Try again';
}
