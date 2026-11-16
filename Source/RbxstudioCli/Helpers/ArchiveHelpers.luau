--[[

ArchiveHelpers

Extracts archive files using the tools each platform ships with, so downloads can
be published as zips the way Rokit expects.

--]]

const process = require("@lune/process")

const IS_WINDOWS = process.os == "windows"

const ArchiveHelpers = {}

--[[
    Extracts a zip archive to the given destination directory, overwriting any
    files already there.
]]
function ArchiveHelpers.extractZip(zipPath: string, destDir: string): boolean
    const result = if IS_WINDOWS
        then process.exec("powershell", {
            "-Command",
            `Expand-Archive -Path '{zipPath}' -DestinationPath '{destDir}' -Force`,
        })
        else process.exec("unzip", { "-o", zipPath, "-d", destDir })
    return result.ok
end

return ArchiveHelpers
