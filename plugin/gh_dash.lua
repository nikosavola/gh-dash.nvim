local ok, gh_dash = pcall(require, 'gh_dash')
if not ok then
  vim.notify('gh-dash.nvim failed to load: ' .. tostring(gh_dash), vim.log.levels.ERROR)
  return
end
gh_dash.setup()
