# Davinci Resolve Linux Fix

Convert any video format to DNxHR (DaVinci Resolve compatible) on Linux.

## Problem
DaVinci Resolve on Linux has limited codec support:
- ❌ Can't import H.264/H.265 MP4/MKV files
- ❌ Can't export to normal video formats (only DNxHR/ProRes)

## Solution
This script converts videos to DNxHR SQ (Spatial Quality) with PCM audio:
- ✅ Full DaVinci Resolve compatibility on Linux
- ✅ Preserves color information (4:2:2 chroma subsampling)
- ✅ Batch convert entire folders
- ✅ Smart duplicate handling

## Features
- Single file or batch folder conversion
- Preserves original files (optional)
- Smart duplicate naming (_1, _2, etc.)
- Disk space checking
- Progress indicators
