import 'package:dio/dio.dart';

/// Категория причины, по которой заявка не прошла. По ней интерфейс
/// выбирает объяснение и подсказку, что делать дальше.
enum OrderFailureKind {
  /// Не хватает покупательной способности (свободных средств).
  insufficientFunds,

  /// Цена вне допустимых границ или не кратна шагу цены.
  badPrice,

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
  /// или имена (`NotEnoughCash`). Если код не узнан, добираем по ключевым
  /// словам сообщения (асинхронные отказы приходят только с текстом).
  static OrderFailureKind classify({String? code, String? message}) {
    final byCode = _classifyCode(code);
    if (byCode != null) return byCode;
    final byMessage = _classifyMessage(message);
    if (byMessage != null) return byMessage;
    return OrderFailureKind.unknown;
  }

  static OrderFailureKind? _classifyCode(String? raw) {
    final code = raw?.trim().toLowerCase();
    if (code == null || code.isEmpty) return null;
    return switch (code) {
      // Деньги: проверка риска (Shepard) и проверка биржи.
      '400' || 'ordercreatesuncoveredrisk' => OrderFailureKind.insufficientFunds,
      '401' || 'notenoughcash' => OrderFailureKind.insufficientFunds,
      '309' || 'insufficientclientfunds' => OrderFailureKind.insufficientFunds,
      // Цена.
      '301' || 'exchangelimitexceeded' => OrderFailureKind.badPrice,
      '503' ||
      'priceinstopordernotmultipleofminincrement' =>
        OrderFailureKind.badPrice,
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
      '409' || 'internalerrorwithprices' => OrderFailureKind.system,
      '501' || 'cantwritestopordertostorage' => OrderFailureKind.system,
      '900' || 'commandresponsetimeout' => OrderFailureKind.system,
      _ => null,
    };
  }

  static OrderFailureKind? _classifyMessage(String? raw) {
    final m = raw?.toLowerCase();
    if (m == null || m.isEmpty) return null;
    bool has(List<String> words) => words.any(m.contains);

    if (has(['timeout', 'таймаут', 'internal', 'внутренняя ошибка'])) {
      return OrderFailureKind.system;
    }
    if (has([
      'недостаточно',
      'не хватает',
      'свободных средств',
      'обеспечение',
      'непокрыт',
      'uncovered',
      'not enough',
      'insufficient',
    ])) {
      return OrderFailureKind.insufficientFunds;
    }
    if (has(['шаг цены', 'лимит цен', 'границ', 'price', 'цена вне'])) {
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
      'not trading',
    ])) {
      return OrderFailureKind.tradingClosed;
    }
    if (has(['шорт', 'short', 'продажа без покрытия'])) {
      return OrderFailureKind.shortNotAllowed;
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
