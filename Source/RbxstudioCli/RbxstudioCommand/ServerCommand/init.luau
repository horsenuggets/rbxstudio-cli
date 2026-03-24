--[[

ServerCommand

Starts a local test server with optional test clients. Useful for testing
multiplayer games locally without publishing.

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")

return Commandline.Command.new({
    Name = "server",
    Description = "Start a local test server for a published place.",
    Args = {
        Commandline.Arg.new({
            Name = "placeid",
            Description = "The place ID to run.",
            Type = "string",
        }),
        Commandline.Arg.new({
            Name = "universeid",
            Description = "The universe ID containing the place.",
            Type = "string",
        }),
    },
    Flags = {
        Commandline.Flag.new({
            Name = "players",
            Shorthand = "p",
            Description = "Number of test players to spawn (0-8).",
            Type = "int",
            Default = 0,
        }),
        Commandline.Flag.new({
            Name = "port",
            Description = "Local port for the server (0 for random).",
            Type = "int",
            Default = 0,
        }),
    },
    Impl = function(args, flags)
        local placeId = args.placeid
        local universeId = args.universeid
        local players = flags.players and flags.players.Value or 0
        local port = flags.port and flags.port.Value or 0

        local details = { `place {placeId}`, `universe {universeId}` }
        if players > 0 then
            table.insert(details, `{players} {if players == 1 then "player" else "players"}`)
        end
        print(`Starting test server for {table.concat(details, ", ")}...`)

        local studioArgs = {
            "-task",
            "StartServer",
            "-placeId",
            placeId,
            "-universeId",
            universeId,
            "-port",
            tostring(port),
            "-numTestServerPlayersUponStartup",
            tostring(players),
        }

        StudioHelpers.launch(studioArgs)
    end,
})
