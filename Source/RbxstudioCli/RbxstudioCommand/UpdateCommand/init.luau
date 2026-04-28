--[[

UpdateCommand

Updates the rbxstudio CLI and bundled Rojo binary to the latest versions.
Downloads platform-appropriate binaries from GitHub releases and replaces
the current ones in-place.

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local RojoHelpers = require("@rbxstudiocli/Helpers/RojoHelpers")
local __ROJO_VERSION__ = require("@rbxstudiocli/RbxstudioCommand/__ROJO_VERSION__")
local __VERSION__ = require("@rbxstudiocli/RbxstudioCommand/__VERSION__")
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local SelfUpdate = Commandline.Toolkit._SelfUpdate

local NAME = "rbxstudio"
local REPOSITORY = "horsenuggets/rbxstudio-cli"

local IS_WINDOWS = process.os == "windows"
local EXECUTABLE_SUFFIX = if IS_WINDOWS then ".exe" else ""

local function getRelease(targetVersion: string?): { version: string, assets: { any } }?
    local url: string
    if targetVersion then
        url = `https://api.github.com/repos/{REPOSITORY}/releases/tags/{targetVersion}`
    else
        url = `https://api.github.com/repos/{REPOSITORY}/releases/latest`
    end

    local ok, response = pcall(net.request, {
        url = url,
        method = "GET",
        headers = { ["User-Agent"] = NAME },
    })
    if not ok or not response.ok then
        return nil
    end

    local success, data = pcall(serde.decode, "json" :: "json", response.body)
    if not success then
        return nil
    end

    return {
        version = data.tag_name,
        assets = data.assets or {},
    }
end

return Commandline.Command.new({
    Name = "update",
    Description = `Update {NAME} CLI to the latest version.`,
    Flags = {
        Commandline.Flag.new({
            Name = "version",
            Shorthand = "v",
            Description = "Install a specific version instead of the latest.",
            Type = "string",
        }),
    },
    Impl = function(args)
        local targetVersion = args.version

        -- Clean up leftover .old file from previous Windows update
        local currentExe = SelfUpdate.findExecutable(NAME)
        if currentExe then
            SelfUpdate.cleanupOldBinary(currentExe)
        end

        -- Update rbxstudio binary
        print(`Checking for updates to {Chalk.bold(Chalk.blueBright(NAME))}...`)

        local release = getRelease(targetVersion)
        if not release then
            print(
                Chalk.red(
                    if targetVersion then `Version "{targetVersion}" not found.` else "Failed to fetch latest release."
                )
            )
            process.exit(1)
        end

        local newVersion = release.version
        if newVersion == __VERSION__ and not targetVersion then
            print(`Already on the latest version ({Chalk.bold(Chalk.blueBright(__VERSION__))}).`)
        else
            print(`Updating from {Chalk.dim(__VERSION__)} to {Chalk.bold(Chalk.blueBright(newVersion))}...`)

            -- Find download URL for current platform
            local platformSuffix = SelfUpdate.getPlatformSuffix()
            local assetName = `{NAME}-{platformSuffix}{EXECUTABLE_SUFFIX}`
            local downloadUrl: string? = nil

            for _, asset in release.assets do
                if asset.name == assetName then
                    downloadUrl = asset.browser_download_url
                    break
                end
            end

            if not downloadUrl then
                print(Chalk.red(`Binary for {platformSuffix} not found in release {newVersion}.`))
                process.exit(1)
            end

            -- Download new binary
            local dlOk, dlResponse = pcall(net.request, {
                url = downloadUrl,
                method = "GET",
                headers = { ["User-Agent"] = NAME },
            })

            if not dlOk or not dlResponse.ok then
                print(Chalk.red("Failed to download update."))
                process.exit(1)
            end

            -- Replace the current binary in-place
            if currentExe then
                SelfUpdate.replaceBinary({
                    targetPath = currentExe,
                    newContents = dlResponse.body,
                })
                print(Chalk.bold(Chalk.greenBright(`Updated to {newVersion}!`)))
            else
                print(Chalk.red(`Could not find {NAME} on PATH. Run "{NAME} install" first.`))
                process.exit(1)
            end
        end

        -- Update bundled Rojo
        print()
        local rojoBinPath = RojoHelpers.getRojoBinPath()
        local rojoInstalled = fs.isFile(rojoBinPath)

        if rojoInstalled then
            print(`Updating bundled {Chalk.bold(Chalk.blueBright("Rojo"))} to {Chalk.dim(__ROJO_VERSION__)}...`)
        else
            print(`Installing bundled {Chalk.bold(Chalk.blueBright("Rojo"))} {Chalk.dim(__ROJO_VERSION__)}...`)
        end

        local binDir = string.match(rojoBinPath, "(.+)/[^/]+$") or ""
        if not fs.isDir(binDir) then
            fs.writeDir(binDir)
        end

        if RojoHelpers.downloadRojo(binDir, __ROJO_VERSION__) then
            print(`Installed Rojo to {Chalk.dim(rojoBinPath)}.`)
        else
            print(Chalk.yellow("Rojo update failed. You can still use a system-installed Rojo."))
        end
    end,
})
