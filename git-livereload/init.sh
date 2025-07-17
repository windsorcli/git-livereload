#!/usr/bin/env bash
set -eou pipefail

RSYNC_EXCLUDE=${RSYNC_EXCLUDE:-}
RSYNC_INCLUDE=${RSYNC_INCLUDE:-}
GIT_USERNAME=${GIT_USERNAME:-git}
GIT_PASSWORD=${GIT_PASSWORD:-p@$$w0rd}

setup_htpasswd() {
  htpasswd -bc /etc/nginx/.htpasswd "$GIT_USERNAME" "$GIT_PASSWORD"
  chmod 0640 /etc/nginx/.htpasswd
}

configure_git() {
  git config --global user.name "Auto-commit"
  git config --global user.email "auto-commit@localhost"
  git config --global init.defaultBranch main
}

declare -a rsync_args=('--exclude=.git')

# Build all rsync filtering arguments in proper order
build_rsync_args() {
  local -A included_dirs=()
  local -a traversal_rules=()
  local -a content_rules=()
  local -a exclude_rules=()
  
  # Process includes first to generate traversal and content rules
  if [ -n "$RSYNC_INCLUDE" ]; then
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
  if [ -n "$RSYNC_EXCLUDE" ]; then
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



# Main execution
echo "Starting initialization..."
setup_htpasswd
configure_git
build_rsync_args

echo "Setting up directory structure..."
mkdir -p /repos/mount /repos/git /repos/serve
echo "Repository initialization will be handled dynamically by sync service"

echo "Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
