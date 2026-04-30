---@class GhDash.Config
---@field keymaps? GhDash.Keymaps Keymap configuration
---@field border? string|table Border style: 'single', 'double', 'square', 'rounded', 'none', or a custom table
---@field width? number Floating window width as a fraction of editor width (0.0-1.0)
---@field height? number Floating window height as a fraction of editor height (0.0-1.0)
---@field cmd? string|string[] Command to run in the terminal buffer
---@field autoinstall? boolean Whether to auto-install gh-dash extension if not found

---@class GhDash.Keymaps
---@field toggle? string Keymap to toggle the gh-dash popup

---@class GhDash.State
---@field buf? integer Buffer handle
---@field win? integer Window handle
---@field job? integer Job ID

local M = {}

---@type GhDash.Config
local defaults = {
  keymaps = {},
  border = 'single',
  width = 0.8,
  height = 0.8,
  cmd = { 'gh', 'dash' },
  autoinstall = false,
}

---@type GhDash.Config
local config = vim.deepcopy(defaults)

---@type GhDash.State
local state = {
  buf = nil,
  win = nil,
  job = nil,
}

local styles = {
  single = {
    { '╭', 'FloatBorder' },
    { '─', 'FloatBorder' },
    { '╮', 'FloatBorder' },
    { '│', 'FloatBorder' },
    { '╯', 'FloatBorder' },
    { '─', 'FloatBorder' },
    { '╰', 'FloatBorder' },
    { '│', 'FloatBorder' },
  },
  double = {
    { '╔', 'FloatBorder' },
    { '═', 'FloatBorder' },
    { '╗', 'FloatBorder' },
    { '║', 'FloatBorder' },
    { '╝', 'FloatBorder' },
    { '═', 'FloatBorder' },
    { '╚', 'FloatBorder' },
    { '║', 'FloatBorder' },
  },
  rounded = {
    { '╭', 'FloatBorder' },
    { '─', 'FloatBorder' },
    { '╮', 'FloatBorder' },
    { '│', 'FloatBorder' },
    { '╯', 'FloatBorder' },
    { '─', 'FloatBorder' },
    { '╰', 'FloatBorder' },
    { '│', 'FloatBorder' },
  },
  square = {
    { '┌', 'FloatBorder' },
    { '─', 'FloatBorder' },
    { '┐', 'FloatBorder' },
    { '│', 'FloatBorder' },
    { '┘', 'FloatBorder' },
    { '─', 'FloatBorder' },
    { '└', 'FloatBorder' },
    { '│', 'FloatBorder' },
  },
}

--- Resolve the border configuration to a value accepted by nvim_open_win.
---@param border string|table
---@return string|table
local function resolve_border(border)
  if type(border) == 'table' then
    return border
  end
  if border == 'none' then
    return 'none'
  end
  return styles[border] or styles.single
end

--- Create a floating window displaying the gh_dash buffer.
local function open_window()
  local width = math.floor(vim.o.columns * config.width)
  local height = math.floor(vim.o.lines * config.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = resolve_border(config.border),
  })
end

--- Configure the plugin. Must be called by the user (or via `opts` in lazy.nvim).
---@param user_config? GhDash.Config
function M.setup(user_config)
  config = vim.tbl_deep_extend('force', defaults, user_config or {})

  vim.api.nvim_create_user_command('GHdash', function()
    M.toggle()
  end, { desc = 'Toggle gh-dash popup' })
  vim.api.nvim_create_user_command('GHdashToggle', function()
    M.toggle()
  end, { desc = 'Toggle gh-dash popup (alias)' })

  if config.keymaps and config.keymaps.toggle then
    vim.keymap.set('n', config.keymaps.toggle, '<cmd>GHdashToggle<CR>', {
      noremap = true,
      silent = true,
      desc = 'Toggle gh-dash popup',
    })
  end
end

--- Open the gh-dash floating terminal. If already open, focus it.
function M.open()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) or vim.bo[state.buf].modified then
    state.buf = vim.api.nvim_create_buf(false, false)
    vim.bo[state.buf].bufhidden = 'hide'
    vim.bo[state.buf].swapfile = false
    vim.bo[state.buf].filetype = 'gh_dash'

    vim.keymap.set('t', '<Esc>', function()
      vim.defer_fn(function()
        M.toggle()
      end, 10)
    end, { buffer = state.buf, noremap = true, silent = true, desc = 'Hide gh-dash popup' })
  end

  open_window()

  -- Determine the executable to check
  local check_cmd = nil
  if type(config.cmd) == 'string' then
    if not config.cmd:find '%s' then
      check_cmd = config.cmd
    end
  elseif type(config.cmd) == 'table' and #config.cmd > 0 then
    check_cmd = config.cmd[1]
  end

  -- Handle missing executable
  if check_cmd and vim.fn.executable(check_cmd) == 0 then
    if config.autoinstall then
      if vim.fn.executable 'gh' == 1 then
        local shell_cmd = vim.o.shell or 'sh'
        local cmd = {
          shell_cmd,
          '-c',
          "echo 'Autoinstalling gh-dash via gh CLI extensions...'; gh extension install dlvhdr/gh-dash",
        }
        state.job = vim.fn.termopen(cmd, {
          cwd = vim.uv.cwd(),
          on_exit = function(_, exit_code, _)
            state.job = nil
            if exit_code == 0 then
              vim.schedule(function()
                M.close()
              end)
            end
          end,
        })
      else
        local msg = {
          'gh CLI not found; cannot auto-install gh-dash extension.',
          '',
          'Please install the gh CLI via your system package manager',
          'i.e. `brew install gh`',
        }
        vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, msg)
      end
    else
      local msg = {
        'gh-dash CLI not found.',
        '',
        'Install with:',
        '  gh extension install dlvhdr/gh-dash',
        '',
        'Or enable autoinstall in your plugin setup:',
        '  require("gh_dash").setup({ autoinstall = true })',
      }
      vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, msg)
    end
    return
  end

  -- Spawn the terminal process
  if not state.job then
    state.job = vim.fn.termopen(config.cmd, {
      cwd = vim.uv.cwd(),
      on_exit = function(_, exit_code, _)
        state.job = nil
        if exit_code == 0 then
          vim.schedule(function()
            M.close()
          end)
        end
      end,
    })
  end
end

--- Close the gh-dash window and delete the buffer.
function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
    state.win = nil
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
    state.buf = nil
  end
end

--- Toggle the gh-dash popup. Hides if visible, shows if hidden, opens if not started.
function M.toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
    state.win = nil
  elseif state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    open_window()
  else
    M.open()
  end
end

--- Return statusline text indicating a backgrounded gh-dash session.
---@return string
function M.statusline()
  if state.job and not (state.win and vim.api.nvim_win_is_valid(state.win)) then
    return '[gh_dash]'
  end
  return ''
end

--- Return a lualine.nvim component table for displaying gh-dash status.
--- Usage: `table.insert(opts.sections.lualine_x, require('gh_dash').status())`
---@return table
function M.status()
  return {
    function()
      return M.statusline()
    end,
    cond = function()
      return M.statusline() ~= ''
    end,
    icon = '',
    color = { fg = '#51afef' },
  }
end

return M
