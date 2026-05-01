# Resolveify

**Zsh script** to fix DaVinci Resolve video compatibility on Linux

Convert any video format to DNxHR (DaVinci Resolve compatible) and normalize exports for universal playback.

## Problem
DaVinci Resolve on Linux has limited codec support:
- ❌ Can't import H.264/H.265 MP4/MKV files
- ❌ Can't export to normal video formats (only DNxHR/ProRes)

## Solution
Two complementary zsh scripts:
1. **`resolveify_dir`** - Convert ANY video to DNxHR for import into Resolve
2. **`normalize_dir`** - Convert Resolve exports back to standard MP4

## Features
- Single file or batch folder conversion
- Preserves original files (optional)
- Smart duplicate naming (_1, _2, etc.)
- Disk space checking
- Progress indicators
- Case-insensitive file matching
- Automatic conflict resolution

## Requirements
- **zsh** (Z shell) - these scripts will NOT work with bash
- ffmpeg and ffprobe installed
- DaVinci Resolve (obviously)

### Install ffmpeg on Linux:
```bash
# Ubuntu/Debian
sudo apt install ffmpeg

# Fedora/RHEL
sudo dnf install ffmpeg

# Arch Linux
sudo pacman -S ffmpeg
```

## Usage
1. resolveify_dir - Import videos to DaVinci Resolve

Converts any video to DNxHR (DaVinci Resolve compatible format)
bash

#### Convert a single video file
resolveify_dir "my_video.mp4"

####Convert a single file and keep original
resolveify_dir "my_video.mkv" true

#### Convert an entire folder of videos
resolveify_dir "/path/to/videos"

#### Convert folder and auto-delete after confirmation
resolveify_dir "/path/to/videos" false
