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

type SessionInfo = {
    status: string,
    placeId: string?,
    highlight: string?,
}

-- Determines what Studio is doing based on its log file. Scans for
-- the latest session state since the user may switch places, open
-- new documents, or return to the Start Page after launch.
local function getSessionInfo(logPath: string): SessionInfo
    if not fs.isFile(logPath) then
        return { status = "Unknown", placeId = nil }
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
        return { status = "Unknown", placeId = nil }
    end

    if latestPos == lastStartPagePos and lastStartPagePos > lastTaskPos then
        return { status = "Start Page", placeId = nil }
    end

    if latestPos == lastTeamCreatePos and lastTeamCreatePlace then
        local name = getPlaceName(lastTeamCreatePlace)
        return {
            status = if name then `Team Create ({name})` else "Team Create",
            placeId = lastTeamCreatePlace,
            highlight = name,
        }
    end

    if lastTask == "EditFile" then
        local filePath = content:match("%-localPlaceFile%s+(%S+)")
        if filePath then
            local fileName = filePath:match("([^/\\]+)$") or filePath
            return {
                status = `Editing {fileName}`,
                placeId = nil,
                highlight = fileName,
            }
        end
        return { status = "Editing local file", placeId = nil, highlight = nil }
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
            return {
                status = if name then `Editing {name}` else "Editing place",
                placeId = lastPlaceId,
                highlight = name,
            }
        end
        return { status = "Editing place", placeId = nil, highlight = nil }
    end

    if lastTask then
        return { status = "Editing new place", placeId = nil, highlight = nil }
    end

    return { status = "Unknown", placeId = nil, highlight = nil }
end

------------------------------------------------------------------------------------------
-- Table rendering
------------------------------------------------------------------------------------------

-- Converts ps etime format (MM:SS, HH:MM:SS, DD-HH:MM:SS) to a
-- human-readable string like "2d 5h 30m" or "45s"
local function formatUptime(etime: string): string
    local days, hours, minutes, seconds

    -- DD-HH:MM:SS
    local d, rest = etime:match("^(%d+)-(.+)$")
    if d then
        days = tonumber(d)
        hours, minutes, seconds = rest:match("^(%d+):(%d+):(%d+)$")
        hours = tonumber(hours)
        minutes = tonumber(minutes)
        seconds = tonumber(seconds)
    else
        -- HH:MM:SS
        local h, m, s = etime:match("^(%d+):(%d+):(%d+)$")
        if h then
            days = 0
            hours = tonumber(h)
            minutes = tonumber(m)
            seconds = tonumber(s)
        else
            -- MM:SS
            local mm, ss = etime:match("^(%d+):(%d+)$")
            if mm then
                days = 0
                hours = 0
                minutes = tonumber(mm)
                seconds = tonumber(ss)
            else
                return etime
            end
        end
    end

    local d_s = Chalk.dim("d")
    local h_s = Chalk.dim("h")
    local m_s = Chalk.dim("m")
    local s_s = Chalk.dim("s")

    local parts = {}
    local rawParts = {}
    if days and days > 0 then
        table.insert(parts, `{days}{d_s}`)
        table.insert(rawParts, `{days}d`)
    end
    if hours and hours > 0 then
        table.insert(parts, `{hours}{h_s}`)
        table.insert(rawParts, `{hours}h`)
    end
    if minutes and minutes > 0 then
        table.insert(parts, `{minutes}{m_s}`)
        table.insert(rawParts, `{minutes}m`)
    end
    if seconds and seconds > 0 then
        table.insert(parts, `{seconds}{s_s}`)
        table.insert(rawParts, `{seconds}s`)
    end
    if #parts == 0 then
        table.insert(parts, `0{s_s}`)
        table.insert(rawParts, "0s")
    end

    return table.concat(parts, " "), table.concat(rawParts, " ")
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
        table.insert(boldHeaders, Chalk.bold(h))
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

type StudioProcess = {
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
                local coloredUptime, rawUptime = formatUptime(etime)
                table.insert(studios, {
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
            local coloredPlaceId = if session.placeId then Chalk.greenBright(session.placeId) else Chalk.dim("nil")

            -- Color the highlight portion of the status. Escape
            -- pattern special characters since highlights may contain
            -- dots, dashes, etc.
            local coloredStatus = session.status
            if session.highlight then
                local escaped = session.highlight:gsub("([%.%-%+%*%?%^%$%(%)%[%]%%])", "%%%1")
                coloredStatus = coloredStatus:gsub(escaped, Chalk.cyanBright(session.highlight), 1)
            end

            table.insert(rows, {
                raw = {
                    studio.pid,
                    studio.uptimeRaw,
                    rawPlaceId,
                    session.status,
                },
                colored = {
                    studio.pid,
                    studio.uptime,
                    coloredPlaceId,
                    coloredStatus,
                },
            })
        end

        local count = tostring(#studios)
        print(
            `There {if #studios == 1 then "is" else "are"} {Chalk.bold(Chalk.yellowBright(count))} Roblox Studio {if #studios
                    == 1
                then "instance"
                else "instances"} running.`
        )
        print()
        renderTable({ "Process ID", "Uptime", "Place ID", "Status" }, rows)
    end,
})
