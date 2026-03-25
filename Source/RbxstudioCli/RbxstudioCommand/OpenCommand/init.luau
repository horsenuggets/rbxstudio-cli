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
        local details = {}
        local studioArgs = {}

        if flags.noplugins and flags.noplugins.Value then
            table.insert(studioArgs, "-disableLoadUserPlugins")
            table.insert(details, "plugins disabled")
        end

        if flags.reset and flags.reset.Value then
            table.insert(studioArgs, "-resetLayout")
            table.insert(details, "layout reset")
        end

        local suffix = if #details > 0 then ` ({Chalk.dim(table.concat(details, ", "))})` else ""
        print(`Opening Roblox Studio{suffix}...`)

        StudioHelpers.launch(studioArgs)
    end,
})
