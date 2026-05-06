// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Aloria';

  @override
  String get navLearn => 'Обучение';

  @override
  String get navPortfolio => 'Портфель';

  @override
  String get navMarket => 'Обзор рынка';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonContinue => 'Продолжить';

  @override
  String get commonBack => 'Назад';

  @override
  String get commonError => 'Что-то пошло не так';

  @override
  String get commonLoading => 'Загружаем…';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get settingsThemeSystem => 'Как в системе';

  @override
  String get settingsThemeLight => 'Светлая';

  @override
  String get settingsThemeDark => 'Тёмная';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsLanguageSystem => 'Как в системе';

  @override
  String get settingsLanguageRu => 'Русский';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsLearningMode => 'Режим обучения интерфейсу';

  @override
  String get settingsLearningModeHint =>
      'Подсветить элементы и показывать пояснения по тапу. Сделки в этом режиме не выполняются.';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get settingsLogout => 'Выйти';

  @override
  String get portfolioTitle => 'Портфель';

  @override
  String get portfolioEvaluationCaption => 'Оценка портфеля';

  @override
  String get portfolioInPositions => 'В ПОЗИЦИЯХ';

  @override
  String get portfolioBuyingPower => 'НА ПОКУПКУ';

  @override
  String get portfolioPnl => 'P/U';

  @override
  String get portfolioDistribution => 'РАСПРЕДЕЛЕНИЕ ПОЗИЦИЙ';

  @override
  String portfolioCount(int count) {
    return '$count ШТ';
  }

  @override
  String get portfolioTopUp => 'Пополнить';

  @override
  String portfolioActiveOrders(int count) {
    return 'Активные заявки · $count';
  }

  @override
  String get portfolioActiveOrdersHint => 'Ожидают исполнения';

  @override
  String get portfolioTabPositions => 'Позиции';

  @override
  String get portfolioTabOrders => 'Заявки';

  @override
  String get portfolioEmptyPositions => 'Нет открытых позиций';

  @override
  String get portfolioEmptyOrders => 'Заявок нет';

  @override
  String get learningTitle => 'Обучение';

  @override
  String get learningContinue => 'Продолжить';

  @override
  String get learningStart => 'Начать обучение';

  @override
  String get learningSectionLabel => 'Раздел';

  @override
  String learningLessonOf(int current, int total) {
    return 'Урок $current из $total';
  }

  @override
  String get learningMarkRead => 'Отметить пройденным';

  @override
  String get learningNextLesson => 'Следующий урок';

  @override
  String get learningFinishSection => 'Завершить раздел';

  @override
  String get learningCheckYourself => 'Проверь себя';

  @override
  String get learningCheckAnswers => 'Проверить ответы';

  @override
  String get learningAnswerAll => 'Ответьте на все вопросы';

  @override
  String get learningAllCorrect => 'Все ответы верные.';

  @override
  String learningCorrectOf(int correct, int total) {
    return 'Правильных: $correct из $total.';
  }

  @override
  String get learningTryAgain => 'Заново';
}
