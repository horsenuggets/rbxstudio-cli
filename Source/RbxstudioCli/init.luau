#!/usr/bin/env -S lune run

--[[

RbxstudioCli

The entry point for the rbxstudio CLI. Registers all commands and executes
with process arguments.

--]]

local process = require("@lune/process")

local Commandline = require("@packages/Commandline")
local RbxstudioCommand = require("@self/RbxstudioCommand")

local function rbxstudioCli()
    Commandline.registerCommand(RbxstudioCommand)
    RbxstudioCommand:Execute(process.args)
end

rbxstudioCli()
