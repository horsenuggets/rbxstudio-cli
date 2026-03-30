--[[

OpenCommandTest.spec

Tests for the open command's target classification logic.

--]]

local classifyTarget = require("@rbxstudiocli/RbxstudioCommand/OpenCommand/classifyTarget")

return function()
    describe("classifyTarget", function()
        it("should detect pure digit strings as place IDs", function()
            local result, err = classifyTarget("12345")
            expect(err).to.equal(nil)
            expect(result).to.be.ok()
            expect(result.Type).to.equal("placeid")
            expect(result.Value).to.equal("12345")
        end)

        it("should detect large place IDs", function()
            local result, err = classifyTarget("987654321012345")
            expect(err).to.equal(nil)
            expect(result).to.be.ok()
            expect(result.Type).to.equal("placeid")
            expect(result.Value).to.equal("987654321012345")
        end)

        it("should detect .rbxl paths as files", function()
            local result, err = classifyTarget("game.rbxl")
            expect(err).to.equal(nil)
            expect(result).to.be.ok()
            expect(result.Type).to.equal("file")
            expect(result.Value).to.equal("game.rbxl")
        end)

        it("should detect .rbxlx paths as files", function()
            local result, err = classifyTarget("game.rbxlx")
            expect(err).to.equal(nil)
            expect(result).to.be.ok()
            expect(result.Type).to.equal("file")
            expect(result.Value).to.equal("game.rbxlx")
        end)

        it("should detect .project.json paths as Rojo projects", function()
            local result, err = classifyTarget("default.project.json")
            expect(err).to.equal(nil)
            expect(result).to.be.ok()
            expect(result.Type).to.equal("file")
            expect(result.Value).to.equal("default.project.json")
        end)

        it("should detect relative paths with .rbxl extension", function()
            local result, err = classifyTarget("./game.rbxl")
            expect(err).to.equal(nil)
            expect(result).to.be.ok()
            expect(result.Type).to.equal("file")
            expect(result.Value).to.equal("./game.rbxl")
        end)

        it("should detect absolute paths with .rbxlx extension", function()
            local result, err = classifyTarget("/Users/test/game.rbxlx")
            expect(err).to.equal(nil)
            expect(result).to.be.ok()
            expect(result.Type).to.equal("file")
            expect(result.Value).to.equal("/Users/test/game.rbxlx")
        end)

        it("should detect absolute paths with .project.json extension", function()
            local result, err = classifyTarget("/home/user/my-game.project.json")
            expect(err).to.equal(nil)
            expect(result).to.be.ok()
            expect(result.Type).to.equal("file")
            expect(result.Value).to.equal("/home/user/my-game.project.json")
        end)

        it("should error on mixed alphanumeric strings", function()
            local result, err = classifyTarget("123abc")
            expect(result).to.equal(nil)
            expect(err).to.be.ok()
            expect(type(err)).to.equal("string")
        end)

        it("should error on empty string", function()
            local result, err = classifyTarget("")
            expect(result).to.equal(nil)
            expect(err).to.be.ok()
            expect(type(err)).to.equal("string")
        end)

        it("should error on unrecognized strings without file extension", function()
            local result, err = classifyTarget("some-random-string")
            expect(result).to.equal(nil)
            expect(err).to.be.ok()
        end)

        it("should detect existing paths on disk", function()
            -- The CHANGELOG.md file exists in the project root
            local result, err = classifyTarget("CHANGELOG.md")
            expect(err).to.equal(nil)
            expect(result).to.be.ok()
            expect(result.Type).to.equal("file")
        end)
    end)
end
