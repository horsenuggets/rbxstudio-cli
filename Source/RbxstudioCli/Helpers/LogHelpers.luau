--[[

LogHelpers

Utilities for parsing Roblox Studio log files to determine session
state. Extracts information about what a Studio instance is currently
doing based on log entries.

--]]

local LogHelpers = {}

export type SessionInfo = {
    status: string,
    placeId: string?,
    highlight: string?,
}

-- Parses log content to determine what Studio is doing. Scans for
-- the latest session state since the user may switch places, open
-- new documents, or return to the Start Page after launch.
--
-- The optional getPlaceNameFn callback resolves a place ID to a
-- human-readable name. If not provided, place IDs are used as-is.
function LogHelpers.parseSessionInfo(content: string, getPlaceNameFn: ((string) -> string?)?): SessionInfo
    local getPlaceName = getPlaceNameFn or function(_placeId: string)
        return nil
    end

    -- Track the latest event by finding the last occurrence of each
    -- pattern and comparing their positions in the log
    local lastTeamCreatePos = 0
    local lastTeamCreatePlace: string? = nil
    local lastTaskPos = 0
    local lastTask: string? = nil
    local lastStartPagePos = 0

    -- Find all Team Create log entries (latest wins). Track position
    -- from any TeamCreateJoinPayload line, but only extract place ID
    -- from lines that contain it.
    local searchStart = 1
    while true do
        local matchStart, matchEnd = content:find("TeamCreateJoinPayload", searchStart)
        if not matchStart then
            break
        end
        lastTeamCreatePos = matchStart

        -- Extract place ID if this line has one
        local lineEnd = content:find("\n", matchEnd) or #content
        local line = content:sub(matchStart, lineEnd)
        local place = line:match("place (%d+)")
        if place then
            lastTeamCreatePlace = place
        end

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
        return { status = "Unknown", placeId = nil, highlight = nil }
    end

    if latestPos == lastStartPagePos and lastStartPagePos > lastTaskPos then
        return { status = "Start Page", placeId = nil, highlight = nil }
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
        return {
            status = "Editing local file",
            placeId = nil,
            highlight = nil,
        }
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
        return {
            status = "Editing place",
            placeId = nil,
            highlight = nil,
        }
    end

    if lastTask then
        return {
            status = "Editing new place",
            placeId = nil,
            highlight = nil,
        }
    end

    return { status = "Unknown", placeId = nil, highlight = nil }
end

return LogHelpers
