--[[

CliRelease

Finds and installs the rbxstudio CLI from its GitHub releases. Releases publish
one zip per target, named "rbxstudio-<target>.zip", which is the layout Rokit
expects when installing the same release. Releases before 1.0.3 only publish a
bare binary, so those still install directly.

--]]

const ArchiveHelpers = require("./ArchiveHelpers")
const Commandline = require("@packages/Commandline")
const fs = require("@lune/fs")
const net = require("@lune/net")
const process = require("@lune/process")
const serde = require("@lune/serde")

const SelfUpdate = Commandline.Toolkit._SelfUpdate

const NAME = "rbxstudio"
const REPOSITORY = "horsenuggets/rbxstudio-cli"

const IS_WINDOWS = process.os == "windows"
const EXECUTABLE_SUFFIX = if IS_WINDOWS then ".exe" else ""

const CliRelease = {}

export type Release = {
    -- Archives need extracting; a legacy bare binary is written straight out.
    IsArchive: boolean,
    Version: string,
    DownloadUrl: string,
}

--[[
    Picks the asset for a platform from a release's asset names. The zip wins
    when both exist, and a release from before zips were published falls back
    to its bare binary. Returns the chosen name and whether it is an archive.
]]
function CliRelease.selectAsset(
    assetNames: { string },
    platformSuffix: string,
    executableSuffix: string
): (string?, boolean)
    const archiveName = `{NAME}-{platformSuffix}.zip`
    const binaryName = `{NAME}-{platformSuffix}{executableSuffix}`

    if table.find(assetNames, archiveName) then
        return archiveName, true
    elseif table.find(assetNames, binaryName) then
        return binaryName, false
    end
    return nil, false
end

--[[
    Returns the folder holding `path`, accepting both separators, since Windows
    reports the running executable with backslashes.
]]
function CliRelease.parentDir(path: string): string
    return string.match(path, "^(.*)[/\\][^/\\]+$") or "."
end

--[[
    Finds the release for this platform, from an exact tag when one is given.
    Returns nil when the release or its asset is missing.
]]
function CliRelease.getRelease(targetVersion: string?): Release?
    const url = if targetVersion
        then `https://api.github.com/repos/{REPOSITORY}/releases/tags/{targetVersion}`
        else `https://api.github.com/repos/{REPOSITORY}/releases/latest`

    const ok, response = pcall(net.request, {
        url = url,
        method = "GET",
        headers = { ["User-Agent"] = NAME },
    })
    if not ok or not response.ok then
        return nil
    end

    const decoded, data = pcall(serde.decode, "json" :: "json", response.body)
    if not decoded then
        return nil
    end

    const assets = data.assets or {}
    const assetNames = {}
    for _, asset in assets do
        table.insert(assetNames, asset.name)
    end

    const assetName, isArchive = CliRelease.selectAsset(assetNames, SelfUpdate.getPlatformSuffix(), EXECUTABLE_SUFFIX)
    for _, asset in assets do
        if asset.name == assetName then
            return {
                IsArchive = isArchive,
                Version = data.tag_name,
                DownloadUrl = asset.browser_download_url,
            }
        end
    end

    return nil
end

--[[
    Downloads the release's archive, extracts the binary, and writes it to
    `destPath` through SelfUpdate, which also marks it executable on Unix.
]]
function CliRelease.install(release: Release, destPath: string): boolean
    const ok, response = pcall(net.request, {
        url = release.DownloadUrl,
        method = "GET",
        headers = { ["User-Agent"] = NAME },
    })
    if not ok or not response.ok then
        return false
    end

    if not release.IsArchive then
        SelfUpdate.replaceBinary({
            targetPath = destPath,
            newContents = response.body,
        })
        return true
    end

    const parent = CliRelease.parentDir(destPath)
    const zipPath = `{parent}/.{NAME}-download.zip`
    const extractDir = `{parent}/.{NAME}-extract`

    fs.writeFile(zipPath, response.body)
    if fs.isDir(extractDir) then
        fs.removeDir(extractDir)
    end
    fs.writeDir(extractDir)

    const extracted = ArchiveHelpers.extractZip(zipPath, extractDir)
    const extractedPath = `{extractDir}/{NAME}{EXECUTABLE_SUFFIX}`
    const contents = if extracted and fs.isFile(extractedPath) then fs.readFile(extractedPath) else nil

    fs.removeFile(zipPath)
    fs.removeDir(extractDir)

    if contents == nil then
        return false
    end

    SelfUpdate.replaceBinary({
        targetPath = destPath,
        newContents = contents,
    })
    return true
end

return CliRelease
