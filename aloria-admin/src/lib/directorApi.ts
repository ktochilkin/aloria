import { api } from './api';

// Клиент админ-API Aloria Director (ИИ-режиссёр экономического мира).
// В dev ходит через vite-proxy /director → localhost:5077.

export type WorldTuning = {
  eventRateMultiplier: number;
  tailChance: number;
  crisisSeverityThreshold: number;
  peakBubbleBurstPerDay: number;
  crisisHazardPerDay: number;
  volatilityMultiplier: number;
  crisisCooldownDays: number;
  crisisDroughtRampStartDays: number;
  crisisDroughtRampPerDay: number;
};

export type WorldSnapshot = {
  day: number;
  cycleDay: number;
  regime: 'Expansion' | 'Peak' | 'Recession' | 'Recovery';
  crisis: boolean;
  keyRate: number;
  inflation: number;
  growth: number;
  daysSinceCrisis: number;
};

export type DirectorState = {
  snapshot: WorldSnapshot;
  futureSeed: number | null;
  issuers: {
    symbol: string;
    name: string;
    sector: string;
    fair: number;
    target: number;
    eps: number;
    distress: number;
    defaulted: boolean;
  }[];
  bonds: {
    symbol: string;
    name: string;
    spread: number;
    target: number;
    accrued: number;
    daysToMaturity: number;
    defaulted: boolean;
    matured: boolean;
  }[];
  funds: { symbol: string; name: string; target: number }[];
  calendarAhead: {
    id: string;
    type: string;
    day: number;
    tickOfDay: number;
    symbol: string | null;
  }[];
};

export type SimResult = {
  fromDay: number;
  days: number;
  seed: number;
  tuning: WorldTuning;
  newsPerDay: number;
  crisisShareOfTime: number;
  firstCrisisDay: number | null;
  firstCrisisAfterDays: number | null;
  regimeDays: Record<string, number>;
  defaults: string[];
  indexDaily: number[];
  regimeDaily: string[];
  crisisDaily: boolean[];
  finalSnapshot: WorldSnapshot;
};

/// Дефолтная калибровка мира (совпадает с WorldTuning по умолчанию в Core).
export const defaultTuning: WorldTuning = {
  eventRateMultiplier: 1.0,
  tailChance: 0.09,
  crisisSeverityThreshold: 0.85,
  peakBubbleBurstPerDay: 0.04,
  crisisHazardPerDay: 0.0,
  volatilityMultiplier: 1.0,
  crisisCooldownDays: 12,
  crisisDroughtRampStartDays: 25,
  crisisDroughtRampPerDay: 0.015,
};

/// Итог ансамбля из N независимых веток: статистика вместо одной траектории.
export type EnsembleResult = {
  fromDay: number;
  days: number;
  runs: number;
  crisisShare: { mean: number; min: number; max: number };
  pAnyCrisis: number;
  firstCrisisMedianDays: number | null;
  defaultProb: Record<string, number>;
  newsPerDay: number;
  indexP10: number[];
  indexP50: number[];
  indexP90: number[];
  crisisProbDaily: number[];
};

/// «Просчёт» — точное будущее живого мира (тот же поток костей).
export type ForesightResult = {
  exact: true;
  fromDay: number;
  horizonDays: number;
  maxDays: number;
  crisisShareOfTime: number;
  firstCrisisAfterDays: number | null;
  defaults: { symbol: string; afterDays: number }[];
  indexDaily: number[];
  regimeDaily: string[];
  crisisDaily: boolean[];
  notable: { afterDays: number; what: string }[];
  caveat: string;
};

export const directorApi = {
  state: () => api.get<DirectorState>('/director/state'),
  tuning: () => api.get<WorldTuning>('/director/tuning'),
  saveTuning: (t: WorldTuning) => api.put<WorldTuning>('/director/tuning', t),
  simulate: (body: { days: number; seed?: number | null; tuning?: WorldTuning | null }) =>
    api.post<SimResult>('/director/simulate', body),
  simulateEnsemble: (body: { days: number; runs: number; tuning?: WorldTuning | null }) =>
    api.post<EnsembleResult>('/director/simulate', body),
  foresight: (days?: number) => api.post<ForesightResult>('/director/foresight', { days }),
  reseed: (seed?: number | null) =>
    api.post<{ futureSeed: number }>('/director/reseed', { seed }),
  forceCrisis: () => api.post<{ crisis: boolean }>('/director/crisis'),
  forceRegime: (regime: string) => api.post<{ forced: string }>('/director/regime', { regime }),
};

export const regimeRu: Record<string, string> = {
  Expansion: 'Рост',
  Peak: 'Перегрев',
  Recession: 'Рецессия',
  Recovery: 'Восстановление',
};
