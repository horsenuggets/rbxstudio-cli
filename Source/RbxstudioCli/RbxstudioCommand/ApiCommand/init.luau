--[[

ApiCommand

Dumps the Roblox Luau scripting API as JSON to a specified output file.
Launches Roblox Studio briefly to extract the API definitions.

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")
local fs = require("@lune/fs")
local process = require("@lune/process")

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

        -- Wait for the output file to appear
        local timeout = 30
        local elapsed = 0
        while elapsed < timeout do
            if fs.isFile(output) then
                print(Chalk.greenBright("API dump complete."))
                return
            end
            task.wait(0.5)
            elapsed += 0.5
        end

        print(Chalk.red(`API dump timed out after {timeout} {if timeout == 1 then "second" else "seconds"}.`))
        process.exit(1)
    end,
})
