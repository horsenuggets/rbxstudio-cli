--[[

UpdateCommand

Updates the rbxstudio CLI and bundled Rojo binary to the latest versions.
Downloads platform-appropriate binaries from GitHub releases and replaces
the current ones in-place.

--]]

const Chalk = require("@packages/Chalk")
const CliRelease = require("@rbxstudiocli/Helpers/CliRelease")
const Commandline = require("@packages/Commandline")
const RojoHelpers = require("@rbxstudiocli/Helpers/RojoHelpers")
const __ROJO_VERSION__ = require("@rbxstudiocli/RbxstudioCommand/__ROJO_VERSION__")
const __VERSION__ = require("@rbxstudiocli/RbxstudioCommand/__VERSION__")
const fs = require("@lune/fs")
const process = require("@lune/process")

const SelfUpdate = Commandline.Toolkit._SelfUpdate

const NAME = "rbxstudio"

return Commandline.Command.new({
    Name = "update",
    Description = `Update {NAME} CLI to the latest version.`,
    Flags = {
        Commandline.Flag.new({
            Name = "version",
            Shorthand = "v",
            Description = "Install a specific version instead of the latest.",
            Type = "string"
        })
    },
    Impl = function(_args, flags)
        const targetVersion: string? = flags.version and flags.version.Value

        -- Clean up leftover .old file from previous Windows update
        const currentExe = SelfUpdate.findExecutable(NAME)
        if currentExe then
            SelfUpdate.cleanupOldBinary(currentExe)
        end

        -- Update rbxstudio binary
        print(`Checking for updates to {Chalk.bold(Chalk.blueBright(NAME))}...`)

        const release = CliRelease.getRelease(targetVersion)
        if not release then
            print(
                Chalk.red(
                    if targetVersion
                        then `Version "{targetVersion}" not found for this platform.`
                        else "Failed to find a release for this platform."
                )
            )
            process.exit(1)
        end

        const newVersion = release.Version
        if newVersion == __VERSION__ and not targetVersion then
            print(`Already on the latest version ({Chalk.bold(Chalk.blueBright(__VERSION__))}).`)
        elseif not currentExe then
            print(Chalk.red(`Could not find {NAME} on PATH. Run "{NAME} install" first.`))
            process.exit(1)
        else
            print(`Updating from {Chalk.dim(__VERSION__)} to {Chalk.bold(Chalk.blueBright(newVersion))}...`)

            if not CliRelease.install(release, currentExe) then
                print(Chalk.red("Failed to download update."))
                process.exit(1)
            end

            print(Chalk.bold(Chalk.greenBright(`Updated to {newVersion}!`)))
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
    end
})
