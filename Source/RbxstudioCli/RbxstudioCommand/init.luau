--[[

RbxstudioCommand

The root command for the rbxstudio CLI. Registers all subcommands for launching
and managing Roblox Studio sessions.

--]]

local ApiCommand = require("@self/ApiCommand")
local CleanCommand = require("@self/CleanCommand")
local Commandline = require("@packages/Commandline")
local EditCommand = require("@self/EditCommand")
local FileCommand = require("@self/FileCommand")
local KillCommand = require("@self/KillCommand")
local ListCommand = require("@self/ListCommand")
local NewCommand = require("@self/NewCommand")
local OpenCommand = require("@self/OpenCommand")
local PluginCommand = require("@self/PluginCommand")
local ServerCommand = require("@self/ServerCommand")
local __VERSION__ = require("@self/__VERSION__")

return Commandline.Command.new({
    Name = "rbxstudio",
    Description = "A feature-rich CLI for launching Roblox Studio with various configurations.",
    Version = __VERSION__,
    Subcommands = {
        ApiCommand,
        CleanCommand,
        EditCommand,
        FileCommand,
        KillCommand,
        ListCommand,
        NewCommand,
        OpenCommand,
        PluginCommand,
        ServerCommand,
    },
})
