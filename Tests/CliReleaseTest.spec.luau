--[[

CliReleaseTest.spec

Tests how a release asset is chosen for a platform and how the folder beside the
installed binary is found, without touching the network or the filesystem.

--]]

const CliRelease = require("@rbxstudiocli/Helpers/CliRelease")

const ARCHIVE = "rbxstudio-macos-aarch64.zip"
const BINARY = "rbxstudio-macos-aarch64"

return function()
    describe("selectAsset", function()
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
