--[[

StudioHelpers

Utilities for locating and launching Roblox Studio. Handles resolving the
Studio binary path per platform and spawning Studio as a detached process.
Throttles launches to prevent auth race conditions when multiple instances
start simultaneously.

--]]

local Chalk = require("@packages/Chalk")
local fs = require("@lune/fs")
local process = require("@lune/process")
local t = require("@packages/t")

local STUDIO_PATHS = {
    macos = "/Applications/RobloxStudio.app",
    windows = `{process.env.LOCALAPPDATA or ""}/Roblox/Versions`,
    linux = "/usr/bin/roblox-studio",
}

local LAUNCH_COOLDOWN = 5
local LOCKFILE_DIR = `{process.env.HOME}/.rbxstudio-cli`
local LOCKFILE_PATH = `{LOCKFILE_DIR}/last-launch`

local StudioHelpers = {}

-- Finds the Studio binary path for the current platform
function StudioHelpers.getStudioPath(): string
    if process.os == "macos" then
        local appPath = STUDIO_PATHS.macos
        local binaryPath = `{appPath}/Contents/MacOS/RobloxStudio`
        if not fs.isFile(binaryPath) then
            print(Chalk.red("Roblox Studio not found at the expected path."))
            print(Chalk.dim(binaryPath))
            process.exit(1)
        end
        return binaryPath
    elseif process.os == "windows" then
        -- Windows installs Studio in a versioned folder under
        -- %LOCALAPPDATA%/Roblox/Versions/<version>/RobloxStudioBeta.exe
        local versionsDir = STUDIO_PATHS.windows
        if fs.isDir(versionsDir) then
            for _, entry in fs.readDir(versionsDir) do
                local candidate = `{versionsDir}/{entry}/RobloxStudioBeta.exe`
                if fs.isFile(candidate) then
                    return candidate
                end
            end
        end
        print(Chalk.red("Roblox Studio not found."))
        print(Chalk.dim(versionsDir))
        process.exit(1)
        return "" -- unreachable, satisfies type checker
    else
        local binaryPath = STUDIO_PATHS.linux
        if not fs.isFile(binaryPath) then
            print(Chalk.red("Roblox Studio not found at the expected path."))
            print(Chalk.dim(binaryPath))
            process.exit(1)
        end
        return binaryPath
    end
end

-- Waits until the launch cooldown has elapsed since the last launch.
-- Uses flock to serialize concurrent CLI invocations so only one
-- Studio process starts at a time, preventing auth race conditions.
local function waitForCooldown()
    if not fs.isDir(LOCKFILE_DIR) then
        fs.writeDir(LOCKFILE_DIR)
    end

    -- Serialize launches using an atomic mkdir lock in a shell
    -- script. mkdir fails if the directory already exists, so only
    -- one process acquires the lock at a time. Others spin until
    -- they can acquire it.
    local lockDir = LOCKFILE_PATH .. ".lock"
    local cooldown = tostring(LAUNCH_COOLDOWN)

    -- Build the shell script with concatenation to avoid backtick
    -- interpolation issues with $ characters
    local lines = {
        "while ! mkdir " .. '"' .. lockDir .. '"' .. " 2>/dev/null; do",
        "  sleep 0.1",
        "done",
        'if [ -f "' .. LOCKFILE_PATH .. '" ]; then',
        '  last=$(cat "' .. LOCKFILE_PATH .. '" 2>/dev/null)',
        "  now=$(date +%s)",
        "  elapsed=$((now - last))",
        "  if [ $elapsed -lt " .. cooldown .. " ]; then",
        "    remaining=$((" .. cooldown .. " - elapsed))",
        '    echo "WAIT:$remaining"',
        "    sleep $remaining",
        "  fi",
        "fi",
        'date +%s > "' .. LOCKFILE_PATH .. '"',
        'rmdir "' .. lockDir .. '"',
    }
    local script = table.concat(lines, "\n")

    local result = process.exec("sh", { "-c", script })
    if result.ok and result.stdout:find("WAIT:") then
        local remaining = result.stdout:match("WAIT:(%d+)")
        if remaining then
            print(
                Chalk.dim(
                    `Waited {remaining} {if remaining == "1" then "second" else "seconds"} for previous Studio launch.`
                )
            )
        end
    end
end

-- Launches Studio as a detached process so the CLI exits immediately
function StudioHelpers.launch(args: { string }?)
    assert(t.optional(t.array(t.string))(args))

    local studioArgs = args or {}

    waitForCooldown()

    if process.os == "macos" then
        -- Launch the binary directly via sh so each invocation gets its
        -- own process with the correct arguments. "open -a" ignores args
        -- when Studio is already running.
        local studioPath = StudioHelpers.getStudioPath()
        local quoted = { `"{studioPath}"` }
        for _, arg in studioArgs do
            table.insert(quoted, `"{arg}"`)
        end
        process.exec("sh", {
            "-c",
            `{table.concat(quoted, " ")} &>/dev/null &`,
        }, { stdio = "none" })
    elseif process.os == "windows" then
        -- Use "start" via cmd to launch detached on Windows
        local studioPath = StudioHelpers.getStudioPath()
        local cmdArgs = { "/c", "start", '""', studioPath }
        for _, arg in studioArgs do
            table.insert(cmdArgs, arg)
        end
        process.exec("cmd", cmdArgs, { stdio = "none" })
    else
        -- On Linux, background the process via sh
        local studioPath = StudioHelpers.getStudioPath()
        local shellArgs = { "-c", `"{studioPath}" {table.concat(studioArgs, " ")} &` }
        process.exec("sh", shellArgs, { stdio = "none" })
    end

    print(Chalk.greenBright("Roblox Studio launched."))
end

return StudioHelpers
