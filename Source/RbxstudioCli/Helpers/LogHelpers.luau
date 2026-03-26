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

    -- Helpers to reduce repetition in return values
    local NEW_PLACE: SessionInfo = { status = "Edit (New place)", placeId = nil, highlight = nil }

    local function makeResult(prefix: string, id: string?, name: string?): SessionInfo
        return {
            status = if name then `{prefix} ({name})` else prefix,
            placeId = id,
            highlight = name,
        }
    end

    if latestPos == 0 then
        return { status = "Unknown", placeId = nil, highlight = nil }
    end

    if latestPos == lastStartPagePos and lastStartPagePos > lastTaskPos then
        return { status = "Start Page", placeId = nil, highlight = nil }
    end

    if latestPos == lastTeamCreatePos and lastTeamCreatePlace then
        local name = getPlaceName(lastTeamCreatePlace)
        return makeResult("Team Create", lastTeamCreatePlace, name)
    end

    if lastTask == "EditFile" then
        local filePath = content:match("%-localPlaceFile%s+(%S+)")
        if filePath then
            local fileName = filePath:match("([^/\\]+)$") or filePath
            return makeResult("Edit", nil, fileName)
        end
        return makeResult("Edit", nil, "local file")
    end

    if lastTask == "EditPlace" or lastTask == "EditPlaceRevision" then
        -- Check the command line args for the universe ID. If it's
        -- 0, this was originally a new unsaved place (Cmd+N). But
        -- the user may have since published it or navigated to a
        -- different place, so also check for later telemetry entries
        -- with non-zero IDs that appear after the initial startup.
        local cmdLinePlaceId = content:match("%-placeId%s+(%d+)")
        local cmdLineUniverseId = content:match("%-universeId%s+(%d+)")
        local isNewPlace = cmdLineUniverseId == "0"

        -- Find the last non-zero place/universe IDs from telemetry
        local lastPlaceId = nil
        local lastUniverseId = nil
        for pid in content:gmatch("placeid: (%d+)") do
            if pid ~= "0" then
                lastPlaceId = pid
            end
        end
        for uid in content:gmatch("universeid: (%d+)") do
            if uid ~= "0" then
                lastUniverseId = uid
            end
        end

        -- For new places, only use telemetry IDs if they differ
        -- from the inherited command line place ID (indicating a
        -- publish or navigation)
        if isNewPlace then
            if lastPlaceId and lastUniverseId and lastPlaceId ~= cmdLinePlaceId then
                return makeResult("Edit", lastPlaceId, getPlaceName(lastPlaceId))
            end
            return NEW_PLACE
        end

        if lastPlaceId then
            return makeResult("Edit", lastPlaceId, getPlaceName(lastPlaceId))
        end
        return makeResult("Edit", nil, nil)
    end

    if lastTask then
        return NEW_PLACE
    end

    return { status = "Unknown", placeId = nil, highlight = nil }
end

return LogHelpers
