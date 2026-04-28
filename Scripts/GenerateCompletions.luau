#!/usr/bin/env -S lune run

--[[

GenerateCompletions

Generates shell completion scripts for the rbxstudio CLI.

--]]

local Commandline = require("@packages/Commandline")
local RbxstudioCommand = require("@rbxstudiocli/RbxstudioCommand")
local process = require("@lune/process")

local shell = process.args[1] or "zsh"
print(Commandline.Completions.generate(RbxstudioCommand, shell))
