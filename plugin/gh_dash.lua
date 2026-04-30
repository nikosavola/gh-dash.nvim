-- gh-dash.nvim plugin loader
-- Does NOT call setup() automatically; the user must call require('gh_dash').setup(opts).
-- This file only ensures the module is loadable and prevents double-loading.
if vim.g.loaded_gh_dash then
  return
end
vim.g.loaded_gh_dash = true
