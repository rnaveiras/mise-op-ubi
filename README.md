# mise-op-ubi

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/v/release/rnaveiras/mise-op-ubi)](https://github.com/rnaveiras/mise-op-ubi/releases)

A [mise](https://github.com/jdx/mise) backend plugin that securely integrates 1Password CLI for credential management with [ubi](https://github.com/houseabsolute/ubi) for installing tools from private GitHub repositories.

## The Problem

When using mise's built-in `ubi` backend with private GitHub repositories, you must export `GITHUB_TOKEN` permanently in your shell environment. This creates security concerns:

- **Token exposure**: The token lives in your shell environment indefinitely
- **Accidental leakage**: Easy to forget it's exported and accidentally commit it or share it
- **No rotation**: Changing tokens requires updating multiple shell configurations

## The Solution

**mise-op-ubi** provides a more secure alternative:

✅ **On-demand credential retrieval**: GitHub tokens are fetched from 1Password CLI only when needed

✅ **Smart caching**: Version lists cached for 7 days (configurable) to minimize overhead

✅ **No persistent tokens**: Credentials never live in your shell environment permanently

✅ **Delegates to ubi**: Uses ubi's proven release asset detection - no reimplementation needed

✅ **Minimal performance impact**: ~1 second overhead only on cache misses; instant on cache hits

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  User: mise install op-ubi:company/tool@1.2.3              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
         ┌────────────────────────────────┐
         │  Check version cache           │
         │  (7-day TTL by default)        │
         └────────────────────────────────┘
                          │
                ┌─────────┴─────────┐
                │                   │
           Cache HIT           Cache MISS
                │                   │
                │                   ▼
                │         ┌──────────────────────┐
                │         │  Retrieve token from │
                │         │  1Password CLI (~1s) │
                │         └──────────────────────┘
                │                   │
                │                   ▼
                │         ┌──────────────────────┐
                │         │  Query GitHub API    │
                │         │  for releases        │
                │         └──────────────────────┘
                │                   │
                │                   ▼
                │         ┌──────────────────────┐
                │         │  Cache version list  │
                │         │  for 7 days          │
                │         └──────────────────────┘
                │                   │
                └─────────┬─────────┘
                          │
                          ▼
         ┌────────────────────────────────┐
         │  Install via ubi               │
         │  (with token in subprocess)    │
         └────────────────────────────────┘
                          │
                          ▼
         ┌────────────────────────────────┐
         │  Tool installed & ready to use │
         └────────────────────────────────┘
```

## Prerequisites

1. **[mise](https://mise.jdx.dev/)** - The plugin manager itself
2. **[1Password CLI](https://developer.1password.com/docs/cli/)** (`op`) - For credential management

   ```bash
   mise install ubi:1Password/op
   ```

3. **[ubi](https://github.com/houseabsolute/ubi)** - Universal Binary Installer

   ```bash
   mise install ubi:houseabsolute/ubi
   ```

4. **GitHub token** stored in 1Password (see [Setup](#setup) below)

## Installation

### Option 1: Install from GitHub

```bash
mise plugin install op-ubi https://github.com/rnaveiras/mise-op-ubi.git
```

### Option 2: Local Development

```bash
git clone https://github.com/rnaveiras/mise-op-ubi.git
cd mise-op-ubi
mise plugin link op-ubi "$(pwd)"
```

## Setup

### 1. Store GitHub Token in 1Password

Create a GitHub personal access token with `repo` scope for private repository access:

1. Go to GitHub → Settings → Developer settings → Personal access tokens
2. Create new token (classic) with `repo` scope
3. Copy the generated token
4. Store in 1Password:
   - Create an item (e.g., "GitHub CLI" or "GitHub Private Repos")
   - Add a field named `token` with your GitHub token
   - Note the vault name (e.g., "Private")

### 2. Authenticate 1Password CLI

```bash
# Sign in with 1Password desktop app integration
op signin
```

### 3. Configure the Plugin

Set the 1Password reference path (format: `op://VaultName/ItemName/FieldName`):

```bash
# In your shell profile (~/.zshrc, ~/.bashrc, etc.)
export MISE_OP_UBI_GITHUB_TOKEN_REFERENCE="op://Private/GitHub-CLI/token"
```

Or in your mise configuration:

```toml
# ~/.config/mise/config.toml or .mise.toml
[env]
MISE_OP_UBI_GITHUB_TOKEN_REFERENCE = "op://Private/GitHub-CLI/token"
```

### 4. Install Tools from Private Repositories

```toml
# .mise.toml
[tools]
"op-ubi:yourcompany/private-cli" = "1.2.3"
"op-ubi:yourcompany/deploy-tool" = "latest"
```

```bash
mise install
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MISE_OP_UBI_GITHUB_TOKEN_REFERENCE` | (required) | 1Password reference path for GitHub token |
| `MISE_OP_UBI_CACHE_DAYS` | `7` | Number of days to cache version lists |
| `MISE_OP_UBI_FORCE_REFRESH` | `false` | Force cache refresh (bypass cache) |
| `MISE_OP_UBI_ACCOUNT` | - | Plugin-specific 1Password account name (overrides `OP_ACCOUNT`) |
| `OP_ACCOUNT` | - | 1Password account name (for users with multiple accounts) |

### Tool Specification Format

```
op-ubi:<owner>/<repo>@<version>
```

**Examples:**

- `op-ubi:yourcompany/cli@1.2.3` - Install exact version 1.2.3
- `op-ubi:yourcompany/cli@latest` - Install latest version
- `op-ubi:yourcompany/cli@1.2` - Install latest 1.2.x version

## Usage Examples

### Basic Tool Installation

```toml
# .mise.toml
[tools]
"op-ubi:mycompany/internal-cli" = "1.2.3"
```

```bash
mise install
internal-cli --version
```

### Multiple Tools with Custom Configuration

```toml
# .mise.toml
[tools]
"op-ubi:company/api-cli" = "2.1.5"
"op-ubi:company/deploy-tool" = "latest"
"op-ubi:company/dev-utils" = "0.5.0"

[env]
MISE_OP_UBI_GITHUB_TOKEN_REFERENCE = "op://Production/GitHub/deploy-token"
MISE_OP_UBI_CACHE_DAYS = "14"  # Cache for 2 weeks
```

### Force Cache Refresh

```bash
# When you need to check for new versions immediately
MISE_OP_UBI_FORCE_REFRESH=true mise install op-ubi:company/tool@latest
```

## Performance Characteristics

### First Installation (Cold Cache)

- **Duration**: ~2-3 seconds
- **Operations**: 1Password CLI (~1s) + GitHub API (~500ms) + ubi download/install
- **Cache**: Version list stored for 7 days

### Subsequent Operations (Warm Cache)

- **Duration**: ~100ms
- **Operations**: Cache read only, no external calls
- **Overhead**: Near zero

### Version Bump (Smart Invalidation)

- **Duration**: ~2-3 seconds
- **Operations**: Detects missing version in cache, auto-refreshes
- **Behavior**: Transparent to user

**Result**: For typical workflows with monthly releases and explicit versions, you experience the 1-second overhead approximately once per week per tool.

## Security Model

### What Gets Cached (Disk)

✅ Version lists (public information from GitHub releases)

✅ Timestamps for cache freshness checks

### What Never Gets Cached

❌ GitHub personal access tokens

❌ 1Password credentials

❌ Any authentication material

### Credential Lifecycle

1. User operation triggers version check or installation
2. Plugin calls `op read "op://path"` (1Password CLI)
3. Token retrieved from 1Password's encrypted storage
4. Token stored temporarily in process memory
5. Token passed to subprocess (curl or ubi) via environment
6. Subprocess completes, token destroyed with process
7. **No trace of token remains on disk**

### Trust Boundaries

- **1Password CLI**: Trusted for secure credential storage
- **Plugin code**: Trusted to handle credentials properly (open source, auditable)
- **ubi CLI**: Receives token via environment, uses for GitHub API
- **GitHub API**: Receives token for authentication
- **File system**: Only stores version lists (public data), never credentials

## Troubleshooting

### Error: "1Password CLI not authenticated"

**Cause**: 1Password CLI is not signed in.

**Solution**:

```bash
# Sign in with 1Password desktop app integration
op signin
```

### Error: "Failed to retrieve GitHub token from 1Password"

**Cause**: The token reference path doesn't exist or is incorrect.

**Solution**:

```bash
# Verify the path works
op read "op://Private/GitHub-CLI/token"

# If wrong, update the environment variable
export MISE_OP_UBI_GITHUB_TOKEN_REFERENCE="op://YourVault/YourItem/token"
```

### Error: "ubi CLI not found in PATH"

**Cause**: ubi is not installed.

**Solution**:

```bash
mise install ubi:houseabsolute/ubi
mise reshim
```

### Slow Performance on Every Command

**Symptom**: Every mise operation takes 1+ seconds.

**Cause**: Cache is not working properly.

**Debug**:

```bash
# Check cache directory exists
ls -lah ~/.cache/mise/op-ubi/

# Enable debug logging
export MISE_DEBUG=1
mise install op-ubi:owner/repo@version
```

### Multiple 1Password Accounts

**Issue**: You have multiple 1Password accounts and the CLI is using the wrong one.

**Solution**:

```bash
# Specify which account to use
export OP_ACCOUNT="work-account"

# Or use plugin-specific setting
export MISE_OP_UBI_ACCOUNT="work-account"
```

## Development

### Running Tests

```bash
cd mise-op-ubi
mise test
```

## Acknowledgments

- Built on [mise](https://github.com/jdx/mise) by [@jdx](https://github.com/jdx)
- Uses [ubi](https://github.com/houseabsolute/ubi) by [@houseabsolute](https://github.com/houseabsolute)
- Integrates with [1Password CLI](https://developer.1password.com/docs/cli/) by [1Password](https://1password.com)

---

**Note**: This plugin is designed for secure credential management in local development environments. The credential retrieval overhead (~1 second) is intentional and traded for security benefits.
