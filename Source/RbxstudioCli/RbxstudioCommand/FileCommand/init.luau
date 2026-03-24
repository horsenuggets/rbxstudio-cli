--[[

FileCommand

Opens a local .rbxl or .rbxlx place file in Roblox Studio. Also supports
opening Rojo project files directly.

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")
local fs = require("@lune/fs")
local process = require("@lune/process")

return Commandline.Command.new({
    Name = "file",
    Description = "Open a local place file (.rbxl/.rbxlx) or Rojo project.",
    Args = {
        Commandline.Arg.new({
            Name = "path",
            Description = "Path to the place file or Rojo project file.",
            Type = "string",
        }),
    },
    Flags = {
        Commandline.Flag.new({
            Name = "noplugins",
            Description = "Disable loading user plugins on startup.",
        }),
    },
    Impl = function(args, flags)
        local filePath = args.path

        if not fs.isFile(filePath) then
            print(Chalk.red(`File not found "{filePath}".`))
            process.exit(1)
        end

        local isProject = filePath:match("%.project%.json$")
        local isPlace = filePath:match("%.rbxlx?$")

        if not isProject and not isPlace then
            print(Chalk.red("File must be a .rbxl, .rbxlx, or .project.json file."))
            process.exit(1)
        end

        print(`Opening "{filePath}"...`)

        local studioArgs = { "-task", "EditFile" }

        if isProject then
            table.insert(studioArgs, "-localProjectFile")
        else
            table.insert(studioArgs, "-localPlaceFile")
        end
        table.insert(studioArgs, filePath)

        if flags.noplugins and flags.noplugins.Value then
            table.insert(studioArgs, "-disableLoadUserPlugins")
        end

        StudioHelpers.launch(studioArgs)
    end,
})
