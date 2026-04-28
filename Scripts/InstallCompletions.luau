#!/usr/bin/env -S lune run

--[[

InstallCompletions

Installs shell completion scripts for the rbxstudio CLI.

--]]

local Commandline = require("@packages/Commandline")
local RbxstudioCommand = require("@rbxstudiocli/RbxstudioCommand")
local process = require("@lune/process")

Commandline.Toolkit.installCompletions({
    Command = RbxstudioCommand,
    Shell = process.args[1] or "zsh",
})
