
normalize_dir() {
  local src="$1"
  local keep_originals="${2:-false}"  # Second param: "true" to keep, "false" to delete after confirm
  
  if [[ -z "$src" || ! -d "$src" ]]; then
    echo "❌ Please provide a valid folder"
    return 1
  fi

  # Check for ffmpeg and ffprobe
  if ! command -v ffmpeg &> /dev/null || ! command -v ffprobe &> /dev/null; then
    echo "❌ ffmpeg/ffprobe not found. Please install them first."
    return 1
  fi
  
  local dst="${src}_normalized"
  mkdir -p "$dst" || return 1
  
  # Check available disk space (in KB)
  local available_space=$(df "$PWD" | awk 'NR==2 {print $4}')
  local min_space_required=1048576  # 1GB in KB
  
  if [[ $available_space -lt $min_space_required ]]; then
    echo "⚠️  Low disk space: $(($available_space / 1024))MB available"
    echo "❌ Need at least 1GB free space. Aborting."
    return 1
  fi
  
  # Set options for zsh
  setopt local_options null_glob
  
  echo "📁 Converting all video files to standard MP4 format..."
  echo "💾 Available space: $(($available_space / 1024))MB"
  echo ""
  
  local prores_converted=0
  local normal_converted=0
  local skipped=0
  local failed=0
  
  # Function to generate unique filename
  get_unique_filename() {
    local dir="$1"
    local base="$2"
    local ext="$3"
    local counter=0
    local result="${base}.${ext}"
    
    while [[ -f "${dir}/${result}" ]]; do
      counter=$((counter + 1))
      result="${base}_${counter}.${ext}"
    done
    
    echo "$result"
  }
  
  # Process all video files (case insensitive)
  for f in "$src"/*.(#i)(mov|mp4|mkv|avi|webm); do
    # Skip if not a file
    [[ -f "$f" ]] || continue
    
    echo "🔍 Checking: ${f:t}"
    
    # Get filename without extension
    local original_filename="${f:t:r}"
    local extension="${f:t:e:l}"  # lowercase extension
    local output_filename=""
    local output_path=""
    local should_convert=false
    
    # Check if it's ProRes 422 HQ (only for .mov files)
    local is_prores=false
    if [[ "$extension" == "mov" ]]; then
      local codec_info=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=codec_name,profile \
        -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
      
      if echo "$codec_info" | grep -iq "prores" && echo "$codec_info" | grep -iq "422" && echo "$codec_info" | grep -iq "hq"; then
        is_prores=true
      fi
    fi
    
    # Determine output filename and conversion type
    if [[ "$is_prores" == true ]]; then
      # ProRes always converts to MP4
      output_filename=$(get_unique_filename "$dst" "$original_filename" "mp4")
      output_path="$dst/$output_filename"
      should_convert=true
      
      echo "🎬 Converting ProRes 422 HQ to MP4: ${f:t}"
      echo "   📝 Output: $output_filename"
      
      # Convert ProRes 422 HQ to H.264 MP4
      if ffmpeg -i "$f" \
        -c:v libx264 -crf 22 -preset medium \
        -c:a aac -b:a 192k \
        -movflags +faststart \
        -pix_fmt yuv420p \
        -stats \
        -y \
        "$output_path" 2>&1 | grep -E "(frame=|Duration:)"; then
        echo "   ✅ Converted: ${output_filename}"
        ((prores_converted++))
        
        # Show size comparison
        local original_size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
        local converted_size=$(stat -f%z "$output_path" 2>/dev/null || stat -c%s "$output_path" 2>/dev/null)
        local original_mb=$((original_size / 1048576))
        local converted_mb=$((converted_size / 1048576))
        echo "   📦 Size: ${original_mb}MB → ${converted_mb}MB"
      else
        echo "   ❌ Failed to convert: ${f:t}"
        ((failed++))
      fi
      
    elif [[ "$extension" == "mov" ]]; then
      # Normal .mov file (not ProRes)
      output_filename=$(get_unique_filename "$dst" "$original_filename" "mp4")
      output_path="$dst/$output_filename"
      should_convert=true
      
      echo "🎬 Converting normal MOV to MP4: ${f:t}"
      echo "   📝 Output: $output_filename"
      
      # Check if it's already H.264 in a .mov container
      local current_codec=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=codec_name \
        -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
      
      if echo "$current_codec" | grep -iq "h264"; then
        # Already H.264, just remux to MP4
        echo "   (Already H.264, remuxing...)"
        if ffmpeg -i "$f" \
          -c:v copy -c:a copy \
          -movflags +faststart \
          -stats \
          -y \
          "$output_path" 2>&1 | grep -E "(frame=|Duration:)"; then
          echo "   ✅ Remuxed to: ${output_filename}"
          ((normal_converted++))
        else
          echo "   ❌ Failed to remux: ${f:t}"
          ((failed++))
        fi
      else
        # Transcode to H.264
        if ffmpeg -i "$f" \
          -c:v libx264 -crf 23 -preset medium \
          -c:a aac -b:a 192k \
          -movflags +faststart \
          -pix_fmt yuv420p \
          -stats \
          -y \
          "$output_path" 2>&1 | grep -E "(frame=|Duration:)"; then
          echo "   ✅ Converted to: ${output_filename}"
          ((normal_converted++))
        else
          echo "   ❌ Failed to convert: ${f:t}"
          ((failed++))
        fi
      fi
      
    elif [[ "$extension" == "mp4" ]]; then
      # Already MP4 - check if an MP4 with same name exists and handle duplicates
      local existing_mp4="${dst}/${original_filename}.mp4"
      
      if [[ -f "$existing_mp4" ]]; then
        # File exists, generate unique name
        output_filename=$(get_unique_filename "$dst" "$original_filename" "mp4")
        output_path="$dst/$output_filename"
        echo "⚠️  Conflict: ${original_filename}.mp4 already exists"
        echo "   📝 Using: $output_filename"
      else
        output_filename="${original_filename}.mp4"
        output_path="$dst/$output_filename"
      fi
      
      echo "📋 MP4 file detected: ${f:t}"
      echo "   📝 Output: $output_filename"
      
      # Check if it has faststart flag
      if ffprobe -v error -show_entries format=flags \
        -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null | grep -q "faststart"; then
        echo "   (Already has faststart, copying...)"
        cp "$f" "$output_path" 2>/dev/null
      else
        echo "   (Adding faststart flag...)"
        ffmpeg -i "$f" \
          -c:v copy -c:a copy \
          -movflags +faststart \
          -y \
          "$output_path" 2>/dev/null
      fi
      
      if [[ $? -eq 0 ]]; then
        echo "   ✅ Processed: ${output_filename}"
        ((skipped++))
      else
        echo "   ❌ Failed to process: ${f:t}"
        ((failed++))
      fi
      
    elif [[ "$extension" == "mkv" || "$extension" == "avi" || "$extension" == "webm" ]]; then
      # Convert other video formats to MP4
      output_filename=$(get_unique_filename "$dst" "$original_filename" "mp4")
      output_path="$dst/$output_filename"
      should_convert=true
      
      echo "🎬 Converting ${extension:u} to MP4: ${f:t}"
      echo "   📝 Output: $output_filename"
      
      if ffmpeg -i "$f" \
        -c:v libx264 -crf 23 -preset medium \
        -c:a aac -b:a 192k \
        -movflags +faststart \
        -pix_fmt yuv420p \
        -stats \
        -y \
        "$output_path" 2>&1 | grep -E "(frame=|Duration:)"; then
        echo "   ✅ Converted to: ${output_filename}"
        ((normal_converted++))
      else
        echo "   ❌ Failed to convert: ${f:t}"
        ((failed++))
      fi
      
    else
      # Unknown format, just copy with unique name
      local new_filename=$(get_unique_filename "$dst" "$original_filename" "$extension")
      echo "⚠️  Unknown format, copying as-is: ${f:t}"
      echo "   📝 Output: $new_filename"
      cp "$f" "$dst/$new_filename" 2>/dev/null
      if [[ $? -eq 0 ]]; then
        ((skipped++))
      else
        echo "   ❌ Failed to copy: ${f:t}"
        ((failed++))
      fi
    fi
    
    # Check disk space after each operation
    local remaining_space=$(df "$PWD" | awk 'NR==2 {print $4}')
    if [[ $remaining_space -lt $min_space_required ]]; then
      echo "⚠️  Low disk space (${remaining_space}KB remaining)!"
      echo "🛑 Stopping conversion to prevent disk full"
      break
    fi
    
    echo ""
  done
  
  # Summary
  echo "═══════════════════════════════════════════════"
  echo "📊 CONVERSION SUMMARY"
  echo "   ✅ ProRes 422 HQ converted: $prores_converted"
  echo "   ✅ Normal videos converted: $normal_converted"
  echo "   📋 Files copied/processed: $skipped"
  [[ $failed -gt 0 ]] && echo "   ❌ Failed conversions: $failed"
  
  local total_processed=$((prores_converted + normal_converted + skipped))
  echo "   📁 Total files processed: $total_processed"
  echo "   📂 Output directory: $dst"
  
  # Smart cleanup options
  echo ""
  echo "═══════════════════════════════════════════════"
  echo "🗑️  ORIGINAL FILES MANAGEMENT"
  
  if [[ "$keep_originals" == "true" ]]; then
    echo "📁 Original files kept in: $src"
    echo "💡 Tip: You can manually delete them when you need space:"
    echo "   rm -rf \"$src\""
  else
    local confirmed=false
    
    # Check disk space trend
    local final_space=$(df "$PWD" | awk 'NR==2 {print $4}')
    local space_percent=$((final_space * 100 / available_space))
    
    if [[ $space_percent -lt 30 ]]; then
      echo "💾 Disk space is getting low (${space_percent}% remaining)"
      echo "🗑️  Would you like to delete original files to free up space?"
      read "delete?Delete originals? (yes/no): "
      [[ "$delete" == "yes" ]] && confirmed=true
    else
      echo "💾 Disk space is healthy (${space_percent}% remaining)"
      echo "🗑️  Delete original files? (you can always re-normalize from originals)"
      read "delete?Delete originals? (yes/no): "
      [[ "$delete" == "yes" ]] && confirmed=true
    fi
    
    if [[ "$confirmed" == true ]]; then
      echo "🗑️  Deleting original folder: $src"
      rm -rf "$src"
      local new_space=$(df "$PWD" | awk 'NR==2 {print $4}')
      local freed=$((new_space - final_space))
      echo "✅ Freed $(($freed / 1024))MB of space"
    else
      echo "📁 Original files kept in: $src"
      echo "💡 Run this later to free up space: rm -rf \"$src\""
    fi
  fi
  
  echo "✅ Normalization process completed."
  
  # Final space info
  local final_space=$(df "$PWD" | awk 'NR==2 {print $4}')
  echo "💾 Final available space: $(($final_space / 1024))MB"
  
  return $failed
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
