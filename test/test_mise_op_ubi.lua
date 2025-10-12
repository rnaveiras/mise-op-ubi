-- test/test_mise_op_ubi.lua
-- Comprehensive test suite for mise-op-ubi plugin

-- Test framework utilities
local test_count = 0
local pass_count = 0
local fail_count = 0

-- Simple test assertion function
function assert_equal(actual, expected, message)
    test_count = test_count + 1
    if actual == expected then
        pass_count = pass_count + 1
        print("✓ " .. message)
        return true
    else
        fail_count = fail_count + 1
        print("✗ " .. message)
        print("  Expected: " .. tostring(expected))
        print("  Actual:   " .. tostring(actual))
        return false
    end
end

function assert_true(condition, message)
    return assert_equal(condition, true, message)
end

function assert_false(condition, message)
    return assert_equal(condition, false, message)
end

function assert_not_nil(value, message)
    test_count = test_count + 1
    if value ~= nil then
        pass_count = pass_count + 1
        print("✓ " .. message)
        return true
    else
        fail_count = fail_count + 1
        print("✗ " .. message)
        print("  Expected: non-nil value")
        print("  Actual:   nil")
        return false
    end
end

-- Test suite runner
function run_test_suite(name, tests)
    print("\n========================================")
    print("Test Suite: " .. name)
    print("========================================\n")

    for test_name, test_func in pairs(tests) do
        print("Running: " .. test_name)
        local success, error_msg = pcall(test_func)
        if not success then
            fail_count = fail_count + 1
            print("✗ " .. test_name .. " CRASHED")
            print("  Error: " .. tostring(error_msg))
        end
        print("")
    end
end

-- Mock implementations for testing without actual 1Password/GitHub access
local mock_cmd = {
    exec = function(command, options)
        -- Mock date command
        if command:match("^date %+%%s") then
            return tostring(os.time())
        end

        -- Mock mkdir
        if command:match("^mkdir") then
            return ""
        end

        -- Mock file existence check
        if command:match("^%[ %-f") then
            -- Simulate file exists
            return ""
        end

        -- Mock cat command for reading cache
        if command:match("^cat") then
            if command:match("timestamp") then
                return tostring(os.time())
            elseif command:match("versions%.json") then
                return '["1.0.0","1.1.0","1.2.0"]'
            end
        end

        -- Mock echo command for writing cache
        if command:match("^echo") then
            return ""
        end

        -- Mock which command
        if command:match("^which") then
            return "/usr/bin/op"
        end

        -- Mock op account list
        if command:match("^op account list") then
            return "account-info"
        end

        -- Mock op read
        if command:match("^op read") then
            return "ghp_mocktoken123456789"
        end

        -- Mock curl (GitHub API)
        if command:match("^curl") then
            return '[{"tag_name":"v1.0.0"},{"tag_name":"v1.1.0"},{"tag_name":"v1.2.0"}]'
        end

        -- Mock ubi
        if command:match("^ubi") then
            return "Installation successful"
        end

        -- Mock ls check for binaries
        if command:match("ls %-A") then
            return "binary-name"
        end

        return ""
    end,
}

local mock_json = {
    encode = function(data)
        -- Simple JSON encoding for testing
        if type(data) == "table" then
            local items = {}
            for _, v in ipairs(data) do
                table.insert(items, '"' .. tostring(v) .. '"')
            end
            return "[" .. table.concat(items, ",") .. "]"
        end
        return '"' .. tostring(data) .. '"'
    end,

    decode = function(json_str)
        -- Simple JSON parsing for testing
        if json_str == '["1.0.0","1.1.0","1.2.0"]' then
            return { "1.0.0", "1.1.0", "1.2.0" }
        elseif json_str:match("^%[") then
            -- Parse array
            local result = {}
            for item in json_str:gmatch('"([^"]+)"') do
                table.insert(result, item)
            end
            return result
        elseif json_str:match("^%{.*tag_name") then
            -- Parse GitHub API response
            return {
                { tag_name = "v1.0.0" },
                { tag_name = "v1.1.0" },
                { tag_name = "v1.2.0" },
            }
        end
        return {}
    end,
}

local mock_strings = {
    trim_space = function(str)
        return str:match("^%s*(.-)%s*$")
    end,

    trim_prefix = function(str, prefix)
        if str:sub(1, #prefix) == prefix then
            return str:sub(#prefix + 1)
        end
        return str
    end,
}

local mock_file = {
    join_path = function(...)
        local parts = { ... }
        return table.concat(parts, "/")
    end,
}

-- Override require for testing
local original_require = require
_G.require = function(module)
    if module == "cmd" then
        return mock_cmd
    elseif module == "json" then
        return mock_json
    elseif module == "strings" then
        return mock_strings
    elseif module == "file" then
        return mock_file
    end
    return original_require(module)
end

-- Tests for cache module
local cache_tests = {
    ["test_get_cache_dir"] = function()
        local cache = require("lib.cache")
        local cache_dir = cache.get_cache_dir()
        assert_not_nil(cache_dir, "Cache directory path should be returned")
        assert_true(cache_dir:match("mise"), "Cache directory should contain 'mise'")
        assert_true(cache_dir:match("op%-ubi"), "Cache directory should contain 'op-ubi'")
    end,

    ["test_get_cache_path"] = function()
        local cache = require("lib.cache")
        local path = cache.get_cache_path("owner/repo", "versions.json")
        assert_not_nil(path, "Cache path should be returned")
        assert_true(path:match("owner%-repo"), "Cache path should sanitize repo name")
        assert_true(path:match("versions%.json"), "Cache path should include filename")
    end,

    ["test_is_fresh_with_fresh_cache"] = function()
        local cache = require("lib.cache")
        -- Mock a timestamp from 1 hour ago
        local fresh = cache.is_fresh("/tmp/timestamp", 7)
        assert_true(fresh, "Cache from 1 hour ago should be fresh with 7 day window")
    end,

    ["test_write_and_read_json"] = function()
        local cache = require("lib.cache")
        local test_data = { "1.0.0", "1.1.0", "1.2.0" }
        cache.write_json("/tmp/test.json", test_data)
        local read_data = cache.read_json("/tmp/test.json")
        assert_not_nil(read_data, "Should read back written JSON data")
        assert_equal(#read_data, 3, "Should have 3 versions")
    end,
}

-- Tests for credentials module
local credentials_tests = {
    ["test_get_token_path_not_configured"] = function()
        -- Clear environment variable
        os.execute("unset MISE_OP_UBI_GITHUB_TOKEN_REFERENCE")
        local credentials = require("lib.credentials")
        local success = pcall(function()
            credentials.get_token_path()
        end)
        assert_false(success, "Should error when token reference not configured")
    end,

    ["test_get_token_path_from_env"] = function()
        os.execute("export MISE_OP_UBI_GITHUB_TOKEN_REFERENCE='op://Custom/Path/token'")
        local credentials = require("lib.credentials")
        local path = credentials.get_token_path()
        assert_true(path:match("Custom"), "Should use token path from environment")
    end,

    ["test_check_op_available"] = function()
        local credentials = require("lib.credentials")
        local available, err = credentials.check_op_available()
        assert_true(available, "1Password CLI should be available in mock")
        assert_equal(err, nil, "No error should be returned when available")
    end,

    ["test_get_github_token"] = function()
        local credentials = require("lib.credentials")
        local token = credentials.get_github_token()
        assert_not_nil(token, "GitHub token should be retrieved")
        assert_true(#token > 10, "Token should have reasonable length")
    end,
}

-- Tests for github module
local github_tests = {
    ["test_parse_versions"] = function()
        local github = require("lib.github")
        local json_response = '[{"tag_name":"v1.0.0"},{"tag_name":"v1.1.0"},{"tag_name":"v1.2.0"}]'
        local versions = github.parse_versions(json_response)
        assert_not_nil(versions, "Versions should be parsed")
        assert_equal(#versions, 3, "Should have 3 versions")
        assert_equal(versions[1], "1.0.0", "Should strip 'v' prefix from version")
    end,

    ["test_version_exists"] = function()
        local github = require("lib.github")
        local versions = { "1.0.0", "1.1.0", "1.2.0" }
        assert_true(github.version_exists(versions, "1.1.0"), "Should find existing version")
        assert_true(github.version_exists(versions, "v1.1.0"), "Should find version with 'v' prefix")
        assert_false(github.version_exists(versions, "2.0.0"), "Should not find non-existent version")
    end,

    ["test_fetch_releases"] = function()
        local github = require("lib.github")
        local json = github.fetch_releases("owner/repo", "mock-token")
        assert_not_nil(json, "Should fetch releases")
        assert_true(json:match("tag_name"), "Response should contain tag_name")
    end,
}

-- Integration tests for backend hooks
local integration_tests = {
    ["test_backend_list_versions_with_cache_hit"] = function()
        -- Load the plugin
        package.path = "../?.lua;" .. package.path
        dofile("../metadata.lua")
        dofile("../hooks/backend_list_versions.lua")

        local ctx = {
            tool = "owner/repo",  -- mise strips the backend prefix
            version = "1.1.0",
        }

        -- This should hit the cache (mocked to always exist)
        local result = PLUGIN:BackendListVersions(ctx)
        assert_not_nil(result, "Should return result")
        assert_not_nil(result.versions, "Should return versions array")
        assert_true(#result.versions > 0, "Should have at least one version")
    end,

    ["test_backend_install"] = function()
        package.path = "../?.lua;" .. package.path
        dofile("../metadata.lua")
        dofile("../hooks/backend_install.lua")

        local ctx = {
            tool = "owner/repo",  -- mise strips the backend prefix
            version = "1.2.0",
            install_path = "/tmp/test-install",
        }

        -- Should complete without error in mock environment
        local success, result = pcall(function()
            return PLUGIN:BackendInstall(ctx)
        end)
        assert_true(success, "Installation should succeed: " .. tostring(result))
    end,

    ["test_backend_exec_env"] = function()
        package.path = "../?.lua;" .. package.path
        dofile("../metadata.lua")
        dofile("../hooks/backend_exec_env.lua")

        local ctx = {
            install_path = "/opt/mise/installs/test-tool/1.0.0",
        }

        local result = PLUGIN:BackendExecEnv(ctx)
        assert_not_nil(result, "Should return result")
        assert_not_nil(result.env_vars, "Should return env_vars")
        assert_equal(#result.env_vars, 1, "Should have one env var (PATH)")
        assert_true(result.env_vars[1].value:match("/bin"), "PATH should include bin directory")
    end,
}

-- Run all test suites
run_test_suite("Cache Module Tests", cache_tests)
run_test_suite("Credentials Module Tests", credentials_tests)
run_test_suite("GitHub Module Tests", github_tests)
run_test_suite("Integration Tests", integration_tests)

-- Print summary
print("\n========================================")
print("Test Summary")
print("========================================")
print(string.format("Total Tests: %d", test_count))
print(string.format("Passed: %d", pass_count))
print(string.format("Failed: %d", fail_count))
print("========================================\n")

-- Exit with appropriate code
if fail_count > 0 then
    os.exit(1)
else
    os.exit(0)
end
