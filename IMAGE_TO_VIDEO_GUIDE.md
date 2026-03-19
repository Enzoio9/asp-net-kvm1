# 🎬 Prompt + Image → Video Guide

## How It Works

Your dicabr.com.br website now supports **image-to-video generation** using AI! Users can upload an image along with a text prompt, and the system will generate a video based on both.

---

## 🚀 User Flow

### 1. User Visits Website
```
http://dicabr.com.br
```

### 2. User Fills Form
- **Prompt**: Text description of desired video
- **Image**: Upload reference image (optional)
- **Duration**: Video length in seconds
- **Resolution**: 480p, 720p, or 1080p
- **Style**: Optional style descriptor

### 3. System Processes
```
User Input (Prompt + Image) 
    ↓
ASP.NET Core Backend
    ↓
Saves image to /data/images/
    ↓
Sends to Ollama API (runway/gen2-lite)
    ↓
AI generates video
    ↓
Saves video to /data/videos/
    ↓
Returns video URL to user
```

---

## 📡 API Usage

### Endpoint: `POST /api/v1/jobs`

**Content-Type**: `multipart/form-data`

#### Request Parameters:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `prompt` | string | Yes | Text description of the video |
| `image` | file | No | Image file (jpg, png, webp) |
| `duration` | integer | No | Video duration in seconds (default: 5) |
| `resolution` | string | No | Resolution: 480p, 720p, 1080p (default: 720p) |
| `style` | string | No | Style descriptor (e.g., "cinematic") |

#### Example cURL Request:

```bash
curl -X POST http://localhost:8080/api/v1/jobs \
  -F "prompt=A beautiful sunset over the ocean" \
  -F "image=@/path/to/sunset.jpg" \
  -F "duration=5" \
  -F "resolution=720p" \
  -F "style=cinematic"
```

#### Response:

```json
{
  "id": "job-123-guid",
  "status": "pending",
  "progress": 0,
  "prompt": "A beautiful sunset over the ocean",
  "imageUrl": "/images/job-123-guid.jpg",
  "videoUrl": null,
  "thumbnailUrl": null,
  "createdAt": "2026-03-19T...",
  "updatedAt": "2026-03-19T...",
  "errorMessage": null
}
```

---

## 🔧 Backend Processing

### 1. Image Upload Handling

When user submits form with image:

```csharp
// Controllers.cs - CreateJob method
if (formData.Image != null && formData.Image.Length > 0)
{
    var imageDir = Environment.GetEnvironmentVariable("IMAGE_DIR");
    var safeFileName = $"{jobId}{Path.GetExtension(formData.Image.FileName)}";
    var imagePath = Path.Combine(imageDir, safeFileName);
    
    using (var stream = new FileStream(imagePath, FileMode.Create))
    {
        await formData.Image.CopyToAsync(stream);
    }
    
    imageUrl = $"/images/{safeFileName}";
}
```

### 2. Ollama Integration (Image-to-Video)

Backend sends image + prompt to Ollama:

```csharp
// Services.cs - ProcessJobAsync method
if (!string.IsNullOrEmpty(job.ImagePath) && File.Exists(job.ImagePath))
{
    // Read image and convert to base64
    var imageBytes = await File.ReadAllBytesAsync(job.ImagePath);
    var imageBase64 = Convert.ToBase64String(imageBytes);
    
    // Add image to Ollama request
    requestData.image = $"data:image/jpeg;base64,{imageBase64}";
    requestData.prompt = job.Prompt;
    requestData.model = "runway/gen2-lite";
}
```

### 3. Video Generation Flow

```
1. Receive job with image + prompt
   ↓
2. Save image to disk (/data/images/{job_id}.jpg)
   ↓
3. Update job status to "processing"
   ↓
4. Convert image to base64
   ↓
5. Send to Ollama API:
   {
     "model": "runway/gen2-lite",
     "prompt": "user's text prompt",
     "image": "data:image/jpeg;base64,/9j/4AAQSkZJRg..."
   }
   ↓
6. Ollama processes and returns video data
   ↓
7. Save video to /data/videos/{job_id}.mp4
   ↓
8. Update job status to "completed"
```

---

## 🖼️ Supported Image Formats

The system accepts common image formats:
- ✅ JPEG/JPG
- ✅ PNG
- ✅ WebP
- ✅ BMP (converted by browser)

**Max Size**: Limited by server configuration (default: 10MB)

---

## 📊 Storage Structure

```
/var/www/dicabr.com.br/data/
├── images/
│   ├── {job_id_1}.jpg       # Uploaded image 1
│   ├── {job_id_2}.png       # Uploaded image 2
│   └── {job_id_3}.webp      # Uploaded image 3
│
└── videos/
    ├── {job_id_1}.mp4       # Generated video 1
    ├── {job_id_2}.mp4       # Generated video 2
    └── {job_id_3}.mp4       # Generated video 3
```

---

## 🎯 Use Cases

### Example 1: Animate a Landscape
- **User uploads**: Photo of mountains
- **User prompt**: "Gentle clouds moving across the sky, cinematic lighting"
- **Result**: Video with animated clouds over the mountain landscape

### Example 2: Product Showcase
- **User uploads**: Product photo
- **User prompt**: "Slow rotation, studio lighting, professional commercial"
- **Result**: Rotating product video

### Example 3: Portrait Animation
- **User uploads**: Portrait photo
- **User prompt**: "Subtle head movement, natural expression, lifelike"
- **Result**: Animated portrait

### Example 4: Text-to-Video Only (No Image)
- **User uploads**: Nothing
- **User prompt**: "A rocket launching into space at sunset"
- **Result**: AI-generated rocket launch video

---

## 🔍 Monitoring & Debugging

### Check if Image was Received

```bash
# View application logs
sudo journalctl -u dicabr-web -f | grep "Processing"
```

Expected output:
```
📷 Processing image-to-video for job abc-123
🚀 Sending request to Ollama: http://localhost:11434/api/generate
📊 Request size: 245678 bytes
✅ Ollama response received for job abc-123
🎬 Video saved to: /var/www/dicabr.com.br/data/videos/abc-123.mp4
```

### Verify Image Storage

```bash
# List uploaded images
ls -lh /var/www/dicabr.com.br/data/images/

# Check specific image
file /var/www/dicabr.com.br/data/images/{job_id}.jpg
```

### Check Ollama is Receiving Images

```bash
# Monitor Ollama logs
sudo journalctl -u ollama -f
```

---

## 📝 Frontend Integration

### HTML Form

```html
<form enctype="multipart/form-data">
    <textarea name="prompt" required></textarea>
    
    <input type="file" name="image" accept="image/*" />
    
    <input type="number" name="duration" value="5" />
    <select name="resolution">
        <option value="720p">720p</option>
    </select>
    
    <button type="submit">Generate Video</button>
</form>
```

### JavaScript Submission

```javascript
const formData = new FormData(form);
formData.append('prompt', 'My video description');
formData.append('image', fileInputElement.files[0]);

fetch('/api/v1/jobs', {
    method: 'POST',
    body: formData
    // Don't set Content-Type - browser adds boundary automatically
});
```

---

## ⚙️ Configuration

### Increase Upload Size Limit (if needed)

In `nginx.conf`:
```nginx
http {
    client_max_body_size 50M;  # Allow 50MB uploads
}
```

In ASP.NET (`Program.cs`):
```csharp
builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxRequestBodySize = 50 * 1024 * 1024; // 50MB
});
```

### Environment Variables

```bash
IMAGE_DIR=/var/www/dicabr.com.br/data/images
VIDEO_DIR=/var/www/dicabr.com.br/data/videos
MAX_CONCURRENT_JOBS=3
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=runway/gen2-lite
```

---

## 🎨 UI/UX Best Practices

### Show Image Preview

Add this to your frontend to preview uploaded image:

```javascript
document.getElementById('image').addEventListener('change', function(e) {
    const file = e.target.files[0];
    if (file) {
        const reader = new FileReader();
        reader.onload = function(e) {
            // Show preview
            const preview = document.createElement('img');
            preview.src = e.target.result;
            preview.style.maxWidth = '300px';
            preview.style.marginTop = '10px';
            this.parentNode.appendChild(preview);
        };
        reader.readAsDataURL(file);
    }
});
```

### Show Progress Indicator

```javascript
// During upload
btnText.textContent = '📤 Uploading image and generating video...';
```

---

## 📊 Performance Considerations

### Image Processing Time

Typical workflow timing:
- Image upload: 1-3 seconds (depends on size)
- Base64 encoding: 0.5-1 second
- Ollama processing: 30-120 seconds (depends on model)
- Video saving: 1-2 seconds

**Total**: ~35-130 seconds per job

### Optimize Image Sizes

Recommend users to upload:
- Max width: 1920px
- Max file size: 5MB
- Format: JPEG (smaller than PNG)

---

## 🆘 Troubleshooting

### Image Not Showing in Job Response

Check:
1. Image directory permissions
```bash
ls -la /var/www/dicabr.com.br/data/images/
sudo chown http:http /var/www/dicabr.com.br/data/images/
```

2. Nginx serves images correctly
```bash
curl http://dicabr.com.br/images/{job_id}.jpg
```

### Ollama Rejects Large Images

Solution: Resize images before sending:
```csharp
// Add image resizing logic here if needed
// Or instruct users to upload smaller images
```

### Upload Timeout

Increase timeout in nginx:
```nginx
location /api/ {
    proxy_read_timeout 300s;
    proxy_send_timeout 300s;
}
```

---

## ✅ Testing Checklist

Test the complete flow:

- [ ] Upload image without prompt (should fail validation)
- [ ] Upload prompt without image (should work - text-to-video)
- [ ] Upload both image + prompt (should work - image-to-video)
- [ ] Check image appears in `/data/images/`
- [ ] Check video appears in `/data/videos/`
- [ ] Verify job status updates to "completed"
- [ ] Test with different image formats (JPG, PNG, WebP)
- [ ] Test with large image files (>5MB)
- [ ] Test concurrent jobs (multiple users uploading)

---

## 🎉 Success Indicators

When everything works correctly:

1. ✅ User sees image preview after upload
2. ✅ Backend logs show "📷 Processing image-to-video"
3. ✅ Image file exists in `/data/images/`
4. ✅ Ollama receives base64-encoded image
5. ✅ Video generated and saved to `/data/videos/`
6. ✅ Job response includes both `imageUrl` and `videoUrl`
7. ✅ User can download/watch final video

---

**Your AI video generation website is ready!** 🚀

Users can now upload images + prompts to create amazing videos with runway/gen2-lite!
