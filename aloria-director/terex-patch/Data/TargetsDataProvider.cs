using Npgsql;
using Terex.OrderGenerator.Configuration;
using Terex.OrderGenerator.Models;

namespace Terex.OrderGenerator.Data;

/// <summary>
/// Читает director.price_targets напрямую через Npgsql (таблица принадлежит
/// сервису Aloria Director и не входит в TerexContext). Если схемы ещё нет
/// (режиссёр не разворачивался) — возвращает пустой массив, генератор молчит.
/// </summary>
internal sealed class TargetsDataProvider : ITargetsDataProvider
{
    private readonly string _connectionString;

    public TargetsDataProvider(GeneratorOptions options)
        => _connectionString = options.TerexDbConnectionString;

    public async Task<TargetInfo[]> GetAllAsync(CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT symbol, target_price, sigma_daily, active
            FROM director.price_targets
            """;

        try
        {
            await using var conn = new NpgsqlConnection(_connectionString);
            await conn.OpenAsync(cancellationToken);
            await using var cmd = new NpgsqlCommand(sql, conn);
            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

            var result = new List<TargetInfo>();
            while (await reader.ReadAsync(cancellationToken))
            {
                result.Add(new TargetInfo
                {
                    Symbol = reader.GetString(0),
                    TargetPrice = reader.GetDecimal(1),
                    SigmaDaily = reader.GetDecimal(2),
                    Active = reader.GetBoolean(3),
                });
            }
            return result.ToArray();
        }
        catch (PostgresException e) when (e.SqlState is "42P01" or "3F000")
        {
            // Схемы/таблицы режиссёра ещё нет — это штатно.
            return [];
        }
    }
}
