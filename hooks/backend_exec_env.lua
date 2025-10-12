-- hooks/backend_exec_env.lua
-- Backend hook for setting up the execution environment for installed tools
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendexecenv

-- This hook is called when mise needs to set up the environment for a tool
-- It's triggered:
-- - When activating mise in the shell (mise activate)
-- - When executing a tool via mise exec
-- - When mise generates shims for installed tools

-- The primary purpose is to add the tool's binaries to the PATH
-- so they can be executed normally
function PLUGIN:BackendExecEnv(ctx)
    local file = require("file")

    -- The tool's binaries are installed in the bin/ subdirectory
    -- of the installation path (created during BackendInstall)
    local bin_path = file.join_path(ctx.install_path, "bin")

    local env_vars = {
        -- Add tool's bin directory to PATH
        { key = "PATH", value = bin_path },
    }

    -- Return environment variables to be set when using this tool
    -- The PATH is the critical one - it tells the shell where to find executables
    return {
        env_vars = env_vars,
    }
end
