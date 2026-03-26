--[[

ListCommand

Lists all running Roblox Studio processes with their PID, uptime, and
what they are working on (place file, Start Page, etc.).

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local LOG_DIR = (process.env.HOME or "") .. "/Library/Logs/Roblox"

-- Cache for place name lookups to avoid duplicate API calls
local placeNameCache: { [string]: string } = {}

-- Reads the .ROBLOSECURITY cookie from the macOS keychain
local function getRobloSecurity(): string?
    if process.os ~= "macos" then
        return nil
    end

    local result = process.exec("security", {
        "find-generic-password",
        "-a",
        "https://www.roblox.com/:SharedROBLOSECURITYForStudio",
        "-w",
    })

    if not result.ok then
        return nil
    end

    -- The value is a hex-encoded binary plist, decode it
    local hexResult = process.exec("sh", {
        "-c",
        "echo '" .. result.stdout:gsub("%s+", "") .. "' | xxd -r -p | plutil -convert xml1 -o - -",
    })

    if not hexResult.ok then
        return nil
    end

    -- Extract the cookie value from the plist XML
    local cookie = hexResult.stdout:match("_|WARNING[^<]+")
    return cookie
end

-- Fetches the place name from the Roblox API
local function getPlaceName(placeId: string): string?
    if placeNameCache[placeId] then
        return placeNameCache[placeId]
    end

    local headers: { [string]: string } = {}
    local cookie = getRobloSecurity()
    if cookie then
        headers["Cookie"] = ".ROBLOSECURITY=" .. cookie
    end

    local ok, response = pcall(net.request, {
        url = `https://games.roblox.com/v1/games/multiget-place-details?placeIds={placeId}`,
        method = "GET",
        headers = headers,
    })

    if ok and response.ok then
        local success, data = pcall(serde.decode, "json", response.body)
        if success and type(data) == "table" and #data > 0 then
            local name = data[1].name
            if name then
                placeNameCache[placeId] = name
                return name
            end
        end
    end

    return nil
end

-- Extracts the log file path from a crash handler's command line args
local function getLogPath(crashHandlerArgs: string): string?
    local logName = crashHandlerArgs:match("attachment_([%w%.%-_]+_last%.log)=")
    if logName then
        return LOG_DIR .. "/" .. logName
    end
    return nil
end

-- Determines what Studio is doing based on its log file. Reads the
-- log for the latest session state since the user may have switched
-- places after launch.
local function getSessionInfo(logPath: string): string
    if not fs.isFile(logPath) then
        return "Unknown"
    end

    local content = fs.readFile(logPath)

    -- Check for Team Create (most specific, check last)
    local teamCreatePlace = nil
    for place in content:gmatch("TeamCreateJoinPayload.*place (%d+)") do
        teamCreatePlace = place
    end
    if teamCreatePlace then
        local name = getPlaceName(teamCreatePlace)
        if name then
            return `Team Create ({name})`
        end
        return `Team Create (place {teamCreatePlace})`
    end

    -- Check for the most recent PlaceManager open action
    local lastTask = nil
    for t in content:gmatch("PlaceManager::createAndShowIDEDoc with task (%w+)") do
        lastTask = t
    end

    if lastTask == "EditFile" then
        -- Find the local file path from the command line in the log
        local filePath = content:match("%-localPlaceFile%s+(%S+)")
        if filePath then
            local fileName = filePath:match("([^/\\]+)$") or filePath
            return `Editing {fileName}`
        end
        return "Editing local file"
    end

    if lastTask == "EditPlace" or lastTask == "EditPlaceRevision" then
        -- Find the last non-zero placeId from telemetry
        local lastPlaceId = nil
        for pid in content:gmatch("placeid: (%d+)") do
            if pid ~= "0" then
                lastPlaceId = pid
            end
        end
        if lastPlaceId then
            local name = getPlaceName(lastPlaceId)
            if name then
                return `Editing {name}`
            end
            return `Editing place {lastPlaceId}`
        end
        return "Editing place"
    end

    -- Check if still on Start Page (no place opened)
    if not lastTask and content:find("showStartPageWidgets") then
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
