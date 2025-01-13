#!/usr/bin/env bash
set -eou pipefail

RSYNC_EXCLUDE=${RSYNC_EXCLUDE:-}
GIT_USERNAME=${GIT_USERNAME:-git}
GIT_PASSWORD=${GIT_PASSWORD:-p@$$w0rd}

setup_htpasswd() {
  htpasswd -bc /etc/nginx/.htpasswd "$GIT_USERNAME" "$GIT_PASSWORD"
  chown nginx:nginx /etc/nginx/.htpasswd
  chmod 0660 /etc/nginx/.htpasswd
}

configure_git() {
  git config --global user.name "Auto-commit"
  git config --global user.email "auto-commit@localhost"
}

declare -a exclude_args=('--exclude=.git')
build_exclude_args() {
  if [ -n "$RSYNC_EXCLUDE" ]; then
    IFS=',' read -ra EXCLUDES <<< "$RSYNC_EXCLUDE"
    for exclude in "${EXCLUDES[@]}"; do
      exclude_args+=("--exclude=$exclude")
    done
  fi
}

initialize_repository() {
  local repo_name="$1"
  local dir="$2"

  # Clean out existing directories
  rm -rf "/repos/git/$repo_name.git" "/repos/serve/$repo_name"

  # Initialize bare and non-bare repositories
  git init --bare "/repos/git/$repo_name.git"
  mkdir -p "/repos/serve/$repo_name"
  cd "/repos/serve/$repo_name" || exit
  git config --global --add safe.directory "/repos/serve/$repo_name"
  git init
  git remote add origin "file:///repos/git/$repo_name.git"

  # Sync files and make initial commit
  rsync -av "${exclude_args[@]}" "$dir/" .
  git add .
  git commit -m 'Initial commit'
  git branch -m main
  git push -u origin main
}

adjust_repo_permissions() {
  chown -R nginx:nginx /repos/git
  chmod -R u+rwX,go+rX,go-w /repos/git
}

# Main execution
setup_htpasswd
configure_git
build_exclude_args

for dir in /repos/mount/*; do
  repo_name=$(basename "$dir")
  initialize_repository "$repo_name" "$dir"
done

adjust_repo_permissions
/usr/bin/supervisord -c /etc/supervisord.conf
