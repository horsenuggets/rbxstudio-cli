#!/usr/bin/env -S lune run

--[[

GenerateVersion.exec

Reads the VERSION file and generates version modules for embedding at build time.
Also extracts the Rojo version from rokit.toml so the CLI knows which version to
download during install/update.

[Usage] ./Scripts/GenerateVersion.exec.luau

--]]

const Toolkit = require("@packages/Commandline").Toolkit
const fs = require("@lune/fs")

const function extractRojoVersion(): string
    const content = fs.readFile("rokit.toml")
    const version = string.match(content, 'rojo%s*=%s*".-@([^"]+)"')
    assert(version, "Could not extract Rojo version from rokit.toml.")
    return version
end

const GenerateVersion = {}

function GenerateVersion.exec()
    Toolkit.generateVersion({
        VersionFile = "VERSION",
        OutputPath = "Source/RbxstudioCli/RbxstudioCommand/__VERSION__.luau",
    })

    -- Generate Rojo version module from rokit.toml
    const rojoVersion = extractRojoVersion()
    const rojoModule = '--[[\n\n__ROJO_VERSION__\n\nAuto-generated Rojo version module. Extracted from rokit.toml at build time.\n\n--]]\n\nreturn "'
        .. rojoVersion
        .. '"\n'
    fs.writeFile("Source/RbxstudioCli/RbxstudioCommand/__ROJO_VERSION__.luau", rojoModule)

    const Chalk = require("@packages/Chalk")
    print("Generated Rojo version module with version " .. Chalk.bold(Chalk.blueBright(rojoVersion)) .. ".")
end

GenerateVersion.exec()
