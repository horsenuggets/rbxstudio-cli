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
Colors.placeId = Chalk.greenBright
Colors.placeName = Chalk.cyanBright
Colors.fileName = Chalk.cyanBright
Colors.configFile = Chalk.hex("#CC7722")
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
