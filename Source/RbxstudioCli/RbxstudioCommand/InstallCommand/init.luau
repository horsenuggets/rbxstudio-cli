--[[

InstallCommand

Installs the rbxstudio CLI and bundled Rojo binary to ~/.rbxstudio-cli/bin/
and adds the directory to PATH. Downloads the platform-appropriate Rojo binary
from GitHub releases.

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
local INSTALL_DIR = ".rbxstudio-cli"
local REPOSITORY = "horsenuggets/rbxstudio-cli"

local IS_WINDOWS = process.os == "windows"
local HOME_DIR = if IS_WINDOWS then process.env.USERPROFILE or "" else process.env.HOME or ""
local INSTALL_PATH = HOME_DIR .. "/" .. INSTALL_DIR
local BIN_DIR = INSTALL_PATH .. "/bin"
local EXECUTABLE_SUFFIX = if IS_WINDOWS then ".exe" else ""
local PATH_EXPORT_COMMENT = "# Added by " .. NAME
local PATH_EXPORT_LINE = `export PATH="{BIN_DIR}:$PATH"`
local SHELL_CONFIGS = {
    { file = ".bash_profile", shell = "bash" },
    { file = ".bashrc", shell = "bash" },
    { file = ".zshrc", shell = "zsh" },
}
local XSH_PATH_FILE = HOME_DIR .. "/.path"

local function downloadLatestBinary(destPath: string): boolean
    local url = `https://api.github.com/repos/{REPOSITORY}/releases/latest`
    local ok, response = pcall(net.request, {
        url = url,
        method = "GET",
        headers = { ["User-Agent"] = NAME },
    })

    if not ok or not response.ok then
        print(Chalk.red("Failed to fetch latest release."))
        return false
    end

    local success, release = pcall(serde.decode, "json" :: "json", response.body)
    if not success then
        print(Chalk.red("Failed to parse release data."))
        return false
    end

    local platformSuffix = SelfUpdate.getPlatformSuffix()
    local assetName = `{NAME}-{platformSuffix}{EXECUTABLE_SUFFIX}`
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

    local dlOk, dlResponse = pcall(net.request, {
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

local function addToPath()
    if IS_WINDOWS then
        local psCmd = "$p = [Environment]::GetEnvironmentVariable('PATH','User');"
            .. " if ($p -notlike '*"
            .. BIN_DIR
            .. "*') { [Environment]::SetEnvironmentVariable('PATH', '"
            .. BIN_DIR
            .. ";' + $p, 'User') }"
        local result = process.exec("powershell", { "-Command", psCmd })
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
        local configPath = `{HOME_DIR}/{config.file}`
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

        local binaryPath = `{BIN_DIR}/{NAME}{EXECUTABLE_SUFFIX}`

        -- Try to copy current running binary first
        local currentExe = SelfUpdate.findExecutable(NAME)
        if currentExe then
            local contents = fs.readFile(currentExe)
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
