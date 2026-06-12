import 'package:aloria/features/market/domain/order_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// Классификация причин отказа заявки. Сообщения в тестах — реальные
/// формулировки торговой системы (Shepard, TEREX, commandapi), а не
/// выдуманные: при изменении формулировок тест должен напомнить
/// обновить ключевые слова.
void main() {
  group('OrderFailure.classify — коды', () {
    test('продажа бумаг, которых нет: 400 + текст про инструмент → шорт', () {
      expect(
        OrderFailure.classify(
          code: 'OrderCreatesUncoveredRisk',
          message:
              'Заявка приводит к отрицательной позиции по инструменту, '
              'который недоступен в маржу',
        ),
        OrderFailureKind.shortNotAllowed,
      );
      expect(
        OrderFailure.classify(
          code: '400',
          message:
              'Заявка приводит к отрицательной позиции по инструменту, '
              'который недоступен в маржу',
        ),
        OrderFailureKind.shortNotAllowed,
      );
    });

    test('400 + текст про валюту или без текста → не хватает денег', () {
      expect(
        OrderFailure.classify(
          code: 'OrderCreatesUncoveredRisk',
          message:
              'Заявка приводит к отрицательной позиции по немаржинальной '
              'валюте',
        ),
        OrderFailureKind.insufficientFunds,
      );
      expect(
        OrderFailure.classify(code: '400'),
        OrderFailureKind.insufficientFunds,
      );
    });

    test('InternalErrorWithPrices (409) — это валидация цены, не сбой', () {
      // TEREX: цена вне MinPrice/MaxPrice или не кратна шагу.
      expect(
        OrderFailure.classify(
          code: 'InternalErrorWithPrices',
          message: 'Price must be less than or equal to 120. CommandId: 1',
        ),
        OrderFailureKind.badPrice,
      );
      expect(OrderFailure.classify(code: '409'), OrderFailureKind.badPrice);
    });

    test('NoOrderPriceFound (411) → нет цены для рыночной', () {
      expect(OrderFailure.classify(code: '411'), OrderFailureKind.noPrice);
    });

    test('таймаут команды → системный сбой', () {
      expect(
        OrderFailure.classify(code: 'CommandResponseTimeout'),
        OrderFailureKind.system,
      );
      expect(OrderFailure.classify(code: '900'), OrderFailureKind.system);
    });
  });

  group('OrderFailure.classify — только текст (асинхронные отказы)', () {
    test('Shepard: цена за пределами лимита', () {
      expect(
        OrderFailure.classify(message: 'Цена заявки за пределами лимита'),
        OrderFailureKind.badPrice,
      );
    });

    test('Shepard: 100% обеспечение', () {
      expect(
        OrderFailure.classify(
          message:
              'Недостаточно свободных средств. Услуга 100% обеспечение '
              'включена.',
        ),
        OrderFailureKind.insufficientFunds,
      );
    });

    test('Shepard: отрицательная позиция по инструменту → шорт', () {
      expect(
        OrderFailure.classify(
          message:
              'Заявка приводит к отрицательной позиции по инструменту, '
              'который недоступен в маржу',
        ),
        OrderFailureKind.shortNotAllowed,
      );
    });

    test('TEREX: торги не идут', () {
      expect(
        OrderFailure.classify(
          message: 'The instrument SBER is not currently trading. CommandId: 1',
        ),
        OrderFailureKind.tradingClosed,
      );
    });

    test('TEREX: количество', () {
      expect(
        OrderFailure.classify(
          message: 'Quantity must be a natural number. CommandId: 1',
        ),
        OrderFailureKind.badQuantity,
      );
    });

    test('Shepard: не найдена цена заявки', () {
      expect(
        OrderFailure.classify(message: 'Не найдена цена заявки'),
        OrderFailureKind.noPrice,
      );
    });

    test('пустота → unknown, не system', () {
      expect(OrderFailure.classify(), OrderFailureKind.unknown);
      expect(OrderFailure.classify(message: ''), OrderFailureKind.unknown);
    });
  });
}
