--[[

OpenCommand

Opens Roblox Studio with no document, showing the Start Page. This is the
simplest launch mode and equivalent to double-clicking the Studio icon.

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")

return Commandline.Command.new({
    Name = "open",
    Description = "Open Roblox Studio to the Start Page.",
    Flags = {
        Commandline.Flag.new({
            Name = "noplugins",
            Description = "Disable loading user plugins on startup.",
        }),
        Commandline.Flag.new({
            Name = "reset",
            Description = "Reset Studio layout and dock settings.",
        }),
    },
    Impl = function(_args, flags)
        print(Chalk.bold(Chalk.blueBright("Opening Roblox Studio...")))

        local studioArgs = {}

        if flags.noplugins and flags.noplugins.Value then
            table.insert(studioArgs, "-disableLoadUserPlugins")
        end

        if flags.reset and flags.reset.Value then
            table.insert(studioArgs, "-resetLayout")
        end

        StudioHelpers.launch(studioArgs)
    end,
})
