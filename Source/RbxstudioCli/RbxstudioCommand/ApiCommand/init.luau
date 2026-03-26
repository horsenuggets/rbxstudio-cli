--[[

ApiCommand

Dumps the Roblox Luau scripting API as JSON to a specified output file.
Launches Roblox Studio briefly to extract the API definitions.

--]]

local Colors = require("@rbxstudiocli/Helpers/Colors")
local Commandline = require("@packages/Commandline")
local StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")
local fs = require("@lune/fs")
local process = require("@lune/process")

return Commandline.Command.new({
    Name = "api",
    Description = "Dump the Luau scripting API as JSON.",
    Flags = {
        Commandline.Flag.new({
            Name = "force",
            Shorthand = "f",
            Description = "Overwrite the output file if it already exists.",
        }),
    },
    Args = {
        Commandline.Arg.new({
            Name = "output",
            Description = "Output file path for the API dump.",
            Type = "string",
            Required = false,
            Default = "api-dump.json",
        }),
    },
    Impl = function(args, flags)
        local output = args.output
        local force = flags.force and flags.force.Value

        if fs.isFile(output) and not force then
            print(Colors.error(`File {Colors.bold(output)} already exists. Use --force to overwrite.`))
            process.exit(1)
        end

        local outputDir = output:match("^(.*/)") or ""
        local outputFile = output:match("([^/]+)$") or output
        print(`Dumping Luau API to {Colors.path(outputDir)}{Colors.configFile(outputFile)}...`)

        StudioHelpers.launch({
            "-API",
            output,
        }, true)

        -- Wait for the output file to appear
        local timeout = 30
        local elapsed = 0
        while elapsed < timeout do
            if fs.isFile(output) then
                print(Colors.success("API dump complete."))
                return
            end
            task.wait(0.5)
            elapsed += 0.5
        end

        print(Colors.error(`API dump timed out after {timeout} {if timeout == 1 then "second" else "seconds"}.`))
        process.exit(1)
    end,
})
