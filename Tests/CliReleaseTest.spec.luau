--[[

CliReleaseTest.spec

Tests how a release asset is chosen for a platform and how the folder beside the
installed binary is found, without touching the network or the filesystem.

--]]

const CliRelease = require("@rbxstudiocli/Helpers/CliRelease")
const Commandline = require("@packages/Commandline")
const PlatformHelpers = require("@rbxstudiocli/Helpers/PlatformHelpers")
const Testable = require("@devpackages/Testable")
const describe, expect, it = Testable.describe, Testable.expect, Testable.it

const SelfUpdate = Commandline.Toolkit._SelfUpdate

const ARCHIVE = "rbxstudio-macos-aarch64.zip"
const BINARY = "rbxstudio-macos-aarch64"
-- The zipped assets published by the rbxstudio-cli 1.0.3 release.
const PUBLISHED_ARCHIVES = {
    "rbxstudio-linux-aarch64.zip",
    "rbxstudio-linux-x86_64.zip",
    "rbxstudio-macos-aarch64.zip",
    "rbxstudio-macos-x86_64.zip",
    "rbxstudio-windows-aarch64.zip",
    "rbxstudio-windows-x86_64.zip",
}

return function()
    describe("selectAsset", function()
        it("should find a published archive from every canonical platform suffix", function()
            for _, os in { "linux", "macos", "windows" } do
                for _, architecture in { "aarch64", "x86_64" } do
                    const platformSuffix =
                        PlatformHelpers.getReleaseSuffix(SelfUpdate.getPlatformSuffix(os, architecture))
                    const executableSuffix = if os == "windows" then ".exe" else ""
                    const name, isArchive = CliRelease.selectAsset(PUBLISHED_ARCHIVES, platformSuffix, executableSuffix)
                    expect(name).to.equal(`rbxstudio-{os}-{architecture}.zip`)
                    expect(isArchive).to.equal(true)
                end
            end
        end)

        -- Every combination of the archive and the legacy binary being published.
        for bits = 0, 3 do
            const hasArchive = bit32.btest(bits, 1)
            const hasBinary = bit32.btest(bits, 2)

            it(`should choose correctly with archive {hasArchive} and binary {hasBinary}`, function()
                const names = { "rbxstudio-linux-x86_64.zip", "rbxstudio-linux-x86_64" }
                if hasBinary then
                    table.insert(names, BINARY)
                end
                if hasArchive then
                    table.insert(names, ARCHIVE)
                end

                const name, isArchive = CliRelease.selectAsset(names, "macos-aarch64", "")
                if hasArchive then
                    expect(name).to.equal(ARCHIVE)
                    expect(isArchive).to.equal(true)
                elseif hasBinary then
                    expect(name).to.equal(BINARY)
                    expect(isArchive).to.equal(false)
                else
                    expect(name).to.equal(nil)
                    expect(isArchive).to.equal(false)
                end
            end)
        end

        it("should use the executable suffix for a legacy Windows binary", function()
            const name, isArchive = CliRelease.selectAsset({ "rbxstudio-windows-x86_64.exe" }, "windows-x86_64", ".exe")
            expect(name).to.equal("rbxstudio-windows-x86_64.exe")
            expect(isArchive).to.equal(false)
        end)

        it("should not match another platform's assets", function()
            const name = CliRelease.selectAsset({ ARCHIVE, BINARY }, "macos-x86_64", "")
            expect(name).to.equal(nil)
        end)
    end)

    describe("parentDir", function()
        for _, case in
            {
                { "/home/a/.rbxstudio-cli/bin/rbxstudio", "/home/a/.rbxstudio-cli/bin" },
                { "C:\\Users\\a\\.rbxstudio-cli\\bin\\rbxstudio.exe", "C:\\Users\\a\\.rbxstudio-cli\\bin" },
                { "C:/Users/a\\bin/rbxstudio.exe", "C:/Users/a\\bin" },
                { "rbxstudio", "." },
            }
        do
            it(`should find the folder holding "{case[1]}"`, function()
                expect(CliRelease.parentDir(case[1])).to.equal(case[2])
            end)
        end
    end)
end
