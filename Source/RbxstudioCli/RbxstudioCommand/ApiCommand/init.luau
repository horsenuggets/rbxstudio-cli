--[[

ApiCommand

Dumps the Roblox Luau scripting API as JSON to a specified output file.
Launches Roblox Studio briefly to extract the API definitions.

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")

return Commandline.Command.new({
    Name = "api",
    Description = "Dump the Luau scripting API as JSON.",
    Args = {
        Commandline.Arg.new({
            Name = "output",
            Description = "Output file path for the API dump.",
            Type = "string",
            Required = false,
            Default = "api-dump.json",
        }),
    },
    Impl = function(args, _flags)
        local output = args.output

        local outputDir = output:match("^(.*/)") or ""
        local outputFile = output:match("([^/]+)$") or output
        print(`Dumping Luau API to {Chalk.dim(outputDir)}{Chalk.yellow(outputFile)}...`)

        StudioHelpers.launch({
            "-API",
            output,
        }, true)
    end,
})
