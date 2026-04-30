vim.cmd 'set rtp+=.'
vim.cmd 'set rtp+=./plenary.nvim' -- if using as a submodule or symlinked
vim.opt.runtimepath:append '~/.local/share/nvim/lazy/plenary.nvim/'
-- Load the plugin guard (sets vim.g.loaded_gh_dash)
require 'plugin.gh_dash'
