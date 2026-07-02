import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { AlertTriangle, FlaskConical, HelpCircle, Play, RotateCcw, Save } from 'lucide-react';
import { Badge, Button, Card, Field, Input, PageHeader, Spinner } from '../components/ui';
import {
  defaultTuning,
  directorApi,
  regimeRu,
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
];

function Stat({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div>
      <div className="text-xs font-semibold uppercase tracking-wider text-(--color-fg-muted)">{label}</div>
      <div className="text-xl font-bold text-(--color-fg) mt-0.5 tabular-nums">{value}</div>
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
  const [simResult, setSimResult] = useState<SimResult | null>(null);
  const [showDocs, setShowDocs] = useState(false);

  const saveTuning = useMutation({
    mutationFn: (t: WorldTuning) => directorApi.saveTuning(t),
    onSuccess: (saved) => {
      setForm(saved);
      qc.setQueryData(['director-tuning'], saved);
    },
  });

  const simulate = useMutation({
    mutationFn: () =>
      directorApi.simulate({
        days: simDays,
        tuning: useFormTuning ? effectiveForm : null,
      }),
    onSuccess: setSimResult,
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
        <div className="grid grid-cols-2 sm:grid-cols-5 gap-4">
          <Stat label="Ставка" value={`${s.keyRate.toFixed(2)}%`} />
          <Stat label="Инфляция" value={`${s.inflation.toFixed(1)}%`} />
          <Stat label="Рост" value={`${s.growth.toFixed(1)}%`} />
          <Stat label="В дистрессе" value={distressed} />
          <Stat
            label="Дефолты"
            value={state.data!.bonds.filter((b) => b.defaulted).length}
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
          <div className="flex items-end gap-4 mb-4">
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
                checked={useFormTuning}
                onChange={(e) => setUseFormTuning(e.target.checked)}
              />
              с ручками из формы (не применяя к миру)
            </label>
          </div>
          <p className="text-xs text-(--color-fg-muted) mb-3">
            Клонирует текущий мир и прогоняет вперёд (~2 с на 120 дней), живой мир не трогает.
            Показывает не «то самое» будущее (его ещё не существует), а <b>одно из возможных</b>:
            каждый клик — новый бросок костей. Жми несколько раз и смотри разброс — частоты честные,
            конкретные даты каждый раз свои.
          </p>
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
                Индекс Алории по дням ветки · итого:{' '}
                {Object.entries(simResult.regimeDays)
                  .map(([r, d]) => `${regimeRu[r] ?? r} ${d}д`)
                  .join(' · ')}
              </div>
            </div>
          )}
        </Card>
      </div>

      {/* Как это работает */}
      <Card className="p-6 mt-4">
        <h2 className="text-base font-bold flex items-center gap-2 mb-2">
          <HelpCircle className="size-4" />
          Как работают рычаги (и при чём тут seed)
        </h2>
        <div className="grid sm:grid-cols-3 gap-4 text-sm text-(--color-fg-muted) leading-relaxed">
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
        </div>
      </Card>

      {/* Инструменты */}
      <div className="grid lg:grid-cols-2 gap-4 mt-4 items-start">
        <Card className="p-6">
          <h2 className="text-base font-bold mb-3">Акции · справедливая vs цель</h2>
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs uppercase tracking-wider text-(--color-fg-muted)">
                <th className="pb-2">Тикер</th>
                <th className="pb-2">Компания</th>
                <th className="pb-2 text-right">Правда</th>
                <th className="pb-2 text-right">Цель</th>
                <th className="pb-2 text-right">Дистресс</th>
              </tr>
            </thead>
            <tbody>
              {state.data!.issuers.map((i) => (
                <tr key={i.symbol} className="border-t border-(--color-border)">
                  <td className="py-1.5 font-mono text-xs">{i.symbol}</td>
                  <td className="py-1.5">{i.name}</td>
                  <td className="py-1.5 text-right tabular-nums">{i.fair.toFixed(1)}</td>
                  <td className="py-1.5 text-right tabular-nums font-semibold">{i.target.toFixed(1)}</td>
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
