--[[

LogHelpersTest.spec

Tests for log parsing and session state detection.

--]]

local LogHelpers = require("@rbxstudiocli/Helpers/LogHelpers")

return function()
    describe("parseSessionInfo", function()
        it("should return Unknown for empty content", function()
            local result = LogHelpers.parseSessionInfo("")
            expect(result.status).to.equal("Unknown")
            expect(result.placeId).to.equal(nil)
            expect(result.highlight).to.equal(nil)
        end)

        it("should detect Start Page", function()
            local content = [[
2026-03-26T17:04:46.914Z Info showStartPageWidgets
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Start Page")
            expect(result.placeId).to.equal(nil)
        end)

        it("should detect EditFile with local place file", function()
            local content = [[
Command line:
/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio -task EditFile -localPlaceFile /Users/chris/test/my-game.rbxl
Info PlaceManager::createAndShowIDEDoc with task EditFile
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Edit (my-game.rbxl)")
            expect(result.placeId).to.equal(nil)
            expect(result.highlight).to.equal("my-game.rbxl")
        end)

        it("should detect EditFile without local place file path", function()
            local content = [[
Info PlaceManager::createAndShowIDEDoc with task EditFile
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Edit (local file)")
            expect(result.placeId).to.equal(nil)
        end)

        it("should detect EditPlace with place ID", function()
            local content = [[
Info PlaceManager::createAndShowIDEDoc with task EditPlace
[telemetryLog] placeid: 0
[telemetryLog] placeid: 9430488623
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Edit")
            expect(result.placeId).to.equal("9430488623")
        end)

        it("should resolve EditPlace with place name via callback", function()
            local content = [[
Info PlaceManager::createAndShowIDEDoc with task EditPlace
[telemetryLog] placeid: 12345
            ]]
            local result = LogHelpers.parseSessionInfo(content, function(id)
                if id == "12345" then
                    return "My Cool Game"
                end
                return nil
            end)
            expect(result.status).to.equal("Edit (My Cool Game)")
            expect(result.placeId).to.equal("12345")
            expect(result.highlight).to.equal("My Cool Game")
        end)

        it("should detect EditPlaceRevision", function()
            local content = [[
Info PlaceManager::createAndShowIDEDoc with task EditPlaceRevision
[telemetryLog] placeid: 5555
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Edit")
            expect(result.placeId).to.equal("5555")
        end)

        it("should detect Team Create with place ID", function()
            local content = [[
Info PlaceManager::createAndShowIDEDoc with task EditFile
Info TeamCreateJoinPayload Joining game abc place 13435539729 at server
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Team Create")
            expect(result.placeId).to.equal("13435539729")
        end)

        it("should resolve Team Create place name via callback", function()
            local content = [[
Info TeamCreateJoinPayload Joining game abc place 99999 at server
            ]]
            local result = LogHelpers.parseSessionInfo(content, function(id)
                if id == "99999" then
                    return "Plugin Sandbox"
                end
                return nil
            end)
            expect(result.status).to.equal("Team Create (Plugin Sandbox)")
            expect(result.placeId).to.equal("99999")
            expect(result.highlight).to.equal("Plugin Sandbox")
        end)

        it("should skip zero place IDs", function()
            local content = [[
Info PlaceManager::createAndShowIDEDoc with task EditPlace
[telemetryLog] placeid: 0
[telemetryLog] placeid: 0
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Edit")
            expect(result.placeId).to.equal(nil)
        end)

        it("should use the last non-zero place ID", function()
            local content = [[
Info PlaceManager::createAndShowIDEDoc with task EditPlace
[telemetryLog] placeid: 111
[telemetryLog] placeid: 0
[telemetryLog] placeid: 222
[telemetryLog] placeid: 0
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.placeId).to.equal("222")
        end)

        it("should detect returning to Start Page after editing", function()
            local content = [[
Info PlaceManager::createAndShowIDEDoc with task EditFile
Info lots of other stuff happening here
Info showStartPageWidgets
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Start Page")
        end)

        it("should detect new task after Start Page", function()
            local content = [[
Info showStartPageWidgets
Info more stuff
Info PlaceManager::createAndShowIDEDoc with task EditFile
-localPlaceFile /path/to/game.rbxl
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Edit (game.rbxl)")
        end)

        it("should detect Team Create overriding EditFile", function()
            local content = [[
Info PlaceManager::createAndShowIDEDoc with task EditFile
Info TeamCreateJoinPayload Joining game x place 7777 at server
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Team Create")
            expect(result.placeId).to.equal("7777")
        end)

        it("should use last Team Create if multiple joins", function()
            local content = [[
Info TeamCreateJoinPayload Joining game a place 1111 at server
Info TeamCreateJoinPayload Joining game b place 2222 at server
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.placeId).to.equal("2222")
        end)

        it("should use last task if multiple opens", function()
            local content = [[
Info PlaceManager::createAndShowIDEDoc with task EditFile
Info PlaceManager::createAndShowIDEDoc with task EditPlace
[telemetryLog] placeid: 8888
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Edit")
            expect(result.placeId).to.equal("8888")
        end)

        it("should detect generic new place for unknown tasks", function()
            local content = [[
Info PlaceManager::createAndShowIDEDoc with task NewDocument
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Edit (new place)")
            expect(result.placeId).to.equal(nil)
        end)

        it("should extract filename from Windows-style paths", function()
            local content = [[
-localPlaceFile C:\Users\chris\game.rbxl
Info PlaceManager::createAndShowIDEDoc with task EditFile
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.highlight).to.equal("game.rbxl")
        end)

        it("should handle log content with no relevant patterns", function()
            local content = [[
2026-03-26T17:04:46.914Z Info some random log line
2026-03-26T17:04:46.915Z Info another random log line
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Unknown")
        end)

        it("should detect published place from new place", function()
            local content = [[
Command line:
/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio -universeId 0 -placeId 95206881 -task EditPlace
Info PlaceManager::createAndShowIDEDoc with task EditPlace
[telemetryLog] placeid: 95206881
[telemetryLog] universeid: 0
[telemetryLog] placeid: 85939162614693
[telemetryLog] universeid: 9944635641
            ]]
            local result = LogHelpers.parseSessionInfo(content, function(id)
                if id == "85939162614693" then
                    return "test game :)"
                end
                return nil
            end)
            expect(result.status).to.equal("Edit (test game :))")
            expect(result.placeId).to.equal("85939162614693")
            expect(result.highlight).to.equal("test game :)")
        end)

        it("should detect new unsaved place with inherited place ID", function()
            local content = [[
Command line:
/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio -universeId 0 -placeId 95206881 -task EditPlace
Info PlaceManager::createAndShowIDEDoc with task EditPlace
[telemetryLog] placeid: 95206881
[telemetryLog] universeid: 0
            ]]
            local result = LogHelpers.parseSessionInfo(content)
            expect(result.status).to.equal("Edit (new place)")
            expect(result.placeId).to.equal(nil)
        end)
    end)
end
