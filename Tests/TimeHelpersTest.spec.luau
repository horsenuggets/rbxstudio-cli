--[[

TimeHelpersTest.spec

Tests for the TimeHelpers module's uptime formatting.

--]]

local TimeHelpers = require("@rbxstudiocli/Helpers/TimeHelpers")

return function()
    describe("formatUptime", function()
        it("should format seconds only", function()
            expect(TimeHelpers.formatUptime("00:45")).to.equal("45s")
        end)

        it("should format zero seconds", function()
            expect(TimeHelpers.formatUptime("00:00")).to.equal("0s")
        end)

        it("should format minutes and seconds", function()
            expect(TimeHelpers.formatUptime("05:30")).to.equal("5m 30s")
        end)

        it("should format minutes with zero seconds", function()
            expect(TimeHelpers.formatUptime("10:00")).to.equal("10m")
        end)

        it("should format hours, minutes, and seconds", function()
            expect(TimeHelpers.formatUptime("02:30:15")).to.equal("2h 30m 15s")
        end)

        it("should format hours with zero minutes and seconds", function()
            expect(TimeHelpers.formatUptime("05:00:00")).to.equal("5h")
        end)

        it("should format hours and minutes with zero seconds", function()
            expect(TimeHelpers.formatUptime("01:45:00")).to.equal("1h 45m")
        end)

        it("should format days, hours, minutes, and seconds", function()
            expect(TimeHelpers.formatUptime("3-05:30:12")).to.equal("3d 5h 30m 12s")
        end)

        it("should format days with zero hours, minutes, and seconds", function()
            expect(TimeHelpers.formatUptime("7-00:00:00")).to.equal("7d")
        end)

        it("should format days and hours only", function()
            expect(TimeHelpers.formatUptime("1-12:00:00")).to.equal("1d 12h")
        end)

        it("should format large day counts", function()
            expect(TimeHelpers.formatUptime("14-13:50:08")).to.equal("14d 13h 50m 8s")
        end)

        it("should return input unchanged for unrecognized formats", function()
            expect(TimeHelpers.formatUptime("invalid")).to.equal("invalid")
        end)
    end)
end
