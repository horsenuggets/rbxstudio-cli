--[[

MemoryHelpers

Utilities for formatting memory values with a fire gradient color
based on usage. Green under 1 GB, transitioning through yellow and
orange to red at 6 GB+.

--]]

local Chalk = require("@packages/Chalk")
local Colors = require("@rbxstudiocli/Helpers/Colors")

local MemoryHelpers = {}

-- Returns an RGB color on a gradient from green to red based on
-- memory usage in MB.
function MemoryHelpers.color(mb: number): (string) -> string
    local pct = math.clamp((mb - 1024) / (6 * 1024 - 1024), 0, 1)
    local r, g, b
    if pct <= 0 then
        r, g, b = 100, 240, 100
    elseif pct <= 0.4 then
        local t = pct / 0.4
        r = math.floor(100 + 155 * t)
        g = math.floor(240 - 10 * t)
        b = math.floor(100 - 70 * t)
    elseif pct <= 0.7 then
        local t = (pct - 0.4) / 0.3
        r = 255
        g = math.floor(230 - 120 * t)
        b = math.floor(30 - 10 * t)
    else
        local t = (pct - 0.7) / 0.3
        r = 255
        g = math.floor(110 - 80 * t)
        b = math.floor(20 + 10 * t)
    end
    return Chalk.rgb(r, g, b)
end

-- Formats memory in KB to a human-readable string. Returns both a
-- colored string (gradient based on usage) and a raw string for
-- width calculation.
function MemoryHelpers.format(rssKb: number): (string, string)
    local mb = rssKb / 1024
    local num, unit
    if rssKb >= 1024 * 1024 then
        num = string.format("%.1f", rssKb / (1024 * 1024))
        unit = "GB"
    elseif rssKb >= 1024 then
        num = string.format("%.0f", mb)
        unit = "MB"
    else
        num = tostring(rssKb)
        unit = "KB"
    end

    local colorFn = MemoryHelpers.color(mb)
    local colored = colorFn(num .. " " .. unit)
    local raw = num .. " " .. unit
    return colored, raw
end

return MemoryHelpers
