@echo off
REM Media Storage Setup Script for Windows
REM Creates directory structure for media files

echo =========================================
echo Like2Share Media Storage Setup
echo =========================================
echo.

REM Navigate to storage directory
cd /d "%~dp0\..\storage"

echo Creating media storage directories...

REM Create main directories
if not exist "media" mkdir media
cd media

REM Images
if not exist "images" mkdir images
cd images
if not exist "posts" mkdir posts
if not exist "original" mkdir original
if not exist "processed" mkdir processed
cd ..

REM Videos
if not exist "videos" mkdir videos
cd videos
if not exist "posts" mkdir posts
if not exist "original" mkdir original
if not exist "processed" mkdir processed
if not exist "streams" mkdir streams
cd ..

REM Thumbnails
if not exist "thumbnails" mkdir thumbnails
cd thumbnails
if not exist "images" mkdir images
if not exist "videos" mkdir videos
cd ..

REM Profiles
if not exist "profiles" mkdir profiles
cd profiles
if not exist "avatars" mkdir avatars
if not exist "covers" mkdir covers
cd ..

REM Temp
if not exist "temp" mkdir temp
cd temp
if not exist "uploads" mkdir uploads
if not exist "processing" mkdir processing
cd ..

cd ..

REM Create backup directory
cd ..
if not exist "backups" mkdir backups
cd backups
if not exist "media" mkdir media
cd ..

echo Directory structure created!
echo.

REM Create storage environment example
cd ..
(
echo # Storage Configuration
echo MEDIA_STORAGE_PATH=/app/media
echo MEDIA_BASE_URL=http://localhost/media
echo.
echo # File Size Limits ^(in bytes^)
echo MAX_FILE_SIZE=104857600        # 100MB
echo MAX_IMAGE_SIZE=10485760        # 10MB
echo MAX_VIDEO_SIZE=104857600       # 100MB
echo MAX_PROFILE_PIC_SIZE=2097152   # 2MB
echo.
echo # Allowed file types
echo ALLOWED_IMAGE_TYPES=jpg,jpeg,png,gif,webp
echo ALLOWED_VIDEO_TYPES=mp4,webm,mov
echo.
echo # Thumbnail settings
echo THUMBNAIL_SMALL_SIZE=150
echo THUMBNAIL_MEDIUM_SIZE=300
echo THUMBNAIL_LARGE_SIZE=600
echo THUMBNAIL_QUALITY=85
echo.
echo # Video processing
echo ENABLE_VIDEO_PROCESSING=true
echo VIDEO_MAX_DURATION=300         # 5 minutes in seconds
echo VIDEO_TRANSCODE_FORMAT=mp4
echo.
echo # Cleanup
echo TEMP_FILE_RETENTION_HOURS=24
echo AUTO_CLEANUP_ENABLED=true
echo.
echo # Storage quotas per user
echo USER_STORAGE_QUOTA=5368709120  # 5GB in bytes
echo USER_MAX_FILES=1000
) > storage.env.example

echo Created storage.env.example
echo.

REM Display directory structure
echo Directory structure:
tree /F storage\media

echo.
echo =========================================
echo Media storage setup completed!
echo =========================================
echo.
echo Storage structure created at: %CD%\storage\media
echo.
echo Next steps:
echo 1. Review storage.env.example and add to your .env file
echo 2. Configure your backend to use these paths
echo 3. Set up backup strategy
echo 4. Consider CDN for production
echo.

pause
