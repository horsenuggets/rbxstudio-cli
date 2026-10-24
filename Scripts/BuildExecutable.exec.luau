#!/usr/bin/env -S lune run

--[[

BuildExecutable.exec

Compiles the rbxstudio CLI to a standalone executable.

[Usage] ./Scripts/BuildExecutable.exec.luau [target]

--]]

const Toolkit = require("@packages/Commandline").Toolkit
const process = require("@lune/process")

const BuildExecutable = {}

function BuildExecutable.exec()
    -- Generate version modules (including Rojo version from rokit.toml)
    const result = process.exec("lune", { "run", "Scripts/GenerateVersion.exec.luau" })
    if not result.ok then
        print("Failed to generate version modules.")
        print(result.stderr)
        process.exit(1)
    end
    print(result.stdout)

    Toolkit.build({
        Name = "rbxstudio",
        EntryPoint = "Source/RbxstudioCli",
        Target = process.args[1],
    })
end

BuildExecutable.exec()
