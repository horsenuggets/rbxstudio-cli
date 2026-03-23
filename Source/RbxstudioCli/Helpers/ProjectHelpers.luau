--[[

ProjectHelpers

Utilities for creating temporary Roblox place files using Rojo. Handles
generating minimal project JSON files and building them into .rbxl files that
Studio can open.

--]]

local Chalk = require("@packages/Chalk")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local t = require("@packages/t")

local ProjectHelpers = {}

local TEMPLATE_PROJECT = {
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

function ProjectHelpers.createTempPlace(name: string?): string
    assert(t.optional(t.string)(name))

    local placeName = name or "rbxstudio-temp"
    local tempDir = `{process.env.HOME}/.rbxstudio-cli/temp/{placeName}`

    if not fs.isDir(tempDir) then
        fs.writeDir(tempDir)
    end

    local projectPath = `{tempDir}/default.project.json`
    local outputPath = `{tempDir}/{placeName}.rbxl`

    -- Write the project JSON
    local project = table.clone(TEMPLATE_PROJECT)
    project.name = placeName

    fs.writeFile(projectPath, serde.encode("json", project, true))
    print(`Created project file at {Chalk.dim(projectPath)}`)

    -- Build the place file with Rojo
    local result = process.exec("rojo", {
        "build",
        projectPath,
        "--output",
        outputPath,
    })

    if not result.ok then
        print(Chalk.red("Failed to build place file with Rojo."))
        print(result.stderr)
        process.exit(1)
    end

    print(`Built place file at {Chalk.dim(outputPath)}`)
    return outputPath
end

return ProjectHelpers
