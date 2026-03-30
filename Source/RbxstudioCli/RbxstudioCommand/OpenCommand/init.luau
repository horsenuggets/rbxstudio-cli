--[[

OpenCommand

Smart multi-target command that opens a place file or published place by ID.
Detects whether the target is a place ID (digits) or a file path, then
dispatches to the appropriate launcher.

--]]

local Colors = require("@rbxstudiocli/Helpers/Colors")
local Commandline = require("@packages/Commandline")
local EditLauncher = require("@rbxstudiocli/Helpers/EditLauncher")
local FileLauncher = require("@rbxstudiocli/Helpers/FileLauncher")
local classifyTarget = require("@self/classifyTarget")
local process = require("@lune/process")

return Commandline.Command.new({
    Name = "open",
    Description = "Open a place file or published place by ID.",
    Args = {
        Commandline.Arg.new({
            Name = "target",
            Description = "A file path or place ID.",
            Type = "string",
        }),
    },
    Flags = {
        Commandline.Flag.new({
            Name = "noplugins",
            Description = "Disable loading user plugins on startup.",
        }),
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
    },
    Impl = function(args, flags)
        local target = args.target
        local noPlugins = flags.noplugins and flags.noplugins.Value

        local classification, err = classifyTarget(target)
        if not classification then
            print(Colors.error(err :: string))
            process.exit(1)
        end

        if classification.Type == "placeid" then
            EditLauncher.launch({
                PlaceId = classification.Value,
                Version = flags.version and flags.version.Value,
                ScriptPath = flags.script and flags.script.Value,
                Line = flags.line and flags.line.Value,
                NoPlugins = noPlugins,
            })
        else
            FileLauncher.launch({
                Path = classification.Value,
                NoPlugins = noPlugins,
            })
        end
    end,
})
