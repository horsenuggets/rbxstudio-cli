--[[

PluginCommand

Opens the plugin installation page for a given plugin ID in Roblox Studio.

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")

return Commandline.Command.new({
    Name = "plugin",
    Description = "Install a plugin by plugin ID.",
    Args = {
        Commandline.Arg.new({
            Name = "pluginid",
            Description = "The plugin ID to install.",
            Type = "string",
        }),
    },
    Impl = function(args, _flags)
        local pluginId = args.pluginid

        print(`Installing plugin {Chalk.dim(pluginId)}...`)

        StudioHelpers.launch({
            "-task",
            "InstallPlugin",
            "-pluginId",
            pluginId,
        })
    end,
})
