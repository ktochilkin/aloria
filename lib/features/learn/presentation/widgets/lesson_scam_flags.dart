import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Учебный блок к уроку про мошенничество: мини-тренажёр «красный флаг или
/// нет?». Несколько реальных по форме предложений; пользователь решает сам,
/// потом раскрывается разбор. Превращает пассивный список красных флагов в
/// тренировку самого навыка.
///
/// Собран на block_kit (стиль «воздух»): каждое предложение — отдельная
/// [LessonBlockCard], ответы — BlockButton, вердикт — BlockChip(tone).
class LessonScamFlags extends StatefulWidget {
  const LessonScamFlags({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonScamFlags> createState() => _LessonScamFlagsState();
}

class _LessonScamFlagsState extends State<LessonScamFlags> {
  static const _offers = [
    _Offer(
      text: '«Гарантирую 30% в месяц. Риска никакого — деньги под защитой»',
      isScam: true,
      why: 'Гарантия высокой доходности без риска не бывает. Чем выше обещают, '
          'тем выше риск — а «риска нет» здесь просто ложь.',
    ),
    _Offer(
      text: '«Облигация крупной компании, купон 12% годовых, выплата раз в '
          'полгода»',
      isScam: false,
      why: 'Это нормальное рыночное предложение: доходность сопоставима со '
          'ставкой, риск есть и его видно. Не обещают «без риска».',
    ),
    _Offer(
      text: '«Только сегодня! Приведи двух друзей — и мы удвоим твой вклад»',
      isScam: true,
      why: 'Срочность давит на решение, а доход «за приведённых друзей» — это '
          'признак пирамиды: платят не из прибыли, а из денег новых участников.',
    ),
  ];

  final Map<int, bool> _answers = {}; // индекс → ответил «флаг»

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _offers.length; i++) ...[
          if (i > 0) const SizedBox(height: BlockSpacing.m),
          _FlagCard(
            offer: _offers[i],
            answeredScam: _answers[i],
            tint: widget.tint,
            onAnswer: (scam) => setState(() => _answers[i] = scam),
          ),
        ],
      ],
    );
  }
}

class _Offer {
  const _Offer({required this.text, required this.isScam, required this.why});

  final String text;
  final bool isScam;
  final String why;
}

class _FlagCard extends StatelessWidget {
  const _FlagCard({
    required this.offer,
    required this.answeredScam,
    required this.tint,
    required this.onAnswer,
  });

  final _Offer offer;
  final bool? answeredScam;
  final Color tint;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final answered = answeredScam != null;
    final correct = answered && answeredScam == offer.isScam;

    return LessonBlockCard(
      tint: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.text,
            style: text.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          if (!answered)
            Row(
              children: [
                Expanded(
                  child: BlockButton(
                    tint: tint,
                    label: 'Красный флаг',
                    icon: Icons.flag,
                    onPressed: () => onAnswer(true),
                  ),
                ),
                const SizedBox(width: BlockSpacing.s),
                Expanded(
                  child: BlockButton(
                    tint: tint,
                    label: 'Нормально',
                    icon: Icons.check,
                    onPressed: () => onAnswer(false),
                  ),
                ),
              ],
            )
          else
            _Verdict(offer: offer, correct: correct, tint: tint),
        ],
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.offer,
    required this.correct,
    required this.tint,
  });

  final _Offer offer;
  final bool correct;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                correct ? 'Верно' : 'Не совсем',
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: BlockSpacing.s),
            BlockChip(
              text: offer.isScam ? 'красный флаг' : 'нормальное предложение',
              tint: tint,
              tone: offer.isScam ? BlockTone.error : BlockTone.success,
            ),
          ],
        ),
        const SizedBox(height: BlockSpacing.s),
        Text(
          offer.why,
          style: text.bodySmall?.copyWith(height: 1.45),
        ),
      ],
    );
  }
}
