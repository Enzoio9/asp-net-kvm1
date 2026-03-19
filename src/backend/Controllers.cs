using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;

namespace OllamaWebApi;

[ApiController]
[Route("api/v1/[controller]")]
public class JobsController : ControllerBase
{
    private readonly AppDbContext _dbContext;
    private readonly IJobQueueManager _queueManager;
    private readonly ILogger<JobsController> _logger;
    private readonly IWebHostEnvironment _environment;

    public JobsController(
        AppDbContext dbContext,
        IJobQueueManager queueManager,
        ILogger<JobsController> logger,
        IWebHostEnvironment environment)
    {
        _dbContext = dbContext;
        _queueManager = queueManager;
        _logger = logger;
        _environment = environment;
    }

    [HttpPost]
    [ProducesResponseType(typeof(JobResponse), 200)]
    [ProducesResponseType(503)]
    public async Task<ActionResult<JobResponse>> CreateJob([FromForm] JobCreateFormData formData)
    {
        var jobId = Guid.NewGuid().ToString();
        var now = DateTime.UtcNow;

        // Handle image upload if provided
        string? imagePath = null;
        string? imageUrl = null;
        
        if (formData.Image != null && formData.Image.Length > 0)
        {
            var videoDir = Environment.GetEnvironmentVariable("VIDEO_DIR") ?? 
                          Path.Combine(_environment.ContentRootPath, "data", "videos");
            var imageDir = Environment.GetEnvironmentVariable("IMAGE_DIR") ?? 
                          Path.Combine(_environment.ContentRootPath, "data", "images");
            
            // Ensure directories exist
            Directory.CreateDirectory(imageDir);
            Directory.CreateDirectory(videoDir);
            
            // Save uploaded image
            var fileExtension = Path.GetExtension(formData.Image.FileName);
            var safeFileName = $"{jobId}{fileExtension}";
            imagePath = Path.Combine(imageDir, safeFileName);
            
            using (var stream = new FileStream(imagePath, FileMode.Create))
            {
                await formData.Image.CopyToAsync(stream);
            }
            
            imageUrl = $"/images/{safeFileName}";
        }

        var job = new VideoJob
        {
            Id = jobId,
            Prompt = formData.Prompt,
            ImagePath = imagePath,
            ImageUrl = imageUrl,
            Status = "pending",
            Progress = 0,
            CreatedAt = now,
            UpdatedAt = now,
            Metadata = System.Text.Json.JsonSerializer.Serialize(new
            {
                Duration = formData.Duration,
                Resolution = formData.Resolution,
                Style = formData.Style,
                HasImage = formData.Image != null
            })
        };

        _dbContext.Jobs.Add(job);
        await _dbContext.SaveChangesAsync();

        if (!await _queueManager.AddJobAsync(jobId))
        {
            return StatusCode(503, "Queue is full");
        }

        return new JobResponse
        {
            Id = job.Id,
            Status = job.Status,
            Progress = job.Progress,
            Prompt = job.Prompt,
            ImageUrl = job.ImageUrl,
            VideoUrl = null,
            ThumbnailUrl = null,
            CreatedAt = job.CreatedAt,
            UpdatedAt = job.UpdatedAt,
            ErrorMessage = job.ErrorMessage
        };
    }

    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<JobResponse>), 200)]
    public async Task<ActionResult<IEnumerable<JobResponse>>> ListJobs(
        [FromQuery] string? status,
        [FromQuery] int limit = 50,
        [FromQuery] int offset = 0)
    {
        IQueryable<VideoJob> query = _dbContext.Jobs;

        if (!string.IsNullOrEmpty(status))
        {
            query = query.Where(j => j.Status == status);
        }

        var jobs = await query
            .OrderByDescending(j => j.CreatedAt)
            .Skip(offset)
            .Take(limit)
            .ToListAsync();

        return jobs.Select(j => new JobResponse
        {
            Id = j.Id,
            Status = j.Status,
            Progress = j.Progress,
            Prompt = j.Prompt,
            ImageUrl = j.ImageUrl,
            VideoUrl = j.VideoPath != null ? $"/videos/{j.VideoPath}" : null,
            ThumbnailUrl = null,
            CreatedAt = j.CreatedAt,
            UpdatedAt = j.UpdatedAt,
            ErrorMessage = j.ErrorMessage
        }).ToList();
    }

    [HttpGet("{jobId}")]
    [ProducesResponseType(typeof(JobResponse), 200)]
    [ProducesResponseType(404)]
    public async Task<ActionResult<JobResponse>> GetJob(string jobId)
    {
        var job = await _dbContext.Jobs.FindAsync(jobId);
        if (job == null)
        {
            return NotFound("Job not found");
        }

        return new JobResponse
        {
            Id = job.Id,
            Status = job.Status,
            Progress = job.Progress,
            Prompt = job.Prompt,
            ImageUrl = job.ImageUrl,
            VideoUrl = job.VideoPath != null ? $"/videos/{job.VideoPath}" : null,
            ThumbnailUrl = null,
            CreatedAt = job.CreatedAt,
            UpdatedAt = job.UpdatedAt,
            ErrorMessage = job.ErrorMessage
        };
    }

    [HttpDelete("{jobId}")]
    [ProducesResponseType(200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> DeleteJob(string jobId)
    {
        var job = await _dbContext.Jobs.FindAsync(jobId);
        if (job == null)
        {
            return NotFound("Job not found");
        }

        _dbContext.Jobs.Remove(job);
        await _dbContext.SaveChangesAsync();

        return Ok(new { message = "Job deleted successfully" });
    }

    [HttpPost("{jobId}/cancel")]
    [ProducesResponseType(200)]
    [ProducesResponseType(400)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> CancelJob(string jobId)
    {
        var job = await _dbContext.Jobs.FindAsync(jobId);
        if (job == null)
        {
            return NotFound("Job not found");
        }

        if (await _queueManager.CancelJobAsync(jobId))
        {
            return Ok(new { message = "Job cancellation requested" });
        }
        else
        {
            return BadRequest("Cannot cancel job in current state");
        }
    }
}

[Route("")]
[ApiController]
public class RootController : ControllerBase
{
    private readonly ILogger<RootController> _logger;

    public RootController(ILogger<RootController> logger)
    {
        _logger = logger;
    }

    [HttpGet]
    public IActionResult Root()
    {
        return Ok(new
        {
            message = "Ollama Web API - dicabr.com.br",
            version = "1.0.0",
            domain = Environment.GetEnvironmentVariable("DOMAIN") ?? "dicabr.com.br",
            docs = "/docs",
            health = "/health"
        });
    }

    [HttpGet("health")]
    public IActionResult Health([FromServices] IJobQueueManager queueManager)
    {
        return Ok(new
        {
            status = "healthy",
            domain = Environment.GetEnvironmentVariable("DOMAIN") ?? "dicabr.com.br",
            timestamp = DateTime.UtcNow.ToString("o"),
            active_workers = 3 // This would need to be tracked in the manager
        });
    }
}

// DTOs
public class JobCreateFormData
{
    [Required]
    [MinLength(1)]
    [MaxLength(2000)]
    public string Prompt { get; set; } = string.Empty;
    
    public IFormFile? Image { get; set; }  // Uploaded image file
    
    [Range(1, 60)]
    public int Duration { get; set; } = 5;
    
    [RegularExpression("^(480p|720p|1080p)$")]
    public string Resolution { get; set; } = "720p";
    
    public string? Style { get; set; }
}

public class JobCreateRequest
{
    [Required]
    [MinLength(1)]
    [MaxLength(2000)]
    public string Prompt { get; set; } = string.Empty;
    
    public string? ImageUrl { get; set; }
    
    [Range(1, 60)]
    public int Duration { get; set; } = 5;
    
    [RegularExpression("^(480p|720p|1080p)$")]
    public string Resolution { get; set; } = "720p";
    
    public string? Style { get; set; }
}

public class JobResponse
{
    public string Id { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public int Progress { get; set; }
    public string Prompt { get; set; } = string.Empty;
    public string? ImageUrl { get; set; }      // User's uploaded image
    public string? VideoUrl { get; set; }      // Generated video
    public string? ThumbnailUrl { get; set; }  // Video thumbnail
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public string? ErrorMessage { get; set; }
}
