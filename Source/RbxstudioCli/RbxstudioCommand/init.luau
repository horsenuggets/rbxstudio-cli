--[[

RbxstudioCommand

The root command for the rbxstudio CLI. Registers all subcommands for launching
and managing Roblox Studio sessions.

--]]

local ApiCommand = require("@self/ApiCommand")
local Commandline = require("@packages/Commandline")
local KillCommand = require("@self/KillCommand")
local ListCommand = require("@self/ListCommand")
local NewCommand = require("@self/NewCommand")
local OpenCommand = require("@self/OpenCommand")
local StartCommand = require("@self/StartCommand")
local __VERSION__ = require("@self/__VERSION__")

local INSTALL_OPTIONS = {
    Name = "rbxstudio",
    InstallDir = ".rbxstudio-cli",
    Version = __VERSION__,
    Repository = "horsenuggets/rbxstudio-cli",
}

return Commandline.Command.new({
    Name = "rbxstudio",
    Description = "A feature-rich CLI for launching Roblox Studio with various configurations.",
    Version = __VERSION__,
    Subcommands = {
        ApiCommand,
        Commandline.Toolkit.installCommand(INSTALL_OPTIONS),
        KillCommand,
        ListCommand,
        NewCommand,
        OpenCommand,
        StartCommand,
        Commandline.Toolkit.updateCommand(INSTALL_OPTIONS),
    },
})
