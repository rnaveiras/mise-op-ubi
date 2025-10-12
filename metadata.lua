-- metadata.lua
-- Backend plugin metadata and configuration
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html

PLUGIN = { -- luacheck: ignore
    -- Required: Plugin name (will be the backend name users reference)
    name = "op-ubi",

    -- Required: Plugin version (not the tool versions)
    version = "1.0.0",

    -- Required: Brief description of the backend and tools it manages
    description = "A mise backend plugin that integrates 1Password CLI for secure credential management with ubi (Universal Binary Installer) for GitHub release installations.",

    -- Required: Plugin author/maintainer
    author = "rnaveiras",

    -- Optional: Plugin homepage/repository URL
    homepage = "https://github.com/rnaveiras/mise-op-ubi",

    -- Optional: Plugin license
    license = "MIT",

    -- Optional: Important notes for users
    notes = {
        -- "Requires <BACKEND> to be installed on your system",
        -- "This plugin manages tools from the <BACKEND> ecosystem"
    },

    -- Plugin supports these tool name patterns:
    -- op-ubi:owner/repo
    -- op-ubi:owner/repo@version
    tool_pattern = "^op%-ubi:",

    -- Default configuration values
    defaults = {
        -- 1Password reference path for GitHub token
        github_token_reference = nil,

        -- cache duration in days
        cache_days = 7,

        -- whether to force cache refresh
        force_refresh = false,
    },
}

-- Helper function to get configuration from environment with fallback to defaults
function PLUGIN:get_config(key)
    local env_var = "MISE_OP_UBI_" .. string.upper(key)
    local env_value = os.getenv(env_var)

    if env_value ~= nil then
        -- Convert string "true"/"false" to boolean for force_refresh
        if key == "force_refresh" then
            return env_value == "true" or env_value == "1"
        end
        -- Convert to number for cache_days
        if key == "cache_days" then
            return tonumber(env_value) or self.defaults[key]
        end
        return env_value
    end

    return self.defaults[key]
end
