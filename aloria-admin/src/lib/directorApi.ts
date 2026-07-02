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
};

export type WorldSnapshot = {
  day: number;
  cycleDay: number;
  regime: 'Expansion' | 'Peak' | 'Recession' | 'Recovery';
  crisis: boolean;
  keyRate: number;
  inflation: number;
  growth: number;
};

export type DirectorState = {
  snapshot: WorldSnapshot;
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
  finalSnapshot: WorldSnapshot;
};

export const directorApi = {
  state: () => api.get<DirectorState>('/director/state'),
  tuning: () => api.get<WorldTuning>('/director/tuning'),
  saveTuning: (t: WorldTuning) => api.put<WorldTuning>('/director/tuning', t),
  simulate: (body: { days: number; seed?: number | null; tuning?: WorldTuning | null }) =>
    api.post<SimResult>('/director/simulate', body),
  forceCrisis: () => api.post<{ crisis: boolean }>('/director/crisis'),
  forceRegime: (regime: string) => api.post<{ forced: string }>('/director/regime', { regime }),
};

export const regimeRu: Record<string, string> = {
  Expansion: 'Расширение',
  Peak: 'Перегрев',
  Recession: 'Рецессия',
  Recovery: 'Восстановление',
};
