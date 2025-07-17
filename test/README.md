# Tests

This directory contains test scripts for the git-livereload system's rsync filtering functionality.

## Available Tests

### test-filtering.sh
Basic test script that demonstrates fundamental rsync include/exclude patterns.

```bash
./test-filtering.sh
```

This test specifically demonstrates:
- Correct rule ordering for includes/excludes
- How to exclude subdirectories within included directories
- Complex multi-directory filtering scenarios
- Real-world use cases

## Key Features Demonstrated

1. **Basic Include**: `RSYNC_INCLUDE=kustomize` → only sync kustomize directory
2. **Include with Exclude**: `RSYNC_INCLUDE=kustomize` + `RSYNC_EXCLUDE=kustomize/protected` → sync kustomize but exclude protected subdirectory
3. **Multiple Includes**: `RSYNC_INCLUDE=src,docs,config` → sync multiple directories
4. **Complex Filtering**: Combination of includes, excludes, and patterns

## Rule Generation Logic

The system generates rsync rules in this specific order for proper precedence:

1. **Base exclusions** (`--exclude=.git`)
2. **Directory traversal includes** (`--include=dir/`)
3. **Specific excludes** (`--exclude=dir/subdir`)
4. **Content includes** (`--include=dir/***`)
5. **Final exclude all** (`--exclude=*`)

This ordering ensures that:
- Directories can be traversed for includes
- Specific exclusions take precedence over broad includes
- Only explicitly included content is synced

## Example Environment Variables

```bash
# Include only kustomize, exclude protected subdirectory
RSYNC_INCLUDE=kustomize
RSYNC_EXCLUDE=kustomize/protected

# Multiple includes with various exclusions
RSYNC_INCLUDE=src,config,docs
RSYNC_EXCLUDE="*/test,*/tests,build,*.log,*.tmp"
RSYNC_PROTECT=.env,.env.local
``` 