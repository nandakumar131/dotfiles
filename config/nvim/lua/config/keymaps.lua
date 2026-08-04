-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- ==============================================================================
-- NATIVE PANE NAVIGATION: Listening for <prefix> + hjkl
-- ==============================================================================

local function smart_navigate(direction, tmux_direction)
  local current_win = vim.api.nvim_get_current_win()

  -- Attempt native Neovim navigation
  vim.cmd("wincmd " .. direction)

  -- Edge detected: If window didn't change AND we are actively inside TMUX
  if current_win == vim.api.nvim_get_current_win() and os.getenv("TMUX") then
    vim.fn.system("tmux select-pane -" .. tmux_direction)
  end
end

vim.keymap.set('n', '<C-b>h', function() smart_navigate('h', 'L') end, { desc = 'Navigate Left' })
vim.keymap.set('n', '<C-b>j', function() smart_navigate('j', 'D') end, { desc = 'Navigate Down' })
vim.keymap.set('n', '<C-b>k', function() smart_navigate('k', 'U') end, { desc = 'Navigate Up' })
vim.keymap.set('n', '<C-b>l', function() smart_navigate('l', 'R') end, { desc = 'Navigate Right' })

