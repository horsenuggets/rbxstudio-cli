--[[

FileLauncherTest.spec

Tests for the message FileLauncher prints when it opens a place or project file.

--]]

const Commandline = require("@packages/Commandline")
const FileLauncher = require("@rbxstudiocli/Helpers/FileLauncher")
const Testable = require("@devpackages/Testable")
const describe, expect, it = Testable.describe, Testable.expect, Testable.it

return function()
    describe("FileLauncher.openingMessage", function()
        it("should name only the file on every platform", function()
            const terminal = Commandline.Terminal.new({ Color = false, Env = {} })
            const cases = {
                { "/tmp/game/LiveEdit.52876.rbxl", "LiveEdit.52876.rbxl" },
                { "C:\\Users\\user\\AppData\\Local\\Temp\\Place.rbxl", "Place.rbxl" },
                { "default.project.json", "default.project.json" },
                { "/tmp/My Place.rbxlx", "My·Place.rbxlx" }
            }
            for _, case in cases do
                expect(FileLauncher.openingMessage(terminal, case[1])).to.equal(`Opening {case[2]}...`)
            end
        end)

        it("should paint the file name in the Roblox path style", function()
            const terminal = Commandline.Terminal.new({ Color = true, Env = {} })
            expect(FileLauncher.openingMessage(terminal, "/tmp/Place.rbxl")).to.equal(
                `Opening {terminal:RobloxPath("Place.rbxl")}...`
            )
        end)
    end)
end
