--[[

EditCommand

Opens a published Roblox place for editing by place ID. Automatically
resolves the universe ID from the Roblox API. Can optionally open a
specific revision or navigate to a script within the place.

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

-- Resolves the universe ID for a place ID using the public Roblox API
local function getUniverseId(placeId: string): string?
    local ok, response = pcall(net.request, {
        url = `https://apis.roblox.com/universes/v1/places/{placeId}/universe`,
        method = "GET",
    })

    if ok and response.ok then
        local success, data = pcall(serde.decode, "json", response.body)
        if success and data and data.universeId then
            return tostring(data.universeId)
        end
    end

    return nil
end

return Commandline.Command.new({
    Name = "edit",
    Description = "Edit a published place by place ID.",
    Args = {
        Commandline.Arg.new({
            Name = "placeid",
            Description = "The place ID to edit.",
            Type = "string",
        }),
    },
    Flags = {
        Commandline.Flag.new({
            Name = "version",
            Shorthand = "v",
            Description = "Open a specific place version (revision).",
            Type = "string",
        }),
        Commandline.Flag.new({
            Name = "script",
            Shorthand = "s",
            Description = "Script path to open (require-by-string format).",
            Type = "string",
        }),
        Commandline.Flag.new({
            Name = "line",
            Shorthand = "l",
            Description = "Line number to navigate to in the script.",
            Type = "int",
        }),
        Commandline.Flag.new({
            Name = "noplugins",
            Description = "Disable loading user plugins on startup.",
        }),
    },
    Impl = function(args, flags)
        local placeId = args.placeid
        local version = flags.version and flags.version.Value
        local scriptPath = flags.script and flags.script.Value
        local line = flags.line and flags.line.Value

        -- Resolve universe ID from the Roblox API
        local universeId = getUniverseId(placeId)
        if not universeId then
            print(Chalk.red(`Failed to resolve universe ID for place {Chalk.bold(placeId)}.`))
            process.exit(1)
        end

        local task = if version then "EditPlaceRevision" else "EditPlace"

        local details = { `place {Chalk.dim(placeId)}` }
        if version then
            table.insert(details, `version {Chalk.dim(tostring(version))}`)
        end
        if scriptPath then
            local scriptDetail = `script {Chalk.dim(scriptPath)}`
            if line then
                scriptDetail ..= ` line {Chalk.dim(tostring(line))}`
            end
            table.insert(details, scriptDetail)
        end

        print(`Editing {table.concat(details, ", ")}...`)

        local studioArgs = {
            "-task",
            task,
            "-placeId",
            placeId,
            "-universeId",
            universeId,
        }

        if version then
            table.insert(studioArgs, "-placeVersion")
            table.insert(studioArgs, tostring(version))
        end

        if scriptPath then
            table.insert(studioArgs, "-openScriptPath")
            table.insert(studioArgs, scriptPath)
        end

        if line then
            table.insert(studioArgs, "-startLine")
            table.insert(studioArgs, tostring(line))
            table.insert(studioArgs, "-endLine")
            table.insert(studioArgs, tostring(line))
        end

        if flags.noplugins and flags.noplugins.Value then
            table.insert(studioArgs, "-disableLoadUserPlugins")
        end

        StudioHelpers.launch(studioArgs)
    end,
})
