#!/usr/bin/env -S lune run

--[[

DemoList

Renders a mock list table to preview the color scheme and memory
gradient across a range of values without needing running Studio
instances.

--]]

local Colors = require("@rbxstudiocli/Helpers/Colors")
local MemoryHelpers = require("@rbxstudiocli/Helpers/MemoryHelpers")
local TableHelpers = require("@rbxstudiocli/Helpers/TableHelpers")
local TimeHelpers = require("@rbxstudiocli/Helpers/TimeHelpers")

type MockEntry = {
    highlight: string?,
    memory: number,
    pid: string,
    placeId: string?,
    status: string,
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

local function demoList()
    local rows: { TableHelpers.TableRow } = {}

    for _, entry in MOCK_DATA do
        local coloredMem, rawMem = MemoryHelpers.format(entry.memory)
        local coloredUptime, rawUptime = TimeHelpers.formatUptimeColored(entry.uptime)
        local rawPlaceId = entry.placeId or "nil"
        local coloredPlaceId = if entry.placeId then Colors.numericId(entry.placeId) else Colors.nil_("nil")

        local coloredStatus = entry.status
        if entry.highlight then
            local escaped = entry.highlight:gsub("([%.%-%+%*%?%^%$%(%)%[%]%%])", "%%%1")
            coloredStatus = coloredStatus:gsub(escaped, Colors.projectName(entry.highlight), 1)
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
    TableHelpers.render({ "Process ID", "Memory", "Uptime", "Place ID", "Status" }, rows)
end

demoList()
