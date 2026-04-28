--[[

CookieHelpers

Retrieves the .ROBLOSECURITY cookie for authenticating with the Roblox API.
Reads from a cached file first to avoid macOS Keychain password prompts,
falling back to the Keychain on first use and caching the result for
subsequent runs.

--]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local IS_MACOS = process.os == "macos"
local HOME_DIR = process.env.HOME or ""
local COOKIE_PATH = HOME_DIR .. "/.rbxstudio-cli/.cookie"

local CookieHelpers = {}

local cachedCookie: string? = nil

-- Extracts the .ROBLOSECURITY cookie value from a macOS Keychain entry.
-- The cookie is stored as a hex-encoded plist by Roblox Studio.
local function readFromKeychain(): string?
    if not IS_MACOS then
        return nil
    end

    local result = process.exec("security", {
        "find-generic-password",
        "-a",
        "https://www.roblox.com/:SharedROBLOSECURITYForStudio",
        "-w",
    })

    if not result.ok then
        return nil
    end

    local hexResult = process.exec("sh", {
        "-c",
        "echo '" .. result.stdout:gsub("%s+", "") .. "' | xxd -r -p | plutil -convert xml1 -o - -",
    })

    if not hexResult.ok then
        return nil
    end

    return hexResult.stdout:match("_|WARNING[^<]+")
end

-- Reads the cached cookie from ~/.rbxstudio-cli/.cookie
local function readFromFile(): string?
    if not fs.isFile(COOKIE_PATH) then
        return nil
    end

    local content = fs.readFile(COOKIE_PATH)
    local cookie = content:match("^%s*(.-)%s*$")
    if cookie and #cookie > 0 then
        return cookie
    end

    return nil
end

-- Saves the cookie to ~/.rbxstudio-cli/.cookie with restrictive permissions
local function saveToFile(cookie: string)
    local dir = COOKIE_PATH:match("(.+)/[^/]+$")
    if dir and not fs.isDir(dir) then
        fs.writeDir(dir)
    end

    fs.writeFile(COOKIE_PATH, cookie .. "\n")

    if not (process.os == "windows") then
        process.exec("chmod", { "600", COOKIE_PATH })
    end
end

--[[
    Retrieves the .ROBLOSECURITY cookie. Checks sources in order:

    1. In-memory cache (same process)
    2. File cache at ~/.rbxstudio-cli/.cookie (avoids Keychain prompt)
    3. macOS Keychain (prompts on first access, then cached to file)

    Returns nil if the cookie cannot be found from any source.
]]
function CookieHelpers.getRobloxSecurity(): string?
    if cachedCookie then
        return cachedCookie
    end

    -- Try file cache first (no Keychain prompt)
    local fileCookie = readFromFile()
    if fileCookie then
        cachedCookie = fileCookie
        return cachedCookie
    end

    -- Fall back to Keychain (may prompt for password)
    local keychainCookie = readFromKeychain()
    if keychainCookie then
        cachedCookie = keychainCookie
        saveToFile(keychainCookie)
        return cachedCookie
    end

    return nil
end

--[[
    Returns HTTP headers with the .ROBLOSECURITY cookie set, or empty
    headers if the cookie is not available.
]]
function CookieHelpers.authHeaders(): { [string]: string }
    local headers: { [string]: string } = {}
    local cookie = CookieHelpers.getRobloxSecurity()
    if cookie then
        headers["Cookie"] = ".ROBLOSECURITY=" .. cookie
    end
    return headers
end

return CookieHelpers
