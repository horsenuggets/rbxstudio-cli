#!/usr/bin/env -S lune run

--[[

DemoList

Renders a mock list table to preview the color scheme and memory
gradient across a range of values without needing running Studio
instances.

--]]

local Chalk = require("@packages/Chalk")
local Colors = require("@rbxstudiocli/Helpers/Colors")
local TimeHelpers = require("@rbxstudiocli/Helpers/TimeHelpers")

------------------------------------------------------------------------------------------
-- Copied from ListCommand to keep this self-contained
------------------------------------------------------------------------------------------

local function memoryColor(mb: number): (string) -> string
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

local function formatMemory(rssKb: number): (string, string)
    local mb = rssKb / 1024
    local num, unit
    if rssKb >= 1024 * 1024 then
        num = string.format("%.1f", rssKb / (1024 * 1024))
        unit = "gb"
    elseif rssKb >= 1024 then
        num = string.format("%.0f", mb)
        unit = "mb"
    else
        num = tostring(rssKb)
        unit = "kb"
    end
    local colorFn = memoryColor(mb)
    return colorFn(num .. " " .. unit), num .. " " .. unit
end

local function formatUptime(etime: string): (string, string)
    local raw = TimeHelpers.formatUptime(etime)
    local coloredParts = {}
    for part in raw:gmatch("%S+") do
        local n, u = part:match("^(%d+)(%a)$")
        if n and u then
            table.insert(coloredParts, n .. Colors.dim(u))
        else
            table.insert(coloredParts, part)
        end
    end
    return table.concat(coloredParts, " "), raw
end

type TableRow = {
    raw: { string },
    colored: { string },
}

local function renderTable(headers: { string }, rows: { TableRow })
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
-- Mock data
------------------------------------------------------------------------------------------

type MockEntry = {
    memory: number,
    pid: string,
    placeId: string?,
    status: string,
    highlight: string?,
    uptime: string,
}

local MOCK_DATA: { MockEntry } = {
    { pid = "10001", memory = 384 * 1024, uptime = "02:15", placeId = nil, status = "Start Page", highlight = nil },
    {
        pid = "10002",
        memory = 620 * 1024,
        uptime = "05:30",
        placeId = nil,
        status = "Edit (temp-a1b2c3d4.rbxl)",
        highlight = "temp-a1b2c3d4.rbxl",
    },
    {
        pid = "10003",
        memory = 890 * 1024,
        uptime = "12:45",
        placeId = "13435539729",
        status = "Team Create (Plugin Sandbox)",
        highlight = "Plugin Sandbox",
    },
    {
        pid = "10004",
        memory = 1200 * 1024,
        uptime = "01:30:00",
        placeId = "85939162614693",
        status = "Edit (test game :))",
        highlight = "test game :)",
    },
    {
        pid = "10005",
        memory = 2048 * 1024,
        uptime = "02:15:30",
        placeId = "9430488623",
        status = "Edit (My Obby)",
        highlight = "My Obby",
    },
    {
        pid = "10006",
        memory = 3200 * 1024,
        uptime = "03:45:12",
        placeId = nil,
        status = "Edit (New place)",
        highlight = nil,
    },
    {
        pid = "10007",
        memory = 4500 * 1024,
        uptime = "05:00:00",
        placeId = "1234567890",
        status = "Edit (Big RPG World)",
        highlight = "Big RPG World",
    },
    {
        pid = "10008",
        memory = 5800 * 1024,
        uptime = "1-02:30:15",
        placeId = "9876543210",
        status = "Team Create (Massive Game)",
        highlight = "Massive Game",
    },
    {
        pid = "10009",
        memory = 6500 * 1024,
        uptime = "2-12:00:00",
        placeId = "5555555555",
        status = "Edit (Memory Hog)",
        highlight = "Memory Hog",
    },
    {
        pid = "10010",
        memory = 8192 * 1024,
        uptime = "3-06:45:30",
        placeId = "1111111111",
        status = "Edit (Leaking Place)",
        highlight = "Leaking Place",
    },
}

------------------------------------------------------------------------------------------
-- Build and render
------------------------------------------------------------------------------------------

local function demoList()
    local rows: { TableRow } = {}

    for _, entry in MOCK_DATA do
        local coloredMem, rawMem = formatMemory(entry.memory)
        local coloredUptime, rawUptime = formatUptime(entry.uptime)
        local rawPlaceId = entry.placeId or "nil"
        local coloredPlaceId = if entry.placeId then Colors.numericId(entry.placeId) else Colors.nil_("nil")

        local coloredStatus = entry.status
        if entry.highlight then
            local escaped = entry.highlight:gsub("([%.%-%+%*%?%^%$%(%)%[%]%%])", "%%%1")
            coloredStatus = coloredStatus:gsub(escaped, Colors.placeName(entry.highlight), 1)
        end

        table.insert(rows, {
            raw = {
                entry.pid,
                rawMem,
                rawUptime,
                rawPlaceId,
                entry.status,
            },
            colored = {
                entry.pid,
                coloredMem,
                coloredUptime,
                coloredPlaceId,
                coloredStatus,
            },
        })
    end

    local count = tostring(#MOCK_DATA)
    print(
        `There {if #MOCK_DATA == 1 then "is" else "are"} {Colors.count(count)} Roblox Studio {if #MOCK_DATA == 1
            then "instance"
            else "instances"} running.`
    )
    print()
    renderTable({ "Process ID", "Memory", "Uptime", "Place ID", "Status" }, rows)
end

demoList()
