import 'package:dio/dio.dart';

/// Категория причины, по которой заявка не прошла. По ней интерфейс
/// выбирает объяснение и подсказку, что делать дальше.
enum OrderFailureKind {
  /// Не хватает покупательной способности (свободных средств).
  insufficientFunds,

  /// Цена вне допустимых границ или не кратна шагу цены.
  badPrice,

  /// Рыночной заявке не нашлось цены исполнения (в стакане пусто).
  noPrice,

  /// Некорректное количество (не кратно лоту, ноль и т.п.).
  badQuantity,

  /// Торги по инструменту остановлены или сессия закрыта.
  tradingClosed,

  /// Продажа бумаг, которых нет в портфеле (шорт недоступен).
  shortNotAllowed,

  /// Действие запрещено для клиента или типа заявки.
  forbidden,

  /// Заявка для отмены/изменения не найдена (уже исполнилась или снята).
  orderNotFound,

  /// Системный сбой: таймаут команды, 5xx, обрыв сети — проблема не в
  /// действиях пользователя.
  system,

  /// Причину не удалось распознать.
  unknown,
}

/// Разобранная причина неудачи заявки: категория + исходные код и сообщение
/// торговой системы.
class OrderFailure {
  const OrderFailure({
    required this.kind,
    this.code,
    this.message,
    this.statusCode,
  });

  final OrderFailureKind kind;

  /// Код ошибки торговой системы (например, `NotEnoughCash` или `401`).
  final String? code;

  /// Техническое сообщение торговой системы.
  final String? message;

  /// HTTP-статус ответа, если ошибка пришла по HTTP.
  final int? statusCode;

  /// true — сбой системный, пользователь ни при чём: показываем «проблему
  /// в мире Алории» и предлагаем написать в поддержку.
  bool get isSystem => kind == OrderFailureKind.system;

  /// Разбирает исключение, прилетевшее при отправке/отмене заявки.
  ///
  /// commandapi на отказ отвечает HTTP 400 с телом `{code, message}`;
  /// таймауты, 5xx и сетевые обрывы считаем системным сбоем.
  factory OrderFailure.fromException(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return const OrderFailure(kind: OrderFailureKind.system);
        case DioExceptionType.badResponse:
        case DioExceptionType.cancel:
        case DioExceptionType.badCertificate:
        case DioExceptionType.unknown:
          break;
      }

      final response = error.response;
      if (response != null) {
        final status = response.statusCode ?? 0;
        String? code;
        String? message;
        final data = response.data;
        if (data is Map) {
          code = data['code']?.toString();
          message = data['message']?.toString();
        } else if (data is String && data.isNotEmpty) {
          message = data;
        }
        if (status >= 500) {
          return OrderFailure(
            kind: OrderFailureKind.system,
            code: code,
            message: message,
            statusCode: status,
          );
        }
        return OrderFailure(
          kind: classify(code: code, message: message),
          code: code,
          message: message,
          statusCode: status,
        );
      }
      // DioException без ответа — не дозвонились до сервера.
      return const OrderFailure(kind: OrderFailureKind.system);
    }
    return OrderFailure(kind: OrderFailureKind.unknown, message: '$error');
  }

  /// Классифицирует асинхронный отказ (`OrderStatus.rejected`) по тексту
  /// комментария заявки — кода там нет, только сообщение.
  factory OrderFailure.fromRejectionComment(String? comment) {
    return OrderFailure(
      kind: classify(message: comment),
      message: comment,
    );
  }

  /// Определяет категорию по коду ошибки торговой системы и/или тексту.
  ///
  /// Коды — из ErrorCode торговой системы: числовые (301, 401, 900…)
  /// или имена (`NotEnoughCash`). Некоторые коды многозначные и уточняются
  /// по тексту; асинхронные отказы приходят вовсе без кода — только текст.
  static OrderFailureKind classify({String? code, String? message}) {
    final c = code?.trim().toLowerCase();

    // OrderCreatesUncoveredRisk (400) — общий вердикт риск-движка: им
    // отклоняется и покупка без денег, и продажа бумаг, которых нет.
    // Конкретику Shepard кладёт только в текст.
    if (c == '400' || c == 'ordercreatesuncoveredrisk') {
      return _isShortSellMessage(message)
          ? OrderFailureKind.shortNotAllowed
          : OrderFailureKind.insufficientFunds;
    }

    final byCode = _classifyCode(c);
    if (byCode != null) return byCode;
    final byMessage = _classifyMessage(message);
    if (byMessage != null) return byMessage;
    return OrderFailureKind.unknown;
  }

  /// «Заявка приводит к отрицательной позиции по инструменту, который
  /// недоступен в маржу» — так Shepard сообщает о продаже бумаг, которых
  /// нет в портфеле (шорт запрещён).
  static bool _isShortSellMessage(String? raw) {
    final m = raw?.toLowerCase();
    if (m == null) return false;
    return (m.contains('отрицательной позиции') && !m.contains('валюте')) ||
        m.contains('недоступен в маржу') ||
        m.contains('шорт') ||
        m.contains('short');
  }

  static OrderFailureKind? _classifyCode(String? code) {
    if (code == null || code.isEmpty) return null;
    return switch (code) {
      // Деньги: проверка риска (Shepard) и проверка биржи.
      '401' || 'notenoughcash' => OrderFailureKind.insufficientFunds,
      '309' || 'insufficientclientfunds' => OrderFailureKind.insufficientFunds,
      // Цена. InternalErrorWithPrices (409) — несмотря на название, это
      // обычная валидация цены: TEREX отвечает им на цену вне лимитов
      // MinPrice/MaxPrice и не кратную шагу, Shepard — на выход из
      // ценового коридора («Цена заявки за пределами лимита»).
      '301' || 'exchangelimitexceeded' => OrderFailureKind.badPrice,
      '409' || 'internalerrorwithprices' => OrderFailureKind.badPrice,
      '503' ||
      'priceinstopordernotmultipleofminincrement' =>
        OrderFailureKind.badPrice,
      // «Не найдена цена заявки» — у рыночной заявки нет цены исполнения
      // (в стакане пусто или по инструменту ещё не было цены).
      '411' || 'noorderpricefound' => OrderFailureKind.noPrice,
      // Количество.
      '304' || 'exchangeincorrectquantity' => OrderFailureKind.badQuantity,
      // Сессия.
      '306' || 'exchangetradingisstopped' => OrderFailureKind.tradingClosed,
      // Шорт.
      '405' || 'instrumentcantbeshortselled' => OrderFailureKind.shortNotAllowed,
      // Запреты.
      '406' ||
      'instrumentinboardforbiddenforclient' =>
        OrderFailureKind.forbidden,
      '407' || 'clientblocked' => OrderFailureKind.forbidden,
      '410' ||
      'invalidcomplexproductcategory' =>
        OrderFailureKind.forbidden,
      '412' || 'forbiddenordertype' => OrderFailureKind.forbidden,
      '413' || 'lowriskmarginalforbidden' => OrderFailureKind.forbidden,
      '502' || 'unsupportedstopordertype' => OrderFailureKind.forbidden,
      // Заявка не найдена (или уже исполнена/снята).
      '253' || 'exchangeordernotfound' => OrderFailureKind.orderNotFound,
      '300' ||
      'exchangeoperationnotsupported' =>
        OrderFailureKind.orderNotFound,
      '403' || 'ordertomodifynotfound' => OrderFailureKind.orderNotFound,
      '404' || 'ordertocancelnotfound' => OrderFailureKind.orderNotFound,
      // Системное.
      '402' || 'revertnotgenerated' => OrderFailureKind.system,
      '408' || 'unknownerror' => OrderFailureKind.system,
      '501' || 'cantwritestopordertostorage' => OrderFailureKind.system,
      '900' || 'commandresponsetimeout' => OrderFailureKind.system,
      _ => null,
    };
  }

  static OrderFailureKind? _classifyMessage(String? raw) {
    final m = raw?.toLowerCase();
    if (m == null || m.isEmpty) return null;
    bool has(List<String> words) => words.any(m.contains);

    // Сначала специфичные формулировки, потом общие слова: например,
    // «отрицательная позиция по инструменту» важнее «недостаточно».
    if (_isShortSellMessage(m)) {
      return OrderFailureKind.shortNotAllowed;
    }
    if (has(['timeout', 'таймаут', 'внутренняя ошибка'])) {
      return OrderFailureKind.system;
    }
    if (has(['не найдена цена', 'нет цены'])) {
      return OrderFailureKind.noPrice;
    }
    if (has([
      'недостаточно',
      'не хватает',
      'свободных средств',
      'обеспечение',
      'непокрыт',
      'отрицательной позиции по немаржинальной валюте',
      'uncovered',
      'not enough',
      'insufficient',
    ])) {
      return OrderFailureKind.insufficientFunds;
    }
    if (has([
      'шаг цены',
      'лимит цен',
      'пределами лимита',
      'границ',
      'price',
      'цена вне',
      'цена заявки',
    ])) {
      return OrderFailureKind.badPrice;
    }
    if (has(['количеств', 'кратно лоту', 'quantity', 'лотност'])) {
      return OrderFailureKind.badQuantity;
    }
    if (has([
      'торги останов',
      'торги приостанов',
      'сессия закрыта',
      'не торгуется',
      'trading is stopped',
      'not currently trading',
      'not trading',
    ])) {
      return OrderFailureKind.tradingClosed;
    }
    if (has(['запрещ', 'заблокирован', 'forbidden', 'blocked'])) {
      return OrderFailureKind.forbidden;
    }
    if (has(['не найдена', 'not found'])) {
      return OrderFailureKind.orderNotFound;
    }
    return null;
  }
}
