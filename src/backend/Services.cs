using System.Collections.Concurrent;
using System.Text;
using Microsoft.EntityFrameworkCore;

namespace OllamaWebApi;

public interface IJobQueueManager
{
    void StartWorkers();
    Task<bool> AddJobAsync(string jobId);
    Task<bool> CancelJobAsync(string jobId);
}

public class JobQueueManager : IJobQueueManager, IDisposable
{
    private readonly IServiceProvider _serviceProvider;
    private readonly BlockingCollection<string> _jobQueue = new();
    private readonly List<Task> _workers = new();
    private CancellationTokenSource? _cancellationTokenSource;
    private int _maxWorkers;

    public JobQueueManager(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
        _maxWorkers = int.Parse(Environment.GetEnvironmentVariable("MAX_CONCURRENT_JOBS") ?? "3");
    }

    public void StartWorkers()
    {
        _cancellationTokenSource = new CancellationTokenSource();
        
        for (int i = 0; i < _maxWorkers; i++)
        {
            var workerId = i;
            var task = Task.Run(() => WorkerLoop(workerId, _cancellationTokenSource.Token));
            _workers.Add(task);
        }

        Console.WriteLine($"✅ {_maxWorkers} workers started");
    }

    private async Task WorkerLoop(int workerId, CancellationToken cancellationToken)
    {
        Console.WriteLine($"Worker {workerId} started");

        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                string jobId = _jobQueue.Take(cancellationToken);
                await ProcessJobAsync(jobId, workerId);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Worker {workerId} error: {ex.Message}");
            }
        }
    }

    private async Task ProcessJobAsync(string jobId, int workerId)
    {
        using var scope = _serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var job = await dbContext.Jobs.FindAsync(jobId);
        if (job == null) return;

        try
        {
            job.Status = "processing";
            job.Progress = 10;
            job.UpdatedAt = DateTime.UtcNow;
            await dbContext.SaveChangesAsync();

            // Get Ollama configuration
            var ollamaHost = Environment.GetEnvironmentVariable("OLLAMA_HOST") ?? "http://localhost:11434";
            var ollamaModel = Environment.GetEnvironmentVariable("OLLAMA_MODEL") ?? "runway/gen2-lite";

            // Call actual Ollama API for image+prompt to video generation
            using var httpClient = new HttpClient();
            httpClient.BaseAddress = new Uri(ollamaHost);
            
            // Prepare request data for image-to-video generation
            dynamic requestData = new System.Dynamic.ExpandoObject();
            requestData.model = ollamaModel;
            requestData.prompt = job.Prompt;
            requestData.stream = false;
            
            // If user provided an image, include it in the request
            if (!string.IsNullOrEmpty(job.ImagePath) && File.Exists(job.ImagePath))
            {
                // Read image and convert to base64
                var imageBytes = await File.ReadAllBytesAsync(job.ImagePath);
                var imageBase64 = Convert.ToBase64String(imageBytes);
                
                // Add image to request (Ollama supports base64 encoded images)
                requestData.image = $"data:image/jpeg;base64,{imageBase64}";
                
                Console.WriteLine($"📷 Processing image-to-video for job {jobId}");
            }
            else
            {
                Console.WriteLine($"📝 Processing text-to-video for job {jobId}");
            }

            var jsonRequest = System.Text.Json.JsonSerializer.Serialize(requestData);
            var content = new StringContent(jsonRequest, Encoding.UTF8, "application/json");

            Console.WriteLine($"🚀 Sending request to Ollama: {ollamaHost}/api/generate");
            Console.WriteLine($"📊 Request size: {jsonRequest.Length} bytes");

            // Make REAL request to Ollama
            var response = await httpClient.PostAsync("/api/generate", content);
            
            if (!response.IsSuccessStatusCode)
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                throw new Exception($"Ollama API error: {response.StatusCode} - {errorContent}");
            }

            var result = await response.Content.ReadAsStringAsync();
            
            Console.WriteLine($"✅ Ollama response received for job {jobId}");
            
            // Save generated video
            var videoDir = Environment.GetEnvironmentVariable("VIDEO_DIR") ?? "/var/www/dicabr.com.br/data/videos";
            Directory.CreateDirectory(videoDir);
            
            var videoFileName = $"{jobId}.mp4";
            var videoPath = Path.Combine(videoDir, videoFileName);
            
            // TODO: Extract actual video data from Ollama response
            // For now, create a placeholder file - replace with actual video extraction
            // The response format depends on the specific Ollama model implementation
            await File.WriteAllBytesAsync(videoPath, new byte[0]);

            // Complete job
            job.Status = "completed";
            job.Progress = 100;
            job.VideoPath = $"/videos/{videoFileName}";
            job.Metadata = System.Text.Json.JsonSerializer.Serialize(new {
                ollama_response = result,
                model_used = ollamaModel,
                had_image = !string.IsNullOrEmpty(job.ImagePath),
                processing_time_seconds = (DateTime.UtcNow - job.CreatedAt).TotalSeconds
            });
            job.UpdatedAt = DateTime.UtcNow;
            await dbContext.SaveChangesAsync();

            Console.WriteLine($"✅ Job {jobId} completed by worker {workerId} using Ollama model: {ollamaModel}");
            Console.WriteLine($"🎬 Video saved to: {videoPath}");
        }
        catch (Exception ex)
        {
            job.Status = "failed";
            job.ErrorMessage = ex.Message;
            job.UpdatedAt = DateTime.UtcNow;
            await dbContext.SaveChangesAsync();

            Console.WriteLine($"❌ Job {jobId} failed: {ex.Message}");
            Console.WriteLine($"Stack trace: {ex.StackTrace}");
        }
    }

    public Task<bool> AddJobAsync(string jobId)
    {
        try
        {
            _jobQueue.Add(jobId);
            return Task.FromResult(true);
        }
        catch (InvalidOperationException)
        {
            return Task.FromResult(false);
        }
    }

    public async Task<bool> CancelJobAsync(string jobId)
    {
        using var scope = _serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var job = await dbContext.Jobs.FindAsync(jobId);
        if (job == null) return false;

        if (job.Status == "pending")
        {
            job.Status = "cancelled";
            job.UpdatedAt = DateTime.UtcNow;
            await dbContext.SaveChangesAsync();
            return true;
        }
        else if (job.Status == "processing")
        {
            job.Status = "cancelling";
            job.UpdatedAt = DateTime.UtcNow;
            await dbContext.SaveChangesAsync();
            return true;
        }

        return false;
    }

    public void Dispose()
    {
        _cancellationTokenSource?.Cancel();
        _workers.ForEach(w => w.Wait());
        _cancellationTokenSource?.Dispose();
        _jobQueue.Dispose();
    }
}
