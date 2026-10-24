--[[

ListCommand

Lists all running Roblox Studio processes with their PID, uptime, and
what they are working on (place file, Start Page, etc.). Fetches place
names from the Roblox API for published places.

--]]

const Colors = require("@rbxstudiocli/Helpers/Colors")
const Commandline = require("@packages/Commandline")
const CookieHelpers = require("@rbxstudiocli/Helpers/CookieHelpers")
const fs = require("@lune/fs")
const net = require("@lune/net")
const process = require("@lune/process")
const serde = require("@lune/serde")

const LOG_DIR = (process.env.HOME or "") .. "/Library/Logs/Roblox"

------------------------------------------------------------------------------------------
-- Roblox API helpers
------------------------------------------------------------------------------------------

const placeNameCache: { [string]: string } = {}

const function getPlaceName(placeId: string): string?
    if placeNameCache[placeId] then
        return placeNameCache[placeId]
    end

    const ok, response = pcall(net.request, {
        url = `https://games.roblox.com/v1/games/multiget-place-details?placeIds={placeId}`,
        method = "GET",
        headers = CookieHelpers.authHeaders(),
    })

    if ok and response.ok then
        const success, data = pcall(serde.decode, "json" :: "json", response.body)
        if success and type(data) == "table" and #data > 0 then
            const name = data[1].name
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

const function getLogPath(crashHandlerArgs: string): string?
    const logName = crashHandlerArgs:match("attachment_([%w%.%-_]+_last%.log)=")
    if logName then
        return LOG_DIR .. "/" .. logName
    end
    return nil
end

const LogHelpers = require("@rbxstudiocli/Helpers/LogHelpers")
type SessionInfo = LogHelpers.SessionInfo

const function getSessionInfo(logPath: string): SessionInfo
    if not fs.isFile(logPath) then
        return { Status = "Unknown", PlaceId = nil, Highlight = nil }
    end
    const content = fs.readFile(logPath)
    return LogHelpers.parseSessionInfo(content, getPlaceName)
end

------------------------------------------------------------------------------------------
-- Table rendering
------------------------------------------------------------------------------------------

const MemoryHelpers = require("@rbxstudiocli/Helpers/MemoryHelpers")
const TableHelpers = require("@rbxstudiocli/Helpers/TableHelpers")
const TimeHelpers = require("@rbxstudiocli/Helpers/TimeHelpers")
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

        const result = process.exec("ps", { "-eo", "pid,rss,etime,args" })
        if not result.ok then
            print(Colors.error("Failed to list processes."))
            process.exit(1)
        end

        -- Parse Studio processes and crash handlers
        const studios: { StudioProcess } = {}

        for line in result.stdout:gmatch("[^\n]+") do
            const pid, rss, etime = line:match("^%s*(%d+)%s+(%d+)%s+(%S+)")
            if
                pid
                and line:find("RobloxStudio.app/Contents/MacOS/RobloxStudio")
                and not line:find("RobloxCrashHandler")
            then
                const coloredUptime, rawUptime = TimeHelpers.formatUptimeColored(etime)
                const coloredMemory, rawMemory = MemoryHelpers.format(tonumber(rss) or 0)
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
                const studioPid = line:match("%-%-studioPid%s+(%d+)")
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
                else { Status = "Unknown", PlaceId = nil }
        end

        -- Build table rows with colored and raw versions
        const rows: { TableRow } = {}
        for _, studio in studios do
            const session = studio.session :: SessionInfo
            const rawPlaceId = session.PlaceId or "nil"
            const coloredPlaceId = if session.PlaceId then Colors.numericId(session.PlaceId) else Colors.nil_("nil")

            -- Color the highlight portion of the status. Escape
            -- pattern special characters since highlights may contain
            -- dots, dashes, etc.
            local coloredStatus = session.Status
            if session.Highlight then
                const escaped = session.Highlight:gsub("([%.%-%+%*%?%^%$%(%)%[%]%%])", "%%%1")
                coloredStatus = coloredStatus:gsub(escaped, Colors.projectName(session.Highlight), 1)
            end

            table.insert(rows, {
                Raw = {
                    studio.pid,
                    studio.memoryRaw,
                    studio.uptimeRaw,
                    rawPlaceId,
                    session.Status,
                },
                Colored = {
                    studio.pid,
                    studio.memory,
                    studio.uptime,
                    coloredPlaceId,
                    coloredStatus,
                },
            })
        end

        const count = tostring(#studios)
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
