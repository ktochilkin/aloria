namespace Aloria.Api.Domain;

/// <summary>
/// Текущее состояние макромира (одна строка). На шаге 1 — мок/ручная правка,
/// позже обновляет ИИ-режиссёр. Ставка/инфляция — double (не деньги), чтобы
/// храниться как REAL в SQLite.
/// </summary>
public class MacroState
{
    public Guid Id { get; set; }

    /// <summary>expansion | peak | recession | recovery</summary>
    public string Regime { get; set; } = "expansion";

    public double KeyRate { get; set; }
    public double Inflation { get; set; }

    public int CycleDay { get; set; }
    public int CycleLength { get; set; } = 10;

    /// <summary>mock | director — источник состояния.</summary>
    public string Source { get; set; } = "mock";

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
