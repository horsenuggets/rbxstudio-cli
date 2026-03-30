--[[

ListCommand

Lists all running Roblox Studio processes with their PID, uptime, and
what they are working on (place file, Start Page, etc.). Fetches place
names from the Roblox API for published places.

--]]

local Colors = require("@rbxstudiocli/Helpers/Colors")
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
        local success, data = pcall(serde.decode, "json" :: "json", response.body)
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

local LogHelpers = require("@rbxstudiocli/Helpers/LogHelpers")
type SessionInfo = LogHelpers.SessionInfo

local function getSessionInfo(logPath: string): SessionInfo
    if not fs.isFile(logPath) then
        return { status = "Unknown", placeId = nil, highlight = nil }
    end
    local content = fs.readFile(logPath)
    return LogHelpers.parseSessionInfo(content, getPlaceName)
end

------------------------------------------------------------------------------------------
-- Table rendering
------------------------------------------------------------------------------------------

local MemoryHelpers = require("@rbxstudiocli/Helpers/MemoryHelpers")
local TableHelpers = require("@rbxstudiocli/Helpers/TableHelpers")
local TimeHelpers = require("@rbxstudiocli/Helpers/TimeHelpers")
type TableRow = TableHelpers.TableRow

type StudioProcess = {
    memory: string,
    memoryRaw: string,
    pid: string,
    uptime: string,
    uptimeRaw: string,
    logPath: string?,
    session: SessionInfo?,
}

return Commandline.Command.new({
    Name = "list",
    Description = "List all running Roblox Studio processes.",
    Impl = function(_args, _flags)
        if process.os ~= "macos" then
            print("Listing Roblox Studio processes is currently only supported on macOS.")
            process.exit(1)
        end

        local result = process.exec("ps", { "-eo", "pid,rss,etime,args" })
        if not result.ok then
            print(Colors.error("Failed to list processes."))
            process.exit(1)
        end

        -- Parse Studio processes and crash handlers
        local studios: { StudioProcess } = {}

        for line in result.stdout:gmatch("[^\n]+") do
            local pid, rss, etime = line:match("^%s*(%d+)%s+(%d+)%s+(%S+)")
            if
                pid
                and line:find("RobloxStudio.app/Contents/MacOS/RobloxStudio")
                and not line:find("RobloxCrashHandler")
            then
                local coloredUptime, rawUptime = TimeHelpers.formatUptimeColored(etime)
                local coloredMemory, rawMemory = MemoryHelpers.format(tonumber(rss) or 0)
                table.insert(studios, {
                    memory = coloredMemory,
                    memoryRaw = rawMemory,
                    pid = pid,
                    uptime = coloredUptime,
                    uptimeRaw = rawUptime,
                    logPath = nil,
                    session = nil,
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

        -- Sort by process ID
        table.sort(studios, function(a, b)
            return tonumber(a.pid) < tonumber(b.pid)
        end)

        -- Gather session info for all processes
        for _, studio in studios do
            studio.session = if studio.logPath
                then getSessionInfo(studio.logPath)
                else { status = "Unknown", placeId = nil }
        end

        -- Build table rows with colored and raw versions
        local rows: { TableRow } = {}
        for _, studio in studios do
            local session = studio.session :: SessionInfo
            local rawPlaceId = session.placeId or "nil"
            local coloredPlaceId = if session.placeId then Colors.numericId(session.placeId) else Colors.nil_("nil")

            -- Color the highlight portion of the status. Escape
            -- pattern special characters since highlights may contain
            -- dots, dashes, etc.
            local coloredStatus = session.status
            if session.highlight then
                local escaped = session.highlight:gsub("([%.%-%+%*%?%^%$%(%)%[%]%%])", "%%%1")
                coloredStatus = coloredStatus:gsub(escaped, Colors.projectName(session.highlight), 1)
            end

            table.insert(rows, {
                raw = {
                    studio.pid,
                    studio.memoryRaw,
                    studio.uptimeRaw,
                    rawPlaceId,
                    session.status,
                },
                colored = {
                    studio.pid,
                    studio.memory,
                    studio.uptime,
                    coloredPlaceId,
                    coloredStatus,
                },
            })
        end

        local count = tostring(#studios)
        print(
            `There {if #studios == 1 then "is" else "are"} {Colors.count(count)} Roblox Studio {if #studios
                    == 1
                then "instance"
                else "instances"} running.`
        )
        print()
        TableHelpers.render({ "Process ID", "Memory", "Uptime", "Place ID", "Status" }, rows)
    end,
})
