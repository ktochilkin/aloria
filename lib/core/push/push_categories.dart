/// Категории push-уведомлений.
///
/// Контракт единый с бэком (aloria-api): каждая категория — int-флаг битовой
/// маски, которая хранится per-device на сервере (DeviceToken.Categories)
/// и локально в [storageKey]. Не менять флаги без синхронного изменения бэка.
enum PushCategory {
  /// Начало/конец кризиса, решение ЦБ по ставке, дефолт эмитента, смена главы ЦБ.
  worldAlerts(
    flag: 1,
    title: 'Срочное в мире',
    description: 'Кризисы, решения ЦБ по ставке, дефолты эмитентов',
  ),

  /// Смена фазы экономического цикла, старт нового цикла.
  cycleEvents(
    flag: 2,
    title: 'Экономический цикл',
    description: 'Смена фазы экономики и начало нового цикла',
  ),

  /// Продукты, отчёты, смены CEO и прочие новости компаний.
  companyNews(
    flag: 4,
    title: 'Новости компаний',
    description: 'Отчёты, продукты, назначения и другие события компаний',
  ),

  /// Один пуш при открытии мирового дня со сводкой событий.
  calendarDigest(
    flag: 8,
    title: 'Календарь дня',
    description: 'Одно уведомление в начале дня: отчёты, купоны, отсечки',
  ),

  /// Существующие учебные уведомления: ачивки, повторения, стрики.
  learning(
    flag: 16,
    title: 'Обучение и стрики',
    description: 'Достижения, напоминания о повторении и серии занятий',
  );

  const PushCategory({
    required this.flag,
    required this.title,
    required this.description,
  });

  /// Флаг категории в битовой маске.
  final int flag;

  /// Название тумблера в UI.
  final String title;

  /// Короткое описание под тумблером.
  final String description;

  /// Дефолтная маска нового устройства: всё, кроме новостей компаний.
  static const int defaultMask = 27; // worldAlerts+cycleEvents+calendarDigest+learning

  /// Ключ локальной копии маски в хранилище (`Storage`).
  static const String storageKey = 'push_categories_mask';

  /// Включена ли категория в маске [mask].
  bool enabledIn(int mask) => (mask & flag) != 0;
}
