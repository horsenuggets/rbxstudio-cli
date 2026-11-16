--[[

CliRelease

Finds and installs the rbxstudio CLI from its GitHub releases. Releases publish
one zip per target, named "rbxstudio-<target>.zip", which is the layout Rokit
expects when installing the same release.

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
    Version: string,
    DownloadUrl: string,
}

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

    const assetName = `{NAME}-{SelfUpdate.getPlatformSuffix()}.zip`
    for _, asset in data.assets or {} do
        if asset.name == assetName then
            return {
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

    const parent = string.match(destPath, "^(.*)/[^/]+$") or "."
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
