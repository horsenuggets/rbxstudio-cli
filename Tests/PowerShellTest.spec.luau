--[[

PowerShellTest.spec

Tests that PowerShell command text survives awkward profile folder names, covering
quoting, the archive extraction command, and the user PATH command.

--]]

const ArchiveHelpers = require("@rbxstudiocli/Helpers/ArchiveHelpers")
const PowerShell = require("@rbxstudiocli/Helpers/PowerShell")

return function()
    describe("quote", function()
        for _, case in
            {
                { "C:\\Users\\a", "'C:\\Users\\a'" },
                { "C:\\Users\\O'Brien", "'C:\\Users\\O''Brien'" },
                { "''", "''''''" },
                { "C:\\Users\\dev[1]", "'C:\\Users\\dev[1]'" },
                { "$env:PATH", "'$env:PATH'" },
                { "", "''" },
            }
        do
            it(`should quote "{case[1]}"`, function()
                expect(PowerShell.quote(case[1])).to.equal(case[2])
            end)
        end

        it("should always produce an even number of quotes", function()
            for _, value in { "a", "'", "a'b'c", "'''" } do
                const _, count = string.gsub(PowerShell.quote(value), "'", "")
                expect(count % 2).to.equal(0)
            end
        end)
    end)

    describe("expandArchiveCommand", function()
        it("should name the archive literally and stop on errors", function()
            const command = ArchiveHelpers.expandArchiveCommand("C:\\a\\x.zip", "C:\\a")
            expect(command).to.equal(
                "Expand-Archive -LiteralPath 'C:\\a\\x.zip' -DestinationPath 'C:\\a' -Force -ErrorAction Stop"
            )
        end)

        it("should escape apostrophes in both paths", function()
            const command = ArchiveHelpers.expandArchiveCommand("C:\\O'Brien\\x.zip", "C:\\O'Brien")
            expect(string.find(command, "'C:\\O''Brien\\x.zip'", 1, true)).to.be.ok()
            expect(string.find(command, "-DestinationPath 'C:\\O''Brien'", 1, true)).to.be.ok()
        end)
    end)

    describe("addToUserPathCommand", function()
        it("should escape apostrophes in the folder", function()
            const command = PowerShell.addToUserPathCommand("C:/Users/O'Brien/.rbxstudio-cli/bin")
            expect(string.find(command, "$d = 'C:/Users/O''Brien/.rbxstudio-cli/bin';", 1, true)).to.be.ok()
        end)

        it("should compare the folder as plain text", function()
            const command = PowerShell.addToUserPathCommand("C:/Users/dev[1]/bin")
            expect(string.find(command, "-like", 1, true)).never.to.be.ok()
            expect(string.find(command, ".Contains(", 1, true)).to.be.ok()
        end)
    end)
end
