#!/usr/bin/env -S lune run

--[[

Cleanup

Standalone script that removes stale temporary place files. Designed to be
spawned as a detached background process from the main CLI so it never blocks
the user's terminal.

--]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local SEVEN_DAYS = 604800

local function cleanup()
    local tempDir = `{process.env.HOME}/.rbxstudio-cli/temp`

    if not fs.isDir(tempDir) then
        return
    end

    local now = os.time()
    local entries = fs.readDir(tempDir)

    for _, entry in entries do
        local entryPath = `{tempDir}/{entry}`
        if not fs.isDir(entryPath) then
            continue
        end

        local createdPath = `{entryPath}/.created`
        local isOld = true

        if fs.isFile(createdPath) then
            local timestamp = tonumber(fs.readFile(createdPath))
            if timestamp and (now - timestamp) < SEVEN_DAYS then
                isOld = false
            end
        end

        if isOld then
            pcall(fs.removeDir, entryPath)
        end
    end
end

cleanup()
