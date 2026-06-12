import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ВРЕМЕННО (ветка coinbase-canvas-variants): подбор цвета холста приложения
// вживую. Кнопка-палитра в нижней навигации циклит кандидаты; тема, шапки и
// экраны обучения читают выбранный цвет. Когда выберем — зашьём один в тему и
// уберём этот файл/кнопку.
const canvasCandidates = <(String, Color)>[
  ('Белый · FFFFFF', Color(0xFFFFFFFF)),
  ('Нейтральный серый · F6F7F9', Color(0xFFF6F7F9)),
  ('Серее · F0F2F5', Color(0xFFF0F2F5)),
  ('Тёплый off-white · FAFAF7', Color(0xFFFAFAF7)),
  ('Тёплее · F6F4EF', Color(0xFFF6F4EF)),
  ('Лёгкий синий · F3F6FE', Color(0xFFF3F6FE)),
];

final canvasIndexProvider = StateProvider<int>((ref) => 3); // #FAFAF7

/// Текущий выбранный цвет холста.
final canvasColorProvider = Provider<Color>((ref) {
  final i = ref.watch(canvasIndexProvider).clamp(0, canvasCandidates.length - 1);
  return canvasCandidates[i].$2;
});
