/// Делит тело урока на «биты» для фокус-скролла — крупными смысловыми
/// кусками (не по одной мысли, а по разделам/блокам), чтобы текст не дробился.
///
/// Границы бита:
/// - врезка-лид `:::lead … :::` — отдельный бит;
/// - блок-директива `:::имя` — отдельный бит (станет «на весь экран»);
/// - заголовок `## …` начинает новый бит и тянет за собой ВЕСЬ свой текст
///   (все абзацы раздела до следующего заголовка/блока);
/// - текст до первого заголовка — один вводный бит.
///
/// Возвращает markdown-куски; каждый рендерится обычным [LessonMarkdownBody].
List<String> splitLessonIntoBeats(String body) {
  final lines = body.split('\n');
  final beats = <String>[];
  final buf = StringBuffer();

  void flush() {
    final t = buf.toString().trim();
    if (t.isNotEmpty) beats.add(t);
    buf.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final trimmed = lines[i].trim();

    if (trimmed == ':::lead') {
      flush();
      final b = StringBuffer()..writeln(lines[i]);
      i++;
      while (i < lines.length && lines[i].trim() != ':::') {
        b.writeln(lines[i]);
        i++;
      }
      if (i < lines.length) {
        b.writeln(lines[i]);
        i++;
      }
      beats.add(b.toString().trim());
      continue;
    }

    final isBlock = RegExp(r'^:::([a-z0-9-]+)$').hasMatch(trimmed);
    if (isBlock) {
      flush();
      beats.add(trimmed);
      i++;
      continue;
    }

    // Заголовок начинает новый бит — копим его и весь раздел до следующей
    // границы (следующий заголовок/блок/лид разорвут накопление выше).
    if (trimmed.startsWith('## ')) {
      flush();
    }
    buf.writeln(lines[i]);
    i++;
  }
  flush();

  return beats.where((b) => b.trim().isNotEmpty).toList(growable: false);
}

/// Бит — это интерактивный блок (`:::имя`, но не лид)?
bool beatIsBlock(String beat) {
  final t = beat.trim();
  return t.startsWith(':::') && t != ':::lead' && !t.contains('\n');
}
