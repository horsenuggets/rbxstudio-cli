--[[

RojoHelpers

Utilities for managing the bundled Rojo binary. Handles resolving the Rojo
executable path (bundled or system), downloading platform-specific binaries
from GitHub releases, and extracting zip archives.

--]]

const Chalk = require("@packages/Chalk")
const Commandline = require("@packages/Commandline")
const fs = require("@lune/fs")
const net = require("@lune/net")
const process = require("@lune/process")
const serde = require("@lune/serde")

const SelfUpdate = Commandline.Toolkit._SelfUpdate

const IS_WINDOWS = process.os == "windows"
const HOME_DIR = if IS_WINDOWS then process.env.USERPROFILE or "" else process.env.HOME or ""
const BIN_DIR = HOME_DIR .. "/.rbxstudio-cli/bin"
const EXECUTABLE_SUFFIX = if IS_WINDOWS then ".exe" else ""

const ROJO_REPOSITORY = "horsenuggets/rojo"

const RojoHelpers = {}

--[[
    Returns the path where the bundled Rojo binary should be installed.
]]
function RojoHelpers.getRojoBinPath(): string
    return `{BIN_DIR}/rojo{EXECUTABLE_SUFFIX}`
end

--[[
    Resolves the Rojo binary path. Checks the bundled install location
    first, then falls back to PATH lookup. Returns nil if not found.
]]
function RojoHelpers.findRojo(): string?
    const bundledPath = RojoHelpers.getRojoBinPath()
    if fs.isFile(bundledPath) then
        return bundledPath
    end

    return SelfUpdate.findExecutable("rojo")
end

--[[
    Resolves the Rojo binary path, exiting with an error if not found.
]]
function RojoHelpers.resolveRojo(): string
    const path = RojoHelpers.findRojo()
    if path then
        return path
    end

    print(Chalk.red('Rojo not found. Install it with "rbxstudio install" or add it to your PATH.'))
    process.exit(1)
    return "" -- unreachable
end

--[[
    Extracts a zip archive to the given destination directory.
    Uses platform-appropriate tools (unzip on Unix, PowerShell on Windows).
]]
function RojoHelpers.extractZip(zipPath: string, destDir: string): boolean
    local result
    if IS_WINDOWS then
        result = process.exec("powershell", {
            "-Command",
            `Expand-Archive -Path '{zipPath}' -DestinationPath '{destDir}' -Force`,
        })
    else
        result = process.exec("unzip", { "-o", zipPath, "-d", destDir })
    end
    return result.ok
end

--[[
    Downloads and installs the Rojo binary from GitHub releases.

    Fetches the release matching the given version tag, finds the
    platform-appropriate zip asset, downloads it, extracts the binary,
    and places it in the target directory.

    Options:
    > binDir - Directory to install the Rojo binary into
    > version - Version tag to download (e.g., "7.7.0-rc.1-horse.0.7")
]]
function RojoHelpers.downloadRojo(binDir: string, version: string): boolean
    const tag = if string.sub(version, 1, 1) == "v" then version else `v{version}`
    const url = `https://api.github.com/repos/{ROJO_REPOSITORY}/releases/tags/{tag}`

    const ok, response = pcall(net.request, {
        url = url,
        method = "GET",
        headers = { ["User-Agent"] = "rbxstudio" },
    })

    if not ok or not response.ok then
        print(Chalk.yellow("Failed to fetch Rojo release."))
        return false
    end

    const success, release = pcall(serde.decode, "json" :: "json", response.body)
    if not success then
        print(Chalk.yellow("Failed to parse Rojo release data."))
        return false
    end

    -- Find the matching platform asset (zipped)
    const platformSuffix = SelfUpdate.getPlatformSuffix()
    const assetName = `rojo-{version}-{platformSuffix}.zip`
    local downloadUrl: string? = nil

    for _, asset in release.assets or {} do
        if asset.name == assetName then
            downloadUrl = asset.browser_download_url
            break
        end
    end

    if not downloadUrl then
        print(Chalk.yellow(`Rojo asset "{assetName}" not found in release.`))
        return false
    end

    -- Download the zip
    const dlOk, dlResponse = pcall(net.request, {
        url = downloadUrl,
        method = "GET",
        headers = { ["User-Agent"] = "rbxstudio" },
    })

    if not dlOk or not dlResponse.ok then
        print(Chalk.yellow("Failed to download Rojo binary."))
        return false
    end

    -- Write zip to temp location and extract
    const zipPath = `{binDir}/.rojo-download.zip`
    fs.writeFile(zipPath, dlResponse.body)

    const extracted = RojoHelpers.extractZip(zipPath, binDir)

    -- Clean up zip
    if fs.isFile(zipPath) then
        fs.removeFile(zipPath)
    end

    if not extracted then
        print(Chalk.yellow("Failed to extract Rojo archive."))
        return false
    end

    -- Make executable on Unix
    const rojoBinPath = `{binDir}/rojo{EXECUTABLE_SUFFIX}`
    if not IS_WINDOWS and fs.isFile(rojoBinPath) then
        process.exec("chmod", { "+x", rojoBinPath })
    end

    return true
end

return RojoHelpers
