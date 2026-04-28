#!/usr/bin/env -S lune run

--[[

BuildExecutable

Compiles the rbxstudio CLI to a standalone executable.

[Usage] ./Scripts/BuildExecutable.luau [target]

--]]

local Toolkit = require("@packages/Commandline").Toolkit
local process = require("@lune/process")

local function buildExecutable()
    -- Generate version modules (including Rojo version from rokit.toml)
    local result = process.exec("lune", { "run", "Scripts/GenerateVersion.luau" })
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

buildExecutable()
