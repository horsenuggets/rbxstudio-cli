--[[

CookieHelpers

Retrieves the .ROBLOSECURITY cookie for authenticating with the Roblox API.
Reads from a cached file first to avoid macOS Keychain password prompts,
falling back to the Keychain on first use and caching the result for
subsequent runs.

--]]

const fs = require("@lune/fs")
const process = require("@lune/process")

const IS_MACOS = process.os == "macos"
const HOME_DIR = process.env.HOME or ""
const COOKIE_PATH = HOME_DIR .. "/.rbxstudio-cli/.cookie"

const CookieHelpers = {}

local cachedCookie: string? = nil

-- Extracts the .ROBLOSECURITY cookie value from a macOS Keychain entry.
-- The cookie is stored as a hex-encoded plist by Roblox Studio.
const function readFromKeychain(): string?
    if not IS_MACOS then
        return nil
    end

    const result = process.exec("security", {
        "find-generic-password",
        "-a",
        "https://www.roblox.com/:SharedROBLOSECURITYForStudio",
        "-w",
    })

    if not result.ok then
        return nil
    end

    const hexResult = process.exec("sh", {
        "-c",
        "echo '" .. result.stdout:gsub("%s+", "") .. "' | xxd -r -p | plutil -convert xml1 -o - -",
    })

    if not hexResult.ok then
        return nil
    end

    return hexResult.stdout:match("_|WARNING[^<]+")
end

-- Reads the cached cookie from ~/.rbxstudio-cli/.cookie
const function readFromFile(): string?
    if not fs.isFile(COOKIE_PATH) then
        return nil
    end

    const content = fs.readFile(COOKIE_PATH)
    const cookie = content:match("^%s*(.-)%s*$")
    if cookie and #cookie > 0 then
        return cookie
    end

    return nil
end

-- Saves the cookie to ~/.rbxstudio-cli/.cookie with restrictive permissions
const function saveToFile(cookie: string)
    const dir = COOKIE_PATH:match("(.+)/[^/]+$")
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
    const fileCookie = readFromFile()
    if fileCookie then
        cachedCookie = fileCookie
        return cachedCookie
    end

    -- Fall back to Keychain (may prompt for password)
    const keychainCookie = readFromKeychain()
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
    const headers: { [string]: string } = {}
    const cookie = CookieHelpers.getRobloxSecurity()
    if cookie then
        headers["Cookie"] = ".ROBLOSECURITY=" .. cookie
    end
    return headers
end

return CookieHelpers
