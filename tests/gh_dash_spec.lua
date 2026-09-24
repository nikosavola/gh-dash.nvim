-- tests/gh_dash_spec.lua
local eq = assert.equals

describe('gh_dash.nvim', function()
  local gh_dash

  before_each(function()
    vim.cmd 'set noswapfile'
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
        if ft == 'gh_dash' then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
    end
    gh_dash = require 'gh_dash'
    gh_dash.close()
    gh_dash.setup { keymaps = {}, cmd = 'sleep 30' }
  end)

  after_each(function()
    gh_dash.close()
  end)

  it('loads the module', function()
    local ok, mod = pcall(require, 'gh_dash')
    assert(ok, 'gh_dash module failed to load')
    assert(mod.open, 'gh_dash.open missing')
    assert(mod.close, 'gh_dash.close missing')
    assert(mod.toggle, 'gh_dash.toggle missing')
  end)

  it('creates gh_dash commands', function()
    gh_dash.setup { keymaps = {} }
    local cmds = vim.api.nvim_get_commands {}
    assert(cmds['GHdash'], 'GHdash command not found')
    assert(cmds['GHdashToggle'], 'GHdashToggle command not found')
  end)

  it('opens a floating terminal window', function()
    gh_dash.open()

    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    assert(vim.api.nvim_buf_is_valid(buf), 'buffer should exist')
    eq(vim.api.nvim_get_option_value('filetype', { buf = buf }), 'gh_dash')
    eq(vim.api.nvim_get_option_value('buftype', { buf = buf }), 'terminal')
  end)

  it('toggles the window', function()
    gh_dash.toggle()
    local win1 = vim.api.nvim_get_current_win()
    assert(vim.api.nvim_win_is_valid(win1), 'gh_dash window should be open')

    gh_dash.toggle()
    local still_valid = pcall(vim.api.nvim_win_get_buf, win1)
    assert(not still_valid, 'gh_dash window should be closed')
  end)

  it('hides the window on <Esc> but keeps job alive', function()
    gh_dash.open()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)

    -- headless nvim cannot dispatch keys in Terminal mode, so look up the
    -- buffer-local <Esc> mapping and execute its rhs directly
    local maps = vim.api.nvim_buf_get_keymap(buf, 't')
    assert(#maps > 0, 'terminal-mode <Esc> mapping should exist')
    local rhs = maps[1].rhs
    assert(rhs and rhs:find('toggle', 1, true), '<Esc> should be mapped to toggle')
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes(rhs, true, false, true), 'xt')

    local hidden = vim.wait(2000, function()
      return not vim.api.nvim_win_is_valid(win)
    end)
    assert(hidden, '<Esc> should hide the window')

    eq(gh_dash.statusline(), '[gh_dash]', 'job should still be running after hiding window')
  end)

  it('open() after hiding reuses the same buffer and job', function()
    gh_dash.open()
    local buf1 = vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win())

    gh_dash.toggle() -- hide, job keeps running in the background
    eq(gh_dash.statusline(), '[gh_dash]')

    gh_dash.open()
    local buf2 = vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win())
    eq(buf1, buf2, 'open() should reuse the existing buffer instead of orphaning the job')
    eq(vim.api.nvim_get_option_value('buftype', { buf = buf2 }), 'terminal')
  end)

  it('shows statusline only when the job runs without a window', function()
    gh_dash.open()
    eq(gh_dash.statusline(), '', 'window is open, nothing to report')

    gh_dash.toggle() -- hide, job keeps running in the background
    eq(gh_dash.statusline(), '[gh_dash]')

    gh_dash.close()
    eq(gh_dash.statusline(), '', 'close() must stop the job and reset state')
  end)

  it('recovers from a failed spawn instead of keeping a dead job id', function()
    gh_dash.setup { cmd = {} }
    gh_dash.open()
    -- a failed termopen returns 0 for invalid args and -1 for a missing executable; both are
    -- not valid job ids and the -1 case is truthy, so neither must be kept as the job id
    eq(gh_dash.statusline(), '', 'no job should be registered after a failed spawn')

    gh_dash.setup { cmd = 'sleep 30' }
    gh_dash.open()
    local buf = vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win())
    eq(vim.api.nvim_get_option_value('buftype', { buf = buf }), 'terminal', 'respawn must work after a failure')
  end)

  it('closes the popup and notifies when the command exits nonzero', function()
    local orig_notify = vim.notify
    local notified = false
    vim.notify = function()
      notified = true
    end

    gh_dash.setup { cmd = { 'sh', '-c', 'exit 3' } }
    gh_dash.open()
    local buf = vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win())

    local closed = vim.wait(3000, function()
      return not vim.api.nvim_buf_is_valid(buf)
    end)
    vim.notify = orig_notify

    assert(closed, 'popup should close after a nonzero exit')
    assert(notified, 'a nonzero exit should notify the user')
    eq(gh_dash.statusline(), '', 'state should be reset after a nonzero exit')
  end)
end)
