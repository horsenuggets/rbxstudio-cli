--[[

StudioHelpers

Utilities for locating and launching Roblox Studio. Handles resolving the
Studio binary path per platform and spawning Studio as a detached process.

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

-- Launches Studio as a detached process so the CLI exits immediately
function StudioHelpers.launch(args: { string }?)
    assert(t.optional(t.array(t.string))(args))

    local studioArgs = args or {}

    local argParts = {}
    for _, arg in studioArgs do
        table.insert(argParts, Chalk.dim(arg))
    end

    if #argParts > 0 then
        print(`Launching with {table.concat(argParts, " ")}`)
    end

    if process.os == "macos" then
        -- Use "open -a" to launch as a macOS app, detached from terminal
        local openArgs = { "-a", STUDIO_PATHS.macos, "--args" }
        for _, arg in studioArgs do
            table.insert(openArgs, arg)
        end
        process.exec("open", openArgs, { stdio = "none" })
    elseif process.os == "windows" then
        -- Use "start" via cmd to launch detached on Windows
        local studioPath = StudioHelpers.getStudioPath()
        local cmdArgs = { "/c", "start", '""', studioPath }
        for _, arg in studioArgs do
            table.insert(cmdArgs, arg)
        end
        process.exec("cmd", cmdArgs, { stdio = "none" })
    else
        -- On Linux, use setsid or nohup to detach, falling back to
        -- direct execution
        local studioPath = StudioHelpers.getStudioPath()
        local shellArgs = { "-c", `"{studioPath}" {table.concat(studioArgs, " ")} &` }
        process.exec("sh", shellArgs, { stdio = "none" })
    end

    print(Chalk.bold(Chalk.greenBright("Roblox Studio launched.")))
end

return StudioHelpers
