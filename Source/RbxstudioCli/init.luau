#!/usr/bin/env -S lune run

--[[

RbxstudioCli

The entry point for the rbxstudio CLI. Registers all commands and executes
with process arguments.

--]]

local process = require("@lune/process")

local Commandline = require("@packages/Commandline")
local RbxstudioCommand = require("@rbxstudiocli/RbxstudioCommand")

local CLEANUP_SCRIPT = debug.info(function() end, "s"):match("^(.*/)") .. "Cleanup.luau"

local function spawnCleanup()
    pcall(process.exec, "sh", {
        "-c",
        `lune run "{CLEANUP_SCRIPT}" &>/dev/null &`,
    }, { stdio = "none" })
end

local function rbxstudioCli()
    spawnCleanup()
    Commandline.registerCommand(RbxstudioCommand)
    RbxstudioCommand:Execute(process.args)
end

rbxstudioCli()
