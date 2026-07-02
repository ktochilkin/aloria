# Правки существующих файлов terex.ordergenerator (по 2 строки)

## 1. `Configuration/GeneratorOptions.cs`

Добавить свойство (секция опциональна — Warn, не Required):

```csharp
    [AlorSettings(SettingsSource.Identity, SettingsSeverity.WarnIfInvalidOrNull,
        SourceName = "Terex::TargetGenerator")]
    public TargetGeneratorOptions? TargetGeneratorOptions { get; init; }
```

## 2. `Configuration/ServiceCollectionExtensions.cs`

В `AddCommandsGenerators()` добавить регистрацию генератора:

```csharp
        services.AddSingleton<ICommandsGenerator, TargetPriceCommandsGenerator>();
```

В `AddCommandsGeneratorWorker()` добавить регистрацию провайдера целей:

```csharp
            .AddSingleton<ITargetsDataProvider, TargetsDataProvider>()
```

Всё остальное — новые файлы (см. README.md патча). Старые генераторы
(Simple/Interval) не изменены; без конфига `Terex::TargetGenerator` поведение
сервиса идентично текущему.
