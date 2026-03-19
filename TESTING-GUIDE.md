# 🧪 Testing Your Image-to-Video System

## Quick Test Procedure

### Step 1: Start Services

```bash
# Check services are running
sudo systemctl status ollama
sudo systemctl status dicabr-web

# Start if needed
sudo systemctl start ollama
sudo systemctl start dicabr-web
```

### Step 2: Test with cURL (Command Line)

#### Test 1: Text-only to Video (No Image)

```bash
curl -X POST http://localhost:8080/api/v1/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A beautiful sunset over the ocean with waves",
    "duration": 5,
    "resolution": "720p",
    "style": "cinematic"
  }' | python -m json.tool
```

Expected response:
```json
{
  "id": "guid-here",
  "status": "pending",
  "progress": 0,
  "prompt": "A beautiful sunset...",
  "imageUrl": null,
  "videoUrl": null
}
```

#### Test 2: Image + Prompt to Video

First, prepare an image file (e.g., `test-image.jpg`), then:

```bash
curl -X POST http://localhost:8080/api/v1/jobs \
  -F "prompt=Animate this landscape with moving clouds" \
  -F "image=@/path/to/test-image.jpg" \
  -F "duration=5" \
  -F "resolution=720p" \
  -F "style=realistic" | python -m json.tool
```

Expected response:
```json
{
  "id": "guid-here",
  "status": "pending",
  "progress": 0,
  "prompt": "Animate this landscape...",
  "imageUrl": "/images/guid-here.jpg",
  "videoUrl": null
}
```

### Step 3: Monitor Processing

```bash
# Watch logs in real-time
sudo journalctl -u dicabr-web -f

# Look for:
# 📷 Processing image-to-video for job {id}
# 🚀 Sending request to Ollama
# ✅ Job completed
```

### Step 4: Check Job Status

```bash
# Get job details
curl http://localhost:8080/api/v1/jobs/{JOB_ID} | python -m json.tool
```

When completed:
```json
{
  "id": "guid-here",
  "status": "completed",
  "progress": 100,
  "prompt": "...",
  "imageUrl": "/images/guid-here.jpg",
  "videoUrl": "/videos/guid-here.mp4"
}
```

### Step 5: Verify Files Exist

```bash
# Check uploaded image
ls -lh /var/www/dicabr.com.br/data/images/

# Check generated video
ls -lh /var/www/dicabr.com.br/data/videos/

# View video info
file /var/www/dicabr.com.br/data/videos/{job_id}.mp4
```

### Step 6: Access via Browser

```bash
# Access image
http://localhost:8080/images/{job_id}.jpg

# Access video
http://localhost:8080/videos/{job_id}.mp4

# Or via domain
http://dicabr.com.br/images/{job_id}.jpg
http://dicabr.com.br/videos/{job_id}.mp4
```

---

## Frontend Testing

### Open Website

```
http://dicabr.com.br
```

### Manual Test Steps:

1. **Navigate to Create Section**
   - Click on "Create" or scroll to form

2. **Test without Image**
   - Fill prompt: "A rocket launching into space"
   - Leave image field empty
   - Click "Generate Video"
   - Should see job appear in active jobs

3. **Test with Image**
   - Upload a landscape photo
   - Fill prompt: "Animate this scene with gentle movement"
   - Click "Generate Video"
   - Should show image preview (if implemented)
   - Should see job created with imageUrl

4. **Monitor Progress**
   - Watch progress bar update (0% → 100%)
   - Wait for status change: pending → processing → completed

5. **View Result**
   - Video player should appear
   - Download link should work
   - Image should be visible (if uploaded)

---

## Common Issues & Solutions

### Issue 1: Upload Fails (File Too Large)

**Error**: Request entity too large (413)

**Solution**: Increase nginx limit
```nginx
# In /etc/nginx/nginx.conf
client_max_body_size 50M;
```

Then restart:
```bash
sudo systemctl restart nginx
```

### Issue 2: Image Not Saved

**Check permissions**:
```bash
sudo chown -R http:http /var/www/dicabr.com.br/data/images
sudo chmod 755 /var/www/dicabr.com.br/data/images
```

### Issue 3: Ollama Rejects Request

**Check model is loaded**:
```bash
ollama list
# Should show: runway/gen2-lite
```

**Re-pull if needed**:
```bash
ollama pull runway/gen2-lite
```

### Issue 4: Video Not Generated

**Check Ollama is responding**:
```bash
curl http://localhost:11434/api/tags
```

Should return models list.

### Issue 5: WebSocket Not Connecting

**Check firewall**:
```bash
sudo ufw status
# Should allow port 8080
```

---

## Performance Testing

### Test Concurrent Jobs

Open multiple browser tabs and submit jobs simultaneously:

```bash
# Terminal 1: Monitor first job
curl -X POST http://localhost:8080/api/v1/jobs \
  -F "prompt=Test 1" -F "image=@img1.jpg" &

# Terminal 2: Monitor second job
curl -X POST http://localhost:8080/api/v1/jobs \
  -F "prompt=Test 2" -F "image=@img2.jpg" &

# Terminal 3: Monitor third job
curl -X POST http://localhost:8080/api/v1/jobs \
  -F "prompt=Test 3" -F "image=@img3.jpg" &
```

Should process all 3 concurrently (MAX_CONCURRENT_JOBS=3).

---

## API Documentation Testing

### Swagger UI

Visit: `http://dicabr.com.br/swagger`

Test endpoints interactively:
1. Expand POST /api/v1/jobs
2. Click "Try it out"
3. Fill form with prompt + upload image
4. Execute
5. See response

---

## Verification Checklist

After testing, verify:

- [ ] Images are saved to correct directory
- [ ] Videos are generated by Ollama
- [ ] Database records job status correctly
- [ ] Frontend shows progress updates
- [ ] Completed videos are accessible via URL
- [ ] Uploaded images are accessible via URL
- [ ] Multiple concurrent jobs work
- [ ] Error handling works (bad requests, etc.)

---

## Success Criteria

✅ **System is working correctly when:**

1. User can upload image + prompt via web form
2. Backend saves image to disk
3. Backend sends image+prompt to Ollama
4. Ollama generates video
5. Video is saved and accessible
6. User sees completed video on website
7. Both imageUrl and videoUrl are present in API response

---

## Example Test Script

Save as `test-image-upload.sh`:

```bash
#!/bin/bash

echo "🧪 Testing Image-to-Video System..."

# Create test image (1x1 pixel red PNG)
echo "Creating test image..."
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==" | base64 -d > test.png

echo "Submitting job with image..."
RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/jobs \
  -F "prompt=Test animation" \
  -F "image=@test.png" \
  -F "duration=3")

JOB_ID=$(echo $RESPONSE | python -c "import sys, json; print(json.load(sys.stdin)['id'])")

echo "Job ID: $JOB_ID"
echo ""
echo "Checking job status every 5 seconds..."

for i in {1..20}; do
    STATUS=$(curl -s http://localhost:8080/api/v1/jobs/$JOB_ID | python -c "import sys, json; print(json.load(sys.stdin)['status'])")
    PROGRESS=$(curl -s http://localhost:8080/api/v1/jobs/$JOB_ID | python -c "import sys, json; print(json.load(sys.stdin)['progress'])")
    
    echo "Status: $STATUS | Progress: $PROGRESS%"
    
    if [ "$STATUS" == "completed" ]; then
        echo "✅ Job completed!"
        VIDEO_URL=$(curl -s http://localhost:8080/api/v1/jobs/$JOB_ID | python -c "import sys, json; print(json.load(sys.stdin)['videoUrl'])")
        echo "Video URL: $VIDEO_URL"
        break
    fi
    
    sleep 5
done

# Cleanup
rm test.png

echo "Test complete!"
```

Run with:
```bash
chmod +x test-image-upload.sh
./test-image-upload.sh
```

---

**Your image-to-video AI system is ready for testing!** 🎉
