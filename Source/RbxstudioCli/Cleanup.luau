#!/usr/bin/env -S lune run

--[[

Cleanup

Standalone script that removes stale temporary place files. Designed to be
spawned as a detached background process from the main CLI so it never blocks
the user's terminal.

--]]

const fs = require("@lune/fs")
const process = require("@lune/process")

const SEVEN_DAYS = 604800

const function cleanup()
    const tempDir = `{process.env.HOME}/.rbxstudio-cli/temp`

    if not fs.isDir(tempDir) then
        return
    end

    const now = os.time()
    const entries = fs.readDir(tempDir)

    for _, entry in entries do
        const entryPath = `{tempDir}/{entry}`
        if not fs.isDir(entryPath) then
            continue
        end

        const createdPath = `{entryPath}/.created`
        local isOld = true

        if fs.isFile(createdPath) then
            const timestamp = tonumber(fs.readFile(createdPath))
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
