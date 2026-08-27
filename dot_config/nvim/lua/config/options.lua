-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Comma as leader, overriding LazyVim's space.
--
-- This file is the right place for it, and the ordering is not incidental:
-- LazyVim's M.load() (lua/lazyvim/config/init.lua) sources
-- `lazyvim.config.options` -- which sets mapleader to " " -- and only then
-- `config.options`, so ours wins. That same M.load("options") runs before
-- lazy.nvim sources any plugin spec, which is the condition mapleader has to
-- meet: plugins resolve <leader> in their `keys` at map time, so a leader set
-- any later would leave every plugin mapping on the old prefix.
--
-- Note this shadows vim's built-in `,` (repeat the last f/t motion backwards).
vim.g.mapleader = ","

-- maplocalleader is deliberately left at LazyVim's default ("\\").
