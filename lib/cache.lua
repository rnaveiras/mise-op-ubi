-- lib/cache.lua
-- Caching utilities for version lists and timestamps

local cache = {}

-- Get the cache directory path for this plugin
-- Uses MISE_CACHE_DIR if set, otherwise falls back to platform defaults
function cache.get_cache_dir()
    local base_dir = os.getenv("MISE_CACHE_DIR")

    if not base_dir then
        local home = os.getenv("HOME")
        -- Platform-specific cache location
        if package.config:sub(1, 1) == "\\" then
            -- Windows
            base_dir = os.getenv("LOCALAPPDATA") .. "\\mise\\cache"
        elseif os.execute("uname -s | grep -q Darwin") == 0 then
            -- macOS
            base_dir = home .. "/Library/Caches/mise"
        else
            -- Linux and other Unix-like systems
            base_dir = home .. "/.cache/mise"
        end
    end

    return base_dir .. "/op-ubi"
end

-- Get the cache file path for a specific tool
-- tool_name: e.g., "owner/repo"
-- file_type: "versions.json" or "timestamp"
function cache.get_cache_path(tool_name, file_type)
    local cache_dir = cache.get_cache_dir()
    -- Replace slashes in tool name with dashes for safe filename
    local safe_name = tool_name:gsub("/", "-")
    return cache_dir .. "/" .. safe_name .. "-" .. file_type
end

-- Ensure cache directory exists
function cache.ensure_cache_dir()
    local cmd = require("cmd")
    local cache_dir = cache.get_cache_dir()

    -- Create directory with parents if needed
    local success = pcall(function()
        cmd.exec("mkdir -p '" .. cache_dir .. "'")
    end)

    if not success then
        error("Failed to create cache directory: " .. cache_dir)
    end
end

-- Check if cache is fresh based on timestamp file
-- timestamp_file: full path to timestamp file
-- max_age_days: maximum age in days before cache is stale
-- Returns: true if cache is fresh, false otherwise
function cache.is_fresh(timestamp_file, max_age_days)
    local cmd = require("cmd")

    -- Check if timestamp file exists
    local exists = pcall(function()
        cmd.exec("[ -f '" .. timestamp_file .. "' ]")
    end)

    if not exists then
        return false
    end

    -- Read timestamp
    local success, timestamp_str = pcall(function()
        return cmd.exec("cat '" .. timestamp_file .. "'")
    end)

    if not success then
        return false
    end

    -- Parse timestamp (Unix epoch seconds)
    -- Note: gsub returns (string, count), so we need to capture only the first value
    local cleaned_timestamp = timestamp_str:gsub("%s+", "")
    local cache_time = tonumber(cleaned_timestamp)
    if not cache_time then
        return false
    end

    -- Get current time
    local current_time_str = cmd.exec("date +%s")
    local cleaned_current = current_time_str:gsub("%s+", "")
    local current_time = tonumber(cleaned_current)

    if not current_time then
        return false
    end

    -- Check if cache age is within acceptable range
    local age_seconds = current_time - cache_time
    local max_age_seconds = max_age_days * 86400

    return age_seconds < max_age_seconds
end

-- Read cache file and parse as JSON
-- cache_file: full path to cache file
-- Returns: parsed JSON data or nil if failed
function cache.read_json(cache_file)
    local cmd = require("cmd")
    local json = require("json")

    -- Check if file exists
    local exists = pcall(function()
        cmd.exec("[ -f '" .. cache_file .. "' ]")
    end)

    if not exists then
        return nil
    end

    -- Read file content
    local success, content = pcall(function()
        return cmd.exec("cat '" .. cache_file .. "'")
    end)

    if not success then
        return nil
    end

    -- Parse JSON
    local parse_success, data = pcall(function()
        return json.decode(content)
    end)

    if not parse_success then
        return nil
    end

    return data
end

-- Write data to cache file as JSON
-- cache_file: full path to cache file
-- data: data to serialize as JSON
function cache.write_json(cache_file, data)
    local cmd = require("cmd")
    local json = require("json")

    cache.ensure_cache_dir()

    -- Serialize to JSON
    local json_str = json.encode(data)

    -- Escape single quotes for shell command
    json_str = json_str:gsub("'", "'\\''")

    -- Write to file
    cmd.exec("echo '" .. json_str .. "' > '" .. cache_file .. "'")
end

-- Write current timestamp to file
-- timestamp_file: full path to timestamp file
function cache.write_timestamp(timestamp_file)
    local cmd = require("cmd")

    cache.ensure_cache_dir()

    -- Get current Unix timestamp
    local timestamp = cmd.exec("date +%s")

    -- Write to file
    cmd.exec("echo '" .. timestamp:gsub("%s+", "") .. "' > '" .. timestamp_file .. "'")
end

-- Invalidate cache for a specific tool
-- Removes both version list and timestamp files
function cache.invalidate(tool_name)
    local cmd = require("cmd")

    local versions_file = cache.get_cache_path(tool_name, "versions.json")
    local timestamp_file = cache.get_cache_path(tool_name, "timestamp")

    pcall(function()
        cmd.exec("rm -f '" .. versions_file .. "' '" .. timestamp_file .. "'")
    end)
end

return cache
