--[[

TableHelpers

Renders bordered terminal tables with support for colored cell
content and separate raw text for width calculation.

--]]

local Colors = require("@rbxstudiocli/Helpers/Colors")

local TableHelpers = {}

export type TableRow = {
    Raw: { string },
    Colored: { string },
}

function TableHelpers.render(headers: { string }, rows: { TableRow })
    -- Calculate column widths from raw uncolored text
    local widths = {}
    for i, header in headers do
        widths[i] = #header
    end
    for _, row in rows do
        for i, cell in row.Raw do
            widths[i] = math.max(widths[i] or 0, #cell)
        end
    end

    local function border(left: string, mid: string, right: string): string
        local parts = {}
        for _, w in widths do
            table.insert(parts, string.rep("─", w + 2))
        end
        return left .. table.concat(parts, mid) .. right
    end

    local function formatCells(cells: { string }, rawCells: { string }): string
        local parts = {}
        for i, cell in cells do
            local rawLen = #(rawCells[i] or "")
            local padding = string.rep(" ", (widths[i] or 0) - rawLen)
            table.insert(parts, ` {cell}{padding} `)
        end
        return "│" .. table.concat(parts, "│") .. "│"
    end

    local boldHeaders = {}
    for _, h in headers do
        table.insert(boldHeaders, Colors.bold(h))
    end

    print(border("┌", "┬", "┐"))
    print(formatCells(boldHeaders, headers))
    print(border("├", "┼", "┤"))
    for _, row in rows do
        print(formatCells(row.Colored, row.Raw))
    end
    print(border("└", "┴", "┘"))
end

return TableHelpers
