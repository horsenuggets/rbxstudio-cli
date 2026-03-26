--[[

PluginCommand

Opens the Roblox marketplace page for a plugin so the user can
install it from the browser.

--]]

local Colors = require("@rbxstudiocli/Helpers/Colors")
local Commandline = require("@packages/Commandline")
local process = require("@lune/process")

return Commandline.Command.new({
    Name = "plugin",
    Description = "Open a plugin's marketplace page in the browser.",
    Args = {
        Commandline.Arg.new({
            Name = "pluginid",
            Description = "The plugin ID to view.",
            Type = "string",
        }),
    },
    Impl = function(args, _flags)
        local pluginId = args.pluginid
        local url = `https://create.roblox.com/store/asset/{pluginId}`

        print(`Opening plugin {Colors.numericId(pluginId)} in browser...`)

        if process.os == "macos" then
            process.exec("open", { url })
        elseif process.os == "windows" then
            process.exec("cmd", { "/c", "start", url })
        else
            process.exec("xdg-open", { url })
        end

        print(Colors.success("Opened in browser."))
    end,
})
