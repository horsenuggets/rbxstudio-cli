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
    Highlight: string?,
    Memory: number,
    Pid: string,
    PlaceId: string?,
    Status: string,
    Uptime: string,
}

local MOCK_DATA: { MockEntry } = {
    { Pid = "10001", Memory = 384 * 1024, Uptime = "02:15", PlaceId = nil, Status = "Start Page", Highlight = nil },
    {
        Pid = "10002",
        Memory = 620 * 1024,
        Uptime = "05:30",
        PlaceId = nil,
        Status = "Edit (temp-a1b2c3d4.rbxl)",
        Highlight = "temp-a1b2c3d4.rbxl",
    },
    {
        Pid = "10003",
        Memory = 890 * 1024,
        Uptime = "12:45",
        PlaceId = "13435539729",
        Status = "Team Create (Plugin Sandbox)",
        Highlight = "Plugin Sandbox",
    },
    {
        Pid = "10004",
        Memory = 1200 * 1024,
        Uptime = "01:30:00",
        PlaceId = "85939162614693",
        Status = "Edit (test game :))",
        Highlight = "test game :)",
    },
    {
        Pid = "10005",
        Memory = 2048 * 1024,
        Uptime = "02:15:30",
        PlaceId = "9430488623",
        Status = "Edit (My Obby)",
        Highlight = "My Obby",
    },
    {
        Pid = "10006",
        Memory = 3200 * 1024,
        Uptime = "03:45:12",
        PlaceId = nil,
        Status = "Edit (New place)",
        Highlight = nil,
    },
    {
        Pid = "10007",
        Memory = 4500 * 1024,
        Uptime = "05:00:00",
        PlaceId = "1234567890",
        Status = "Edit (Big RPG World)",
        Highlight = "Big RPG World",
    },
    {
        Pid = "10008",
        Memory = 5800 * 1024,
        Uptime = "1-02:30:15",
        PlaceId = "9876543210",
        Status = "Team Create (Massive Game)",
        Highlight = "Massive Game",
    },
    {
        Pid = "10009",
        Memory = 6500 * 1024,
        Uptime = "2-12:00:00",
        PlaceId = "5555555555",
        Status = "Edit (Memory Hog)",
        Highlight = "Memory Hog",
    },
    {
        Pid = "10010",
        Memory = 8192 * 1024,
        Uptime = "3-06:45:30",
        PlaceId = "1111111111",
        Status = "Edit (Leaking Place)",
        Highlight = "Leaking Place",
    },
}

local function demoList()
    local rows: { TableHelpers.TableRow } = {}

    for _, entry in MOCK_DATA do
        local coloredMem, rawMem = MemoryHelpers.format(entry.Memory)
        local coloredUptime, rawUptime = TimeHelpers.formatUptimeColored(entry.Uptime)
        local rawPlaceId = entry.PlaceId or "nil"
        local coloredPlaceId = if entry.PlaceId then Colors.numericId(entry.PlaceId) else Colors.nil_("nil")

        local coloredStatus = entry.Status
        if entry.Highlight then
            local escaped = entry.Highlight:gsub("([%.%-%+%*%?%^%$%(%)%[%]%%])", "%%%1")
            coloredStatus = coloredStatus:gsub(escaped, Colors.projectName(entry.Highlight), 1)
        end

        table.insert(rows, {
            Raw = {
                entry.Pid,
                rawMem,
                rawUptime,
                rawPlaceId,
                entry.Status,
            },
            Colored = {
                entry.Pid,
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
