using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.EntityFrameworkCore;
using System.Text;

namespace OllamaWebApi;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Add services to the container.
        builder.Services.AddControllers();
        builder.Services.AddEndpointsApiExplorer();
        builder.Services.AddSwaggerGen(c =>
        {
            c.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
            {
                Title = "Ollama Web API - dicabr.com.br",
                Version = "v1",
                Description = "ASP.NET Core API for AI video generation"
            });
        });

        // Database context
        builder.Services.AddDbContext<AppDbContext>(options =>
        {
            var dbPath = Environment.GetEnvironmentVariable("DB_PATH") ?? 
                        Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "data", "queue.db");
            options.UseSqlite($"Data Source={dbPath}");
        });

        // CORS - Allow all origins (configure for production)
        builder.Services.AddCors(options =>
        {
            options.AddPolicy("AllowAll", policy =>
            {
                policy.AllowAnyOrigin()
                      .AllowAnyMethod()
                      .AllowAnyHeader();
            });
        });

        // Authentication
        var apiKey = Environment.GetEnvironmentVariable("API_KEY") ?? "ollama-web-secret-key-change-in-production";
        var enableAuth = Environment.GetEnvironmentVariable("ENABLE_AUTH")?.ToLower() == "true";

        if (enableAuth)
        {
            builder.Services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
                options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
            })
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = false,
                    ValidateAudience = false,
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(apiKey))
                };
            });
        }

        // Job Queue Manager
        builder.Services.AddSingleton<IJobQueueManager, JobQueueManager>();

        var app = builder.Build();

        // Configure the HTTP request pipeline.
        if (app.Environment.IsDevelopment())
        {
            app.UseSwagger();
            app.UseSwaggerUI();
        }

        app.UseCors("AllowAll");

        if (enableAuth)
        {
            app.UseAuthentication();
            app.UseAuthorization();
        }
        else
        {
            app.UseAuthorization();
        }

        // Initialize database
        using (var scope = app.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            dbContext.Database.EnsureCreated();
        }

        // Start job queue manager
        var queueManager = app.Services.GetRequiredService<IJobQueueManager>();
        queueManager.StartWorkers();

        app.MapControllers();

        Console.WriteLine("✅ ASP.NET Application started successfully!");
        Console.WriteLine($"Domain: {Environment.GetEnvironmentVariable("DOMAIN") ?? "dicabr.com.br"}");
        Console.WriteLine($"Port: {Environment.GetEnvironmentVariable("ASPNETCORE_HTTP_PORTS") ?? "8080"}");

        app.Run();
    }
}
