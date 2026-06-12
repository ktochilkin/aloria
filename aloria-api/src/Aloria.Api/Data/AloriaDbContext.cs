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
    public DbSet<ReviewItem> ReviewItems => Set<ReviewItem>();
    public DbSet<DeviceToken> DeviceTokens => Set<DeviceToken>();

    // r11 — спиральная модель
    public DbSet<Concept> Concepts => Set<Concept>();
    public DbSet<LessonConcept> LessonConcepts => Set<LessonConcept>();
    public DbSet<PracticeRequirement> PracticeRequirements => Set<PracticeRequirement>();
    public DbSet<UserStageProgress> UserStageProgress => Set<UserStageProgress>();
    public DbSet<UserLessonProgress> UserLessonProgress => Set<UserLessonProgress>();
    public DbSet<UserConceptMastery> UserConceptMastery => Set<UserConceptMastery>();
    public DbSet<UserPracticeFulfillment> UserPracticeFulfillments => Set<UserPracticeFulfillment>();
    public DbSet<TradeEvent> TradeEvents => Set<TradeEvent>();
    public DbSet<SupportTicket> SupportTickets => Set<SupportTicket>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        base.OnModelCreating(b);

        b.Entity<Section>(e =>
        {
            e.HasIndex(x => x.Slug).IsUnique();
            e.Property(x => x.Slug).HasMaxLength(64).IsRequired();
            e.Property(x => x.Title).HasMaxLength(256).IsRequired();
            e.Property(x => x.Kind).HasMaxLength(16).HasDefaultValue("stage");
            e.HasMany(x => x.Lessons).WithOne(x => x.Section!).HasForeignKey(x => x.SectionId).OnDelete(DeleteBehavior.Cascade);
            e.HasMany(x => x.PracticeRequirements).WithOne(x => x.Section!).HasForeignKey(x => x.SectionId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<Lesson>(e =>
        {
            e.HasIndex(x => new { x.SectionId, x.Slug }).IsUnique();
            e.Property(x => x.Slug).HasMaxLength(64).IsRequired();
            e.Property(x => x.Title).HasMaxLength(256).IsRequired();
            e.HasOne(x => x.Quiz).WithOne(x => x.Lesson!).HasForeignKey<Quiz>(x => x.LessonId).OnDelete(DeleteBehavior.Cascade);
            e.HasMany(x => x.Concepts).WithOne(x => x.Lesson!).HasForeignKey(x => x.LessonId).OnDelete(DeleteBehavior.Cascade);
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

        b.Entity<ReviewItem>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.LessonId }).IsUnique();
        });

        b.Entity<DeviceToken>(e =>
        {
            e.HasIndex(x => x.Token).IsUnique();
            e.Property(x => x.Token).IsRequired();
        });

        // r11 — спиральная модель: концепции, связи, практика и прогресс.

        b.Entity<Concept>(e =>
        {
            e.HasIndex(x => x.Slug).IsUnique();
            e.Property(x => x.Slug).HasMaxLength(64).IsRequired();
            e.Property(x => x.Title).HasMaxLength(128).IsRequired();
            e.Property(x => x.ShortDefinition).HasMaxLength(512);
        });

        b.Entity<LessonConcept>(e =>
        {
            e.HasKey(x => new { x.LessonId, x.ConceptId, x.Role });
            e.HasOne(x => x.Lesson).WithMany(x => x.Concepts).HasForeignKey(x => x.LessonId).OnDelete(DeleteBehavior.Cascade);
            e.HasOne(x => x.Concept).WithMany(x => x.Lessons).HasForeignKey(x => x.ConceptId).OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(x => new { x.ConceptId, x.Role });
        });

        b.Entity<PracticeRequirement>(e =>
        {
            e.HasIndex(x => new { x.SectionId, x.Code }).IsUnique();
            e.Property(x => x.Code).HasMaxLength(64).IsRequired();
            e.Property(x => x.Title).HasMaxLength(256).IsRequired();
            e.HasIndex(x => x.Archived);
        });

        b.Entity<UserStageProgress>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.SectionId }).IsUnique();
        });

        b.Entity<UserLessonProgress>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.LessonId }).IsUnique();
        });

        b.Entity<UserConceptMastery>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.ConceptId }).IsUnique();
        });

        b.Entity<UserPracticeFulfillment>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.PracticeRequirementId }).IsUnique();
            e.HasIndex(x => x.IdempotencyKey).IsUnique();
            e.Property(x => x.IdempotencyKey).HasMaxLength(128).IsRequired();
        });

        b.Entity<TradeEvent>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.OccurredAt });
            e.HasIndex(x => x.IdempotencyKey).IsUnique();
            e.Property(x => x.IdempotencyKey).HasMaxLength(128).IsRequired();
            e.Property(x => x.Symbol).HasMaxLength(32);
            e.Property(x => x.AssetClass).HasMaxLength(16);
            e.Property(x => x.Qty).HasPrecision(18, 6);
            e.Property(x => x.Price).HasPrecision(18, 6);
        });

        b.Entity<SupportTicket>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.CreatedAt });
            e.Property(x => x.Status).HasMaxLength(16).IsRequired();
            e.Property(x => x.Subject).HasMaxLength(256).IsRequired();
            e.Property(x => x.ErrorCode).HasMaxLength(64);
        });
    }
}
