--[[

CookieHelpersTest.spec

Tests when a rejected cookie is worth refreshing from the Keychain, across every
combination of response status and where the cookie came from.

--]]

const CookieHelpers = require("@rbxstudiocli/Helpers/CookieHelpers")
const Testable = require("@devpackages/Testable")
const describe, expect, it = Testable.describe, Testable.expect, Testable.it

return function()
    describe("shouldRefresh", function()
        for _, statusCode in { 200, 401, 403, 404, 500 } do
            for _, source in { "File", "Keychain", "None" } do
                const expected = statusCode == 401 and source == "File"

                it(`should report {expected} for status {statusCode} with a cookie from "{source}"`, function()
                    expect(CookieHelpers.shouldRefresh(statusCode, source :: any)).to.equal(expected)
                end)
            end
        end
    end)
end
