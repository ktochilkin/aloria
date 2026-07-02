# Aloria Director — ИИ-режиссёр экономического мира

Сервис, который делает рынок Алории живым: крутит макроцикл, генерирует
события и новости (RNG-сэмплер → LLM через OpenRouter → математическое ядро),
считает целевые цены и отдаёт их маркетмейкеру terex.

Дизайн: `../docs/ai-director-design.md`. Концепция: `../docs/macro-economy-concept.md`.

## Структура

```
src/Aloria.Director.Core   — чистое ядро мира (без I/O): модель, математика, шаблоны
src/Aloria.Director        — хост: tick-loop, Postgres terex, OpenRouter, aloria-api, админ-API
tests/…Core.Tests          — юнит-тесты математики и движка (xunit)
```

## Запуск

```bash
# Симуляция мира на 60 дней (без БД и LLM — шаблоны), трейс + сводка:
cd src/Aloria.Director
dotnet run -- simulate --days 60 --seed 20260701 --out sim-trace.jsonl

# Засев вселенной в Postgres terex (идемпотентно) + стартовые целевые цены:
export DIRECTOR_TEREX_DB="Host=localhost;Port=5432;Database=terex;Username=postgres;Password=..."
dotnet run -- seed

# Боевой режим: тик каждые TickSeconds, админка на :5077
export OPENROUTER_API_KEY=sk-or-...
dotnet run
```

Админ-API: `GET /director/state` (весь мир), `POST /director/regime`
(`{"regime":"recession"}` — единственный ручной рычаг).

## Как это двигает рынок

Режиссёр пишет `director.price_targets` (символ → целевая цена + дневная
волатильность) в ту же Postgres, что использует terex. Новый генератор
`TargetPriceCommandsGenerator` в terex.ordergenerator периодически перечитывает
цели и котирует лестницу заявок вокруг них от клиента `GEN` — стакан живёт и
двигается за миром. Старые генераторы не тронуты.

Новости/макро/календарь публикуются в aloria-api (`/api/admin/market/*`) —
их читает приложение.

## Конфиг

`appsettings.json` секция `Director` (+ env `DIRECTOR_TEREX_DB`,
`DIRECTOR_SEED`, `OPENROUTER_API_KEY`). LLM выключается флагом
`Director:Llm:Enabled=false` — мир продолжает жить на шаблонных новостях.
