--[[

ArchiveHelpers

Extracts archive files using the tools each platform ships with, so downloads can
be published as zips the way Rokit expects.

--]]

const PowerShell = require("./PowerShell")
const process = require("@lune/process")

const IS_WINDOWS = process.os == "windows"

const ArchiveHelpers = {}

--[[
    Builds the PowerShell command that extracts a zip. The archive is named with
    -LiteralPath, since -Path would read brackets in a folder name as wildcards.
]]
function ArchiveHelpers.expandArchiveCommand(zipPath: string, destDir: string): string
    const zip = PowerShell.quote(zipPath)
    const dest = PowerShell.quote(destDir)
    return `Expand-Archive -LiteralPath {zip} -DestinationPath {dest} -Force -ErrorAction Stop`
end

--[[
    Extracts a zip archive to the given destination directory, overwriting any
    files already there.
]]
function ArchiveHelpers.extractZip(zipPath: string, destDir: string): boolean
    const result = if IS_WINDOWS
        then process.exec("powershell", {
            "-Command",
            ArchiveHelpers.expandArchiveCommand(zipPath, destDir)
        })
        else process.exec("unzip", { "-o", zipPath, "-d", destDir })
    return result.ok
end

return ArchiveHelpers
