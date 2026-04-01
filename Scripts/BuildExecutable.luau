#!/usr/bin/env -S lune run

--[[

BuildExecutable

Compiles the rbxstudio CLI to a standalone executable.

[Usage] ./Scripts/BuildExecutable.luau [target]

--]]

local Toolkit = require("@packages/Commandline").Toolkit
local process = require("@lune/process")

local function buildExecutable()
    Toolkit.generateVersion({
        VersionFile = "VERSION",
        OutputPath = "Source/RbxstudioCli/RbxstudioCommand/__VERSION__.luau",
    })

    Toolkit.build({
        Name = "rbxstudio",
        EntryPoint = "Source/RbxstudioCli",
        Target = process.args[1],
    })
end

buildExecutable()
