--[[

ListCommand

Lists all running Roblox Studio processes with their PID, uptime, and
what they are working on (place file, Start Page, etc.).

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local fs = require("@lune/fs")
local process = require("@lune/process")

local LOG_DIR = (process.env.HOME or "") .. "/Library/Logs/Roblox"

-- Extracts the log file path from a crash handler's command line args
local function getLogPath(crashHandlerArgs: string): string?
    local logName = crashHandlerArgs:match("attachment_([%w%.%-_]+_last%.log)=")
    if logName then
        return LOG_DIR .. "/" .. logName
    end
    return nil
end

-- Determines what Studio is doing based on its log file
local function getSessionInfo(logPath: string): string
    if not fs.isFile(logPath) then
        return "Unknown"
    end

    local content = fs.readFile(logPath)

    -- Check for local file editing
    local localFile = content:match("localplacefile.*=.*([^\n]+)") or content:match("Opening local file ([^\n]+)")
    if localFile then
        -- Extract just the filename from the path
        local fileName = localFile:match("([^/\\]+)$") or localFile
        return `Editing {fileName}`
    end

    -- Check for place editing by ID
    local placeId = content:match("placeid.*=.*(%d+)")
    if placeId then
        return `Editing place {placeId}`
    end

    -- Check for Start Page
    if content:find("StartPage") then
        return "Start Page"
    end

    return "Unknown"
end

return Commandline.Command.new({
    Name = "list",
    Description = "List all running Roblox Studio processes.",
    Impl = function(_args, _flags)
        if process.os ~= "macos" then
            print("Listing Studio processes is currently only supported on macOS.")
            process.exit(1)
        end

        -- Get all RobloxStudio processes
        local result = process.exec("ps", {
            "-eo",
            "pid,etime,args",
        })

        if not result.ok then
            print(Chalk.red("Failed to list processes."))
            process.exit(1)
        end

        -- Parse Studio main processes and their crash handlers
        type StudioProcess = {
            pid: string,
            uptime: string,
            logPath: string?,
        }

        local studios: { StudioProcess } = {}

        for line in result.stdout:gmatch("[^\n]+") do
            local pid, etime = line:match("^%s*(%d+)%s+(%S+)")
            if pid and line:find("RobloxStudio.app/Contents/MacOS/RobloxStudio") then
                if not line:find("RobloxCrashHandler") then
                    table.insert(studios, {
                        pid = pid,
                        uptime = etime,
                        logPath = nil,
                    })
                end
            end
        end

        -- Match crash handlers to find log paths
        for line in result.stdout:gmatch("[^\n]+") do
            if line:find("RobloxCrashHandler") then
                local studioPid = line:match("%-%-studioPid%s+(%d+)")
                if studioPid then
                    for _, studio in studios do
                        if studio.pid == studioPid then
                            studio.logPath = getLogPath(line)
                            break
                        end
                    end
                end
            end
        end

        if #studios == 0 then
            print("No Roblox Studio processes running.")
            return
        end

        print(`{#studios} {if #studios == 1 then "instance" else "instances"} running.`)
        print()

        for _, studio in studios do
            local info = if studio.logPath then getSessionInfo(studio.logPath) else "Unknown"
            print(`  {Chalk.bold(studio.pid)}  {Chalk.dim(studio.uptime)}  {info}`)
        end
    end,
})
