using System.Text.Json;
using Aloria.Api.Data;
using Aloria.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Services;

/// <summary>
/// Берёт нормализованное торговое событие (TradeEvent) и проверяет, какие
/// активные требования практики (PracticeRequirement) оно закрывает. Логика
/// матчинга — щедрая: если ученик сделал больше, чем нужно для конкретной
/// цели, она засчитывается. Если меньше — не засчитывается.
/// </summary>
public class PracticeEventDispatcher(
    AloriaDbContext db,
    ProgressUpdater progressUpdater,
    ILogger<PracticeEventDispatcher> log)
{
    /// <summary>
    /// Принимает уже сохранённый TradeEvent и фулфилит все совпавшие
    /// требования практики. Возвращает список закрытых требований для UI.
    /// </summary>
    public async Task<List<PracticeRequirement>> DispatchAsync(
        User user, TradeEvent tradeEvent, CancellationToken ct)
    {
        // Все активные требования по этапам, до которых дошёл пользователь:
        // не Archived, не уже фулфилленные этим юзером.
        var alreadyFulfilledIds = await db.UserPracticeFulfillments
            .Where(uf => uf.UserId == user.Id)
            .Select(uf => uf.PracticeRequirementId)
            .ToHashSetAsync(ct);

        var candidates = await db.PracticeRequirements
            .Where(pr => !pr.Archived && !alreadyFulfilledIds.Contains(pr.Id))
            .ToListAsync(ct);

        var fulfilled = new List<PracticeRequirement>();
        foreach (var req in candidates)
        {
            if (!Matches(req, tradeEvent))
            {
                continue;
            }

            var idemKey = $"trade:{tradeEvent.Id}:req:{req.Id}";

            // Защита от двойного зачёта: проверка существующей записи по
            // (UserId, PracticeRequirementId) — есть unique index.
            var exists = await db.UserPracticeFulfillments
                .AnyAsync(uf => uf.UserId == user.Id && uf.PracticeRequirementId == req.Id, ct);
            if (exists) continue;

            var ev = new UserPracticeFulfillment
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                PracticeRequirementId = req.Id,
                FulfilledAt = tradeEvent.OccurredAt,
                IdempotencyKey = idemKey,
                EvidenceJson = JsonSerializer.Serialize(new
                {
                    source = "trade-event",
                    tradeEventId = tradeEvent.Id,
                    type = tradeEvent.Type.ToString(),
                    symbol = tradeEvent.Symbol,
                    assetClass = tradeEvent.AssetClass,
                    qty = tradeEvent.Qty,
                    price = tradeEvent.Price,
                }),
            };
            db.UserPracticeFulfillments.Add(ev);

            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException ex)
            {
                // Гонка с параллельным запросом — кто-то уже зачёл это
                // требование. Пропускаем дубль.
                log.LogDebug(ex, "Concurrent practice fulfillment for user {UserId}, req {Code}",
                    user.Id, req.Code);
                continue;
            }

            await progressUpdater.OnPracticeFulfilledAsync(user, req, ct);
            fulfilled.Add(req);
            log.LogInformation("Practice fulfilled: user={UserId} req={Code}", user.Id, req.Code);
        }
        return fulfilled;
    }

    /// <summary>
    /// Сопоставление события с конкретным требованием. Возвращает true, если
    /// событие закрывает требование. Реализуется «щедро» — лучше засчитать
    /// лишнее, чем создать ощущение бюрократии.
    /// </summary>
    private static bool Matches(PracticeRequirement req, TradeEvent ev)
    {
        return req.Kind switch
        {
            PracticeKind.OpenPosition => MatchesOpenPosition(req, ev),
            PracticeKind.HoldUntilEvent => MatchesHoldUntilEvent(req, ev),
            PracticeKind.PlaceLimitOrder => ev.Type == TradeEventType.OrderPlaced,
            PracticeKind.CancelOrder => ev.Type == TradeEventType.OrderCancelled,
            PracticeKind.ClosePosition => ev.Type == TradeEventType.PositionClosed,
            PracticeKind.Custom => false, // обрабатывается в специализированных хендлерах
            _ => false,
        };
    }

    private static bool MatchesOpenPosition(PracticeRequirement req, TradeEvent ev)
    {
        if (ev.Type != TradeEventType.OrderFilled && ev.Type != TradeEventType.PositionOpened)
            return false;

        try
        {
            using var doc = JsonDocument.Parse(req.ParamsJson);
            var root = doc.RootElement;

            var assetClass = root.TryGetProperty("assetClass", out var ac) ? ac.GetString() : null;
            var minQty = root.TryGetProperty("minQty", out var mq) && mq.ValueKind == JsonValueKind.Number
                ? mq.GetDecimal() : 1m;

            if (!string.IsNullOrWhiteSpace(assetClass)
                && !assetClass.Equals("any", StringComparison.OrdinalIgnoreCase)
                && !assetClass.Equals(ev.AssetClass, StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            if (Math.Abs(ev.Qty) < minQty) return false;

            if (root.TryGetProperty("symbolIn", out var symEl) && symEl.ValueKind == JsonValueKind.Array)
            {
                var allowed = symEl.EnumerateArray()
                    .Select(s => s.GetString())
                    .Where(s => !string.IsNullOrEmpty(s));
                if (!allowed.Contains(ev.Symbol, StringComparer.OrdinalIgnoreCase))
                    return false;
            }

            return true;
        }
        catch
        {
            return false;
        }
    }

    private static bool MatchesHoldUntilEvent(PracticeRequirement req, TradeEvent ev)
    {
        try
        {
            using var doc = JsonDocument.Parse(req.ParamsJson);
            var root = doc.RootElement;
            var eventType = root.TryGetProperty("eventType", out var et) ? et.GetString() : null;

            return eventType?.ToLowerInvariant() switch
            {
                "coupon" => ev.Type == TradeEventType.CouponPaid,
                "dividend" => ev.Type == TradeEventType.DividendPaid,
                _ => false,
            };
        }
        catch
        {
            return false;
        }
    }
}
