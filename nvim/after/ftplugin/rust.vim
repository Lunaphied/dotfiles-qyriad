" Don't automatically insert the comment leader on <CR> or o
setlocal formatoptions-=ro

"if exists("*nvim_treesitter#foldexpr")
"	setlocal foldmethod=expr foldexpr=nvim_treesitter#foldexpr()
"endif
setlocal foldmethod=syntax
setlocal foldtext=

" From our fancy Rust LSP plugin
lua << EOF
local bufnr = vim.api.nvim_get_current_buf()
vim.keymap.set(
  "n",
  "<leader>a",
  function()
    vim.cmd.RustLsp('codeAction') -- supports rust-analyzer's grouping
    -- or vim.lsp.buf.codeAction() if you don't want grouping.
  end,
  { silent = true, buffer = bufnr }
)
vim.keymap.set(
  "n",
  "K",  -- Override Neovim's built-in hover keymap with rustaceanvim's hover actions
  function()
    vim.cmd.RustLsp({'hover', 'actions'})
  end,
  { silent = true, buffer = bufnr }
)
EOF
