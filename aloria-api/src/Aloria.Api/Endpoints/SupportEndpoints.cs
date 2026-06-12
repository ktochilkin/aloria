using Aloria.Api.Data;
using Aloria.Api.Domain;
using Aloria.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Endpoints;

/// <summary>
/// Обращения в поддержку: создание из приложения с подробным контекстом
/// и просмотр статуса своих обращений. Ответ пользователю уходит на почту,
/// чата в приложении нет — поэтому статусы максимально простые.
/// </summary>
public static class SupportEndpoints
{
    public record CreateTicketRequest(
        string Subject,
        string? ErrorCode,
        string? ErrorMessage,
        string? Context,
        string? Comment);

    public record AnswerTicketRequest(string Answer);

    public static IEndpointRouteBuilder MapSupportEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/v1/support/tickets").WithTags("Support");

        // Создать обращение. Контекст (заявка, портфель, позиции) приложение
        // собирает само и передаёт строкой JSON — он нужен только для разбора.
        group.MapPost("", async (
            string portfolioId,
            CreateTicketRequest body,
            AloriaDbContext db,
            UserService users,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(portfolioId))
                return Results.BadRequest("portfolioId required");
            if (string.IsNullOrWhiteSpace(body.Subject))
                return Results.BadRequest("subject required");

            var user = await users.EnsureUserAsync(portfolioId, ct);
            var ticket = new SupportTicket
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                Subject = body.Subject.Trim(),
                ErrorCode = body.ErrorCode,
                ErrorMessage = body.ErrorMessage,
                ContextJson = body.Context,
                UserComment = string.IsNullOrWhiteSpace(body.Comment) ? null : body.Comment!.Trim(),
            };
            db.SupportTickets.Add(ticket);
            await db.SaveChangesAsync(ct);
            return Results.Ok(new
            {
                id = ticket.Id,
                status = ticket.Status,
                createdAt = ticket.CreatedAt,
            });
        });

        // Свои обращения: тема, статус, ответ (без технического контекста).
        group.MapGet("", async (
            string portfolioId,
            AloriaDbContext db,
            UserService users,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(portfolioId))
                return Results.BadRequest("portfolioId required");

            var user = await users.EnsureUserAsync(portfolioId, ct);
            var tickets = await db.SupportTickets
                .Where(t => t.UserId == user.Id)
                .OrderByDescending(t => t.CreatedAt)
                .Select(t => new
                {
                    id = t.Id,
                    subject = t.Subject,
                    status = t.Status,
                    createdAt = t.CreatedAt,
                    answer = t.Answer,
                    answeredAt = t.AnsweredAt,
                })
                .ToListAsync(ct);
            return Results.Ok(tickets);
        });

        // Админка: все обращения с полным контекстом для разбора.
        var admin = app.MapGroup("/api/admin/support/tickets").WithTags("Admin");

        admin.MapGet("", async (AloriaDbContext db, CancellationToken ct) =>
        {
            var tickets = await db.SupportTickets
                .Include(t => t.User)
                .OrderByDescending(t => t.CreatedAt)
                .Select(t => new
                {
                    id = t.Id,
                    portfolioId = t.User!.AlorPortfolioId,
                    subject = t.Subject,
                    status = t.Status,
                    errorCode = t.ErrorCode,
                    errorMessage = t.ErrorMessage,
                    context = t.ContextJson,
                    comment = t.UserComment,
                    answer = t.Answer,
                    createdAt = t.CreatedAt,
                    answeredAt = t.AnsweredAt,
                })
                .ToListAsync(ct);
            return Results.Ok(tickets);
        });

        admin.MapPost("/{id:guid}/answer", async (
            Guid id,
            AnswerTicketRequest body,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(body.Answer))
                return Results.BadRequest("answer required");

            var ticket = await db.SupportTickets.FirstOrDefaultAsync(t => t.Id == id, ct);
            if (ticket == null) return Results.NotFound();

            ticket.Answer = body.Answer.Trim();
            ticket.Status = "answered";
            ticket.AnsweredAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("answer", "SupportTicket", id, ticket.Subject, ct);
            return Results.Ok(new { id = ticket.Id, status = ticket.Status });
        });

        return app;
    }
}
