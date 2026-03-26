--[[

ProjectHelpersTest.spec

Tests for project creation helpers.

--]]

local ProjectHelpers = require("@rbxstudiocli/Helpers/ProjectHelpers")

return function()
    describe("generateHexId", function()
        it("should return an 8 character string", function()
            local id = ProjectHelpers.generateHexId()
            expect(#id).to.equal(8)
        end)

        it("should only contain hex characters", function()
            local id = ProjectHelpers.generateHexId()
            expect(id:match("^[0-9a-f]+$")).to.be.ok()
        end)

        it("should generate unique IDs", function()
            local ids = {}
            for _ = 1, 20 do
                local id = ProjectHelpers.generateHexId()
                expect(ids[id]).to.equal(nil)
                ids[id] = true
            end
        end)
    end)
end
