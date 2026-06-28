/// Делит тело урока на «карточки» для свайп-режима — по одной мысли на экран.
///
/// Границы карточек:
/// - врезка-лид `:::lead … :::` — отдельная карточка;
/// - блок-директива `:::имя` — отдельная карточка;
/// - заголовок `## …` приклеивается к следующему абзацу (заголовок + текст);
/// - каждый абзац (текст между пустыми строками) — отдельная карточка;
/// - список (подряд идущие строки `-`) остаётся одной карточкой.
///
/// Возвращает markdown-куски; каждый рендерится обычным [LessonMarkdownBody],
/// поэтому концепт-ссылки, **жирный** и интерактивные блоки работают как есть.
List<String> splitLessonIntoCards(String body) {
  final lines = body.split('\n');

  // 1) Собираем «единицы»: непрерывные непустые строки = одна единица.
  //    Лид собираем как единый огороженный блок.
  final units = <String>[];
  var i = 0;
  while (i < lines.length) {
    final trimmed = lines[i].trim();
    if (trimmed.isEmpty) {
      i++;
      continue;
    }
    if (trimmed == ':::lead') {
      final buf = StringBuffer()..writeln(lines[i]);
      i++;
      while (i < lines.length && lines[i].trim() != ':::') {
        buf.writeln(lines[i]);
        i++;
      }
      if (i < lines.length) {
        buf.writeln(lines[i]); // закрывающая ограда
        i++;
      }
      units.add(buf.toString().trimRight());
      continue;
    }
    final buf = StringBuffer();
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      buf.writeln(lines[i]);
      i++;
    }
    units.add(buf.toString().trimRight());
  }

  // 2) Заголовок-одиночка (`## …` без переноса) клеим к следующей единице.
  final cards = <String>[];
  for (var k = 0; k < units.length; k++) {
    final u = units[k];
    final isHeadingOnly = u.startsWith('#') && !u.contains('\n');
    if (isHeadingOnly && k + 1 < units.length) {
      cards.add('$u\n\n${units[k + 1]}');
      k++;
    } else {
      cards.add(u);
    }
  }

  return cards.where((c) => c.trim().isNotEmpty).toList(growable: false);
}
