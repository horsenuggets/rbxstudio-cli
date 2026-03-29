--[[

Colors

Semantic color functions for consistent styling across the CLI.
Wraps Chalk with meaningful names so output styling is centralized.

--]]

local Chalk = require("@packages/Chalk")

local Colors = {}

-- Text emphasis
Colors.bold = Chalk.bold
Colors.dim = Chalk.dim

-- Status
Colors.success = Chalk.greenBright
Colors.error = Chalk.red
Colors.warning = Chalk.yellow

-- Data values
Colors.numericId = Chalk.hex("#96cc22")
Colors.projectName = function(text: string): string
    return Chalk.bold(Chalk.cyanBright(text))
end
Colors.count = function(text: string): string
    return Chalk.bold(Chalk.yellowBright(text))
end
Colors.nil_ = Chalk.dim

-- Path formatting
Colors.path = Chalk.dim

-- Process info
Colors.pid = Chalk.bold
Colors.uptime = Chalk.dim

return Colors
