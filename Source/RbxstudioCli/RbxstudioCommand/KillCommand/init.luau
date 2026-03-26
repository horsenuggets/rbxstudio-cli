--[[

KillCommand

Kills Roblox Studio processes. Can kill a specific process by PID or
all running Studio instances.

--]]

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local process = require("@lune/process")

-- Counts running Studio processes
local function countStudioProcesses(): number
    local result = process.exec("pgrep", { "-x", "RobloxStudio" })
    if not result.ok then
        return 0
    end
    local count = 0
    for _ in result.stdout:gmatch("%d+") do
        count += 1
    end
    return count
end

return Commandline.Command.new({
    Name = "kill",
    Description = "Kill Roblox Studio processes.",
    Args = {
        Commandline.Arg.new({
            Name = "pid",
            Description = 'PID of the Studio process to kill, or "all" to kill all.',
            Type = "string",
            Required = false,
        }),
    },
    Impl = function(args, _flags)
        local target = args.pid

        if target == nil or target == "all" then
            local count = countStudioProcesses()
            if count == 0 then
                print("No Roblox Studio processes running.")
                return
            end

            process.exec("pkill", { "-9", "-f", "RobloxStudio" }, { stdio = "none" })
            print(
                `Killed {Chalk.bold(Chalk.yellowBright(tostring(count)))} Roblox Studio {if count == 1
                    then "process"
                    else "processes"}.`
            )
        else
            -- Verify the PID is a Studio process
            local result = process.exec("ps", { "-p", target, "-o", "args=" })
            if not result.ok or not result.stdout:find("RobloxStudio") then
                print(Chalk.red(`Process {Chalk.bold(target)} is not a Roblox Studio process.`))
                process.exit(1)
            end

            process.exec("kill", { "-9", target }, { stdio = "none" })
            print(`Killed Roblox Studio process {Chalk.bold(Chalk.yellowBright(target))}.`)
        end
    end,
})
