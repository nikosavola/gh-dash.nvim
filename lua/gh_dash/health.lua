local M = {}

--- Called by :checkhealth gh_dash
function M.check()
  vim.health.start 'gh-dash.nvim'

  if vim.fn.has 'nvim-0.10' == 1 then
    vim.health.ok 'Neovim >= 0.10'
  else
    vim.health.warn 'Neovim 0.10+ is recommended for full feature support'
  end

  if vim.fn.executable 'gh' == 1 then
    vim.health.ok '`gh` CLI found'
  else
    vim.health.error('`gh` CLI not found', {
      'Install from https://cli.github.com/',
      'e.g. `brew install gh` on macOS',
    })
  end

  local handle = io.popen 'gh extension list 2>/dev/null'
  if handle then
    local output = handle:read '*a'
    handle:close()
    if output and output:find 'gh%-dash' then
      vim.health.ok '`gh-dash` extension installed'
    else
      vim.health.warn('`gh-dash` extension not found', {
        'Install with: `gh extension install dlvhdr/gh-dash`',
        'Or set `autoinstall = true` in your plugin config.',
      })
    end
  end
end

return M
