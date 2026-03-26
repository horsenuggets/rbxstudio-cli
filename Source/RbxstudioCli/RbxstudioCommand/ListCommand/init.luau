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

local TimeHelpers = require("@rbxstudiocli/Helpers/TimeHelpers")

-- Formats uptime with dim unit suffixes for display. Returns both
-- a colored string and a raw string for width calculation.
local function formatUptime(etime: string): (string, string)
    local raw = TimeHelpers.formatUptime(etime)

    -- Add dim styling to the unit suffixes. Process each part
    -- individually to avoid ANSI codes interfering with patterns.
    local coloredParts = {}
    for part in raw:gmatch("%S+") do
        local num, unit = part:match("^(%d+)(%a)$")
        if num and unit then
            table.insert(coloredParts, num .. Colors.dim(unit))
        else
            table.insert(coloredParts, part)
        end
    end
    local colored = table.concat(coloredParts, " ")

    return colored, raw
end

-- Each row has raw (for width calculation) and colored (for display)
type TableRow = {
    raw: { string },
    colored: { string },
}

local function renderTable(headers: { string }, rows: { TableRow })
    -- Calculate column widths from raw uncolored text
    local widths = {}
    for i, header in headers do
        widths[i] = #header
    end
    for _, row in rows do
        for i, cell in row.raw do
            widths[i] = math.max(widths[i] or 0, #cell)
        end
    end

    local function border(left: string, mid: string, right: string): string
        local parts = {}
        for _, w in widths do
            table.insert(parts, string.rep("─", w + 2))
        end
        return left .. table.concat(parts, mid) .. right
    end

    local function formatCells(cells: { string }, rawCells: { string }): string
        local parts = {}
        for i, cell in cells do
            local rawLen = #(rawCells[i] or "")
            local padding = string.rep(" ", (widths[i] or 0) - rawLen)
            table.insert(parts, ` {cell}{padding} `)
        end
        return "│" .. table.concat(parts, "│") .. "│"
    end

    -- Build bold header cells
    local boldHeaders = {}
    for _, h in headers do
        table.insert(boldHeaders, Colors.bold(h))
    end

    print(border("┌", "┬", "┐"))
    print(formatCells(boldHeaders, headers))
    print(border("├", "┼", "┤"))
    for _, row in rows do
        print(formatCells(row.colored, row.raw))
    end
    print(border("└", "┴", "┘"))
end

------------------------------------------------------------------------------------------
-- Command
------------------------------------------------------------------------------------------

-- Formats memory in KB to a human-readable string
local function formatMemory(rssKb: number): string
    if rssKb >= 1024 * 1024 then
        return string.format("%.1f GB", rssKb / (1024 * 1024))
    elseif rssKb >= 1024 then
        return string.format("%.0f MB", rssKb / 1024)
    end
    return `{rssKb} KB`
end

type StudioProcess = {
    memory: string,
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
                local coloredUptime, rawUptime = formatUptime(etime)
                table.insert(studios, {
                    memory = formatMemory(tonumber(rss) or 0),
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
                coloredStatus = coloredStatus:gsub(escaped, Colors.placeName(session.highlight), 1)
            end

            table.insert(rows, {
                raw = {
                    studio.pid,
                    studio.memory,
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
        renderTable({ "Process ID", "Memory", "Uptime", "Place ID", "Status" }, rows)
    end,
})
