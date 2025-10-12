-- hooks/backend_install.lua
-- Backend hook for installing tools via ubi with credentials from 1Password
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendinstall

-- This hook is called when mise needs to actually install a tool version
-- It's triggered by commands like:
-- - mise install (if the tool/version isn't already installed)
-- - mise use (if auto-install is enabled)

function PLUGIN:BackendInstall(ctx)
    -- Load required modules
    local cmd = require("cmd")
    local file = require("file")
    local credentials = require("lib.credentials")
    local installer = require("lib.installer")

    -- extract repository name from tool identifier
    -- NOTE: mise strips the backend prefix before calling this hook
    -- So ctx.tool is just "owner/repo", not "op-ubi:owner/repo"
    local repo = ctx.tool

    -- validate it looks like a GitHub repository path
    if not repo:match("^[^/]+/[^/]+$") then
        error("Invalid tool format. Expected 'owner/repo', got: " .. ctx.tool)
    end

    -- validate we have a version to install
    if not ctx.version then
        error("No version specified for installation")
    end

    -- Check if ubi CLI is available in PATH
    -- ubi is required for the actual installation logic
    local ubi_available = pcall(function()
        cmd.exec("which ubi > /dev/null 2>&1")
    end)

    if not ubi_available then
        error(installer.format_ubi_not_found_error())
    end

    -- retrieve GitHub token from 1Password, operation takes ~1 second
    -- NOTE: even if we just fetched versions (which also got the token),
    -- we need to get it again here because that was in a different hook invocation
    -- The token is never cached on disk per security reasons
    local github_token = credentials.get_github_token_safe()

    -- create the installation directory structure
    -- mise expects tools to have a bin/ subdirectory containing executables
    local bin_path = file.join_path(ctx.install_path, "bin")
    cmd.exec("mkdir -p '" .. bin_path .. "'")

    -- attempt installation with version tag
    -- GoReleaser and most GitHub releases use 'v' prefix (v1.2.3)
    -- Try with 'v' prefix first (common case), then without if that fails
    local success, result, version_tag = installer.try_ubi_install(repo, "v" .. ctx.version, bin_path, github_token)

    if not success then
        -- fallback: try without 'v' prefix for repos that don't use it
        success, result, version_tag = installer.try_ubi_install(repo, ctx.version, bin_path, github_token)
    end

    -- check if ubi succeeded
    if not success then
        error(installer.format_install_error(repo, ctx.version, result))
    end

    -- verify that installation actually created files in bin/
    -- This catches cases where ubi succeeded but didn't place any binaries
    local verify_cmd = "[ -d '" .. bin_path .. "' ] && [ -n \"$(ls -A '" .. bin_path .. "' 2>/dev/null)\" ]"
    local has_binaries = pcall(function()
        cmd.exec(verify_cmd)
    end)

    if not has_binaries then
        error(installer.format_verification_error(repo, bin_path, version_tag))
    end

    -- installation successful
    -- return empty table to indicate success to mise
    return {}
end
