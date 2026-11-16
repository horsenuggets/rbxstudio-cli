--[[

RbxstudioCommand

The root command for the rbxstudio CLI. Registers all subcommands for launching
and managing Roblox Studio sessions.

--]]

const ApiCommand = require("@self/ApiCommand")
const Commandline = require("@packages/Commandline")
const InstallCommand = require("@self/InstallCommand")
const KillCommand = require("@self/KillCommand")
const ListCommand = require("@self/ListCommand")
const NewCommand = require("@self/NewCommand")
const OpenCommand = require("@self/OpenCommand")
const StartCommand = require("@self/StartCommand")
const UpdateCommand = require("@self/UpdateCommand")
const __VERSION__ = require("@self/__VERSION__")

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
