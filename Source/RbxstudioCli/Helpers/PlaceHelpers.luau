--[[

PlaceHelpers

Utilities for working with Roblox place IDs and the Roblox API. Provides
shared logic for resolving universe IDs and place names from place IDs.

--]]

const CookieHelpers = require("@rbxstudiocli/Helpers/CookieHelpers")
const net = require("@lune/net")
const serde = require("@lune/serde")

const PlaceHelpers = {}

-- Resolves the universe ID for a place ID using the public Roblox API
function PlaceHelpers.getUniverseId(placeId: string): string?
    assert(type(placeId) == "string")

    const ok, response = pcall(net.request, {
        url = `https://apis.roblox.com/universes/v1/places/{placeId}/universe`,
        method = "GET",
    })

    if ok and response.ok then
        const success, data = pcall(serde.decode, "json" :: "json", response.body)
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

    const ok, response = pcall(net.request, {
        url = `https://games.roblox.com/v1/games/multiget-place-details?placeIds={placeId}`,
        method = "GET",
        headers = CookieHelpers.authHeaders(),
    })

    if ok and response.ok then
        const success, data = pcall(serde.decode, "json" :: "json", response.body)
        if success and type(data) == "table" and #data > 0 then
            return data[1].name
        end
    end

    return nil
end

return PlaceHelpers
