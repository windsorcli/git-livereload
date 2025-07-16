#!/usr/bin/env bash
set -ou pipefail
trap 'catch $? $LINENO' EXIT

catch() {
  if [ "$1" != "0" ]; then
    echo "Error $1 occurred on $2"
  fi
}

RSYNC_EXCLUDE=${RSYNC_EXCLUDE:-}
RSYNC_PROTECT=${RSYNC_PROTECT:-}
RSYNC_INCLUDE=${RSYNC_INCLUDE:-}

declare rsync_args=('--exclude=.git')
declare protect_arg_str='--filter="P .git"'

# Build all rsync filtering arguments in proper order
build_rsync_args() {
  local -A included_dirs=()
  local -a traversal_rules=()
  local -a content_rules=()
  local -a exclude_rules=()
  
  # Process includes first to generate traversal and content rules
  if [[ -n "$RSYNC_INCLUDE" ]]; then
    IFS=',' read -ra INCLUDES <<< "$RSYNC_INCLUDE"
    for include in "${INCLUDES[@]}"; do
      [[ -n "$include" ]] || continue
      
      # Strip trailing slashes for consistent processing
      include="${include%/}"
      
      # Generate include rules for each path component to allow directory traversal
      local path_components=()
      local current_path=""
      
      # Split path into components
      IFS='/' read -ra path_parts <<< "$include"
      for part in "${path_parts[@]}"; do
        [[ -n "$part" ]] || continue
        if [[ -n "$current_path" ]]; then
          current_path="$current_path/$part"
        else
          current_path="$part"
        fi
        path_components+=("$current_path")
      done
      
      # Add include rules for directory traversal (all path components except the last)
      for ((i=0; i<${#path_components[@]}-1; i++)); do
        local dir_path="${path_components[i]}"
        if [[ -z "${included_dirs[$dir_path]:-}" ]]; then
          traversal_rules+=("--include=$dir_path/")
          included_dirs[$dir_path]=1
        fi
      done
      
      # Add include rule for the final path (include all contents with /***)
      if [[ ${#path_components[@]} -gt 0 ]]; then
        local final_path="${path_components[-1]}"
        content_rules+=("--include=$final_path/***")
      fi
    done
  fi
  
  # Process excludes
  if [[ -n "$RSYNC_EXCLUDE" ]]; then
    IFS=',' read -ra EXCLUDES <<< "$RSYNC_EXCLUDE"
    for exclude in "${EXCLUDES[@]}"; do
      [[ -n "$exclude" ]] && exclude_rules+=("--exclude=$exclude")
    done
  fi
  
  # Build final args array in correct order:
  # 1. Start with base exclusions
  rsync_args=('--exclude=.git')
  
  # 2. Add directory traversal includes
  rsync_args+=("${traversal_rules[@]}")
  
  # 3. Add excludes (these need to come before content includes for proper precedence)
  rsync_args+=("${exclude_rules[@]}")
  
  # 4. Add content includes
  rsync_args+=("${content_rules[@]}")
  
  # 5. Add final exclude-all rule when includes are specified
  if [[ ${#content_rules[@]} -gt 0 ]]; then
    rsync_args+=("--exclude=*")
  fi
}

# Build protection argument string
build_protect_args() {
  if [[ -n "$RSYNC_PROTECT" ]]; then
    IFS=',' read -ra PROTECTS <<< "$RSYNC_PROTECT"
    for protect in "${PROTECTS[@]}"; do
      if [[ -n "$protect" ]]; then
        protect_arg_str+=" --filter=\"P $protect\""
      fi
    done
  fi
}

# Function to handle syncing for a given repository
handle_sync() {
  local repo_name="$1"
  local src_dir="/repos/mount/$repo_name"
  local work_dir="/repos/serve/$repo_name"

  # Execute the rsync command with specific info level
  # Convert array to space-separated string for eval
  local rsync_args_str="${rsync_args[*]}"
  eval "rsync -a --delete --info=flist0,name $rsync_args_str $protect_arg_str $src_dir/ $work_dir/"
}

# Perform Git operations in a separate function for clarity
handle_git_operations() {
  local work_dir="$1"
  cd "$work_dir" || return

  git add .

  if ! git diff --quiet --cached; then
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    git commit -m "Autocommit: $timestamp"
    git pull --rebase origin main
    git push origin main

    # Send webhook if URL is set
    if [[ -n "$WEBHOOK_URL" ]]; then
      local curl_opts="-X POST -H 'Content-Type: application/json' -s -d '{\"event\":\"commit_pushed\",\"timestamp\":\"$timestamp\"}'"
      if [[ "$VERIFY_SSL" == "false" ]]; then
        curl_opts="-k $curl_opts"
      fi
      eval "curl $curl_opts \"$WEBHOOK_URL\""
      echo "Webhook sent"
    fi
  fi
}

# Main execution
build_rsync_args
build_protect_args

while true; do
  for dir in /repos/mount/*; do
    repo_name=$(basename "$dir")
    
    handle_sync "$repo_name"
    handle_git_operations "/repos/serve/$repo_name"
  done
  sleep 1
done
