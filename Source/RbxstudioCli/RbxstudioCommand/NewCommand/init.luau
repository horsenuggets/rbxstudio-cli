--[[

NewCommand

Creates a new temporary place file from a Rojo template and opens it in Roblox
Studio. The place includes all standard Roblox services and has HttpService
enabled for Rojo connectivity.

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local ProjectHelpers = require("@rbxstudiocli/Helpers/ProjectHelpers")
local StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")

return Commandline.Command.new({
    Name = "new",
    Description = "Create a new temporary place and open it in Studio.",
    Args = {
        Commandline.Arg.new({
            Name = "name",
            Description = "Name for the temporary place.",
            Type = "string",
            Required = false,
            Default = "rbxstudio-temp",
        }),
    },
    Flags = {
        Commandline.Flag.new({
            Name = "noplugins",
            Description = "Disable loading user plugins on startup.",
        }),
    },
    Impl = function(args, flags)
        local name = args.name

        print(`Creating new place {Chalk.dim(name)}...`)

        local placePath = ProjectHelpers.createTempPlace(name)

        local studioArgs = {
            "-task",
            "EditFile",
            "-localPlaceFile",
            placePath,
        }

        if flags.noplugins and flags.noplugins.Value then
            table.insert(studioArgs, "-disableLoadUserPlugins")
        end

        StudioHelpers.launch(studioArgs)
    end,
})
