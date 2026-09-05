-- Copland: the Copland OS Enterprise look from Serial Experiments Lain (the Navi's OS). A dark navy, blue-washed,
-- NeXTSTEP-ish interface with brushed-silver chrome and hologram-cyan highlights. The series gives no palette; these colours are an
-- interpretation shared with the Kitty theme in desktop.nix.
vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.o.background = "dark"
vim.g.colors_name = "copland"

local c = {
  bg = "#0b1220", bg_alt = "#12203a", bg_hi = "#1a2d4f", chrome = "#2b4a7a", edge = "#3a4d6b",
  fg = "#cfe3ff", white = "#e6f1ff", dim = "#6c86a8", dimmer = "#4a6285",
  cyan = "#5fd3ff", ice = "#9be8ff", blue = "#4a8fe8", sky = "#7db8ff",
  purple = "#9b7ce8", lilac = "#bda6ff", red = "#e0405a", pink = "#ff6b81",
  green = "#4fd1a1", mint = "#7ff0c0", yellow = "#d9c26a", sand = "#f0dc8c",
  silver = "#c0c8d4", silver_dk = "#8a94a6", silver_lt = "#e1e7ef",
}

local function hl(group, opts) vim.api.nvim_set_hl(0, group, opts) end

-- Editor chrome
hl("Normal", { fg = c.fg, bg = c.bg })
hl("NormalFloat", { fg = c.fg, bg = c.bg_alt })
hl("FloatBorder", { fg = c.silver, bg = c.bg_alt })
hl("FloatTitle", { fg = c.cyan, bg = c.bg_alt, bold = true })
hl("Cursor", { fg = c.bg, bg = c.cyan })
hl("CursorLine", { bg = c.bg_alt })
hl("CursorColumn", { bg = c.bg_alt })
hl("ColorColumn", { bg = c.bg_alt })
hl("LineNr", { fg = c.silver_dk })
hl("CursorLineNr", { fg = c.silver_lt, bold = true })
hl("SignColumn", { bg = c.bg })
hl("VertSplit", { fg = c.silver_dk })
hl("WinSeparator", { fg = c.silver_dk })
hl("EndOfBuffer", { fg = c.bg })
hl("NonText", { fg = c.edge })
hl("Whitespace", { fg = c.bg_hi })
hl("Folded", { fg = c.dim, bg = c.bg_alt })
hl("MatchParen", { fg = c.bg, bg = c.cyan, bold = true })
hl("Visual", { bg = c.chrome })
hl("Search", { fg = c.bg, bg = c.yellow })
hl("IncSearch", { fg = c.bg, bg = c.cyan })
hl("CurSearch", { fg = c.bg, bg = c.cyan })
hl("StatusLine", { fg = c.bg, bg = c.silver, bold = true })
hl("StatusLineNC", { fg = c.silver_dk, bg = c.bg_alt })
hl("TabLine", { fg = c.silver_dk, bg = c.bg_hi })
hl("TabLineSel", { fg = c.bg, bg = c.silver, bold = true })
hl("TabLineFill", { bg = c.bg })
hl("Pmenu", { fg = c.fg, bg = c.bg_alt })
hl("PmenuSel", { fg = c.bg, bg = c.cyan })
hl("PmenuSbar", { bg = c.bg_hi })
hl("PmenuThumb", { bg = c.chrome })
hl("WildMenu", { fg = c.bg, bg = c.cyan })
hl("Title", { fg = c.cyan, bold = true })
hl("Directory", { fg = c.sky })
hl("ErrorMsg", { fg = c.red, bold = true })
hl("WarningMsg", { fg = c.yellow, bold = true })
hl("MoreMsg", { fg = c.green })
hl("Question", { fg = c.green })
hl("SpecialKey", { fg = c.edge })

-- Syntax
hl("Comment", { fg = c.dim, italic = true })
hl("Constant", { fg = c.lilac })
hl("String", { fg = c.mint })
hl("Character", { fg = c.mint })
hl("Number", { fg = c.sand })
hl("Boolean", { fg = c.lilac, bold = true })
hl("Float", { fg = c.sand })
hl("Identifier", { fg = c.fg })
hl("Function", { fg = c.cyan })
hl("Statement", { fg = c.blue, bold = true })
hl("Conditional", { fg = c.blue, bold = true })
hl("Repeat", { fg = c.blue, bold = true })
hl("Operator", { fg = c.silver })
hl("Keyword", { fg = c.blue, bold = true })
hl("Exception", { fg = c.pink, bold = true })
hl("PreProc", { fg = c.purple })
hl("Include", { fg = c.purple })
hl("Define", { fg = c.purple })
hl("Macro", { fg = c.purple })
hl("Type", { fg = c.ice })
hl("StorageClass", { fg = c.blue, bold = true })
hl("Structure", { fg = c.ice })
hl("Special", { fg = c.pink })
hl("SpecialChar", { fg = c.pink })
hl("Delimiter", { fg = c.silver_dk })
hl("Underlined", { fg = c.sky, underline = true })
hl("Todo", { fg = c.bg, bg = c.yellow, bold = true })
hl("Error", { fg = c.white, bg = c.red })

-- Diagnostics and diffs
for name, col in pairs({ Error = c.red, Warn = c.yellow, Info = c.blue, Hint = c.cyan, Ok = c.green }) do
  hl("Diagnostic" .. name, { fg = col })
  hl("DiagnosticUnderline" .. name, { sp = col, undercurl = true })
end
hl("DiffAdd", { bg = "#0f3a35" })
hl("DiffChange", { bg = "#1a2d4f" })
hl("DiffDelete", { fg = c.red, bg = "#3a1522" })
hl("DiffText", { bg = "#2b4a7a", bold = true })
hl("SpellBad", { sp = c.red, undercurl = true })
hl("SpellCap", { sp = c.blue, undercurl = true })

-- Treesitter groups whose defaults would read wrong here
hl("@variable", { fg = c.fg })
hl("@property", { fg = c.sky })
hl("@parameter", { fg = c.lilac })
hl("@constructor", { fg = c.ice })
hl("@tag", { fg = c.blue })
hl("@tag.attribute", { fg = c.cyan })
hl("@markup.heading", { fg = c.cyan, bold = true })
hl("@markup.link.url", { fg = c.sky, underline = true })

-- :terminal uses the same palette as Kitty
local term = { c.bg, c.red, c.green, c.yellow, c.blue, c.purple, c.cyan, "#b8c2d0",
               "#4f5d75", c.pink, c.mint, c.sand, c.sky, c.lilac, c.ice, "#e8edf4" }
for i, col in ipairs(term) do vim.g["terminal_color_" .. (i - 1)] = col end
