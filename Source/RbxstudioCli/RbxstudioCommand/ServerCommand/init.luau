--[[

ServerCommand

Starts a local test server with optional test clients. Automatically
resolves the universe ID from the Roblox API. Useful for testing
multiplayer games locally without publishing.

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

-- Resolves the universe ID for a place ID using the public Roblox API
local function getUniverseId(placeId: string): string?
    local ok, response = pcall(net.request, {
        url = `https://apis.roblox.com/universes/v1/places/{placeId}/universe`,
        method = "GET",
    })

    if ok and response.ok then
        local success, data = pcall(serde.decode, "json", response.body)
        if success and data and data.universeId then
            return tostring(data.universeId)
        end
    end

    return nil
end

return Commandline.Command.new({
    Name = "server",
    Description = "Start a local test server for a published place.",
    Args = {
        Commandline.Arg.new({
            Name = "placeid",
            Description = "The place ID to run.",
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
        local players = flags.players and flags.players.Value or 0
        local port = flags.port and flags.port.Value or 0

        -- Resolve universe ID from the Roblox API
        local universeId = getUniverseId(placeId)
        if not universeId then
            print(Chalk.red(`Failed to resolve universe ID for place {Chalk.bold(placeId)}.`))
            process.exit(1)
        end

        local details = { `place {Chalk.dim(placeId)}` }
        if players > 0 then
            table.insert(details, `{Chalk.dim(tostring(players))} {if players == 1 then "player" else "players"}`)
        end
        print(`Starting Roblox Studio test server for {table.concat(details, ", ")}...`)

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
