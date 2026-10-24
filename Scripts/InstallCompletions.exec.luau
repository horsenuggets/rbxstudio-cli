#!/usr/bin/env -S lune run

--[[

InstallCompletions.exec

Installs shell completion scripts for the rbxstudio CLI.

[Usage] ./Scripts/InstallCompletions.exec.luau [bash|zsh|fish|powershell]

--]]

const Commandline = require("@packages/Commandline")
const RbxstudioCommand = require("@rbxstudiocli/RbxstudioCommand")
const process = require("@lune/process")

const InstallCompletions = {}

function InstallCompletions.exec()
    Commandline.Toolkit.installCompletions({
        Command = RbxstudioCommand,
        Shell = process.args[1] or "zsh",
    })
end

InstallCompletions.exec()
