using Aloria.Director.Core.Engine;
using Aloria.Director.Core.Model;
using Xunit;

namespace Aloria.Director.Core.Tests;

public class BondMathTests
{
    [Fact]
    public void ParBond_PricesNearHundred()
    {
        // Купон = требуемая доходность → цена около номинала.
        var price = BondMath.CleanPrice(
            couponRatePerCycle: 0.10, couponEveryDays: 2, daysToMaturity: 30,
            yieldPerCycle: 0.10);
        Assert.InRange(price, 97, 103);
    }

    [Fact]
    public void HigherYield_LowerPrice()
    {
        var low = BondMath.CleanPrice(0.10, 2, 30, 0.08);
        var high = BondMath.CleanPrice(0.10, 2, 30, 0.16);
        Assert.True(high < low);
    }

    [Fact]
    public void ShortMaturity_ConvergesToPar()
    {
        var price = BondMath.CleanPrice(0.10, 2, 1, 0.25);
        Assert.InRange(price, 95, 105);
        Assert.Equal(100.0, BondMath.CleanPrice(0.10, 2, 0, 0.25));
    }

    [Fact]
    public void Accrued_GrowsWithinPeriodAndBounded()
    {
        var a0 = BondMath.Accrued(0.10, 2, 0);
        var a1 = BondMath.Accrued(0.10, 2, 1);
        var full = 0.10 * 100 * (2.0 / Universe.CycleDays);
        Assert.Equal(0, a0, 10);
        Assert.True(a1 > 0 && a1 <= full + 1e-9);
    }

    [Fact]
    public void Recovery_InDistressedRange()
    {
        var rng = new Rng(42);
        for (var i = 0; i < 200; i++)
            Assert.InRange(BondMath.RecoveryPrice(rng), 30, 45);
    }
}

public class DerivativesMathTests
{
    [Fact]
    public void PutCallParity_Holds()
    {
        const double s = 100, k = 105, r = 0.08, q = 0.02, sigma = 0.3, tau = 1.5;
        var call = DerivativesMath.Call(s, k, r, q, sigma, tau);
        var put = DerivativesMath.Put(s, k, r, q, sigma, tau);
        var parity = call - put;
        var theoretical = s * Math.Exp(-q * tau) - k * Math.Exp(-r * tau);
        Assert.Equal(theoretical, parity, 4);
    }

    [Fact]
    public void Forward_CostOfCarry()
    {
        Assert.True(DerivativesMath.Forward(100, 0.10, 0, 1) > 100);
        Assert.True(DerivativesMath.Forward(100, 0.02, 0.08, 1) < 100);
        Assert.Equal(100, DerivativesMath.Forward(100, 0.05, 0.05, 2), 9);
    }

    [Fact]
    public void Call_AboveIntrinsic_AndConvergesAtExpiry()
    {
        var call = DerivativesMath.Call(120, 100, 0.05, 0, 0.25, 0.5);
        Assert.True(call >= 20);
        Assert.Equal(20, DerivativesMath.Call(120, 100, 0.05, 0, 0.25, 0), 9);
        Assert.Equal(0, DerivativesMath.Put(120, 100, 0.05, 0, 0.25, 0), 9);
    }

    [Fact]
    public void Delta_WithinBounds()
    {
        var dCall = DerivativesMath.DeltaCall(100, 100, 0.05, 0, 0.3, 1);
        var dPut = DerivativesMath.DeltaPut(100, 100, 0.05, 0, 0.3, 1);
        Assert.InRange(dCall, 0, 1);
        Assert.InRange(dPut, -1, 0);
    }

    [Fact]
    public void NormCdf_KnownValues()
    {
        Assert.Equal(0.5, DerivativesMath.NormCdf(0), 6);
        Assert.Equal(0.8413, DerivativesMath.NormCdf(1), 3);
        Assert.Equal(0.0228, DerivativesMath.NormCdf(-2), 3);
    }
}

public class RegimeMachineTests
{
    [Fact]
    public void Durations_WithinClamps()
    {
        var rng = new Rng(7);
        for (var i = 0; i < 500; i++)
        {
            Assert.InRange(RegimeMachine.SampleDuration(Regime.Expansion, rng), 6, 30);
            Assert.InRange(RegimeMachine.SampleDuration(Regime.Peak, rng), 3, 12);
            Assert.InRange(RegimeMachine.SampleDuration(Regime.Recession, rng), 4, 16);
            Assert.InRange(RegimeMachine.SampleDuration(Regime.Recovery, rng), 3, 14);
        }
    }

    [Fact]
    public void PolicyDelta_SteppedAndClamped()
    {
        var macro = new MacroState { Inflation = 12, Growth = -3 };
        var delta = RegimeMachine.PolicyDelta(macro);
        Assert.Equal(2.0, delta); // клип сверху
        Assert.Equal(0, delta % 0.25, 9);

        macro.Inflation = 4;
        macro.Growth = 2;
        Assert.Equal(0, RegimeMachine.PolicyDelta(macro), 9);
    }

    [Fact]
    public void DailyStep_EventuallyCyclesThroughRegimes()
    {
        var rng = new Rng(123);
        var macro = new MacroState { RegimePlannedDays = 3 };
        var seen = new HashSet<Regime>();
        for (var d = 0; d < 400; d++)
        {
            RegimeMachine.DailyStep(macro, rng);
            seen.Add(macro.Regime);
        }
        Assert.Equal(4, seen.Count); // за год+ мир проходит все фазы
    }
}

public class EventSamplerTests
{
    [Fact]
    public void Severity_InUnitRange_WithHeavyTail()
    {
        var sampler = new EventSampler(new Rng(99));
        var values = Enumerable.Range(0, 20_000).Select(_ => sampler.SampleSeverity()).ToArray();

        Assert.All(values, v => Assert.InRange(v, 0, 1));
        var tailShare = values.Count(v => v >= 0.7) / (double)values.Length;
        Assert.InRange(tailShare, 0.04, 0.12); // хвост есть, но редкий
    }

    [Fact]
    public void TickSampling_ProducesTargetDailyRates()
    {
        var world = new WorldState { TicksPerDay = 96 };
        foreach (var s in Universe.Sectors)
            world.Sectors[s.Slug] = new SectorState { Spec = s };
        foreach (var i in Universe.Issuers)
            world.Issuers[i.Symbol] = new IssuerState { Spec = i };

        var sampler = new EventSampler(new Rng(5));
        var total = 0;
        const int days = 200;
        for (var t = 0; t < 96 * days; t++)
            total += sampler.SampleTick(world).Count;

        var perDay = total / (double)days;
        Assert.InRange(perDay, 2.5, 7.5); // ~4.6 в расширении
    }
}
