normalize_dir() {
  local src="$1"
  local keep_originals="${2:-false}"

  if [[ -z "$src" || ! -d "$src" ]]; then
    echo "❌ Invalid folder"
    return 1
  fi

  setopt extended_glob null_glob

  if ! command -v ffmpeg >/dev/null || ! command -v ffprobe >/dev/null; then
    echo "❌ ffmpeg/ffprobe missing"
    return 1
  fi

  local dst="${src}_normalized"
  mkdir -p "$dst" || return 1

  echo "════════════════════════════"
  echo "🚀 NORMALIZATION START"
  echo "📁 Source: $src"
  echo "📁 Output: $dst"
  echo "════════════════════════════"
  echo ""

  local i=0
  local ok=0
  local fail=0

  get_unique_filename() {
    local dir="$1"
    local base="$2"
    local ext="$3"
    local out="${base}.${ext}"
    local n=1

    while [[ -f "$dir/$out" ]]; do
      out="${base}_${n}.${ext}"
      ((n++))
    done

    echo "$out"
  }

  for f in "$src"/*.(#i)(mov|mp4|mkv|avi|webm); do
    [[ -f "$f" ]] || continue
    ((i++))

    echo "────────────────────────────"
    echo "🎬 FILE #$i: ${f:t}"
    echo "────────────────────────────"

    local base="${f:t:r}"
    local ext="${f:t:e:l}"

    echo "🔍 Step 1: Detecting format..."
    echo "   ↳ extension: .$ext"

    local output=""
    local is_prores=false

    if [[ "$ext" == "mov" ]]; then
      echo "🔬 Step 2: Checking codec..."
      local codec
      codec=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=codec_name,profile \
        -of default=noprint_wrappers=1:nokey=1 "$f")

      echo "   ↳ codec info: $codec"

      echo "$codec" | grep -qi "prores" && is_prores=true
    fi

    # ---------------- PRORES ----------------
    if [[ "$is_prores" == true ]]; then
      echo "⚡ Step 3: ProRes detected → converting to MP4"
      output=$(get_unique_filename "$dst" "$base" "mp4")

      echo "📦 Output file: $output"
      echo "🎥 Running ffmpeg (ProRes → H264)..."

      ffmpeg -i "$f" \
        -c:v libx264 -crf 22 -preset medium \
        -c:a aac -b:a 192k \
        -movflags +faststart \
        -pix_fmt yuv420p \
        -y "$dst/$output" >/dev/null 2>&1

      if [[ $? -eq 0 ]]; then
        echo "✅ DONE: ProRes converted successfully"
        ((ok++))
      else
        echo "❌ FAILED: ProRes conversion error"
        ((fail++))
      fi

    # ---------------- MOV ----------------
    elif [[ "$ext" == "mov" ]]; then
      echo "⚡ Step 3: MOV processing"
      output=$(get_unique_filename "$dst" "$base" "mp4")

      local codec
      codec=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=codec_name \
        -of default=noprint_wrappers=1:nokey=1 "$f")

      echo "   ↳ codec: $codec"

      echo "🎥 Encoding..."

      if echo "$codec" | grep -qi "h264"; then
        ffmpeg -i "$f" -c copy -movflags +faststart -y "$dst/$output" >/dev/null 2>&1
      else
        ffmpeg -i "$f" \
          -c:v libx264 -crf 23 -preset medium \
          -c:a aac -b:a 192k \
          -movflags +faststart \
          -pix_fmt yuv420p \
          -y "$dst/$output" >/dev/null 2>&1
      fi

      if [[ $? -eq 0 ]]; then
        echo "✅ DONE: MOV processed"
        ((ok++))
      else
        echo "❌ FAILED: MOV error"
        ((fail++))
      fi

    # ---------------- MP4 ----------------
    elif [[ "$ext" == "mp4" ]]; then
      echo "⚡ Step 3: MP4 optimization (faststart fix)"
      output=$(get_unique_filename "$dst" "$base" "mp4")

      ffmpeg -i "$f" \
        -c copy -movflags +faststart \
        -y "$dst/$output" >/dev/null 2>&1

      if [[ $? -eq 0 ]]; then
        echo "✅ DONE: MP4 optimized"
        ((ok++))
      else
        echo "❌ FAILED: MP4 fix error"
        ((fail++))
      fi

    # ---------------- OTHER ----------------
    else
      echo "⚡ Step 3: Unsupported format → copying"
      output=$(get_unique_filename "$dst" "$base" "$ext")

      cp "$f" "$dst/$output"

      if [[ $? -eq 0 ]]; then
        echo "📦 COPIED: $output"
        ((ok++))
      else
        echo "❌ COPY FAILED"
        ((fail++))
      fi
    fi

    echo "💾 Step 4: File finished"
    echo ""
  done

  echo "════════════════════════════"
  echo "🏁 DONE"
  echo "✔ Success: $ok"
  echo "❌ Failed: $fail"
  echo "📁 Output: $dst"
  echo "════════════════════════════"

  return $fail
}

resolveify_dir() {
  local src="$1"
  local keep_originals="${2:-false}"
  
  # Check for ffmpeg
  if ! command -v ffmpeg &> /dev/null; then
    echo "❌ ffmpeg not found. Please install it first."
    return 1
  fi

  # Smart detection: Is it a file or folder?
  local is_single_file=false
  local src_dir=""
  local src_file=""
  local dst=""
  local files_to_process=()
  
  if [[ -f "$src" ]]; then
    # Single file mode
    is_single_file=true
    src_dir="$(dirname "$src")"
    src_file="$(basename "$src")"
    
    # Check if it's a valid video file (case insensitive)
    local ext="${src_file:e:l}"
    if [[ ! "$ext" =~ ^(mp4|mkv|mov|webm|avi)$ ]]; then
      echo "❌ Not a supported video file: $src_file"
      echo "   Supported formats: mp4, mkv, mov, webm, avi"
      return 1
    fi
    
    # Create output directory next to the file
    dst="${src_dir}/${src_file:r}_resolve"
    mkdir -p "$dst" || return 1
    
    files_to_process=("$src")
    
    echo "🎯 Single file mode: $src_file"
    
  elif [[ -d "$src" ]]; then
    # Folder mode
    is_single_file=false
    src_dir="$src"
    dst="${src}_resolve"
    mkdir -p "$dst" || return 1
    
    echo "📁 Folder mode: $src"
    echo "🔍 Scanning for video files..."
    
    # FIXED: Better file detection with multiple methods
    setopt local_options null_glob extended_glob
    
    # Method 1: Case insensitive pattern
    files_to_process=("$src"/*.(#i)mp4 "$src"/*.(#i)mkv "$src"/*.(#i)mov "$src"/*.(#i)webm "$src"/*.(#i)avi)
    
    # Method 2: If Method 1 found nothing, try manual case handling
    if [[ ${#files_to_process[@]} -eq 0 ]]; then
      echo "   Trying alternative detection..."
      files_to_process=()
      
      # Manually add files with common extensions (both cases)
      for ext in mp4 MP4 mkv MKV mov MOV webm WEBM avi AVI; do
        for file in "$src"/*.$ext; do
          [[ -f "$file" ]] && files_to_process+=("$file")
        done
      done
    fi
    
    # Method 3: Use find as last resort
    if [[ ${#files_to_process[@]} -eq 0 ]]; then
      echo "   Using find command..."
      while IFS= read -r file; do
        files_to_process+=("$file")
      done < <(find "$src" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" -o -iname "*.avi" \) 2>/dev/null)
    fi
    
    # Sort files for consistent processing
    files_to_process=(${(o)files_to_process})
    
    echo "   Found ${#files_to_process[@]} files"
    
  else
    echo "❌ Please provide a valid video file or folder"
    echo "   Usage: resolveify_dir <file.mp4|folder> [keep_originals]"
    return 1
  fi

  # Check available disk space (in KB)
  local available_space=$(df "$PWD" | awk 'NR==2 {print $4}')
  local min_space_required=1048576  # 1GB in KB
  
  if [[ $available_space -lt $min_space_required ]]; then
    echo "⚠️  Low disk space: $(($available_space / 1024))MB available"
    echo "❌ Need at least 1GB free space. Aborting."
    return 1
  fi

  local total_files=${#files_to_process[@]}
  local current_file=0
  local failed=0
  local converted=0
  local total_original_size=0
  local total_converted_size=0

  if [[ $total_files -eq 0 ]]; then
    echo "❌ No video files found in: $src"
    echo "   Supported formats: mp4, mkv, mov, webm, avi"
    echo "   (case insensitive - MP4, Mp4, .mp4 all work)"
    if [[ ! "$is_single_file" == true ]]; then
      rmdir "$dst" 2>/dev/null
    fi
    return 1
  fi

  echo ""
  echo "📁 Found $total_files video file(s) to convert"
  echo "💾 Available space: $(($available_space / 1024))MB"
  echo ""

  # Function to generate unique output filename
  get_unique_output() {
    local dir="$1"
    local base="$2"
    local counter=0
    local result="${base}.mov"
    
    while [[ -f "${dir}/${result}" ]]; do
      counter=$((counter + 1))
      result="${base}_${counter}.mov"
    done
    
    echo "$result"
  }

  for f in "${files_to_process[@]}"; do
    ((current_file++))
    
    # Skip if not a regular file (safety check)
    [[ ! -f "$f" ]] && continue
    
    local original_size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null)
    local original_size_mb=$((original_size / 1048576))
    local original_filename="$(basename "$f")"
    local filename_base="${original_filename:r}"
    
    # Generate unique output filename
    local output_filename=$(get_unique_output "$dst" "$filename_base")
    local output="$dst/$output_filename"
    
    echo "🎬 [$current_file/$total_files] Converting: $original_filename"
    echo "   📦 Original size: ${original_size_mb}MB"
    echo "   📝 Output: $output_filename"
    
    # Convert with progress
    if ffmpeg -i "$f" \
      -c:v dnxhd -profile:v dnxhr_sq \
      -pix_fmt yuv422p \
      -c:a pcm_s16le \
      -movflags +write_colr \
      -stats \
      -y \
      "$output" 2>&1 | grep -E "(frame=|Duration:)"; then
      
      local converted_size=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null)
      local converted_size_mb=$((converted_size / 1048576))
      total_converted_size=$((total_converted_size + converted_size))
      total_original_size=$((total_original_size + original_size))
      
      echo "   ✅ Converted: ${converted_size_mb}MB (was ${original_size_mb}MB)"
      ((converted++))
      
      # Smart storage management: Check space after each conversion
      local remaining_space=$(df "$PWD" | awk 'NR==2 {print $4}')
      if [[ $remaining_space -lt $min_space_required ]]; then
        echo "⚠️  Low disk space (${remaining_space}KB remaining)!"
        echo "🛑 Stopping conversion to prevent disk full"
        break
      fi
      
    else
      echo "   ❌ Failed to convert: $original_filename"
      failed=1
      # Clean up partial output
      [[ -f "$output" ]] && rm "$output"
    fi
    
    echo ""
  done

  # Summary
  echo "═══════════════════════════════════════════════"
  echo "📊 CONVERSION SUMMARY"
  echo "   ✅ Successfully converted: $converted/$total_files file(s)"
  [[ $failed -eq 1 ]] && echo "   ❌ Some files failed to convert"
  
  if [[ $converted -gt 0 ]]; then
    local total_original_mb=$((total_original_size / 1048576))
    local total_converted_mb=$((total_converted_size / 1048576))
    local space_saved=$((total_original_size - total_converted_size))
    local space_saved_mb=$((space_saved / 1048576))
    
    echo "   📦 Total original size: ${total_original_mb}MB"
    echo "   🎥 Total converted size: ${total_converted_mb}MB"
    
    if [[ $space_saved -gt 0 ]]; then
      echo "   💾 Space saved: ${space_saved_mb}MB"
    else
      echo "   📈 Space increase: $((-space_saved_mb))MB (DNxHD is less compressed)"
    fi
  fi
  
  # Smart cleanup options (different for single file vs folder)
  echo ""
  echo "═══════════════════════════════════════════════"
  echo "🗑️  ORIGINAL FILES MANAGEMENT"
  
  if [[ "$keep_originals" == "true" ]]; then
    if [[ "$is_single_file" == true ]]; then
      echo "📁 Original file kept at: $src"
      echo "💡 Converted file is in: $dst/"
    else
      echo "📁 Original files kept in: $src"
      echo "💡 Tip: You can manually delete them when you need space:"
      echo "   rm -rf \"$src\""
    fi
  else
    local confirmed=false
    
    # Check if user wants to delete based on space
    local current_space=$(df "$PWD" | awk 'NR==2 {print $4}')
    local space_percent=$((current_space * 100 / available_space))
    
    if [[ "$is_single_file" == true ]]; then
      # Single file mode - simpler prompt
      echo "💾 Disk space: ${space_percent}% remaining"
      echo "🗑️  Delete original file '$(basename "$src")'?"
      read "delete?Delete original? (yes/no): "
      [[ "$delete" == "yes" ]] && confirmed=true
      
      if [[ "$confirmed" == true ]]; then
        echo "🗑️  Deleting original file: $src"
        rm -f "$src"
        local new_space=$(df "$PWD" | awk 'NR==2 {print $4}')
        local freed=$((new_space - current_space))
        echo "✅ Freed $(($freed / 1024))MB of space"
        echo "📁 Converted file in: $dst/"
      else
        echo "📁 Original file kept at: $src"
        echo "💡 Converted file in: $dst/"
      fi
    else
      # Folder mode - existing logic
      if [[ $space_percent -lt 30 ]]; then
        echo "💾 Disk space is getting low (${space_percent}% remaining)"
        echo "🗑️  Would you like to delete original files to free up space?"
        read "delete?Delete originals? (yes/no): "
        [[ "$delete" == "yes" ]] && confirmed=true
      else
        echo "💾 Disk space is healthy (${space_percent}% remaining)"
        echo "🗑️  Delete original folder? (recommended to save space)"
        read "delete?Delete originals? (yes/no): "
        [[ "$delete" == "yes" ]] && confirmed=true
      fi
      
      if [[ "$confirmed" == true ]]; then
        echo "🗑️  Deleting original folder: $src"
        rm -rf "$src"
        local new_space=$(df "$PWD" | awk 'NR==2 {print $4}')
        local freed=$((new_space - current_space))
        echo "✅ Freed $(($freed / 1024))MB of space"
      else
        echo "📁 Original files kept in: $src"
        echo "💡 Run this later to free up space: rm -rf \"$src\""
      fi
    fi
  fi
  
  echo "✅ Conversion process completed."
  
  # Final space info
  local final_space=$(df "$PWD" | awk 'NR==2 {print $4}')
  echo "💾 Final available space: $(($final_space / 1024))MB"
  
  return $failed
}
