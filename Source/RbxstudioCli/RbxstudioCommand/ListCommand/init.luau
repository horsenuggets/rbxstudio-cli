--[[

ListCommand

Lists all running Roblox Studio processes with their PID, uptime, and
what they are working on (place file, Start Page, etc.). Fetches place
names from the Roblox API for published places.

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local LOG_DIR = (process.env.HOME or "") .. "/Library/Logs/Roblox"

------------------------------------------------------------------------------------------
-- Roblox API helpers
------------------------------------------------------------------------------------------

local robloSecurityCookie: string? = nil
local placeNameCache: { [string]: string } = {}

local function getRobloSecurity(): string?
    if robloSecurityCookie then
        return robloSecurityCookie
    end

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

    local hexResult = process.exec("sh", {
        "-c",
        "echo '" .. result.stdout:gsub("%s+", "") .. "' | xxd -r -p | plutil -convert xml1 -o - -",
    })

    if not hexResult.ok then
        return nil
    end

    robloSecurityCookie = hexResult.stdout:match("_|WARNING[^<]+")
    return robloSecurityCookie
end

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

------------------------------------------------------------------------------------------
-- Log parsing
------------------------------------------------------------------------------------------

local function getLogPath(crashHandlerArgs: string): string?
    local logName = crashHandlerArgs:match("attachment_([%w%.%-_]+_last%.log)=")
    if logName then
        return LOG_DIR .. "/" .. logName
    end
    return nil
end

-- Determines what Studio is doing based on its log file. Scans for
-- the latest session state since the user may switch places, open
-- new documents, or return to the Start Page after launch.
local function getSessionInfo(logPath: string): string
    if not fs.isFile(logPath) then
        return "Unknown"
    end

    local content = fs.readFile(logPath)

    -- Track the latest event by finding the last occurrence of each
    -- pattern and comparing their positions in the log
    local lastTeamCreatePos = 0
    local lastTeamCreatePlace: string? = nil
    local lastTaskPos = 0
    local lastTask: string? = nil
    local lastStartPagePos = 0

    -- Find all Team Create joins (latest wins)
    local searchStart = 1
    while true do
        local matchStart, matchEnd, place = content:find("TeamCreateJoinPayload.*place (%d+)", searchStart)
        if not matchStart then
            break
        end
        lastTeamCreatePos = matchStart
        lastTeamCreatePlace = place
        searchStart = matchEnd + 1
    end

    -- Find all PlaceManager opens (latest wins)
    searchStart = 1
    while true do
        local matchStart, matchEnd, t = content:find("PlaceManager::createAndShowIDEDoc with task (%w+)", searchStart)
        if not matchStart then
            break
        end
        lastTaskPos = matchStart
        lastTask = t
        searchStart = matchEnd + 1
    end

    -- Find the last Start Page show event
    searchStart = 1
    while true do
        local matchStart, matchEnd = content:find("showStartPageWidgets", searchStart)
        if not matchStart then
            break
        end
        lastStartPagePos = matchStart
        searchStart = matchEnd + 1
    end

    -- Determine state from whichever event is latest
    local latestPos = math.max(lastTeamCreatePos, lastTaskPos, lastStartPagePos)

    if latestPos == 0 then
        return "Unknown"
    end

    if latestPos == lastStartPagePos and lastStartPagePos > lastTaskPos then
        return "Start Page"
    end

    if latestPos == lastTeamCreatePos and lastTeamCreatePlace then
        local name = getPlaceName(lastTeamCreatePlace)
        if name then
            return `Team Create ({name})`
        end
        return `Team Create (place {lastTeamCreatePlace})`
    end

    if lastTask == "EditFile" then
        local filePath = content:match("%-localPlaceFile%s+(%S+)")
        if filePath then
            local fileName = filePath:match("([^/\\]+)$") or filePath
            return `Editing {fileName}`
        end
        return "Editing local file"
    end

    if lastTask == "EditPlace" or lastTask == "EditPlaceRevision" then
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

    -- Generic new document (Cmd+N creates a Baseplate)
    if lastTask then
        return "Editing new place"
    end

    return "Unknown"
end

------------------------------------------------------------------------------------------
-- Table rendering
------------------------------------------------------------------------------------------

local function renderTable(headers: { string }, rows: { { string } })
    -- Calculate column widths
    local widths = {}
    for i, header in headers do
        widths[i] = #header
    end
    for _, row in rows do
        for i, cell in row do
            widths[i] = math.max(widths[i] or 0, #cell)
        end
    end

    -- Build horizontal border
    local borderParts = {}
    for i, w in widths do
        table.insert(borderParts, string.rep("─", w + 2))
    end
    local topBorder = "┌" .. table.concat(borderParts, "┬") .. "┐"
    local midBorder = "├" .. table.concat(borderParts, "┼") .. "┤"
    local botBorder = "└" .. table.concat(borderParts, "┴") .. "┘"

    -- Build a row string
    local function formatRow(cells: { string }): string
        local parts = {}
        for i, cell in cells do
            local padding = string.rep(" ", (widths[i] or 0) - #cell)
            table.insert(parts, " " .. cell .. padding .. " ")
        end
        return "│" .. table.concat(parts, "│") .. "│"
    end

    -- Print the table
    print(topBorder)
    print(formatRow(headers))
    print(midBorder)
    for _, row in rows do
        print(formatRow(row))
    end
    print(botBorder)
end

------------------------------------------------------------------------------------------
-- Command
------------------------------------------------------------------------------------------

type StudioProcess = {
    pid: string,
    uptime: string,
    logPath: string?,
    status: string?,
}

return Commandline.Command.new({
    Name = "list",
    Description = "List all running Roblox Studio processes.",
    Impl = function(_args, _flags)
        if process.os ~= "macos" then
            print("Listing Studio processes is currently only supported on macOS.")
            process.exit(1)
        end

        local result = process.exec("ps", { "-eo", "pid,etime,args" })
        if not result.ok then
            print(Chalk.red("Failed to list processes."))
            process.exit(1)
        end

        -- Parse Studio processes and crash handlers
        local studios: { StudioProcess } = {}

        for line in result.stdout:gmatch("[^\n]+") do
            local pid, etime = line:match("^%s*(%d+)%s+(%S+)")
            if
                pid
                and line:find("RobloxStudio.app/Contents/MacOS/RobloxStudio")
                and not line:find("RobloxCrashHandler")
            then
                table.insert(studios, {
                    pid = pid,
                    uptime = etime,
                    logPath = nil,
                    status = nil,
                })
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

        -- Gather session info for all processes
        for _, studio in studios do
            studio.status = if studio.logPath then getSessionInfo(studio.logPath) else "Unknown"
        end

        -- Build table rows
        local rows: { { string } } = {}
        for _, studio in studios do
            table.insert(rows, {
                studio.pid,
                studio.uptime,
                studio.status or "Unknown",
            })
        end

        print(`{#studios} {if #studios == 1 then "instance" else "instances"} running.`)
        print()
        renderTable({ "PID", "Uptime", "Status" }, rows)
    end,
})
