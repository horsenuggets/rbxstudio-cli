--[[

NewCommand

Creates a new temporary place file from a Rojo template and opens it in Roblox
Studio. The place includes all standard Roblox services and has HttpService
enabled for Rojo connectivity.

--]]

const Colors = require("@rbxstudiocli/Helpers/Colors")
const Commandline = require("@packages/Commandline")
const ProjectHelpers = require("@rbxstudiocli/Helpers/ProjectHelpers")
const StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")

return Commandline.Command.new({
    Name = "new",
    Description = "Create a new temporary place and open it in Studio.",
    Args = {
        Commandline.Arg.new({
            Name = "name",
            Description = "Name for the temporary place. If omitted, a random name is generated.",
            Type = "string",
            Required = false,
        }),
    },
    Flags = {
        Commandline.Flag.new({
            Name = "noplugins",
            Description = "Disable loading user plugins on startup.",
        }),
    },
    Impl = function(args, flags)
        const name = args.name

        if name then
            print(`Creating new place {Colors.dim(name)}...`)
        else
            print("Creating new temporary place...")
        end

        const placePath = ProjectHelpers.createTempPlace(name)

        const studioArgs = {
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
