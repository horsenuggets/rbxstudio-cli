--[[

PlatformHelpers

Maps the canonical platform suffixes from Commandline (e.g., "macos-arm64") to the
architecture names that Rojo and rbxstudio releases publish (e.g., "macos-aarch64").
Those releases keep their historical names because Rokit and older installers already
download them, so the translation happens here instead of in the published assets.

--]]

const t = require("@packages/t")

const RELEASE_ARCHITECTURES = {
    arm64 = "aarch64",
    x64 = "x86_64"
}

const PlatformHelpers = {}

--[[
    Returns the platform suffix used in published release asset names. Suffixes that
    already use the published names pass through unchanged.

    Options:
    > platformSuffix - Platform suffix such as "macos-arm64" or "linux-x64"
]]
function PlatformHelpers.getReleaseSuffix(platformSuffix: string): string
    assert(t.string(platformSuffix))

    const os, architecture = string.match(platformSuffix, "^(.+)%-([^-]+)$")
    if not os or not architecture then
        return platformSuffix
    end

    return `{os}-{RELEASE_ARCHITECTURES[architecture] or architecture}`
end

return PlatformHelpers
