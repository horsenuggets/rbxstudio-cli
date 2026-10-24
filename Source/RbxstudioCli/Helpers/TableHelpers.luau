--[[

TableHelpers

Renders bordered terminal tables with support for colored cell
content and separate raw text for width calculation.

--]]

const Colors = require("@rbxstudiocli/Helpers/Colors")

const TableHelpers = {}

export type TableRow = {
    Raw: { string },
    Colored: { string },
}

function TableHelpers.render(headers: { string }, rows: { TableRow })
    -- Calculate column widths from raw uncolored text
    const widths = {}
    for i, header in headers do
        widths[i] = #header
    end
    for _, row in rows do
        for i, cell in row.Raw do
            widths[i] = math.max(widths[i] or 0, #cell)
        end
    end

    const function border(left: string, mid: string, right: string): string
        const parts = {}
        for _, w in widths do
            table.insert(parts, string.rep("─", w + 2))
        end
        return left .. table.concat(parts, mid) .. right
    end

    const function formatCells(cells: { string }, rawCells: { string }): string
        const parts = {}
        for i, cell in cells do
            const rawLen = #(rawCells[i] or "")
            const padding = string.rep(" ", (widths[i] or 0) - rawLen)
            table.insert(parts, ` {cell}{padding} `)
        end
        return "│" .. table.concat(parts, "│") .. "│"
    end

    const boldHeaders = {}
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
