import 'package:aloria/core/widgets/state_placeholder.dart';
import 'package:aloria/core/widgets/top_notification.dart';
import 'package:aloria/features/learning_mode/presentation/order_form_coaching.dart';
import 'package:aloria/features/market/application/market_news_provider.dart';
import 'package:aloria/features/market/application/order_book_notifier.dart';
import 'package:aloria/features/market/application/orders_provider.dart';
import 'package:aloria/features/market/application/price_feed_notifier.dart';
import 'package:aloria/features/market/data/market_data_repository.dart';
import 'package:aloria/features/market/domain/portfolio_order.dart';
import 'package:aloria/features/market/domain/stop_order.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/market/presentation/trade/coinbase_theme.dart';
import 'package:aloria/features/market/presentation/trade/trade_providers.dart';
import 'package:aloria/features/market/presentation/trade/widgets/trade_body.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Прокрутка, после которой верхняя карточка с ценой уходит из вида и цену
/// дублируем в AppBar — чтобы котировка оставалась видна у формы заявки.
const double _kQuoteRevealOffset = 90.0;

/// Торговая страница инструмента: котировка, график, «Пульс рынка»
/// и форма заявки. Оформлена scoped-темой Coinbase.
class TradePage extends ConsumerStatefulWidget {
  const TradePage({
    super.key,
    required this.symbol,
    required this.shortName,
    this.exchange = 'TEREX',
  });

  final String symbol;
  final String shortName;
  final String exchange;

  @override
  ConsumerState<TradePage> createState() => _TradePageState();
}

class _TradePageState extends ConsumerState<TradePage> {
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _triggerController = TextEditingController();
  final _stopLimitController = TextEditingController();
  late final ScrollController _scrollController;
  OrderFormKind _kind = OrderFormKind.market;
  StopCondition _stopCondition = StopCondition.lessOrEqual;
  bool _submitting = false;
  bool _showAppBarPrice = false;

  /// Коучинг по отказам: id уже показанных отклонённых заявок и флаг «после
  /// отправки», чтобы не всплывать на исторических отказах из потока заявок.
  final Set<String> _coachedRejectionIds = {};
  bool _armedForRejections = false;

  @override
  void initState() {
    super.initState();

    // Создаем ScrollController с начальной позицией сразу
    final savedPosition = ref.read(scrollPositionProvider(widget.symbol));
    _scrollController = ScrollController(initialScrollOffset: savedPosition);
    _showAppBarPrice = savedPosition > _kQuoteRevealOffset;

    // Сохраняем позицию при прокрутке и показываем цену в AppBar, когда верхняя
    // карточка с ценой уже ушла за край — чтобы не дублировать её вверху.
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final offset = _scrollController.offset;
      ref.read(scrollPositionProvider(widget.symbol).notifier).state = offset;
      final show = offset > _kQuoteRevealOffset;
      if (show != _showAppBarPrice) {
        setState(() => _showAppBarPrice = show);
      }
    });
  }

  @override
  void dispose() {
    // Сохраняем позицию при выходе со страницы
    if (_scrollController.hasClients) {
      ref.read(scrollPositionProvider(widget.symbol).notifier).state =
          _scrollController.offset;
    }

    _qtyController.dispose();
    _priceController.dispose();
    _triggerController.dispose();
    _stopLimitController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectPriceFromOrderBook(double price) {
    FocusScope.of(context).unfocus();
    setState(() {
      _kind = OrderFormKind.limit;
      _priceController.text = price.toStringAsFixed(2);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _submit(OrderSide side) async {
    final repo = await ref.read(marketDataRepositoryProvider.future);

    // Готовимся ловить асинхронный отказ: помечаем уже отклонённые заявки как
    // показанные, чтобы всплыло только новое — без зависимости от часов сервера.
    final existingOrders =
        ref.read(ordersProvider).valueOrNull ?? const <ClientOrder>[];
    for (final o in existingOrders) {
      if (o.status == OrderStatus.rejected) _coachedRejectionIds.add(o.id);
    }
    _armedForRejections = true;

    final qty = double.tryParse(_qtyController.text) ?? 0;
    final limitPrice = double.tryParse(_priceController.text);
    setState(() => _submitting = true);
    try {
      if (_kind == OrderFormKind.stop) {
        final trigger = double.tryParse(_triggerController.text);
        if (trigger == null) {
          if (mounted) {
            showTopNotification(
              context,
              'Укажи цену срабатывания стоп-заявки',
              isError: true,
            );
            setState(() => _submitting = false);
          }
          return;
        }
        await repo.placeStopOrder(
          symbol: widget.symbol,
          exchange: widget.exchange,
          side: side,
          condition: _stopCondition,
          triggerPrice: trigger,
          quantity: qty.round(),
          limitPrice: double.tryParse(_stopLimitController.text),
        );
        if (mounted) {
          showTopNotification(context, 'Стоп-заявка выставлена');
        }
      } else {
        final order = TradeOrder(
          symbol: widget.symbol,
          exchange: widget.exchange,
          side: side,
          type: _kind == OrderFormKind.limit
              ? OrderType.limit
              : OrderType.market,
          quantity: qty,
          limitPrice: _kind == OrderFormKind.limit ? limitPrice : null,
        );
        await repo.placeOrder(order);
        if (mounted) {
          showTopNotification(context, 'Заявка отправлена');
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Ошибка отправки';

        // Проверяем, является ли ошибка DioException
        if (e is DioException && e.response != null) {
          final responseData = e.response!.data;
          if (responseData is Map<String, dynamic> &&
              responseData.containsKey('message')) {
            errorMessage = responseData['message'] as String;
          } else {
            errorMessage = 'Ошибка отправки: ${e.response!.statusCode}';
          }
        } else {
          errorMessage = 'Ошибка отправки: $e';
        }

        showTopNotification(context, errorMessage, isError: true);

        // Синхронный отказ (валидация при отправке): всегда показываем
        // человеческое объяснение возможных причин, независимо от режима.
        if (e is DioException && e.response != null) {
          showOrderRejectionHelp(context, brokerMessage: errorMessage);
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Асинхронный отказ приходит через поток заявок (OrdersGetAndSubscribeV2).
    // Реагируем только на новые отклонённые заявки по этому инструменту после
    // отправки — объяснение причины показываем всегда, не только в обучении.
    ref.listen<AsyncValue<List<ClientOrder>>>(ordersProvider, (_, next) {
      if (!_armedForRejections) return;
      final orders = next.valueOrNull;
      if (orders == null) return;
      for (final o in orders) {
        if (o.symbol != widget.symbol) continue;
        if (o.status != OrderStatus.rejected) continue;
        if (!_coachedRejectionIds.add(o.id)) continue;
        if (mounted) {
          showOrderRejectionHelp(context, brokerMessage: o.comment);
        }
      }
    });

    final feed = ref.watch(
      priceFeedProvider((symbol: widget.symbol, exchange: widget.exchange)),
    );
    final orderBook = ref.watch(
      orderBookProvider((
        symbol: widget.symbol,
        exchange: widget.exchange,
        instrumentGroup: null,
        depth: 10,
      )),
    );
    final news = ref.watch(marketNewsProvider(widget.symbol));
    final feedTab = ref.watch(feedTabProvider(widget.symbol));

    final trimmedShort = widget.shortName.trim();
    final showShort = trimmedShort.isNotEmpty && trimmedShort != widget.symbol;
    final titleText = showShort
        ? '${widget.symbol} · $trimmedShort'
        : widget.symbol;

    // Последняя цена дублируется в AppBar, чтобы котировка оставалась на виду,
    // когда пользователь проскроллил вниз к форме заявки.
    final latestPrice = feed.valueOrNull?.latest?.price;

    return Theme(
      data: coinbaseTheme(context),
      child: Scaffold(
      // Клавиатуру уже учитывает внешний Scaffold нижней навигации (shell).
      // Без этого оба Scaffold'а поднимают контент над клавиатурой —
      // получается двойной отступ и большой пустой зазор над клавиатурой.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(titleText, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (latestPrice != null && _showAppBarPrice)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${latestPrice.toStringAsFixed(2)} ₽',
                  style: cbMono(size: 16),
                ),
              ),
            ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: feed.when(
          data: (state) => TradeBody(
            symbol: widget.symbol,
            exchange: widget.exchange,
            state: state,
            orderBook: orderBook,
            news: news,
            feedTab: feedTab,
            onFeedTabChanged: (tab) =>
                ref.read(feedTabProvider(widget.symbol).notifier).state = tab,
            kind: _kind,
            onKindChanged: (value) => setState(() => _kind = value),
            qtyController: _qtyController,
            priceController: _priceController,
            triggerController: _triggerController,
            stopLimitController: _stopLimitController,
            stopCondition: _stopCondition,
            onStopConditionChanged: (value) =>
                setState(() => _stopCondition = value),
            onSubmit: _submit,
            submitting: _submitting,
            onSelectPrice: _selectPriceFromOrderBook,
            scrollController: _scrollController,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => StatePlaceholder(
            framed: false,
            icon: Icons.cloud_off_outlined,
            title: 'Не получилось загрузить котировки',
            message: 'Проверь соединение и попробуй ещё раз.',
            actionLabel: 'Обновить',
            onAction: () => ref.invalidate(priceFeedProvider(
              (symbol: widget.symbol, exchange: widget.exchange),
            )),
          ),
        ),
      ),
      ),
    );
  }
}
