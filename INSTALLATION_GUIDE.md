# Pluto Downloader - Installation & Testing Guide

## The Issue You Had

**Error Message**: `ClientException: Software caused connection abort, uri=https://snap-video3.p.rapidapi.com/download`

**Root Cause**: Your device was running **OLD CACHED CODE** that used the old `snap-video3` API endpoint.

**Current Code**: Now uses `all-in-one-video-downloader1.p.rapidapi.com` ✅

---

## Manual Installation (Recommended)

Since Flutter build has some path issues, install manually:

### Step 1: Copy APK to Your Phone
The fresh APK is located at:
```
/home/programmer/Documents/pluto_downloader/android/app/build/outputs/flutter-apk/app-debug.apk
```

**Ways to transfer:**
1. USB cable → Copy to phone's Download folder
2. Bluetooth → Send to phone
3. Cloud storage (Google Drive, etc.)

### Step 2: Install on Phone
1. Open the APK file on your phone
2. Allow "Install from Unknown Sources" if prompted
3. Install and open the app

---

## What Changed in the Code

### 1. **Fixed API Endpoint** ✅
```dart
// OLD (causing error):
'https://snap-video3.p.rapidapi.com/download'

// NEW (correct):
'https://all-in-one-video-downloader1.p.rapidapi.com/download?url=$encodedUrl'
```

### 2. **Enhanced JSON Parsing** ✅
Now supports multiple JSON response formats:
- `{"videos": [...]}`  ← Primary format
- `{"medias": [...]}`  ← Alternative
- `{"data": {"videos": [...]}}`  ← Nested
- `{"url": "..."}` ← Direct URL

### 3. **Better Error Handling** ✅
- Shows actual API response in logs
- Handles missing/invalid video URLs
- Provides clear error messages

### 4. **Debug Logging** ✅
Now prints API response for troubleshooting:
```dart
print('API Response: $decoded');
```

---

## Testing the App

### Test with a Video URL:
1. Open the app
2. Paste a video URL (e.g., from Instagram, TikTok, YouTube, etc.)
3. Click "Download Now"
4. Check the logs for the API response
5. The video should download to your device

### If It Still Doesn't Work:

#### Check the Console/Logcat:
Look for this debug line:
```
API Response: {your_api_response_here}
```

#### Common Issues:
1. **API Key Invalid** → Update `_rapidApiKey` in code
2. **Wrong URL Format** → Make sure URL is properly encoded
3. **API Rate Limit** → Wait a few minutes and try again
4. **Invalid Video URL** → Try a different platform/video

---

## Next Steps if Issues Persist

1. **Share the API Response** - Look for the `API Response:` log line
2. **Test the API Directly** - Use curl or Postman:
   ```bash
   curl -X GET "https://all-in-one-video-downloader1.p.rapidapi.com/download?url=YOUR_VIDEO_URL" \
     -H "x-rapidapi-host: all-in-one-video-downloader1.p.rapidapi.com" \
     -H "x-rapidapi-key: YOUR_API_KEY"
   ```
3. **Check API Documentation** - Verify the correct JSON structure

---

## Summary

**✅ The issue was**: Old cached code using wrong API
**✅ The fix was**: Clean rebuild with correct API endpoint
**✅ The code now**: Uses `all-in-one-video-downloader1` and handles multiple JSON formats
**✅ Next step**: Install the APK manually and test

---

**APK Location**: 
```
/home/programmer/Documents/pluto_downloader/android/app/build/outputs/flutter-apk/app-debug.apk
```

**Built**: October 16, 2025 at 11:12 AM
**Size**: 124 MB
