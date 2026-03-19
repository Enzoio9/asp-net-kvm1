using Microsoft.EntityFrameworkCore;

namespace OllamaWebApi;

public class VideoJob
{
    public string Id { get; set; } = string.Empty;
    public string Prompt { get; set; } = string.Empty;
    public string? ImagePath { get; set; }  // User uploaded image
    public string? ImageUrl { get; set; }   // URL to access the image
    public string? VideoPath { get; set; }
    public string Status { get; set; } = "pending";
    public int Progress { get; set; } = 0;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public string? ErrorMessage { get; set; }
    public string Metadata { get; set; } = "{}";
}

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<VideoJob> Jobs { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<VideoJob>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Prompt).IsRequired().HasMaxLength(2000);
            entity.Property(e => e.Status).IsRequired();
            entity.HasIndex(e => e.Status);
        });
    }
}
