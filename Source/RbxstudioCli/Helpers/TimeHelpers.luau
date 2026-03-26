--[[

TimeHelpers

Utilities for formatting time durations into human-readable strings.

--]]

local TimeHelpers = {}

-- Converts ps etime format (MM:SS, HH:MM:SS, DD-HH:MM:SS) to a
-- human-readable string like "2d 5h 30m 12s".
-- Returns both a display string and a raw string (without styling).
function TimeHelpers.formatUptime(etime: string): (string, string)
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
                return etime, etime
            end
        end
    end

    local parts = {}
    if days and days > 0 then
        table.insert(parts, `{days}d`)
    end
    if hours and hours > 0 then
        table.insert(parts, `{hours}h`)
    end
    if minutes and minutes > 0 then
        table.insert(parts, `{minutes}m`)
    end
    if seconds and seconds > 0 then
        table.insert(parts, `{seconds}s`)
    end
    if #parts == 0 then
        table.insert(parts, "0s")
    end

    return table.concat(parts, " "), table.concat(parts, " ")
end

-- Formats uptime with dim unit suffixes for display. Returns both
-- a colored string and a raw string for width calculation.
function TimeHelpers.formatUptimeColored(etime: string): (string, string)
    local Colors = require("@rbxstudiocli/Helpers/Colors")
    local raw = TimeHelpers.formatUptime(etime)

    local coloredParts = {}
    for part in raw:gmatch("%S+") do
        local num, unit = part:match("^(%d+)(%a)$")
        if num and unit then
            table.insert(coloredParts, num .. Colors.dim(unit))
        else
            table.insert(coloredParts, part)
        end
    end

    return table.concat(coloredParts, " "), raw
end

return TimeHelpers
