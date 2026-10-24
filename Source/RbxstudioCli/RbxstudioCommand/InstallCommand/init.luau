--[[

InstallCommand

Installs the rbxstudio CLI and bundled Rojo binary to ~/.rbxstudio-cli/bin/
and adds the directory to PATH. Downloads the platform-appropriate Rojo binary
from GitHub releases.

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
const INSTALL_DIR = ".rbxstudio-cli"
const REPOSITORY = "horsenuggets/rbxstudio-cli"

const IS_WINDOWS = process.os == "windows"
const HOME_DIR = if IS_WINDOWS then process.env.USERPROFILE or "" else process.env.HOME or ""
const INSTALL_PATH = HOME_DIR .. "/" .. INSTALL_DIR
const BIN_DIR = INSTALL_PATH .. "/bin"
const EXECUTABLE_SUFFIX = if IS_WINDOWS then ".exe" else ""
const PATH_EXPORT_COMMENT = "# Added by " .. NAME
const PATH_EXPORT_LINE = `export PATH="{BIN_DIR}:$PATH"`
const SHELL_CONFIGS = {
    { file = ".bash_profile", shell = "bash" },
    { file = ".bashrc", shell = "bash" },
    { file = ".zshrc", shell = "zsh" },
}
const XSH_PATH_FILE = HOME_DIR .. "/.path"

const function downloadLatestBinary(destPath: string): boolean
    const url = `https://api.github.com/repos/{REPOSITORY}/releases/latest`
    const ok, response = pcall(net.request, {
        url = url,
        method = "GET",
        headers = { ["User-Agent"] = NAME },
    })

    if not ok or not response.ok then
        print(Chalk.red("Failed to fetch latest release."))
        return false
    end

    const success, release = pcall(serde.decode, "json" :: "json", response.body)
    if not success then
        print(Chalk.red("Failed to parse release data."))
        return false
    end

    const platformSuffix = SelfUpdate.getPlatformSuffix()
    const assetName = `{NAME}-{platformSuffix}{EXECUTABLE_SUFFIX}`
    local downloadUrl: string? = nil

    for _, asset in release.assets or {} do
        if asset.name == assetName then
            downloadUrl = asset.browser_download_url
            break
        end
    end

    if not downloadUrl then
        print(Chalk.red(`Asset "{assetName}" not found in latest release.`))
        return false
    end

    const dlOk, dlResponse = pcall(net.request, {
        url = downloadUrl,
        method = "GET",
        headers = { ["User-Agent"] = NAME },
    })

    if not dlOk or not dlResponse.ok then
        print(Chalk.red("Failed to download binary."))
        return false
    end

    fs.writeFile(destPath, dlResponse.body)
    if not IS_WINDOWS then
        process.exec("chmod", { "+x", destPath })
    end

    return true
end

const function addToPath()
    if IS_WINDOWS then
        const psCmd = "$p = [Environment]::GetEnvironmentVariable('PATH','User');"
            .. " if ($p -notlike '*"
            .. BIN_DIR
            .. "*') { [Environment]::SetEnvironmentVariable('PATH', '"
            .. BIN_DIR
            .. ";' + $p, 'User') }"
        const result = process.exec("powershell", { "-Command", psCmd })
        if result.ok then
            print(`Added {Chalk.dim(BIN_DIR)} to user PATH.`)
        end
        return
    end

    -- Check for xsh-compatible .path file
    if fs.isFile(XSH_PATH_FILE) then
        local content = fs.readFile(XSH_PATH_FILE)
        if not string.find(content, BIN_DIR, 1, true) then
            if content ~= "" and not string.match(content, "\n$") then
                content ..= "\n"
            end
            content ..= BIN_DIR .. "\n"
            fs.writeFile(XSH_PATH_FILE, content)
            print(`Added {Chalk.dim(BIN_DIR)} to {Chalk.dim("~/.path")}.`)
        end
        return
    end

    -- Fall back to shell config files
    for _, config in SHELL_CONFIGS do
        const configPath = `{HOME_DIR}/{config.file}`
        if fs.isFile(configPath) then
            local content = fs.readFile(configPath)
            if not string.find(content, PATH_EXPORT_COMMENT, 1, true) then
                if content ~= "" and not string.match(content, "\n$") then
                    content ..= "\n"
                end
                content ..= "\n" .. PATH_EXPORT_COMMENT .. "\n" .. PATH_EXPORT_LINE .. "\n"
                fs.writeFile(configPath, content)
                print(`Added {Chalk.dim(NAME)} to {Chalk.dim("~/" .. config.file)}.`)
            end
        end
    end
end

return Commandline.Command.new({
    Name = "install",
    Description = `Install {NAME} CLI to ~/{INSTALL_DIR} and add to PATH.`,
    Impl = function()
        print(`Installing {Chalk.bold(Chalk.blueBright(NAME))} {Chalk.dim(__VERSION__)}...`)
        print()

        -- Create directory structure
        if not fs.isDir(INSTALL_PATH) then
            fs.writeDir(INSTALL_PATH)
        end
        if not fs.isDir(BIN_DIR) then
            fs.writeDir(BIN_DIR)
        end

        const binaryPath = `{BIN_DIR}/{NAME}{EXECUTABLE_SUFFIX}`

        -- Try to copy current running binary first
        const currentExe = SelfUpdate.findExecutable(NAME)
        if currentExe then
            const contents = fs.readFile(currentExe)
            fs.writeFile(binaryPath, contents)
            if not IS_WINDOWS then
                process.exec("chmod", { "+x", binaryPath })
            end
            print(`Copied executable to {Chalk.dim(binaryPath)}.`)
        else
            -- Download from GitHub releases
            print("Downloading binary...")
            if not downloadLatestBinary(binaryPath) then
                print(Chalk.red("Failed to install. Could not download binary."))
                process.exit(1)
            end
            print("Downloaded successfully.")
        end

        -- Download bundled Rojo
        print()
        print(`Installing bundled {Chalk.bold(Chalk.blueBright("Rojo"))} {Chalk.dim(__ROJO_VERSION__)}...`)
        if RojoHelpers.downloadRojo(BIN_DIR, __ROJO_VERSION__) then
            print(`Installed Rojo to {Chalk.dim(RojoHelpers.getRojoBinPath())}.`)
        else
            print(Chalk.yellow("Rojo installation failed. You can still use a system-installed Rojo."))
        end

        -- Add to PATH
        addToPath()

        print()
        print(Chalk.bold(Chalk.greenBright("Installation complete!")))
        print(Chalk.yellow("Restart your terminal for PATH changes to take effect."))
    end,
})
