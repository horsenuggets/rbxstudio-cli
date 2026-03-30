--[[

FileLauncher

Shared logic for launching Roblox Studio with a local place file or Rojo
project. Used by both FileCommand and OpenCommand.

--]]

local Colors = require("@rbxstudiocli/Helpers/Colors")
local StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")
local fs = require("@lune/fs")
local process = require("@lune/process")

export type Options = {
    Path: string,
    NoPlugins: boolean?,
}

local FileLauncher = {}

function FileLauncher.launch(options: Options)
    assert(type(options) == "table")
    assert(type(options.Path) == "string")

    local filePath = options.Path

    if not fs.isFile(filePath) then
        print(Colors.error(`File not found {Colors.bold(filePath)}.`))
        process.exit(1)
    end

    local isProject = filePath:match("%.project%.json$")
    local isPlace = filePath:match("%.rbxlx?$")

    if not isProject and not isPlace then
        print(Colors.error("File must be a .rbxl, .rbxlx, or .project.json file."))
        process.exit(1)
    end

    local fileName = filePath:match("([^/]+)$") or filePath
    print(`Opening {Colors.projectName(fileName)}...`)

    local studioArgs = { "-task", "EditFile" }

    if isProject then
        table.insert(studioArgs, "-localProjectFile")
    else
        table.insert(studioArgs, "-localPlaceFile")
    end
    table.insert(studioArgs, filePath)

    if options.NoPlugins then
        table.insert(studioArgs, "-disableLoadUserPlugins")
    end

    StudioHelpers.launch(studioArgs)
end

return FileLauncher
