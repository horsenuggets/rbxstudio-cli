--[[

classifyTarget

Classifies an open command target as either a place ID or a file path.
Returns a table with the classification type and the normalized value.

--]]

local fs = require("@lune/fs")

export type Classification = {
    Type: "placeid" | "file",
    Value: string,
}

local function classifyTarget(target: string): (Classification?, string?)
    assert(type(target) == "string")

    if target == "" then
        return nil, "Target cannot be empty."
    end

    -- Pure digits means place ID
    if target:match("^%d+$") then
        return { Type = "placeid", Value = target }, nil
    end

    -- Known file extensions
    if target:match("%.rbxlx?$") or target:match("%.project%.json$") then
        return { Type = "file", Value = target }, nil
    end

    -- Check if path exists on disk
    if fs.isFile(target) or fs.isDir(target) then
        return { Type = "file", Value = target }, nil
    end

    return nil,
        `Could not determine target type for "{target}". Expected a place ID (digits), a .rbxl/.rbxlx file, a .project.json file, or an existing path.`
end

return classifyTarget
