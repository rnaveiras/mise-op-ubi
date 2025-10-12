-- lib/github.lua
-- GitHub API utilities for fetching release information

local github = {}

-- Helper function to normalize version strings
-- Removes 'v' prefix if present (e.g., "v1.2.3" -> "1.2.3")
local function normalize_version(version)
    if version:sub(1, 1) == "v" then
        return version:sub(2)
    end
    return version
end

-- Query GitHub API for repository releases
-- repo: Repository in "owner/repo" format
-- token: GitHub personal access token
-- Returns: Raw JSON response from GitHub API
function github.fetch_releases(repo, token)
    local cmd = require("cmd")

    local api_url = "https://api.github.com/repos/" .. repo .. "/releases"

    -- Build curl command with authentication
    -- Using -sS for silent mode but show errors
    -- Accept header ensures we get v3 API format
    local curl_cmd = "curl -sS "
        .. "-H 'Authorization: token "
        .. token
        .. "' "
        .. "-H 'Accept: application/vnd.github.v3+json' "
        .. "'"
        .. api_url
        .. "'"

    local success, result = pcall(function()
        return cmd.exec(curl_cmd)
    end)

    if not success then
        error("Failed to query GitHub API: " .. tostring(result))
    end

    -- Check for API error responses
    if result:match('"message":%s*"API rate limit exceeded"') then
        error("GitHub API rate limit exceeded. Wait before retrying or use a token with higher limits.")
    end

    if result:match('"message":%s*"Bad credentials"') then
        error("GitHub authentication failed. Check that your token is valid and not expired.")
    end

    if result:match('"message":%s*"Not Found"') then
        error("Repository not found: " .. repo .. ". Check that the repository exists and your token has access to it.")
    end

    return result
end

-- Parse GitHub releases JSON and extract version list
-- json_str: Raw JSON response from GitHub API
-- Returns: Array of version strings
function github.parse_versions(json_str)
    local json = require("json")

    -- Parse JSON response
    local success, releases = pcall(function()
        return json.decode(json_str)
    end)

    if not success then
        error("Failed to parse GitHub API response as JSON: " .. tostring(releases))
    end

    -- Validate response is an array
    if type(releases) ~= "table" then
        error("GitHub API response is not a valid array")
    end

    local versions = {}

    -- Extract version from each release
    for _, release in ipairs(releases) do
        if release.tag_name then
            -- Remove 'v' prefix if present (e.g., "v1.2.3" -> "1.2.3")
            -- This normalizes versions for consistent comparison
            local version = normalize_version(release.tag_name)
            table.insert(versions, version)
        end
    end

    -- Validate we found at least one version
    if #versions == 0 then
        error("No versions found in GitHub releases for this repository")
    end

    return versions
end

-- Check if a specific version exists in the version list
-- versions: Array of version strings
-- target_version: Version to search for
-- Returns: true if version exists, false otherwise
function github.version_exists(versions, target_version)
    -- Normalize target version (remove 'v' prefix if present)
    local normalized_target = normalize_version(target_version)

    for _, version in ipairs(versions) do
        local normalized_version = normalize_version(version)
        if normalized_version == normalized_target then
            return true
        end
    end

    return false
end

-- Fetch and parse GitHub releases in one operation
-- This is the main entry point for getting version information
-- repo: Repository in "owner/repo" format
-- token: GitHub personal access token
-- Returns: Array of version strings
function github.get_versions(repo, token)
    local json_response = github.fetch_releases(repo, token)
    local versions = github.parse_versions(json_response)
    return versions
end

return github
