--[[

UpdateCommand

Updates the rbxstudio CLI and bundled Rojo binary to the latest versions.
Downloads platform-appropriate binaries from GitHub releases and replaces
the current ones in-place.

--]]

const Chalk = require("@packages/Chalk")
const Commandline = require("@packages/Commandline")
const RojoHelpers = require("@rbxstudiocli/Helpers/RojoHelpers")
const __ROJO_VERSION__ = require("@rbxstudiocli/RbxstudioCommand/__ROJO_VERSION__")
const __VERSION__ = require("@rbxstudiocli/RbxstudioCommand/__VERSION__")
const fs = require("@lune/fs")
const net = require("@lune/net")
const process = require("@lune/process")
const serde = require("@lune/serde")

const SelfUpdate = Commandline.Toolkit._SelfUpdate

const NAME = "rbxstudio"
const REPOSITORY = "horsenuggets/rbxstudio-cli"

const IS_WINDOWS = process.os == "windows"
const EXECUTABLE_SUFFIX = if IS_WINDOWS then ".exe" else ""

const function getRelease(targetVersion: string?): { version: string, assets: { any } }?
    local url: string
    if targetVersion then
        url = `https://api.github.com/repos/{REPOSITORY}/releases/tags/{targetVersion}`
    else
        url = `https://api.github.com/repos/{REPOSITORY}/releases/latest`
    end

    const ok, response = pcall(net.request, {
        url = url,
        method = "GET",
        headers = { ["User-Agent"] = NAME },
    })
    if not ok or not response.ok then
        return nil
    end

    const success, data = pcall(serde.decode, "json" :: "json", response.body)
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
        const targetVersion = args.version

        -- Clean up leftover .old file from previous Windows update
        const currentExe = SelfUpdate.findExecutable(NAME)
        if currentExe then
            SelfUpdate.cleanupOldBinary(currentExe)
        end

        -- Update rbxstudio binary
        print(`Checking for updates to {Chalk.bold(Chalk.blueBright(NAME))}...`)

        const release = getRelease(targetVersion)
        if not release then
            print(
                Chalk.red(
                    if targetVersion then `Version "{targetVersion}" not found.` else "Failed to fetch latest release."
                )
            )
            process.exit(1)
        end

        const newVersion = release.version
        if newVersion == __VERSION__ and not targetVersion then
            print(`Already on the latest version ({Chalk.bold(Chalk.blueBright(__VERSION__))}).`)
        else
            print(`Updating from {Chalk.dim(__VERSION__)} to {Chalk.bold(Chalk.blueBright(newVersion))}...`)

            -- Find download URL for current platform
            const platformSuffix = SelfUpdate.getPlatformSuffix()
            const assetName = `{NAME}-{platformSuffix}{EXECUTABLE_SUFFIX}`
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
            const dlOk, dlResponse = pcall(net.request, {
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
        const rojoBinPath = RojoHelpers.getRojoBinPath()
        const rojoInstalled = fs.isFile(rojoBinPath)

        if rojoInstalled then
            print(`Updating bundled {Chalk.bold(Chalk.blueBright("Rojo"))} to {Chalk.dim(__ROJO_VERSION__)}...`)
        else
            print(`Installing bundled {Chalk.bold(Chalk.blueBright("Rojo"))} {Chalk.dim(__ROJO_VERSION__)}...`)
        end

        const binDir = string.match(rojoBinPath, "(.+)/[^/]+$") or ""
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
