--[[

CleanCommand

Removes temporary place files created by the "new" command. Can remove
a specific place by name or all temporary places at once.

--]]

local Colors = require("@rbxstudiocli/Helpers/Colors")
local Commandline = require("@packages/Commandline")
local fs = require("@lune/fs")
local process = require("@lune/process")

local TEMP_DIR = (process.env.HOME or "") .. "/.rbxstudio-cli/temp"

return Commandline.Command.new({
    Name = "clean",
    Description = "Remove temporary place files.",
    Args = {
        Commandline.Arg.new({
            Name = "name",
            Description = 'Name of the place to remove, or "all" to remove all.',
            Type = "string",
            Required = false,
        }),
    },
    Impl = function(args, _flags)
        if not fs.isDir(TEMP_DIR) then
            print("No temporary places found.")
            return
        end

        local target = args.name

        if target and target ~= "all" then
            -- Remove a specific place
            local placePath = TEMP_DIR .. "/" .. target
            if not fs.isDir(placePath) then
                print(Colors.error(`Place {Colors.bold(target)} not found.`))
                process.exit(1)
            end
            fs.removeDir(placePath)
            print(`Removed {Colors.fileName(target)}.`)
            return
        end

        -- Remove all or list what would be removed
        local entries = fs.readDir(TEMP_DIR)
        if #entries == 0 then
            print("No temporary places found.")
            return
        end

        if target ~= "all" then
            -- No argument — list places and ask
            print(`Found {Colors.count(tostring(#entries))} temporary {if #entries == 1 then "place" else "places"}.`)
            print()
            for _, entry in entries do
                print(`  {Colors.fileName(entry)}`)
            end
            print()
            print(Colors.dim('Run "rbxstudio clean all" to remove all, or "rbxstudio clean <name>" to remove one.'))
            return
        end

        -- Remove all
        for _, entry in entries do
            local entryPath = TEMP_DIR .. "/" .. entry
            if fs.isDir(entryPath) then
                fs.removeDir(entryPath)
            end
        end
        print(`Removed {Colors.count(tostring(#entries))} temporary {if #entries == 1 then "place" else "places"}.`)
    end,
})
