#!/usr/bin/env -S lune run

--[[

RbxstudioCli

The entry point for the rbxstudio CLI. Registers all commands and executes
with process arguments.

--]]

const process = require("@lune/process")

const Commandline = require("@packages/Commandline")
const RbxstudioCommand = require("@rbxstudiocli/RbxstudioCommand")

const CLEANUP_SCRIPT = debug.info(function() end, "s"):match("^(.*/)") .. "Cleanup.luau"

const function spawnCleanup()
    pcall(process.exec, "sh", {
        "-c",
        `lune run "{CLEANUP_SCRIPT}" &>/dev/null &`,
    }, { stdio = "none" })
end

const function rbxstudioCli()
    spawnCleanup()
    Commandline.registerCommand(RbxstudioCommand)
    RbxstudioCommand:Execute(process.args)
end

rbxstudioCli()
