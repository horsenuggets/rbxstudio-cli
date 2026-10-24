--[[

ProjectHelpers

Utilities for creating temporary Roblox place files using Rojo. Handles
generating minimal project JSON files and building them into .rbxl files
that Studio can open.

--]]

const Colors = require("@rbxstudiocli/Helpers/Colors")
const RojoHelpers = require("@rbxstudiocli/Helpers/RojoHelpers")
const fs = require("@lune/fs")
const process = require("@lune/process")
const serde = require("@lune/serde")
const t = require("@packages/t")

const HOME = process.env.HOME or ""

const ProjectHelpers = {}

-- Replaces the home directory prefix with ~ for display
function ProjectHelpers.tildify(path: string): string
    if HOME ~= "" and path:sub(1, #HOME) == HOME then
        return "~" .. path:sub(#HOME + 1)
    end
    return path
end

const TEMPLATE_PROJECT = {
    name = "rbxstudio-temp",
    tree = {
        ["$className"] = "DataModel",
        HttpService = {
            ["$className"] = "HttpService",
            ["$properties"] = {
                HttpEnabled = true,
            },
        },
        Lighting = {
            ["$className"] = "Lighting",
            ["$properties"] = {
                Technology = "ShadowMap",
            },
        },
        ReplicatedFirst = {
            ["$className"] = "ReplicatedFirst",
        },
        ReplicatedStorage = {
            ["$className"] = "ReplicatedStorage",
        },
        ServerScriptService = {
            ["$className"] = "ServerScriptService",
        },
        ServerStorage = {
            ["$className"] = "ServerStorage",
        },
        SoundService = {
            ["$className"] = "SoundService",
        },
        StarterGui = {
            ["$className"] = "StarterGui",
        },
        StarterPack = {
            ["$className"] = "StarterPack",
        },
        StarterPlayer = {
            ["$className"] = "StarterPlayer",
        },
        Workspace = {
            ["$className"] = "Workspace",
        },
    },
}

-- Generates a short random hex ID (8 hex characters)
function ProjectHelpers.generateHexId(): string
    const parts = {}
    for _ = 1, 4 do
        table.insert(parts, string.format("%02x", math.random(0, 255)))
    end
    return table.concat(parts)
end

function ProjectHelpers.createTempPlace(name: string?): string
    assert(t.optional(t.string)(name))

    const placeName = name or `temp-{ProjectHelpers.generateHexId()}`
    const tempDir = `{process.env.HOME}/.rbxstudio-cli/temp/{placeName}`

    if fs.isDir(tempDir) then
        if name then
            print(Colors.error(`Place {Colors.bold(name)} already exists.`))
            process.exit(1)
        end
    else
        fs.writeDir(tempDir)
    end

    -- Write a timestamp file for auto-cleanup
    fs.writeFile(`{tempDir}/.created`, tostring(os.time()))

    const projectPath = `{tempDir}/default.project.json`
    const outputPath = `{tempDir}/{placeName}.rbxl`

    -- Write the project JSON
    const project = table.clone(TEMPLATE_PROJECT)
    project.name = placeName

    fs.writeFile(projectPath, serde.encode("json", project, true))
    const displayPath = ProjectHelpers.tildify(projectPath)
    const projectDir = displayPath:match("^(.*/)") or ""
    const projectFile = displayPath:match("([^/]+)$") or displayPath
    print(`Created project at {Colors.path(projectDir)}{Colors.projectName(projectFile)}.`)

    -- Build the place file with Rojo
    const rojoBin = RojoHelpers.resolveRojo()
    const result = process.exec(rojoBin, {
        "build",
        projectPath,
        "--output",
        outputPath,
    })

    if not result.ok then
        print(Colors.error("Failed to build place file with Rojo."))
        print(result.stderr)
        process.exit(1)
    end

    const displayOutput = ProjectHelpers.tildify(outputPath)
    const outputDir = displayOutput:match("^(.*/)") or ""
    const outputFile = displayOutput:match("([^/]+)$") or displayOutput
    print(`Built place at {Colors.path(outputDir)}{Colors.projectName(outputFile)}.`)
    return outputPath
end

return ProjectHelpers
