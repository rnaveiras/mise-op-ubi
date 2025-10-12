-- hooks/backend_list_versions.lua
-- Backend hook for listing available versions with intelligent caching
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendlistversions

-- This hook is called when mise needs to know what versions are available
-- for a tool. It's triggered by commands like:
-- - mise install (to validate the requested version exists)
-- - mise outdated (to check for newer versions)
-- - mise ls-remote (to show all available versions)
-- - mise install tool@latest (to resolve what "latest" means)

function PLUGIN:BackendListVersions(ctx)
    -- Load required modules
    local cache = require("lib.cache")
    local credentials = require("lib.credentials")
    local github = require("lib.github")

    -- extract repository name from tool identifier
    -- NOTE: mise strips the backend prefix before calling this hook
    -- So ctx.tool is just "owner/repo", not "op-ubi:owner/repo"
    local repo = ctx.tool

    -- Validate it looks like a GitHub repository path
    if not repo:match("^[^/]+/[^/]+$") then
        error("nnvalid tool format. expected 'owner/repo', got: " .. ctx.tool)
    end

    -- get cache configuration
    local cache_days = self:get_config("cache_days")
    local force_refresh = self:get_config("force_refresh")

    -- set up cache file paths
    local cache_file = cache.get_cache_path(repo, "versions.json")
    local timestamp_file = cache.get_cache_path(repo, "timestamp")

    -- check if we should bypass cache (force refresh requested)
    if force_refresh then
        cache.invalidate(repo)
    end

    -- Try to use cached data if available and fresh
    local cache_is_fresh = cache.is_fresh(timestamp_file, cache_days)
    local cached_versions = nil

    if cache_is_fresh then
        cached_versions = cache.read_json(cache_file)
    end

    -- determine if we have a specific version requirement
    -- This happens when someone specifies an exact version in their mise.toml
    -- For example: "op-ubi:owner/repo" = "1.2.3"
    -- The ctx may contain version info in some scenarios
    local required_version = ctx.version or os.getenv("MISE_TOOL_VERSION")

    -- smart cache validation logic:
    -- If we have cached versions AND we have a specific version requirement,
    -- check if that version exists in the cache
    if cached_versions and required_version then
        -- check if the required version is in our cached list
        if github.version_exists(cached_versions, required_version) then
            -- cache hit - return cached data without any API calls
            -- this is the fast path that avoids 1Password CLI overhead
            return { versions = cached_versions }
        else
            -- cache miss - the required version isn't in our cache
            -- this can happen when:
            -- 1. A new version was just released and cache is stale
            -- 2. Someone specified a version that doesn't exist (will fail later)
            -- need to fetch fresh data, which will trigger credential retrieval
            cached_versions = nil -- force refresh
        end
    end

    -- if we have cached versions and no specific requirement (e.g., using "latest")
    -- we can still use the cache even if it might not include the absolute latest
    -- this is acceptable because our cache window is reasonable (7 days by default)
    if cached_versions and not required_version then
        return { versions = cached_versions }
    end

    -- cache miss or invalidated - need to fetch fresh data from GitHub
    -- This is where we incur the 1-second overhead from 1Password CLI

    -- retrieve GitHub token from 1Password
    -- NOTE: is the slow operation (~1 second)
    local github_token = credentials.get_github_token_safe()

    -- query GitHub API for releases
    -- This uses the token we just retrieved
    local versions = github.get_versions(repo, github_token)

    -- cache the results for future use
    -- this benefits all subsequent operations within the cache window
    cache.write_json(cache_file, versions)
    cache.write_timestamp(timestamp_file)

    -- return the version list to mise
    -- mise will use this to validate the requested version exists
    return { versions = versions }
end
