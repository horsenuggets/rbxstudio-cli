--[[

CookieHelpers

Retrieves the .ROBLOSECURITY cookie for authenticating with the Roblox API.
Reads from a cached file first to avoid macOS Keychain password prompts,
falling back to the Keychain on first use and caching the result for
subsequent runs. A cached cookie that Roblox rejects is dropped and read from
the Keychain again.

--]]

const fs = require("@lune/fs")
const net = require("@lune/net")
const process = require("@lune/process")

const IS_MACOS = process.os == "macos"
const HOME_DIR = process.env.HOME or ""
const COOKIE_PATH = HOME_DIR .. "/.rbxstudio-cli/.cookie"

const CookieHelpers = {}

local cachedCookie: string? = nil
local cookieSource: "File" | "Keychain" | "None" = "None"

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
        "-w"
    })

    if not result.ok then
        return nil
    end

    const hexResult = process.exec("sh", {
        "-c",
        "echo '" .. result.stdout:gsub("%s+", "") .. "' | xxd -r -p | plutil -convert xml1 -o - -"
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

-- Writes the cookie into a uniquely named owner-only file and renames it over
-- the cache. The secret only ever passes through a file this process created,
-- so another run deleting or replacing the cache cannot loosen its permissions.
const SAVE_SCRIPT = 'umask 077 && tmp=$(mktemp "$1.XXXXXX") && cat > "$tmp" && mv -f "$tmp" "$1"'

-- Saves the cookie to ~/.rbxstudio-cli/.cookie, readable only by its owner.
const function saveToFile(cookie: string)
    const dir = COOKIE_PATH:match("(.+)/[^/]+$")
    if dir and not fs.isDir(dir) then
        fs.writeDir(dir)
    end

    if process.os == "windows" then
        -- A user profile is already private to its owner on Windows.
        fs.writeFile(COOKIE_PATH, cookie .. "\n")
        return
    end

    process.exec("sh", { "-c", SAVE_SCRIPT, "sh", COOKIE_PATH }, {
        stdio = { stdin = cookie .. "\n" }
    })
end

--[[
    Decides whether a failed request is worth retrying with a fresh cookie. Only
    a rejected cookie that came from the file cache can be stale, since one read
    from the Keychain a moment ago is already the newest there is.
]]
function CookieHelpers.shouldRefresh(statusCode: number, cookieSource: "File" | "Keychain" | "None"): boolean
    return statusCode == 401 and cookieSource == "File"
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
        cookieSource = "File"
        return cachedCookie
    end

    -- Fall back to Keychain (may prompt for password)
    const keychainCookie = readFromKeychain()
    if keychainCookie then
        cachedCookie = keychainCookie
        cookieSource = "Keychain"
        saveToFile(keychainCookie)
        return cachedCookie
    end

    return nil
end

--[[
    Drops the cached cookie from memory and disk, so the next lookup reads the
    Keychain again. Used when Roblox rejects the cached cookie, which happens
    after Studio rotates its session or the user switches accounts.
]]
function CookieHelpers.invalidate()
    cachedCookie = nil
    cookieSource = "None"
    if fs.isFile(COOKIE_PATH) then
        fs.removeFile(COOKIE_PATH)
    end
end

--[[
    Sends a GET request with the cookie attached. When Roblox rejects a cookie
    that came from the file cache, the cache is dropped and the request is sent
    once more with the Keychain's cookie. Returns nil if the request itself fails.
]]
function CookieHelpers.get(url: string): net.FetchResponse?
    const function send(): net.FetchResponse?
        const ok, response = pcall(net.request, {
            url = url,
            method = "GET",
            headers = CookieHelpers.authHeaders()
        })
        return if ok then response else nil
    end

    const response = send()
    if response and CookieHelpers.shouldRefresh(response.statusCode, cookieSource) then
        CookieHelpers.invalidate()
        return send()
    end
    return response
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
