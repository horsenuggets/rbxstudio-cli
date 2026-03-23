--[[

EditCommand

Opens a published Roblox place for editing by place ID and universe ID. Can
optionally open a specific revision or navigate to a script within the place.

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")

return Commandline.Command.new({
    Name = "edit",
    Description = "Edit a published place by place ID.",
    Args = {
        Commandline.Arg.new({
            Name = "placeid",
            Description = "The place ID to edit.",
            Type = "string",
        }),
        Commandline.Arg.new({
            Name = "universeid",
            Description = "The universe ID containing the place.",
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
        local universeId = args.universeid
        local version = flags.version and flags.version.Value
        local scriptPath = flags.script and flags.script.Value
        local line = flags.line and flags.line.Value

        local task = if version then "EditPlaceRevision" else "EditPlace"

        print(Chalk.bold(Chalk.blueBright(`Editing place {placeId}...`)))
        print(`Universe ID is {Chalk.dim(universeId)}`)

        if version then
            print(`Version is {Chalk.dim(tostring(version))}`)
        end

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
            print(`Opening script at {Chalk.dim(scriptPath)}`)
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
