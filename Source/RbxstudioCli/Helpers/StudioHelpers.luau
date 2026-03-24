--[[

StudioHelpers

Utilities for locating and launching Roblox Studio on macOS. Handles resolving
the Studio binary path and spawning Studio processes with CLI arguments.

--]]

local Chalk = require("@packages/Chalk")
local fs = require("@lune/fs")
local process = require("@lune/process")
local t = require("@packages/t")

local STUDIO_APP_PATH = "/Applications/RobloxStudio.app"
local STUDIO_BINARY_PATH = `{STUDIO_APP_PATH}/Contents/MacOS/RobloxStudio`

local StudioHelpers = {}

function StudioHelpers.getStudioPath(): string
    if not fs.isFile(STUDIO_BINARY_PATH) then
        print(Chalk.red("Roblox Studio not found at the expected path."))
        print(Chalk.dim(STUDIO_BINARY_PATH))
        process.exit(1)
    end
    return STUDIO_BINARY_PATH
end

function StudioHelpers.launch(args: { string }?)
    assert(t.optional(t.array(t.string))(args))

    local studioPath = StudioHelpers.getStudioPath()
    local studioArgs = args or {}

    local argParts = {}
    for _, arg in studioArgs do
        table.insert(argParts, Chalk.dim(arg))
    end

    if #argParts > 0 then
        print(`Launching with {table.concat(argParts, " ")}`)
    end

    -- Use "open -a" to launch Studio as an app, detached from the terminal,
    -- so the CLI exits immediately without waiting for Studio to close
    local openArgs = { "-a", STUDIO_APP_PATH, "--args" }
    for _, arg in studioArgs do
        table.insert(openArgs, arg)
    end
    process.exec("open", openArgs, { stdio = "none" })

    print(Chalk.bold(Chalk.greenBright("Roblox Studio launched.")))
end

return StudioHelpers
