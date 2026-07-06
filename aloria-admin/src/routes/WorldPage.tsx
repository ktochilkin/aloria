import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { AlertTriangle, Eye, EyeOff, FlaskConical, HelpCircle, Play, RotateCcw, Save } from 'lucide-react';
import { Badge, Button, Card, Field, Input, PageHeader, Spinner } from '../components/ui';
import {
  defaultTuning,
  directorApi,
  regimeRu,
  type EnsembleResult,
  type ForesightResult,
  type SimResult,
  type WorldTuning,
} from '../lib/directorApi';

// Управление экономическим миром: живое состояние, ручки тюнинга,
// ветка-симуляция «что будет дальше» и ручные рычаги (режим/кризис).

const regimeTone: Record<string, 'success' | 'warning' | 'error' | 'primary'> = {
  Expansion: 'success',
  Peak: 'warning',
  Recession: 'error',
  Recovery: 'primary',
};

const regimeWash: Record<string, string> = {
  Expansion: 'rgba(27,175,122,0.14)',
  Peak: 'rgba(237,161,0,0.18)',
  Recession: 'rgba(227,73,72,0.14)',
  Recovery: 'rgba(42,120,214,0.12)',
};

const stageRu: Record<string, { label: string; tone: 'primary' | 'neutral' | 'success' }> = {
  growth: { label: 'растущая', tone: 'primary' },
  mature: { label: 'зрелая', tone: 'neutral' },
  defensive: { label: 'защитная', tone: 'success' },
};

/// Характер главы ЦБ по hawkishness: ястреб / голубь / нейтрален.
function hawkishnessRu(h: number): string {
  if (h > 0.25) return 'ястреб';
  if (h < -0.25) return 'голубь';
  return 'нейтрален';
}

/// Скрытый ДНК-параметр [0..1] с цветовой шкалой: слабый / средний / сильный.
function DnaValue({ value }: { value: number | null | undefined }) {
  if (value == null) return <span className="text-xs text-(--color-fg-muted)">—</span>;
  const cls =
    value > 0.65
      ? 'text-(--color-success)'
      : value < 0.4
        ? 'text-(--color-error)'
        : 'text-(--color-fg-muted)';
  return <span className={`tabular-nums text-xs font-semibold ${cls}`}>{value.toFixed(2)}</span>;
}

const tuningFields: {
  key: keyof WorldTuning;
  label: string;
  hint: string;
  step: number;
  doc: string;
}[] = [
  {
    key: 'eventRateMultiplier',
    label: 'Частота событий ×',
    hint: 'дефолт 1.0 · диапазон 0.1–10',
    step: 0.1,
    doc:
      'Множитель интенсивности ВСЕХ случайных событий (корпоративных, секторных, макро). ' +
      'При 1.0 мир генерирует ~3.5 корпоративных + 0.8 секторных + 0.3 макро событий в день ' +
      '(рецессия ×1.5, кризис ×1.8 сверху). Крути, если мир кажется сонным (1.5–2) или шумным (0.5–0.8). ' +
      'Влияет и на количество новостей в ленте.',
  },
  {
    key: 'tailChance',
    label: 'Шанс хвоста Парето',
    hint: 'дефолт 0.09 · диапазон 0–0.5',
    doc:
      'С этой вероятностью серьёзность события разыгрывается из тяжёлого хвоста (0.7–1.0) вместо ' +
      '«горба» обычных новостей (среднее ~0.29). Больше хвост — больше сильных движений ±5–12% ' +
      'у отдельных бумаг И чаще кризисы (макрошок из хвоста выше порога = кризис). ' +
      'Рычаг «drama everywhere»: трогает не только кризисы, но и отдельные акции.',
    step: 0.01,
  },
  {
    key: 'crisisSeverityThreshold',
    label: 'Порог кризиса',
    hint: 'дефолт 0.85 · диапазон 0.5–1.0',
    doc:
      'Негативный МАКРО-шок с серьёзностью выше порога включает кризис (волатильность ×2, ' +
      'корреляции секторов → 1, режим → рецессия). Ниже порог — чаще кризисы «из новостей». ' +
      '0.80 ≈ вдвое чаще дефолта; 1.0 — кризисы только через «пузырь» или форс-кнопку.',
    step: 0.01,
  },
  {
    key: 'peakBubbleBurstPerDay',
    label: '«Пузырь» в перегреве /день',
    hint: 'дефолт 0.04 · диапазон 0–0.5',
    doc:
      'Каждый день ПЕРЕГРЕВА пузырь лопается с этой вероятностью → мгновенный кризис. ' +
      'Самый «сюжетный» и прицельный рычаг частоты кризисов: не трогает обычные события, ' +
      'кризисы рождаются из перегрева, как в жизни. 0.04 ≈ каждый 5–6-й пик; ' +
      '0.10 ≈ кризис почти каждый второй пик (проверено: ~19% времени в кризисе).',
    step: 0.01,
  },
  {
    key: 'crisisHazardPerDay',
    label: 'Прямой hazard кризиса /день',
    hint: 'дефолт 0 (выкл) · диапазон 0–0.5',
    doc:
      'Грубый рычаг: фиксированная вероятность кризиса КАЖДЫЙ день, в любом режиме, ' +
      'даже посреди расширения. Предсказуемая частота (0.015 ≈ раз в 67 дней), но кризисы ' +
      'приходят «из ниоткуда» без сюжетной причины. Для обычной жизни лучше держать 0 ' +
      'и управлять «пузырём»; hazard — для стресс-тестов и учебных периодов.',
    step: 0.005,
  },
  {
    key: 'volatilityMultiplier',
    label: 'Волатильность ×',
    hint: 'дефолт 1.0 · диапазон 0.25–4',
    doc:
      'Общий множитель дневного шума цен поверх режимного (расширение ×1.0, перегрев ×1.25, ' +
      'рецессия ×1.7, кризис ещё ×2). Течёт и в спреды маркетмейкера: выше волатильность — ' +
      'шире стакан. 0.5 — спокойный «учебный» рынок; 2 — американские горки без смены событий.',
    step: 0.1,
  },
  {
    key: 'crisisCooldownDays',
    label: 'Кулдаун кризиса, дней',
    hint: 'дефолт 12 · диапазон 0–100',
    doc:
      'Пейсинг, часть 1: после конца кризиса новый НЕВОЗМОЖЕН столько дней (все каналы ' +
      'заблокированы, кроме ручной кнопки). Гарантирует передышку: ученики видят восстановление, ' +
      'кризисы не идут сериями. 0 — выключить защиту.',
    step: 1,
  },
  {
    key: 'crisisDroughtRampStartDays',
    label: 'Засуха: старт роста, дней',
    hint: 'дефолт 25 · диапазон 0–200',
    doc:
      'Пейсинг, часть 2 (защита от невезения): если кризиса нет столько дней, его вероятность ' +
      'начинает расти с каждым днём. До этого порога работают только обычные каналы ' +
      '(пузырь, хвост).',
    step: 1,
  },
  {
    key: 'crisisDroughtRampPerDay',
    label: 'Засуха: прирост /день',
    hint: 'дефолт 0.015 · диапазон 0–0.2',
    doc:
      'Скорость роста вероятности после старта засухи. При 0.015 кризис практически гарантирован ' +
      'к ~50-му дню без кризисов (типично приходит на 30–45-й). Итог связки: интервал между ' +
      'кризисами всегда в окне ~кулдаун…50 дней — ни вечного штиля, ни серий. 0 — чистый рандом.',
    step: 0.005,
  },
];

function Stat({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div>
      <div className="text-xs font-semibold uppercase tracking-wider text-(--color-fg-muted)">{label}</div>
      <div className="text-xl font-bold text-(--color-fg) mt-0.5 tabular-nums">{value}</div>
    </div>
  );
}

/// Веерный график ансамбля: коридор p10–p90, медиана и полоса P(кризис) по дням.
function FanChart({ ens }: { ens: EnsembleResult }) {
  const n = ens.indexP50.length;
  if (n < 2) return null;
  const w = 560;
  const h = 150;
  const padL = 4;
  const plotW = w - padL - 4;
  const min = Math.min(...ens.indexP10);
  const max = Math.max(...ens.indexP90);
  const span = max - min || 1;
  const x = (i: number) => padL + (i / (n - 1)) * plotW;
  const y = (v: number) => h - 34 - ((v - min) / span) * (h - 52);

  const median = ens.indexP50.map((v, i) => `${x(i)},${y(v)}`).join(' ');
  const band =
    ens.indexP90.map((v, i) => `${x(i)},${y(v)}`).join(' ') +
    ' ' +
    [...ens.indexP10].reverse().map((v, i) => `${x(n - 1 - i)},${y(v)}`).join(' ');
  const dayW = plotW / (n - 1);

  return (
    <div>
      <svg viewBox={`0 0 ${w} ${h}`} className="w-full">
        <polygon points={band} fill="rgba(93,140,255,0.16)" />
        <polyline points={median} fill="none" stroke="var(--color-primary)" strokeWidth="2" strokeLinejoin="round" />
        {/* Полоса вероятности кризиса по дням */}
        {ens.crisisProbDaily.map((p, i) =>
          p > 0 ? (
            <rect
              key={i}
              x={x(i) - dayW / 2}
              y={h - 26}
              width={dayW + 0.5}
              height={8}
              fill={`rgba(208,59,59,${Math.min(0.9, 0.15 + p)})`}
            />
          ) : null,
        )}
        <text x={padL} y={12} fontSize="10" fill="var(--color-fg-muted)">{max.toFixed(0)}</text>
        <text x={padL} y={h - 38} fontSize="10" fill="var(--color-fg-muted)">{min.toFixed(0)}</text>
        <text x={padL} y={h - 18} fontSize="9" fill="var(--color-fg-muted)">P(кризис)</text>
        {[0.25, 0.5, 0.75].map((f) => {
          const i = Math.round(f * (n - 1));
          return (
            <text key={f} x={x(i)} y={h - 4} fontSize="10" fill="var(--color-fg-muted)" textAnchor="middle">
              д.{ens.fromDay + i}
            </text>
          );
        })}
      </svg>
      <div className="flex flex-wrap gap-3 mt-1 text-[11px] text-(--color-fg-muted)">
        <span className="inline-flex items-center gap-1">
          <span className="inline-block w-3 h-1 rounded-sm" style={{ background: 'var(--color-primary)' }} />
          медиана индекса
        </span>
        <span className="inline-flex items-center gap-1">
          <span className="inline-block w-3 h-3 rounded-sm" style={{ background: 'rgba(93,140,255,0.16)' }} />
          коридор 10–90% прогонов
        </span>
        <span className="inline-flex items-center gap-1">
          <span className="inline-block w-3 h-3 rounded-sm" style={{ background: 'rgba(208,59,59,0.6)' }} />
          доля прогонов в кризисе в этот день
        </span>
      </div>
    </div>
  );
}

/// График ветки: линия индекса поверх фоновых полос режимов и кризиса.
function SimChart({ sim }: { sim: SimResult }) {
  const values = sim.indexDaily;
  if (values.length < 2) return null;
  const w = 560;
  const h = 140;
  const padL = 4;
  const plotW = w - padL - 4;
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const x = (i: number) => padL + (i / (values.length - 1)) * plotW;
  const y = (v: number) => h - 22 - ((v - min) / span) * (h - 40);

  // Смежные дни одного режима → одна полоса.
  const bands: { from: number; to: number; regime: string }[] = [];
  sim.regimeDaily.forEach((r, i) => {
    const last = bands[bands.length - 1];
    if (last && last.regime === r && last.to === i - 1) last.to = i;
    else bands.push({ from: i, to: i, regime: r });
  });
  const crisis: { from: number; to: number }[] = [];
  sim.crisisDaily.forEach((c, i) => {
    if (!c) return;
    const last = crisis[crisis.length - 1];
    if (last && last.to === i - 1) last.to = i;
    else crisis.push({ from: i, to: i });
  });

  const dayW = plotW / (values.length - 1);
  const pts = values.map((v, i) => `${x(i)},${y(v)}`).join(' ');

  return (
    <div>
      <svg viewBox={`0 0 ${w} ${h}`} className="w-full">
        {bands.map((b, i) => (
          <rect
            key={i}
            x={x(b.from) - dayW / 2}
            y={6}
            width={(b.to - b.from + 1) * dayW}
            height={h - 26}
            fill={regimeWash[b.regime] ?? 'transparent'}
          />
        ))}
        {crisis.map((c, i) => (
          <rect
            key={`c${i}`}
            x={x(c.from) - dayW / 2}
            y={6}
            width={(c.to - c.from + 1) * dayW}
            height={h - 26}
            fill="rgba(208,59,59,0.30)"
          />
        ))}
        <polyline points={pts} fill="none" stroke="var(--color-primary)" strokeWidth="2" strokeLinejoin="round" />
        <text x={padL} y={16} fontSize="10" fill="var(--color-fg-muted)">{max.toFixed(1)}</text>
        <text x={padL} y={h - 26} fontSize="10" fill="var(--color-fg-muted)">{min.toFixed(1)}</text>
        {[0.25, 0.5, 0.75].map((f) => {
          const i = Math.round(f * (values.length - 1));
          return (
            <text key={f} x={x(i)} y={h - 6} fontSize="10" fill="var(--color-fg-muted)" textAnchor="middle">
              д.{sim.fromDay + i}
            </text>
          );
        })}
      </svg>
      <div className="flex flex-wrap gap-3 mt-1 text-[11px] text-(--color-fg-muted)">
        {Object.entries(regimeRu).map(([key, label]) => (
          <span key={key} className="inline-flex items-center gap-1">
            <span className="inline-block w-3 h-3 rounded-sm" style={{ background: regimeWash[key] }} />
            {label}
          </span>
        ))}
        <span className="inline-flex items-center gap-1">
          <span className="inline-block w-3 h-3 rounded-sm" style={{ background: 'rgba(208,59,59,0.30)' }} />
          кризис
        </span>
      </div>
    </div>
  );
}

export function WorldPage() {
  const qc = useQueryClient();

  const state = useQuery({
    queryKey: ['director-state'],
    queryFn: directorApi.state,
    refetchInterval: 10_000,
    retry: false,
  });
  const tuning = useQuery({
    queryKey: ['director-tuning'],
    queryFn: directorApi.tuning,
    retry: false,
  });

  const [form, setForm] = useState<WorldTuning | null>(null);
  const effectiveForm = form ?? tuning.data ?? null;

  const [simDays, setSimDays] = useState(120);
  const [useFormTuning, setUseFormTuning] = useState(true);
  const [ensembleMode, setEnsembleMode] = useState(true);
  const [simResult, setSimResult] = useState<SimResult | null>(null);
  const [ensResult, setEnsResult] = useState<EnsembleResult | null>(null);
  const [showDocs, setShowDocs] = useState(false);
  const [foresightResult, setForesightResult] = useState<ForesightResult | null>(null);
  const [foresightDays, setForesightDays] = useState(30);
  const [seedInput, setSeedInput] = useState('');

  const foresight = useMutation({
    mutationFn: () => directorApi.foresight(foresightDays),
    onSuccess: setForesightResult,
  });

  const reseed = useMutation({
    mutationFn: (seed: number | null) => directorApi.reseed(seed),
    onSuccess: ({ futureSeed }) => {
      setSeedInput(String(futureSeed));
      setForesightResult(null); // прежний просчёт аннулирован
      qc.invalidateQueries({ queryKey: ['director-state'] });
    },
  });

  const saveTuning = useMutation({
    mutationFn: (t: WorldTuning) => directorApi.saveTuning(t),
    onSuccess: (saved) => {
      setForm(saved);
      qc.setQueryData(['director-tuning'], saved);
    },
  });

  const simulate = useMutation({
    mutationFn: async () => {
      const tuning = useFormTuning ? effectiveForm : null;
      if (ensembleMode) {
        const r = await directorApi.simulateEnsemble({ days: simDays, runs: 20, tuning });
        return { ens: r, single: null as SimResult | null };
      }
      const r = await directorApi.simulate({ days: simDays, tuning });
      return { ens: null as EnsembleResult | null, single: r };
    },
    onSuccess: ({ ens, single }) => {
      setEnsResult(ens);
      setSimResult(single);
    },
  });

  const forceCrisis = useMutation({
    mutationFn: directorApi.forceCrisis,
    onSuccess: () => qc.invalidateQueries({ queryKey: ['director-state'] }),
  });
  const forceRegime = useMutation({
    mutationFn: directorApi.forceRegime,
    onSuccess: () => qc.invalidateQueries({ queryKey: ['director-state'] }),
  });

  const distressed = useMemo(
    () => (state.data?.issuers ?? []).filter((i) => i.distress > 0.5).length,
    [state.data],
  );

  if (state.isLoading) return <Spinner />;

  if (state.isError) {
    return (
      <>
        <PageHeader title="Экономический мир" subtitle="Aloria Director — ИИ-режиссёр" />
        <Card className="p-10 text-center">
          <AlertTriangle className="size-8 mx-auto text-(--color-error)" />
          <div className="text-base font-semibold mt-3">Режиссёр не отвечает</div>
          <div className="text-sm text-(--color-fg-muted) mt-1 font-mono">
            cd aloria-director/src/Aloria.Director && dotnet run
          </div>
          <div className="text-xs text-(--color-fg-muted) mt-2">
            Админка ходит на localhost:5077 через vite-proxy (/director)
          </div>
        </Card>
      </>
    );
  }

  const s = state.data!.snapshot;
  // Защищаемся от старого бэка без ДНК-полей: карточка ЦБ просто не рисуется.
  const cb = state.data!.centralBank ?? null;

  return (
    <>
      <PageHeader
        title="Экономический мир"
        subtitle="Живое состояние, тюнинг и симуляция будущего · Aloria Director"
        actions={
          <>
            {(['Expansion', 'Peak', 'Recession', 'Recovery'] as const).map((r) => (
              <Button
                key={r}
                onClick={() => forceRegime.mutate(r)}
                disabled={forceRegime.isPending || s.regime === r}
              >
                {regimeRu[r]}
              </Button>
            ))}
            <Button
              variant="danger"
              onClick={() => forceCrisis.mutate()}
              disabled={forceCrisis.isPending || s.crisis}
            >
              <AlertTriangle className="size-4" />
              Кризис сейчас
            </Button>
          </>
        }
      />

      {/* Живое макросостояние */}
      <Card className="p-6">
        <div className="flex items-center gap-3 mb-4">
          <Badge tone={regimeTone[s.regime] ?? 'neutral'}>{regimeRu[s.regime] ?? s.regime}</Badge>
          {s.crisis && <Badge tone="error">Кризис</Badge>}
          <span className="text-sm text-(--color-fg-muted)">
            день {s.day} · цикл {Math.floor((s.day - 1) / 10) + 1}, день {s.cycleDay}/10
          </span>
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7 gap-4">
          <Stat label="Ставка" value={`${s.keyRate.toFixed(2)}%`} />
          <Stat label="Инфляция" value={`${s.inflation.toFixed(1)}%`} />
          <Stat label="Рост" value={`${s.growth.toFixed(1)}%`} />
          <Stat label="Без кризиса" value={`${s.daysSinceCrisis} дн`} />
          <Stat label="В дистрессе" value={distressed} />
          <Stat
            label="Дефолты"
            value={state.data!.bonds.filter((b) => b.defaulted).length}
          />
          <Stat
            label="ЦБ"
            value={
              cb ? (
                <span className="block text-base leading-tight">
                  {cb.governorName}
                  <span className="block text-xs font-normal text-(--color-fg-muted) mt-0.5">
                    {hawkishnessRu(cb.hawkishness)} · {cb.hawkishness > 0 ? '+' : ''}
                    {cb.hawkishness.toFixed(2)}
                  </span>
                </span>
              ) : (
                '—'
              )
            }
          />
        </div>
      </Card>

      <div className="grid lg:grid-cols-2 gap-4 mt-4 items-start">
        {/* Тюнинг */}
        <Card className="p-6">
          <div className="flex items-center justify-between mb-4 gap-2">
            <h2 className="text-base font-bold">Ручки мира</h2>
            <div className="flex gap-2">
              <Button
                onClick={() => setForm({ ...defaultTuning })}
                title="Вернуть откалиброванные значения в форму (не применяя)"
              >
                <RotateCcw className="size-4" />
                Дефолты
              </Button>
              <Button
                variant="primary"
                disabled={!effectiveForm || saveTuning.isPending}
                onClick={() => effectiveForm && saveTuning.mutate(effectiveForm)}
              >
                <Save className="size-4" />
                Применить
              </Button>
            </div>
          </div>
          {!effectiveForm ? (
            <Spinner />
          ) : (
            <div className="grid sm:grid-cols-2 gap-4">
              {tuningFields.map(({ key, label, hint, step }) => (
                <Field key={key} label={label} hint={hint}>
                  <Input
                    type="number"
                    step={step}
                    value={effectiveForm[key]}
                    onChange={(e) =>
                      setForm({ ...effectiveForm, [key]: Number(e.target.value) })
                    }
                  />
                </Field>
              ))}
            </div>
          )}
          {saveTuning.isSuccess && (
            <div className="text-xs text-(--color-success) mt-3">
              Применено (значения ограничены безопасными диапазонами, переживут рестарт).
            </div>
          )}

          <button
            className="flex items-center gap-1.5 text-sm font-semibold text-(--color-primary) mt-4"
            onClick={() => setShowDocs((v) => !v)}
          >
            <HelpCircle className="size-4" />
            {showDocs ? 'Скрыть шпаргалку по ручкам' : 'Зачем эти ручки? Шпаргалка'}
          </button>
          {showDocs && (
            <div className="mt-3 space-y-3 border-t border-(--color-border) pt-3">
              {tuningFields.map(({ key, label, doc }) => (
                <div key={key}>
                  <div className="text-sm font-semibold">{label}</div>
                  <p className="text-xs text-(--color-fg-muted) mt-0.5 leading-relaxed">{doc}</p>
                </div>
              ))}
              <div className="rounded-lg bg-(--color-bg) border border-(--color-border) p-3">
                <div className="text-sm font-semibold">Рецепты</div>
                <ul className="text-xs text-(--color-fg-muted) mt-1 space-y-1 list-disc pl-4">
                  <li><b>Чаще кризисы, сюжетно</b>: «пузырь» 0.08–0.12 (рекомендую именно это).</li>
                  <li><b>Чаще кризисы, предсказуемо</b>: hazard 0.01–0.02.</li>
                  <li><b>Больше драмы у отдельных бумаг</b>: хвост 0.12–0.15.</li>
                  <li><b>Спокойный рынок для новичков</b>: события ×0.7, волатильность ×0.6, пузырь 0.02.</li>
                </ul>
              </div>
            </div>
          )}
        </Card>

        {/* Симуляция */}
        <Card className="p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-base font-bold flex items-center gap-2">
              <FlaskConical className="size-4" />
              Что будет дальше?
            </h2>
            <Button variant="primary" disabled={simulate.isPending} onClick={() => simulate.mutate()}>
              <Play className="size-4" />
              {simulate.isPending ? 'Считаю…' : 'Прогнать'}
            </Button>
          </div>
          <div className="flex items-end gap-4 mb-3 flex-wrap">
            <Field label="Дней вперёд">
              <Input
                type="number"
                min={10}
                max={365}
                value={simDays}
                onChange={(e) => setSimDays(Number(e.target.value) || 60)}
                className="w-28"
              />
            </Field>
            <label className="flex items-center gap-2 text-sm pb-2.5">
              <input
                type="checkbox"
                checked={ensembleMode}
                onChange={(e) => setEnsembleMode(e.target.checked)}
              />
              ансамбль ×20 (статистика)
            </label>
            <label className="flex items-center gap-2 text-sm pb-2.5">
              <input
                type="checkbox"
                checked={useFormTuning}
                onChange={(e) => setUseFormTuning(e.target.checked)}
              />
              с ручками из формы
            </label>
          </div>
          <p className="text-xs text-(--color-fg-muted) mb-3">
            Живой мир не трогается. <b>Ансамбль</b> прогоняет 20 независимых копий мира и показывает
            статистику — устойчивый ответ для сравнения ручек (одиночные прогоны на одних параметрах
            дают разные истории: это кости, а не баг). <b>Один прогон</b> — посмотреть одну живую
            историю с раскраской режимов.
          </p>
          {ensResult && (
            <div className="border-t border-(--color-border) pt-4">
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-3">
                <Stat
                  label="Кризис, % времени"
                  value={
                    <>
                      {(ensResult.crisisShare.mean * 100).toFixed(1)}%
                      <span className="text-xs font-normal text-(--color-fg-muted)">
                        {' '}({(ensResult.crisisShare.min * 100).toFixed(0)}–
                        {(ensResult.crisisShare.max * 100).toFixed(0)}%)
                      </span>
                    </>
                  }
                />
                <Stat label="Шанс ≥1 кризиса" value={`${(ensResult.pAnyCrisis * 100).toFixed(0)}%`} />
                <Stat
                  label="Первый кризис (медиана)"
                  value={
                    ensResult.firstCrisisMedianDays != null
                      ? `через ${ensResult.firstCrisisMedianDays} дн`
                      : '—'
                  }
                />
                <Stat
                  label="Дефолты (шанс)"
                  value={
                    Object.keys(ensResult.defaultProb).length
                      ? Object.entries(ensResult.defaultProb)
                          .map(([s, p]) => `${s} ${(p * 100).toFixed(0)}%`)
                          .join(', ')
                      : '—'
                  }
                />
              </div>
              <FanChart ens={ensResult} />
              <div className="text-xs text-(--color-fg-muted) mt-2">
                {ensResult.runs} независимых прогонов по {ensResult.days} дней от текущего мира
              </div>
            </div>
          )}
          {simResult && (
            <div className="border-t border-(--color-border) pt-4">
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-3">
                <Stat label="Кризис, % врем." value={`${(simResult.crisisShareOfTime * 100).toFixed(1)}%`} />
                <Stat
                  label="Первый кризис"
                  value={
                    simResult.firstCrisisAfterDays != null
                      ? `через ${simResult.firstCrisisAfterDays} дн`
                      : 'не случился'
                  }
                />
                <Stat label="Новостей/день" value={simResult.newsPerDay} />
                <Stat
                  label="Дефолты"
                  value={simResult.defaults.length ? simResult.defaults.join(', ') : '—'}
                />
              </div>
              <SimChart sim={simResult} />
              <div className="text-xs text-(--color-fg-muted) mt-2">
                Один прогон (одна из возможных историй) · итого:{' '}
                {Object.entries(simResult.regimeDays)
                  .map(([r, d]) => `${regimeRu[r] ?? r} ${d}д`)
                  .join(' · ')}
              </div>
            </div>
          )}
        </Card>
      </div>

      {/* Просчёт: точное будущее (спойлер!) */}
      <Card className="p-6 mt-4" style={{ borderColor: 'rgba(74,58,167,0.4)' }}>
        <div className="flex items-center justify-between gap-2 flex-wrap">
          <h2 className="text-base font-bold flex items-center gap-2">
            <Eye className="size-4" />
            Просчёт: точное будущее
            <Badge tone="primary">спойлер</Badge>
          </h2>
          <div className="flex items-end gap-2 flex-wrap">
            <Field label="Дней">
              <Input
                type="number"
                min={5}
                max={120}
                value={foresightDays}
                onChange={(e) =>
                  setForesightDays(Math.min(120, Math.max(5, Number(e.target.value) || 30)))
                }
                className="w-24"
              />
            </Field>
            {foresightResult && (
              <Button onClick={() => setForesightResult(null)}>
                <EyeOff className="size-4" />
                Скрыть
              </Button>
            )}
            <Button variant="primary" disabled={foresight.isPending} onClick={() => foresight.mutate()}>
              <Play className="size-4" />
              {foresight.isPending ? 'Считаю…' : 'Показать будущее'}
            </Button>
          </div>
        </div>
        <p className="text-xs text-(--color-fg-muted) mt-2">
          В отличие от симуляции, это продолжение <b>того же потока костей</b> — живой мир пройдёт
          ровно этот путь. Действует, пока никто не жмёт кнопки, не меняет ручки и не перебрасывает
          зерно (любое вмешательство ветвит будущее). Максимум 120 дней.
          Решил не подглядывать, чтобы было интересно — просто не нажимай.
        </p>

        {/* Зерно будущего */}
        <div className="flex items-end gap-2 flex-wrap mt-4 pt-3 border-t border-(--color-border)">
          <Field
            label="Зерно будущего"
            hint={`текущее: ${state.data!.futureSeed ?? 'неизвестно (мир до этой фичи)'}`}
          >
            <Input
              type="number"
              placeholder="своё число…"
              value={seedInput}
              onChange={(e) => setSeedInput(e.target.value)}
              className="w-44"
            />
          </Field>
          <Button
            disabled={reseed.isPending || seedInput.trim() === ''}
            onClick={() => reseed.mutate(Number(seedInput))}
          >
            Задать это зерно
          </Button>
          <Button disabled={reseed.isPending} onClick={() => reseed.mutate(null)}>
            <RotateCcw className="size-4" />
            Перебросить случайно
          </Button>
        </div>
        <p className="text-xs text-(--color-fg-muted) mt-2">
          Всё будущее мира = текущее состояние + это число. Не понравился просчёт — перебрось зерно
          и посмотри снова: прошлое не изменится, будущее сгенерируется заново. Число можно записать,
          но учти: оно воспроизводит то же будущее только из той же точки мира.
        </p>
        {foresightResult && (
          <div className="border-t border-(--color-border) pt-4 mt-3">
            <div className="flex flex-wrap gap-2 mb-3">
              {foresightResult.notable.length === 0 ? (
                <span className="text-sm text-(--color-fg-muted)">
                  Ближайшие {foresightResult.horizonDays} дней — без смен режима, кризисов и дефолтов.
                </span>
              ) : (
                foresightResult.notable.map((n, i) => (
                  <span
                    key={i}
                    className="inline-flex items-center gap-1.5 px-2.5 h-7 rounded-lg border border-(--color-border) bg-(--color-bg) text-xs"
                  >
                    <b>+{n.afterDays} дн</b>
                    <span
                      className={
                        n.what.startsWith('КРИЗИС') || n.what.startsWith('ДЕФОЛТ')
                          ? 'text-(--color-error) font-semibold'
                          : ''
                      }
                    >
                      {n.what
                        .replace('Expansion', 'рост')
                        .replace('Peak', 'перегрев')
                        .replace('Recession', 'рецессия')
                        .replace('Recovery', 'восстановление')}
                    </span>
                  </span>
                ))
              )}
            </div>
            <SimChart
              sim={{
                fromDay: foresightResult.fromDay,
                indexDaily: foresightResult.indexDaily,
                regimeDaily: foresightResult.regimeDaily,
                crisisDaily: foresightResult.crisisDaily,
              } as SimResult}
            />
            <div className="text-xs text-(--color-fg-muted) mt-2">{foresightResult.caveat}</div>
          </div>
        )}
      </Card>

      {/* Как это работает */}
      <Card className="p-6 mt-4">
        <h2 className="text-base font-bold flex items-center gap-2 mb-2">
          <HelpCircle className="size-4" />
          Как работают рычаги (и при чём тут seed)
        </h2>
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4 text-sm text-(--color-fg-muted) leading-relaxed">
          <div>
            <div className="font-semibold text-(--color-fg) mb-1">Будущее не записано</div>
            Seed — это не сценарий, а зерно потока случайностей. Мир генерируется тик за тиком:
            на каждом шаге кидаются кости (события, длительности режимов, сюрпризы) от текущего
            состояния. Заранее известны только частоты, не тайминги.
          </div>
          <div>
            <div className="font-semibold text-(--color-fg) mb-1">Кнопки меняют настоящее</div>
            «Рецессия» или «Кризис сейчас» мутируют текущее состояние мира — а дальше случайность
            продолжается уже от него: длительность новой фазы разыграется заново, события пойдут
            с её частотами. Это вмешательство, а не «перемотка сценария».
          </div>
          <div>
            <div className="font-semibold text-(--color-fg) mb-1">Симуляция ничего не трогает</div>
            «Что будет дальше?» клонирует мир и прогоняет копию вперёд с другим зерном —
            живой мир не меняется. Это одно из возможных будущих: частоты честные,
            конкретные даты у реального мира будут другие.
          </div>
          <div>
            <div className="font-semibold text-(--color-fg) mb-1">ДНК компаний</div>
            У каждой компании есть скрытые черты: moat гасит кризисный урон и негативные события,
            mgmt смещает знак продуктовых новостей и дрейф прибыли. Смена CEO перебрасывает mgmt
            (и рождает новость), а характер главы ЦБ (ястреб/голубь) смещает решения по ставке.
          </div>
        </div>
      </Card>

      {/* Инструменты */}
      <div className="grid lg:grid-cols-2 gap-4 mt-4 items-start">
        <Card className="p-6">
          <div className="flex items-center gap-2 mb-1">
            <h2 className="text-base font-bold">Акции · справедливая vs цель</h2>
            <Badge tone="warning">скрыто от учеников</Badge>
          </div>
          <p className="text-xs text-(--color-fg-muted) mb-3">
            Стадия, CEO, moat и mgmt — ДНК компаний: ученики видят только следы
            (устойчивость в кризис, сюрпризы отчётности, новости о руководстве).
          </p>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs uppercase tracking-wider text-(--color-fg-muted)">
                  <th className="pb-2">Тикер</th>
                  <th className="pb-2">Компания</th>
                  <th className="pb-2">Стадия</th>
                  <th className="pb-2">CEO</th>
                  <th className="pb-2 text-right">Правда</th>
                  <th className="pb-2 text-right">Цель</th>
                  <th className="pb-2 text-right">Moat</th>
                  <th className="pb-2 text-right">Mgmt</th>
                  <th className="pb-2 text-right">Дистресс</th>
                </tr>
              </thead>
              <tbody>
                {state.data!.issuers.map((i) => (
                  <tr key={i.symbol} className="border-t border-(--color-border)">
                    <td className="py-1.5 font-mono text-xs">{i.symbol}</td>
                    <td className="py-1.5 whitespace-nowrap">{i.name}</td>
                    <td className="py-1.5">
                      {stageRu[i.stage] ? (
                        <Badge tone={stageRu[i.stage].tone}>{stageRu[i.stage].label}</Badge>
                      ) : (
                        <span className="text-xs text-(--color-fg-muted)">—</span>
                      )}
                    </td>
                    <td className="py-1.5 whitespace-nowrap">
                      {i.ceoName ? (
                        <>
                          {i.ceoName}
                          <span className="block text-[11px] text-(--color-fg-muted)">
                            с дня {i.ceoSinceDay ?? 0}
                          </span>
                        </>
                      ) : (
                        <span className="text-xs text-(--color-fg-muted)">—</span>
                      )}
                    </td>
                    <td className="py-1.5 text-right tabular-nums">{i.fair.toFixed(1)}</td>
                    <td className="py-1.5 text-right tabular-nums font-semibold">{i.target.toFixed(1)}</td>
                    <td className="py-1.5 text-right">
                      <DnaValue value={i.moat} />
                    </td>
                    <td className="py-1.5 text-right">
                      <DnaValue value={i.mgmt} />
                    </td>
                    <td className="py-1.5 text-right">
                      {i.defaulted ? (
                        <Badge tone="error">дефолт</Badge>
                      ) : i.distress > 0.5 ? (
                        <Badge tone="warning">{(i.distress * 100).toFixed(0)}%</Badge>
                      ) : (
                        <span className="text-(--color-fg-muted) tabular-nums text-xs">
                          {(i.distress * 100).toFixed(0)}%
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>

        <Card className="p-6">
          <h2 className="text-base font-bold mb-3">Облигации и фонды</h2>
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs uppercase tracking-wider text-(--color-fg-muted)">
                <th className="pb-2">Тикер</th>
                <th className="pb-2 text-right">Цена, %</th>
                <th className="pb-2 text-right">Спред, пп</th>
                <th className="pb-2 text-right">До погаш.</th>
                <th className="pb-2 text-right">Статус</th>
              </tr>
            </thead>
            <tbody>
              {state.data!.bonds.map((b) => (
                <tr key={b.symbol} className="border-t border-(--color-border)">
                  <td className="py-1.5 font-mono text-xs">{b.symbol}</td>
                  <td className="py-1.5 text-right tabular-nums font-semibold">{b.target.toFixed(2)}</td>
                  <td className="py-1.5 text-right tabular-nums">{(b.spread * 100).toFixed(1)}</td>
                  <td className="py-1.5 text-right tabular-nums">{b.daysToMaturity} дн</td>
                  <td className="py-1.5 text-right">
                    {b.defaulted ? (
                      <Badge tone="error">дефолт</Badge>
                    ) : b.matured ? (
                      <Badge>погашен</Badge>
                    ) : (
                      <Badge tone="success">жив</Badge>
                    )}
                  </td>
                </tr>
              ))}
              {state.data!.funds.map((f) => (
                <tr key={f.symbol} className="border-t border-(--color-border)">
                  <td className="py-1.5 font-mono text-xs">{f.symbol}</td>
                  <td className="py-1.5 text-right tabular-nums font-semibold">{f.target.toFixed(2)}</td>
                  <td className="py-1.5 text-right text-(--color-fg-muted)" colSpan={2}>
                    {f.name}
                  </td>
                  <td className="py-1.5 text-right">
                    <Badge tone="primary">фонд</Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      </div>

      {/* Календарь вперёд */}
      <Card className="p-6 mt-4">
        <h2 className="text-base font-bold mb-3">Календарь мира (ближайшие события)</h2>
        <div className="flex flex-wrap gap-2">
          {state.data!.calendarAhead.map((e) => (
            <span
              key={e.id}
              className="inline-flex items-center gap-1.5 px-2.5 h-7 rounded-lg border border-(--color-border) bg-(--color-bg) text-xs"
            >
              <b>д.{e.day}</b> {e.type}
              {e.symbol && <span className="font-mono">{e.symbol}</span>}
            </span>
          ))}
        </div>
      </Card>
    </>
  );
}
