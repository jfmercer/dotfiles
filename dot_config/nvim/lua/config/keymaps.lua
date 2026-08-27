-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- jk leaves insert mode. vim.keymap.set, not LazyVim.safe_keymap_set: LazyVim's
-- docs are explicit that the latter is internal and must not be used here.
--
-- Tradeoff: a literal "jk" typed in insert mode now waits out 'timeoutlen'
-- before the j lands.
vim.keymap.set("i", "jk", "<Esc>", { desc = "Exit insert mode" })
