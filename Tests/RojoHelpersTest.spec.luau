--[[

RojoHelpersTest.spec

Tests for resolving Rojo release tags and versions.

--]]

const RojoHelpers = require("@rbxstudiocli/Helpers/RojoHelpers")
const Testable = require("@devpackages/Testable")
const describe, expect, it = Testable.describe, Testable.expect, Testable.it

return function()
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
