import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Прототипные справочные данные для понимания мира Aloria (ветка экспериментов).
/// Пока статические/мок — при необходимости переедут на бэк/ИИ-режиссёра.

/// Фазы экономического цикла по порядку (петля).
const cyclePhases = <({String regime, String label})>[
  (regime: 'expansion', label: 'Рост'),
  (regime: 'peak', label: 'Перегрев'),
  (regime: 'recession', label: 'Рецессия'),
  (regime: 'recovery', label: 'Восстановление'),
];

const sectorTitles = <String, String>{
  'finance': 'Финансы',
  'consumer': 'Потребительский',
  'retail': 'Ритейл',
  'food': 'Общепит',
  'logistics': 'Логистика',
  'tech': 'Технологии',
  'travel': 'Туризм',
  'energy': 'Энергетика',
};

/// Тенденция чувствительности сектора к режиму: 1 — обычно выигрывает,
/// −1 — обычно страдает, 0 — нейтрально. Это ТЕНДЕНЦИЯ, не правило.
const sectorSensitivity = <String, Map<String, int>>{
  'expansion': {
    'tech': 1,
    'retail': 1,
    'travel': 1,
    'finance': 1,
    'logistics': 1,
    'consumer': 0,
    'food': 0,
    'energy': 0,
  },
  'peak': {
    'finance': 1,
    'energy': 1,
    'consumer': 0,
    'food': 0,
    'logistics': -1,
    'retail': -1,
    'travel': -1,
    'tech': -1,
  },
  'recession': {
    'food': 1,
    'consumer': 1,
    'energy': -1,
    'finance': -1,
    'retail': -1,
    'travel': -1,
    'tech': -1,
    'logistics': -1,
  },
  'recovery': {
    'tech': 1,
    'retail': 1,
    'travel': 1,
    'finance': 1,
    'logistics': 1,
    'consumer': 0,
    'food': 0,
    'energy': 0,
  },
};

/// Цвет и подпись для тенденции сектора.
({Color color, String label, IconData icon}) sensitivityMeta(int s) =>
    switch (s) {
      > 0 => (
        color: AppColors.success,
        label: 'обычно растёт',
        icon: Icons.trending_up_rounded,
      ),
      < 0 => (
        color: AppColors.error,
        label: 'обычно под давлением',
        icon: Icons.trending_down_rounded,
      ),
      _ => (
        color: AppColors.warning,
        label: 'нейтрально',
        icon: Icons.trending_flat_rounded,
      ),
    };
