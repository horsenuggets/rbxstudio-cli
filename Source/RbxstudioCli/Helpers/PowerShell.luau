--[[

PowerShell

Builds PowerShell command text from values that come from the machine, such as
paths under a user profile, so a name like "O'Brien" cannot break the command.

--]]

const PowerShell = {}

--[[
    Wraps a value in a single-quoted PowerShell literal. Nothing is expanded
    inside single quotes, and an embedded quote is written by doubling it.
]]
function PowerShell.quote(value: string): string
    assert(type(value) == "string")

    return `'{string.gsub(value, "'", "''")}'`
end

--[[
    Builds the command that puts a folder at the front of the user PATH unless
    it is already there. The folder is compared as plain text, since -like would
    read brackets in a folder name as wildcards.
]]
function PowerShell.addToUserPathCommand(directory: string): string
    assert(type(directory) == "string")

    return table.concat({
        `$d = {PowerShell.quote(directory)};`,
        "$p = [Environment]::GetEnvironmentVariable('PATH', 'User');",
        "if (-not $p -or -not $p.ToLower().Contains($d.ToLower()))",
        "{ [Environment]::SetEnvironmentVariable('PATH', $d + ';' + $p, 'User') }",
    }, " ")
end

return PowerShell
