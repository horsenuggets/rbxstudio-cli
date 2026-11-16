--[[

EditLauncher

Shared logic for launching Roblox Studio to edit a published place by place
ID. Used by both EditCommand and OpenCommand.

--]]

const Colors = require("@rbxstudiocli/Helpers/Colors")
const PlaceHelpers = require("@rbxstudiocli/Helpers/PlaceHelpers")
const StudioHelpers = require("@rbxstudiocli/Helpers/StudioHelpers")
const process = require("@lune/process")

export type Options = {
    PlaceId: string,
    Version: string?,
    ScriptPath: string?,
    Line: number?,
    NoPlugins: boolean?,
}

const EditLauncher = {}

function EditLauncher.launch(options: Options)
    assert(type(options) == "table")
    assert(type(options.PlaceId) == "string")

    const placeId = options.PlaceId
    const version = options.Version
    const scriptPath = options.ScriptPath
    const line = options.Line

    -- Resolve universe ID from the Roblox API
    const universeId = PlaceHelpers.getUniverseId(placeId)
    if not universeId then
        print(Colors.error(`Failed to resolve universe ID for place {Colors.bold(placeId)}.`))
        process.exit(1)
    end

    const task = if version then "EditPlaceRevision" else "EditPlace"

    const placeName = PlaceHelpers.getPlaceName(placeId)
    local placeDisplay = `place {Colors.numericId(placeId)}`
    if placeName then
        placeDisplay ..= ` ({Colors.projectName(placeName)})`
    end

    const details = { placeDisplay }
    if version then
        table.insert(details, `version {Colors.dim(tostring(version))}`)
    end
    if scriptPath then
        local scriptDetail = `script {Colors.dim(scriptPath)}`
        if line then
            scriptDetail ..= ` line {Colors.dim(tostring(line))}`
        end
        table.insert(details, scriptDetail)
    end

    print(`Opening {table.concat(details, ", ")}...`)

    const studioArgs = {
        "-task",
        task,
        "-placeId",
        placeId,
        "-universeId",
        universeId,
    }

    if version then
        table.insert(studioArgs, "-placeVersion")
        table.insert(studioArgs, tostring(version))
    end

    if scriptPath then
        table.insert(studioArgs, "-openScriptPath")
        table.insert(studioArgs, scriptPath)
    end

    if line then
        table.insert(studioArgs, "-startLine")
        table.insert(studioArgs, tostring(line))
        table.insert(studioArgs, "-endLine")
        table.insert(studioArgs, tostring(line))
    end

    if options.NoPlugins then
        table.insert(studioArgs, "-disableLoadUserPlugins")
    end

    StudioHelpers.launch(studioArgs)
end

return EditLauncher
