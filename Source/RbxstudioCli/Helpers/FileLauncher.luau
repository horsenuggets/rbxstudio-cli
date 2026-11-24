--[[

FileLauncher

Shared logic for launching Roblox Studio with a local place file or Rojo
project. Used by both FileCommand and OpenCommand.

--]]

const Colors = require("@rbxstudiocli/Helpers/Colors")
const Commandline = require("@packages/Commandline")
const StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")
const fs = require("@lune/fs")
const process = require("@lune/process")
const t = require("@packages/t")

export type Options = {
    Path: string,
    NoPlugins: boolean?
}

type Terminal = typeof(Commandline.Terminal.default())

const FileLauncher = {}

-- Names the file being opened. Only the file name is shown, whichever slash style the
-- path uses, and it always takes the Roblox path style.
function FileLauncher.openingMessage(terminal: Terminal, filePath: string): string
    assert(t.table(terminal))
    assert(t.string(filePath))

    return `Opening {terminal:RobloxPath(Commandline.Path.fileName(filePath))}...`
end

function FileLauncher.launch(options: Options)
    assert(type(options) == "table")
    assert(type(options.Path) == "string")

    const filePath = options.Path

    if not fs.isFile(filePath) then
        print(Colors.error(`File not found {Colors.bold(filePath)}.`))
        process.exit(1)
    end

    const isProject = filePath:match("%.project%.json$")
    const isPlace = filePath:match("%.rbxlx?$")

    if not isProject and not isPlace then
        print(Colors.error("File must be a .rbxl, .rbxlx, or .project.json file."))
        process.exit(1)
    end

    const terminal = Commandline.Terminal.default()
    terminal:Print(FileLauncher.openingMessage(terminal, filePath))

    const studioArgs = { "-task", "EditFile" }

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
