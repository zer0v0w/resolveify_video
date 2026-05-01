# 🎬 Resolveify

Zsh script to fix DaVinci Resolve video compatibility on Linux

Convert any video format to DNxHR (DaVinci Resolve compatible) and normalize exports for universal playback.

---

## 🚨 Problem

DaVinci Resolve on Linux has limited codec support:

* ❌ Can't import H.264 / H.265 MP4 / MKV files
* ❌ Can't export to normal video formats (only DNxHR / ProRes)

---

## 💡 Solution

Two complementary Zsh scripts:

* `resolveify_dir` → Convert ANY video to DNxHR for import into Resolve
* `normalize_dir` → Convert Resolve exports back to standard MP4

---

## ✨ Features

* 📁 Single file or batch folder conversion
* 💾 Preserves original files (optional)
* 🔁 Smart duplicate naming (`_1`, `_2`, etc.)
* 📊 Disk space checking
* 📈 Progress indicators
* 🔤 Case-insensitive file matching
* ⚙️ Automatic conflict resolution

---

## 📦 Requirements

* `zsh` (Z Shell) — **these scripts will NOT work with bash**
* `ffmpeg` and `ffprobe`
* DaVinci Resolve (obviously)

---

## 🧰 Install ffmpeg on Linux

### Ubuntu / Debian

```bash
sudo apt install ffmpeg
```

### Fedora / RHEL

```bash
sudo dnf install ffmpeg
```

### Arch Linux

```bash
sudo pacman -S ffmpeg
```

---

## ⚙️ Installation

### Method 1: Source the script

Download the script:

```bash
curl -O https://raw.githubusercontent.com/yourusername/resolveify/main/resolveify.zsh
```

Source it in your `.zshrc`:

```bash
echo "source $(pwd)/resolveify.zsh" >> ~/.zshrc
```

Reload zsh config:

```bash
source ~/.zshrc
```

---

### Method 2: Add to your zsh functions

Copy the functions directly to your `~/.zshrc`:

```bash
cat resolveify.zsh >> ~/.zshrc
source ~/.zshrc
```

---

## 🚀 Usage

# 1. resolveify_dir - Import videos to DaVinci Resolve

Converts any video to DNxHR (DaVinci Resolve compatible format)

### Examples:

Convert a single video file:

```bash
resolveify_dir "my_video.mp4"
```

Convert a single file and keep original:

```bash
resolveify_dir "my_video.mkv" true
```

Convert an entire folder of videos:

```bash
resolveify_dir "/path/to/videos"
```

Convert folder and auto-delete after confirmation:

```bash
resolveify_dir "/path/to/videos" false
```

### What it does:

* Input: Any video (mp4, mkv, mov, webm, avi)
* Output: DNxHR SQ with PCM audio (.mov container)
* Location: Creates `{filename}_resolve/` folder or `{folder}_resolve/`

### Example output:

```
🎯 Single file mode: travel_video.mp4
🎬 [1/1] Converting: travel_video.mp4
📦 Original size: 245MB
📝 Output: travel_video.mov
✅ Converted: 892MB (was 245MB)
```

---

# 2. normalize_dir - Export from DaVinci Resolve

Converts Resolve exports back to standard MP4 for sharing

### Examples:

Normalize a single video file:

```bash
normalize_dir "resolve_export.mov"
```

Normalize a folder of Resolve exports:

```bash
normalize_dir "/path/to/resolve_exports"
```

Keep originals (don't delete after conversion):

```bash
normalize_dir "/path/to/exports" true
```

### What it does:

* Detects ProRes 422 HQ files (optimized conversion)
* Converts normal MOV files to MP4 (H.264/AAC)
* Remuxes existing MP4s with faststart flag
* Handles MKV, AVI, WebM conversions

### Special handling:

* ProRes 422 HQ → H.264 (CRF 22, high quality)
* Normal MOV → H.264 (CRF 23, balanced)
* MP4 → adds faststart flag for web streaming
* MKV / AVI / WebM → transcodes to MP4

### Example output:

```
🔍 Checking: davinci_export.mov
🎬 Converting ProRes 422 HQ to MP4: davinci_export.mov
📝 Output: davinci_export.mp4
✅ Converted to: davinci_export.mp4
📦 Size: 1523MB → 89MB
```

---

## 🔁 Workflow Example

1. Convert footage for Resolve:

```bash
resolveify_dir "raw_footage/"
```

2. Import into DaVinci Resolve:

```
raw_footage_resolve/
```

3. Edit and color grade

4. Export from Resolve (DNxHR / ProRes)

5. Normalize export:

```bash
normalize_dir "~/ResolveExports/my_edit.mov"
```

6. Share MP4 🎉

---

## ⚡ Advanced Features

### Smart Duplicate Handling

```
video.mov → video_1.mov → video_2.mov
```

---

### Disk Space Protection

* Checks minimum free space (1GB)
* Monitors during conversion
* Stops if disk is too full

---

### Smart Cleanup

* Asks before deleting originals
* Warns if DNxHR is larger than source
* Shows space saved/gained

---

## 📁 File Structure Examples

### Single file

```
Videos/
├── travel.mp4
└── travel_resolve/
    └── travel.mov
```

### Batch folder

```
Videos/
├── clip1.mp4
├── clip2.mkv
├── clip3.avi
└── videos_resolve/
    ├── clip1.mov
    ├── clip2.mov
    └── clip3.mov
```

---

## 🛠 Troubleshooting

### command not found

```bash
echo $SHELL
source ~/.zshrc
```

---

### ffmpeg not found

```bash
sudo apt install ffmpeg
```

---

### No video files found

* Check file extensions (case-sensitive)
* Verify folder path
* Supported: mp4, mkv, mov, webm, avi

---

### Converted file is huge

Normal behavior:

* DNxHR is an editing codec (not for sharing)
* 100MB → 500MB+ is expected
* Use `normalize_dir` for sharing

---

## 📜 License

MIT — Use freely, modify as needed

---

## 🤝 Contributing

PRs welcome:

* Better Linux detection
* GPU acceleration
* Additional codec profiles

---

## ❓ Why zsh?

These scripts use zsh-specific features:

* Case-insensitive globbing (#i)
* Parameter expansion flags (:t, :r, :e)
* Local options (setopt local_options)

⚠️ Will NOT work with bash — use zsh only
