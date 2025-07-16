# git-livereload

A simple local server that livereloads local source files via a containerized git server with advanced rsync filtering support.

## Overview

git-livereload creates a containerized git server that continuously syncs files from your local development directory to a git repository, automatically committing changes and making them available via HTTP. It supports sophisticated file filtering using rsync's include/exclude patterns.

## Features

- **Automatic Git Commits**: Watches for file changes and commits them automatically
- **HTTP Git Server**: Serves git repository over HTTP with basic authentication
- **Advanced Filtering**: Support for include/exclude patterns with proper rsync rule ordering
- **Webhook Support**: Optional webhook notifications on commits
- **Docker-based**: Easy deployment with Docker Compose

## Environment Variables

### Core Configuration
- `GIT_USERNAME` (default: `git`) - Username for HTTP basic authentication
- `GIT_PASSWORD` (default: `p@$$w0rd`) - Password for HTTP basic authentication
- `WEBHOOK_URL` - Optional webhook URL to notify on commits
- `VERIFY_SSL` (default: `true`) - Set to `false` to disable SSL verification for webhooks

### Rsync Filtering

The system supports three types of rsync filtering:

#### RSYNC_INCLUDE
Specifies which files/directories to include. When set, everything else is excluded by default.

```bash
# Include only the 'kustomize' directory
RSYNC_INCLUDE=kustomize

# Include multiple directories
RSYNC_INCLUDE=src,docs,config

# Include nested paths
RSYNC_INCLUDE=app/src,app/config
```

**How it works:**
- Automatically generates directory traversal rules (`--include=dir/` for each path component)
- Includes all contents of specified paths (`--include=path/***`)
- Adds `--exclude=*` to exclude everything else

#### RSYNC_EXCLUDE
Specifies files/directories to exclude from the sync.

```bash
# Exclude common build artifacts
RSYNC_EXCLUDE=node_modules,*.log,build,dist

# Exclude with patterns
RSYNC_EXCLUDE=*.tmp,*.cache,test/*
```

#### RSYNC_PROTECT
Protects files from deletion during sync (uses rsync's protect filter).

```bash
# Protect configuration files
RSYNC_PROTECT=.env,config.local.yaml
```

### Advanced Filtering Examples

#### Example 1: Include only specific directories
```bash
# Only sync 'kustomize' directory, exclude everything else
RSYNC_INCLUDE=kustomize
```
Generates rsync args: `--include=kustomize/*** --exclude=*`

#### Example 2: Include with exclusions
```bash
# Include 'kustomize' but exclude 'kustomize/protected' subdirectory
RSYNC_INCLUDE=kustomize
RSYNC_EXCLUDE=kustomize/protected
```
Generates rsync args: `--include=kustomize/*** --exclude=kustomize/protected --exclude=*`

#### Example 3: Multiple includes with nested paths
```bash
# Include multiple directories with nested structure
RSYNC_INCLUDE=app/src,app/config,docs
```
Generates rsync args: 
```
--include=app/ --include=app/src/*** --include=app/config/*** --include=docs/*** --exclude=*
```

#### Example 4: Complex filtering
```bash
RSYNC_INCLUDE=src,config
RSYNC_EXCLUDE=src/test,*.log,*.tmp
RSYNC_PROTECT=config/.env
```

### Rule Processing Order

The system follows rsync's rule ordering requirements:
1. **Include rules** are processed first (directory traversal + content inclusion)
2. **Exclude rules** are processed next
3. **Protect rules** are processed last
4. When includes are specified, an automatic `--exclude=*` is added at the end

## Docker Compose Usage

### Basic Setup
```yaml
services:
  git-livereload:
    build:
      context: ./git-livereload
    image: git-livereload:latest
    ports:
      - "8080:80"
    volumes:
      - ./my-project:/repos/mount/blueprint
    environment:
      GIT_USERNAME: myuser
      GIT_PASSWORD: mypassword
```

### With Filtering
```yaml
services:
  git-livereload:
    build:
      context: ./git-livereload
    image: git-livereload:latest
    ports:
      - "8080:80"
    volumes:
      - ./my-project:/repos/mount/blueprint
    environment:
      GIT_USERNAME: myuser
      GIT_PASSWORD: mypassword
      # Only include 'kustomize' directory
      RSYNC_INCLUDE: kustomize
      # Exclude protected subdirectory
      RSYNC_EXCLUDE: kustomize/protected
      # Protect environment files
      RSYNC_PROTECT: .env,config.local.yaml
```

## Directory Structure

```
/repos/
├── mount/blueprint/     # Mounted source directory (read-only)
├── serve/blueprint/     # Working git repository
└── git/blueprint.git/   # Bare git repository
```

## Accessing the Git Repository

Once running, you can clone the repository:

```bash
git clone http://myuser:mypassword@localhost:8080/blueprint.git
```

## How Include Patterns Work

The include functionality implements rsync's complex rule requirements:

1. **Directory Traversal**: For path `app/src`, generates `--include=app/` to allow traversal
2. **Content Inclusion**: Adds `--include=app/src/***` to include all contents
3. **Default Exclusion**: Automatically adds `--exclude=*` when includes are specified
4. **Duplicate Prevention**: Avoids duplicate directory traversal rules

Example transformation:
```bash
RSYNC_INCLUDE=app/src,docs
```
Becomes:
```bash
rsync --include=app/ --include=app/src/*** --include=docs/*** --exclude=*
```

## Use Cases

### Development Workflow
- Include only source directories: `RSYNC_INCLUDE=src,docs`
- Exclude build artifacts: `RSYNC_EXCLUDE=build,dist,node_modules`

### Configuration Management
- Include only configs: `RSYNC_INCLUDE=kustomize,config`
- Exclude sensitive data: `RSYNC_EXCLUDE=kustomize/secrets`
- Protect local overrides: `RSYNC_PROTECT=.env.local`

### Selective Sync
- Include specific app modules: `RSYNC_INCLUDE=apps/frontend,apps/api`
- Exclude test directories: `RSYNC_EXCLUDE=*/test,*/tests`

## Troubleshooting

### Debug Rsync Rules
Check container logs to see the actual rsync commands being executed:
```bash
docker-compose logs git-livereload
```

### Test Filtering
Use rsync directly to test your patterns:
```bash
rsync -av --include=kustomize/*** --exclude=* /source/ /dest/
```

### Common Issues
1. **Empty sync**: Check that include patterns are correct and directories exist
2. **Unexpected files**: Verify exclude patterns and rule ordering
3. **Permission errors**: Ensure proper file permissions in mounted volumes

## Architecture

The system runs three main processes:
- **nginx**: HTTP server for git repository access
- **fcgiwrap**: CGI wrapper for git-http-backend
- **sync.sh**: Continuous file synchronization and git operations

File changes trigger rsync operations that respect the configured include/exclude patterns, followed by automatic git commits and pushes to the bare repository.
