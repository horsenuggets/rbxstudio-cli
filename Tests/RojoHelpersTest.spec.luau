--[[

RojoHelpersTest.spec

Tests for resolving Rojo release tags, versions, and asset names.

--]]

const Commandline = require("@packages/Commandline")
const RojoHelpers = require("@rbxstudiocli/Helpers/RojoHelpers")
const Testable = require("@devpackages/Testable")
const describe, expect, it = Testable.describe, Testable.expect, Testable.it

const SelfUpdate = Commandline.Toolkit._SelfUpdate

-- The zipped assets published by the horsenuggets/rojo 7.7.1-horse.2.9 release.
const PUBLISHED_ASSETS = {
    "rojo-7.7.1-horse.2.9-linux-aarch64.zip",
    "rojo-7.7.1-horse.2.9-linux-x86_64.zip",
    "rojo-7.7.1-horse.2.9-macos-aarch64.zip",
    "rojo-7.7.1-horse.2.9-macos-x86_64.zip",
    "rojo-7.7.1-horse.2.9-windows-aarch64.zip",
    "rojo-7.7.1-horse.2.9-windows-x86_64.zip",
}

return function()
    describe("getAssetName", function()
        it("should name a published asset for every supported platform", function()
            const seen = {}
            for _, os in { "linux", "macos", "windows" } do
                for _, architecture in { "aarch64", "x86_64" } do
                    const platformSuffix = SelfUpdate.getPlatformSuffix(os, architecture)
                    const assetName = RojoHelpers.getAssetName("7.7.1-horse.2.9", platformSuffix)
                    expect(table.find(PUBLISHED_ASSETS, assetName)).never.to.equal(nil)
                    expect(seen[assetName]).to.equal(nil)
                    seen[assetName] = true
                end
            end
        end)

        it("should use the published architecture names on Apple Silicon", function()
            expect(RojoHelpers.getAssetName("7.7.1-horse.2.9", "macos-arm64")).to.equal(
                "rojo-7.7.1-horse.2.9-macos-aarch64.zip"
            )
        end)

        it("should drop a leading v from the version", function()
            expect(RojoHelpers.getAssetName("v7.7.1-horse.2.6", "linux-x64")).to.equal(
                "rojo-7.7.1-horse.2.6-linux-x86_64.zip"
            )
        end)
    end)

    describe("stripVersionPrefix", function()
        it("should remove a leading v", function()
            expect(RojoHelpers.stripVersionPrefix("v7.7.1-horse.2.6")).to.equal("7.7.1-horse.2.6")
        end)

        it("should leave an unprefixed version unchanged", function()
            expect(RojoHelpers.stripVersionPrefix("7.7.1-horse.2.9")).to.equal("7.7.1-horse.2.9")
        end)
    end)

    describe("getReleaseTags", function()
        it("should try the unprefixed tag before the v-prefixed tag", function()
            const tags = RojoHelpers.getReleaseTags("7.7.1-horse.2.9")
            expect(#tags).to.equal(2)
            expect(tags[1]).to.equal("7.7.1-horse.2.9")
            expect(tags[2]).to.equal("v7.7.1-horse.2.9")
        end)

        it("should return the same tags whether or not the version has a v prefix", function()
            const prefixed = RojoHelpers.getReleaseTags("v7.7.1-horse.2.6")
            const bare = RojoHelpers.getReleaseTags("7.7.1-horse.2.6")
            expect(#prefixed).to.equal(#bare)
            for index, tag in bare do
                expect(prefixed[index]).to.equal(tag)
            end
        end)

        it("should return the same result when called twice", function()
            const first = RojoHelpers.getReleaseTags("7.7.1-horse.2.9")
            const second = RojoHelpers.getReleaseTags("7.7.1-horse.2.9")
            expect(first[1]).to.equal(second[1])
            expect(first[2]).to.equal(second[2])
        end)
    end)
end
