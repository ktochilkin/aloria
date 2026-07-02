# Патч terex.ordergenerator — маркетмейкер по целевым ценам

Новый генератор для оживления рынка (старые классы НЕ тронуты). Файлы этой
папки раскладываются в
`/Users/kirilltocilkin/Documents/warp/Downloads/terex.ordergenerator-master/Terex.OrderGenerator/`:

| Файл патча | Куда |
|---|---|
| `Configuration/TargetGeneratorOptions.cs` | `Configuration/` (новый) |
| `Models/TargetInfo.cs` | `Models/` (новый) |
| `Data/ITargetsDataProvider.cs` | `Data/` (новый) |
| `Data/TargetsDataProvider.cs` | `Data/` (новый) |
| `Services/TargetPriceCommandsGenerator.cs` | `Services/` (новый) |
| `PATCHES.md` | правки 2 существующих файлов (по 2 строки) |

Что делает: раз в `TargetsRefreshSeconds` перечитывает `director.price_targets`
(таблица Aloria Director в той же Postgres terex) и инструменты; для каждого
активного инструмента держит локальную середину, тянет её к целевой цене
(доля `PullFactorPct` разрыва за котирование, максимум `MaxStepTicks` шагов),
добавляет шум и котирует лестницу лимиток `DepthLevels`×2 со спредом от
дневной волатильности; изредка шлёт рыночную заявку-тейкер в сторону цели.
Цены квантуются к `MinPriceIncrement` (decimal, без int-каста), объёмы целые,
клиент `GEN`, TIF: OneDay/FoK. Без конфига `Terex::TargetGenerator` генератор
выключен (безопасный деплой).

Пример конфига (Identity, `Terex::TargetGenerator`):

```json
{
  "MinIntervalMs": 800,
  "MaxIntervalMs": 2500,
  "TargetsRefreshSeconds": 10,
  "PullFactorPct": 25,
  "MaxStepTicks": 40,
  "NoiseSteps": 3,
  "SpreadSigmaFactorPct": 80,
  "DepthLevels": 3,
  "LevelStepTicks": 2,
  "MaxLimitQuantity": 40,
  "TakerProbPct": 8,
  "MaxMarketQuantity": 12
}
```
