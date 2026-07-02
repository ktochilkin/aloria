import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { AlertTriangle, FlaskConical, Play, Save } from 'lucide-react';
import { Badge, Button, Card, Field, Input, PageHeader, Spinner } from '../components/ui';
import { directorApi, regimeRu, type SimResult, type WorldTuning } from '../lib/directorApi';

// Управление экономическим миром: живое состояние, ручки тюнинга,
// ветка-симуляция «что будет дальше» и ручные рычаги (режим/кризис).

const regimeTone: Record<string, 'success' | 'warning' | 'error' | 'primary'> = {
  Expansion: 'success',
  Peak: 'warning',
  Recession: 'error',
  Recovery: 'primary',
};

const tuningFields: { key: keyof WorldTuning; label: string; hint: string; step: number }[] = [
  { key: 'eventRateMultiplier', label: 'Частота событий ×', hint: '1 = ~4.6 событий/день', step: 0.1 },
  { key: 'tailChance', label: 'Шанс хвоста Парето', hint: 'доля крупных событий (базово 0.09)', step: 0.01 },
  { key: 'crisisSeverityThreshold', label: 'Порог кризиса', hint: 'серьёзность макрошока → кризис (0.85)', step: 0.01 },
  { key: 'peakBubbleBurstPerDay', label: '«Пузырь» в перегреве /день', hint: 'главный рычаг частоты кризисов (0.04)', step: 0.01 },
  { key: 'crisisHazardPerDay', label: 'Прямой hazard кризиса /день', hint: '0 = выкл; грубый рычаг в любом режиме', step: 0.005 },
  { key: 'volatilityMultiplier', label: 'Волатильность ×', hint: 'поверх режимной (1 = базовая)', step: 0.1 },
];

function Stat({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div>
      <div className="text-xs font-semibold uppercase tracking-wider text-(--color-fg-muted)">{label}</div>
      <div className="text-xl font-bold text-(--color-fg) mt-0.5 tabular-nums">{value}</div>
    </div>
  );
}

function IndexSparkline({ values }: { values: number[] }) {
  if (values.length < 2) return null;
  const w = 560;
  const h = 120;
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const pts = values
    .map((v, i) => `${(i / (values.length - 1)) * (w - 8) + 4},${h - 6 - ((v - min) / span) * (h - 12)}`)
    .join(' ');
  return (
    <svg viewBox={`0 0 ${w} ${h}`} className="w-full">
      <polyline points={pts} fill="none" stroke="var(--color-primary)" strokeWidth="2" strokeLinejoin="round" />
      <text x="4" y="12" fontSize="10" fill="var(--color-fg-muted)">{max.toFixed(1)}</text>
      <text x="4" y={h - 10} fontSize="10" fill="var(--color-fg-muted)">{min.toFixed(1)}</text>
    </svg>
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
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-base font-bold">Ручки мира</h2>
            <Button
              variant="primary"
              disabled={!effectiveForm || saveTuning.isPending}
              onClick={() => effectiveForm && saveTuning.mutate(effectiveForm)}
            >
              <Save className="size-4" />
              Применить к живому миру
            </Button>
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
            Клонирует текущий мир и прогоняет вперёд (~2 с на 120 дней). Одно возможное будущее —
            конкретный seed; частоты честные, тайминги случайные.
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
              <IndexSparkline values={simResult.indexDaily} />
              <div className="text-xs text-(--color-fg-muted) mt-1">
                Индекс Алории по дням ветки · режимы:{' '}
                {Object.entries(simResult.regimeDays)
                  .map(([r, d]) => `${regimeRu[r] ?? r} ${d}д`)
                  .join(' · ')}
              </div>
            </div>
          )}
        </Card>
      </div>

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
