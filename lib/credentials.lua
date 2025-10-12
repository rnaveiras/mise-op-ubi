-- lib/credentials.lua
-- 1Password CLI integration for secure credential retrieval

local credentials = {}

-- get the configured 1Password reference path for the GitHub token
-- returns: The op:// reference path string
-- raises error if not configured
function credentials.get_token_path()
    local token_path = os.getenv("MISE_OP_UBI_GITHUB_TOKEN_REFERENCE")

    if not token_path then
        error(
            "\n"
                .. "GitHub token reference not configured\n"
                .. "\n"
                .. "Please set your 1Password reference path:\n"
                .. "  export MISE_OP_UBI_GITHUB_TOKEN_REFERENCE='op://YourVault/YourItem/field'\n"
                .. "\n"
                .. "Example:\n"
                .. "  export MISE_OP_UBI_GITHUB_TOKEN_REFERENCE='op://Production/GitHub/token'\n"
                .. "\n"
                .. "Or in mise.toml:\n"
                .. "  [env]\n"
                .. '  MISE_OP_UBI_GITHUB_TOKEN_REFERENCE = "op://Production/GitHub/token"'
        )
    end

    return token_path
end

-- get the configured 1Password account name
-- returns: Account name string or nil if not specified
function credentials.get_account()
    -- check for plugin-specific setting first (takes priority)
    local account = os.getenv("MISE_OP_UBI_ACCOUNT")

    -- fall back to standard 1Password CLI variable
    if not account then
        account = os.getenv("OP_ACCOUNT")
    end

    return account
end

-- check if 1Password CLI is available and authenticated
-- returns: true if available and authenticated, false otherwise
-- also returns error message as second return value if check fails
function credentials.check_op_available()
    local cmd = require("cmd")

    -- Check if op command exists
    local success = pcall(function()
        cmd.exec("which op > /dev/null 2>&1")
    end)

    if not success then
        return false, "1Password CLI (op) not found in PATH. Install it with: mise install ubi:1Password/op"
    end

    -- build account list command with optional account specification
    local account = credentials.get_account()
    local account_flag = ""
    if account then
        account_flag = " --account '" .. account .. "'"
    end

    -- check if authenticated by trying to list accounts
    -- use || true to capture output even on failure
    local result = cmd.exec("op account list" .. account_flag .. " 2>&1 || true")

    -- Check if the command succeeded
    if result:match("ERROR") or result:match("error") or result:match("not signed in") then
        local err_msg = "1Password CLI not authenticated. Run 'op signin'"
        if account then
            err_msg = err_msg .. " --account '" .. account .. "'"
        end
        err_msg = err_msg .. " or set OP_SERVICE_ACCOUNT_TOKEN"
        return false, err_msg
    end

    return true, nil
end

-- Retrieve GitHub token from 1Password
-- This is the operation that incurs the ~1 second overhead
-- Returns: GitHub token string (trimmed of whitespace)
-- Raises error if retrieval fails
function credentials.get_github_token()
    local cmd = require("cmd")
    local strings = require("strings")

    -- First verify 1Password CLI is available and authenticated
    local available, err_msg = credentials.check_op_available()
    if not available then
        error(err_msg)
    end

    local token_path = credentials.get_token_path()
    local account = credentials.get_account()

    -- Build the op read command with optional account specification
    local account_flag = ""
    if account then
        account_flag = " --account '" .. account .. "'"
    end

    -- Attempt to read the token from 1Password
    -- This command typically takes 500ms-2s depending on:
    -- - Whether biometric unlock is needed
    -- - Network latency to 1Password servers
    -- - Local cache state
    --
    -- We need to capture output even on failure, so we use shell logic
    -- to always exit with success and capture the exit code separately
    local op_cmd = "op read" .. account_flag .. " '" .. token_path .. "' 2>&1 || true"
    local result = cmd.exec(op_cmd)

    -- Check for common error patterns in the output
    if result:match("ERROR") or result:match("isn't an item") or result:match("not found") or result:match("error") then
        -- Build helpful error message
        local account_info = ""
        if account then
            account_info = "\nAccount: " .. account
        end
        error(
            "Failed to retrieve GitHub token from 1Password. "
                .. "Check that '"
                .. token_path
                .. "' exists and is accessible."
                .. account_info
                .. "\n\nError from 1Password CLI:\n"
                .. result
        )
    end

    -- Trim whitespace from token
    local token = strings.trim_space(result)

    -- Basic validation - GitHub tokens should be non-empty and reasonably long
    if not token or #token < 10 then
        error("Retrieved token from 1Password is invalid or empty. Path: " .. token_path)
    end

    return token
end

-- Retrieve GitHub token with user-friendly error handling
-- This wraps get_github_token with better error messages for common issues
-- Returns: GitHub token string or raises error with helpful message
function credentials.get_github_token_safe()
    local success, result = pcall(credentials.get_github_token)

    if success then
        return result
    end

    -- Enhance error message with troubleshooting hints
    local error_msg = tostring(result)

    if error_msg:match("not found in PATH") then
        error(
            "\n"
                .. "1Password CLI Error: op command not found\n"
                .. "\n"
                .. "To fix this:\n"
                .. "  1. Install 1Password CLI: mise install ubi:1Password/op\n"
                .. "  2. Reload your shell or run: mise reshim\n"
                .. "  3. Try your command again"
        )
    elseif error_msg:match("not authenticated") or error_msg:match("signin") then
        error(
            "\n"
                .. "1Password CLI Error: Not signed in\n"
                .. "\n"
                .. "To fix this:\n"
                .. "  Option A (Desktop app integration - recommended):\n"
                .. "    1. Install 1Password desktop app\n"
                .. "    2. Enable CLI integration in app settings\n"
                .. "    3. Run: op signin\n"
                .. "\n"
                .. "  Option B (Service account for automation):\n"
                .. "    1. Create service account in 1Password\n"
                .. "    2. Export token: export OP_SERVICE_ACCOUNT_TOKEN='your-token'\n"
                .. "    3. Try your command again"
        )
    elseif error_msg:match("isn't an item") or error_msg:match("not found") then
        local token_path = credentials.get_token_path()
        error(
            "\n"
                .. "1Password CLI Error: Token not found at configured path\n"
                .. "\n"
                .. "Current path: "
                .. token_path
                .. "\n"
                .. "\n"
                .. "To fix this:\n"
                .. "  1. Verify the token exists: op read '"
                .. token_path
                .. "'\n"
                .. "  2. If path is wrong, set: export MISE_OP_UBI_GITHUB_TOKEN_REFERENCE='op://Vault/Item/field'\n"
                .. "  3. If you have multiple accounts, set: export OP_ACCOUNT='your-account-name'\n"
                .. "  4. Create the token in 1Password if it doesn't exist"
        )
    else
        -- Generic error - pass through original message
        error(error_msg)
    end
end

return credentials
