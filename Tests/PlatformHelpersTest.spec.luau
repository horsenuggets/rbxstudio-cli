--[[

PlatformHelpersTest.spec

Tests mapping canonical platform suffixes from Commandline to the architecture names that
Rojo and rbxstudio releases publish.

--]]

const Commandline = require("@packages/Commandline")
const PlatformHelpers = require("@rbxstudiocli/Helpers/PlatformHelpers")
const Testable = require("@devpackages/Testable")
const describe, expect, it = Testable.describe, Testable.expect, Testable.it

const SelfUpdate = Commandline.Toolkit._SelfUpdate

-- Every architecture spelling mapped to the name releases publish for it.
const ARCHITECTURES = {
    { Input = "aarch64", Published = "aarch64" },
    { Input = "arm64", Published = "aarch64" },
    { Input = "x64", Published = "x86_64" },
    { Input = "x86_64", Published = "x86_64" },
}
const OPERATING_SYSTEMS = { "linux", "macos", "windows" }

return function()
    describe("getReleaseSuffix", function()
        for _, os in OPERATING_SYSTEMS do
            for _, architecture in ARCHITECTURES do
                it(`should map "{os}-{architecture.Input}" to "{os}-{architecture.Published}"`, function()
                    expect(PlatformHelpers.getReleaseSuffix(`{os}-{architecture.Input}`)).to.equal(
                        `{os}-{architecture.Published}`
                    )
                end)
            end
        end

        it("should return the same result when applied twice", function()
            for _, os in OPERATING_SYSTEMS do
                for _, architecture in ARCHITECTURES do
                    const once = PlatformHelpers.getReleaseSuffix(`{os}-{architecture.Input}`)
                    expect(PlatformHelpers.getReleaseSuffix(once)).to.equal(once)
                end
            end
        end)

        it("should leave an unknown architecture unchanged", function()
            expect(PlatformHelpers.getReleaseSuffix("linux-riscv64")).to.equal("linux-riscv64")
        end)

        it("should leave a suffix without an architecture unchanged", function()
            expect(PlatformHelpers.getReleaseSuffix("linux")).to.equal("linux")
        end)

        it("should map the canonical suffixes Commandline returns for Lune architectures", function()
            for _, os in OPERATING_SYSTEMS do
                for _, architecture in { "aarch64", "x86_64" } do
                    const canonical = SelfUpdate.getPlatformSuffix(os, architecture)
                    expect(PlatformHelpers.getReleaseSuffix(canonical)).to.equal(`{os}-{architecture}`)
                end
            end
        end)

        it("should reject a non-string suffix", function()
            expect(function()
                PlatformHelpers.getReleaseSuffix(nil :: any)
            end).to.throw()
        end)
    end)
end
