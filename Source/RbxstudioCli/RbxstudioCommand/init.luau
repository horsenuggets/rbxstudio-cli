--[[

RbxstudioCommand

The root command for the rbxstudio CLI. Registers all subcommands for launching
and managing Roblox Studio sessions.

--]]

local ApiCommand = require("@self/ApiCommand")
local Commandline = require("@packages/Commandline")
local InstallCommand = require("@self/InstallCommand")
local KillCommand = require("@self/KillCommand")
local ListCommand = require("@self/ListCommand")
local NewCommand = require("@self/NewCommand")
local OpenCommand = require("@self/OpenCommand")
local StartCommand = require("@self/StartCommand")
local UpdateCommand = require("@self/UpdateCommand")
local __VERSION__ = require("@self/__VERSION__")

return Commandline.Command.new({
    Name = "rbxstudio",
    Description = "A feature-rich CLI for launching Roblox Studio with various configurations.",
    Version = __VERSION__,
    Subcommands = {
        ApiCommand,
        InstallCommand,
        KillCommand,
        ListCommand,
        NewCommand,
        OpenCommand,
        StartCommand,
        UpdateCommand,
    },
})
