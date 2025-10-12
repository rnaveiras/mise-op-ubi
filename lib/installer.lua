-- lib/installer.lua
-- installation utilities for ubi-based tool installation

local installer = {}

-- format ubi CLI not found error message
-- returns: formatted error message string
function installer.format_ubi_not_found_error()
    return "\n"
        .. "ubi CLI not found in PATH\n"
        .. "\n"
        .. "ubi (Universal Binary Installer) is required for installation.\n"
        .. "\n"
        .. "To install ubi:\n"
        .. "  mise use ubi:houseabsolute/ubi\n"
        .. "\n"
        .. "Then try your command again."
end

-- format installation error message with context and troubleshooting steps
-- params:
--   repo: GitHub repository (owner/repo)
--   version: version that failed to install
--   error_msg: error message from ubi
-- returns: formatted error message string
function installer.format_install_error(repo, version, error_msg)
    return "\n"
        .. "ubi installation failed\n"
        .. "\n"
        .. "Tool: "
        .. repo
        .. "\n"
        .. "Version: "
        .. version
        .. "\n"
        .. "Error: "
        .. tostring(error_msg)
        .. "\n"
        .. "\n"
        .. "This could mean:\n"
        .. "  - The version doesn't exist in the repository\n"
        .. "  - The release doesn't have compatible binaries for your platform\n"
        .. "  - Your GitHub token doesn't have access to this repository"
end

-- format binary verification error message
-- params:
--   repo: GitHub repository (owner/repo)
--   bin_path: directory where binaries should be
--   version_tag: version tag that was installed
-- returns: formatted error message string
function installer.format_verification_error(repo, bin_path, version_tag)
    return "\n"
        .. "Installation completed but no binaries found\n"
        .. "\n"
        .. "ubi executed successfully but didn't place any files in:\n"
        .. "  "
        .. bin_path
        .. "\n"
        .. "\n"
        .. "This might indicate:\n"
        .. "  - The release has no binaries for your OS/architecture\n"
        .. "  - The release assets have an unexpected structure\n"
        .. "\n"
        .. "Check the release manually at:\n"
        .. "  https://github.com/"
        .. repo
        .. "/releases/tag/"
        .. version_tag
end

-- attempt ubi installation with a specific version tag
-- params:
--   repo: GitHub repository (owner/repo)
--   tag: version tag to install
--   bin_path: directory where binary should be placed
--   github_token: GitHub API token for authentication
-- returns: success (boolean), result (output or error), tag (version used)
function installer.try_ubi_install(repo, tag, bin_path, github_token)
    local cmd = require("cmd")

    local ubi_cmd = string.format("ubi --project '%s' --tag '%s' --in '%s'", repo, tag, bin_path)

    local success, result = pcall(function()
        return cmd.exec(ubi_cmd, {
            env = {
                GITHUB_TOKEN = github_token,
                -- pass through essential environment variables
                HOME = os.getenv("HOME"),
                PATH = os.getenv("PATH"),
                USER = os.getenv("USER"),
            },
        })
    end)

    return success, result, tag
end

return installer
