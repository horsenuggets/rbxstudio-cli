--[[

PlaceHelpers

Utilities for working with Roblox place IDs and the Roblox API. Provides
shared logic for resolving universe IDs and place names from place IDs.

--]]

local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local PlaceHelpers = {}

local cachedCookie: string? = nil

-- Retrieves the .ROBLOSECURITY cookie from the macOS Keychain.
-- Returns nil on non-macOS platforms or if the cookie is not found.
local function getRobloSecurity(): string?
    if cachedCookie then
        return cachedCookie
    end

    if process.os ~= "macos" then
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

    cachedCookie = hexResult.stdout:match("_|WARNING[^<]+")
    return cachedCookie
end

local function authHeaders(): { [string]: string }
    local headers: { [string]: string } = {}
    local cookie = getRobloSecurity()
    if cookie then
        headers["Cookie"] = ".ROBLOSECURITY=" .. cookie
    end
    return headers
end

-- Resolves the universe ID for a place ID using the public Roblox API
function PlaceHelpers.getUniverseId(placeId: string): string?
    assert(type(placeId) == "string")

    local ok, response = pcall(net.request, {
        url = `https://apis.roblox.com/universes/v1/places/{placeId}/universe`,
        method = "GET",
    })

    if ok and response.ok then
        local success, data = pcall(serde.decode, "json" :: "json", response.body)
        if success and data and data.universeId then
            return tostring(data.universeId)
        end
    end

    return nil
end

-- Resolves the place name for a place ID using the Roblox API.
-- Uses the .ROBLOSECURITY cookie for private places.
-- Returns nil if the request fails.
function PlaceHelpers.getPlaceName(placeId: string): string?
    assert(type(placeId) == "string")

    local ok, response = pcall(net.request, {
        url = `https://games.roblox.com/v1/games/multiget-place-details?placeIds={placeId}`,
        method = "GET",
        headers = authHeaders(),
    })

    if ok and response.ok then
        local success, data = pcall(serde.decode, "json" :: "json", response.body)
        if success and type(data) == "table" and #data > 0 then
            return data[1].name
        end
    end

    return nil
end

return PlaceHelpers
