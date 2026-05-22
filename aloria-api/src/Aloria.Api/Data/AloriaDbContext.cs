using Aloria.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Data;

public class AloriaDbContext(DbContextOptions<AloriaDbContext> options) : DbContext(options)
{
    public DbSet<Section> Sections => Set<Section>();
    public DbSet<Lesson> Lessons => Set<Lesson>();
    public DbSet<Quiz> Quizzes => Set<Quiz>();
    public DbSet<QuizQuestion> QuizQuestions => Set<QuizQuestion>();
    public DbSet<QuizOption> QuizOptions => Set<QuizOption>();
    public DbSet<Achievement> Achievements => Set<Achievement>();
    public DbSet<User> Users => Set<User>();
    public DbSet<LessonCompletion> LessonCompletions => Set<LessonCompletion>();
    public DbSet<QuizAttempt> QuizAttempts => Set<QuizAttempt>();
    public DbSet<AchievementUnlock> AchievementUnlocks => Set<AchievementUnlock>();
    public DbSet<BuyingPowerGrant> BuyingPowerGrants => Set<BuyingPowerGrant>();
    public DbSet<AuditLogEntry> AuditLog => Set<AuditLogEntry>();
    public DbSet<UserEvent> UserEvents => Set<UserEvent>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        base.OnModelCreating(b);

        b.Entity<Section>(e =>
        {
            e.HasIndex(x => x.Slug).IsUnique();
            e.Property(x => x.Slug).HasMaxLength(64).IsRequired();
            e.Property(x => x.Title).HasMaxLength(256).IsRequired();
            e.HasMany(x => x.Lessons).WithOne(x => x.Section!).HasForeignKey(x => x.SectionId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<Lesson>(e =>
        {
            e.HasIndex(x => new { x.SectionId, x.Slug }).IsUnique();
            e.Property(x => x.Slug).HasMaxLength(64).IsRequired();
            e.Property(x => x.Title).HasMaxLength(256).IsRequired();
            e.HasOne(x => x.Quiz).WithOne(x => x.Lesson!).HasForeignKey<Quiz>(x => x.LessonId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<Quiz>(e =>
        {
            e.HasIndex(x => x.Slug).IsUnique();
            e.Property(x => x.Slug).HasMaxLength(96).IsRequired();
            e.Property(x => x.Title).HasMaxLength(256).IsRequired();
            e.Property(x => x.RewardBuyingPower).HasPrecision(18, 2);
            e.HasMany(x => x.Questions).WithOne(x => x.Quiz!).HasForeignKey(x => x.QuizId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<QuizQuestion>(e =>
        {
            e.HasMany(x => x.Options).WithOne(x => x.Question!).HasForeignKey(x => x.QuestionId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<Achievement>(e =>
        {
            e.HasIndex(x => x.Code).IsUnique();
            e.Property(x => x.Code).HasMaxLength(64).IsRequired();
            e.Property(x => x.RewardBuyingPower).HasPrecision(18, 2);
        });

        b.Entity<User>(e =>
        {
            e.HasIndex(x => x.AlorPortfolioId).IsUnique();
            e.Property(x => x.AlorPortfolioId).HasMaxLength(64).IsRequired();
        });

        b.Entity<LessonCompletion>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.LessonId }).IsUnique();
        });

        b.Entity<QuizAttempt>(e =>
        {
            e.HasIndex(x => x.IdempotencyKey).IsUnique();
            e.Property(x => x.IdempotencyKey).HasMaxLength(128).IsRequired();
            e.Property(x => x.AwardedBuyingPower).HasPrecision(18, 2);
        });

        b.Entity<AchievementUnlock>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.AchievementId }).IsUnique();
        });

        b.Entity<BuyingPowerGrant>(e =>
        {
            e.HasIndex(x => x.IdempotencyKey).IsUnique();
            e.Property(x => x.IdempotencyKey).HasMaxLength(128).IsRequired();
            e.Property(x => x.Amount).HasPrecision(18, 2);
            e.Property(x => x.Status).HasMaxLength(16).IsRequired();
        });

        b.Entity<AuditLogEntry>(e =>
        {
            e.HasIndex(x => x.CreatedAt);
        });

        b.Entity<UserEvent>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.Code }).IsUnique();
            e.Property(x => x.Code).HasMaxLength(64).IsRequired();
        });
    }
}
