import 'package:aloria/core/theme/components/list_items.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:aloria/features/market/presentation/positions/widgets/portfolio_empty_card.dart';
import 'package:aloria/features/market/presentation/positions/widgets/position_tile.dart';
import 'package:aloria/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Секция позиций на вкладке «Портфель»: список открытых позиций
/// (ненулевое количество, не больше 50) с empty/loading/error состояниями.
class PositionsListSection extends StatelessWidget {
  const PositionsListSection({super.key, required this.positions});

  /// Позиции портфеля.
  final AsyncValue<List<Position>> positions;

  @override
  Widget build(BuildContext context) {
    return positions.when(
      data: (list) {
        final items = list.where((p) => p.quantity != 0).take(50).toList();
        if (items.isEmpty) {
          return PortfolioEmptyCard(
            text: AppLocalizations.of(context)!.portfolioEmptyPositions,
          );
        }

        return AppListSection(
          children: items.map((p) => PositionTile(position: p)).toList(),
        );
      },
      loading: () => const PortfolioSectionLoader(),
      error: (e, _) => Center(child: Text('Ошибка позиций: $e')),
    );
  }
}
