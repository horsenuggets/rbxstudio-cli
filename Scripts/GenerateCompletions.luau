#!/usr/bin/env -S lune run

--[[

GenerateCompletions

Generates shell completion scripts for the rbxstudio CLI.

--]]

local Commandline = require("@packages/Commandline")
local process = require("@lune/process")

-- Build the command tree manually to avoid requiring the full app
local rootCommand = Commandline.Command.new({
    Name = "rbxstudio",
    Description = "A feature-rich CLI for launching Roblox Studio with various configurations.",
    Subcommands = {
        Commandline.Command.new({
            Name = "api",
            Description = "Dump the Luau scripting API as JSON.",
            Args = {
                Commandline.Arg.new({
                    Name = "output",
                    Description = "Output file path for the API dump.",
                    Type = "string",
                    Required = false,
                }),
            },
            Flags = {
                Commandline.Flag.new({
                    Name = "force",
                    Shorthand = "f",
                    Description = "Overwrite the output file if it already exists.",
                }),
            },
        }),
        Commandline.Command.new({
            Name = "kill",
            Description = "Kill Roblox Studio processes.",
            Args = {
                Commandline.Arg.new({
                    Name = "pid",
                    Description = 'PID of the Studio process to kill, or "all" to kill all.',
                    Type = "string",
                    Required = false,
                }),
            },
        }),
        Commandline.Command.new({
            Name = "list",
            Description = "List all running Roblox Studio processes.",
        }),
        Commandline.Command.new({
            Name = "new",
            Description = "Create a new temporary place and open it in Studio.",
            Args = {
                Commandline.Arg.new({
                    Name = "name",
                    Description = "Name for the temporary place. If omitted, a random name is generated.",
                    Type = "string",
                    Required = false,
                }),
            },
            Flags = {
                Commandline.Flag.new({
                    Name = "noplugins",
                    Description = "Disable loading user plugins on startup.",
                }),
            },
        }),
        Commandline.Command.new({
            Name = "open",
            Description = "Open a place file or published place by ID.",
            Args = {
                Commandline.Arg.new({
                    Name = "target",
                    Description = "A file path or place ID.",
                    Type = "string",
                }),
            },
            Flags = {
                Commandline.Flag.new({
                    Name = "line",
                    Shorthand = "l",
                    Description = "Line number to navigate to in the script.",
                    Type = "int",
                }),
                Commandline.Flag.new({
                    Name = "noplugins",
                    Description = "Disable loading user plugins on startup.",
                }),
                Commandline.Flag.new({
                    Name = "script",
                    Shorthand = "s",
                    Description = "Script path to open (require-by-string format).",
                    Type = "string",
                }),
                Commandline.Flag.new({
                    Name = "version",
                    Shorthand = "v",
                    Description = "Open a specific place version (revision).",
                    Type = "string",
                }),
            },
        }),
        Commandline.Command.new({
            Name = "start",
            Description = "Launch Roblox Studio.",
            Flags = {
                Commandline.Flag.new({
                    Name = "noplugins",
                    Description = "Disable loading user plugins on startup.",
                }),
                Commandline.Flag.new({
                    Name = "reset",
                    Description = "Reset Studio layout and dock settings.",
                }),
            },
        }),
    },
})

local shell = process.args[1] or "zsh"
print(Commandline.Completions.generate(rootCommand, shell))
