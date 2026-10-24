#!/usr/bin/env -S lune run

--[[

GenerateCompletions.exec

Generates shell completion scripts for the rbxstudio CLI.

[Usage] ./Scripts/GenerateCompletions.exec.luau [bash|zsh|fish|powershell]

--]]

const Commandline = require("@packages/Commandline")
const RbxstudioCommand = require("@rbxstudiocli/RbxstudioCommand")
const process = require("@lune/process")

const GenerateCompletions = {}

function GenerateCompletions.exec()
    print(Commandline.Completions.generate(RbxstudioCommand, process.args[1] or "zsh"))
end

GenerateCompletions.exec()
