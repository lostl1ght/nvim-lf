local api = vim.api

---@enum State
local State = {
  Closed = 0,
  Hidden = 1,
  Opened = 2,
}

---@class DefaultConfig
local DefaultConfig = {
  hide = false,
  width = 0.9,
  height = 0.9,
  border = 'none',
  lfrc = '',
}

---@class Private
local Private = {
  state = State.Closed,
  bufnr = -1,
  winid = -1,
  prev_winid = -1,
  cmd = 'lf ',
  config = DefaultConfig,
}

---Delete terminal buffer
function Private:delete_buffer()
  if api.nvim_buf_is_valid(self.bufnr) then
    api.nvim_buf_set_var(self.bufnr, 'bufhidden', 'wipe')
    api.nvim_buf_delete(self.bufnr, { force = true })
  end
  self.bufnr = -1
end

---Delete floating window
function Private:delete_window()
  if api.nvim_win_is_valid(self.winid) then
    api.nvim_win_close(self.winid, true)
  end
  self.winid = -1
end

---Create a buffer and open the terminal
---@param path string|nil
function Private:create_buffer(path)
  if not api.nvim_buf_is_valid(self.bufnr) then
    self.bufnr = api.nvim_create_buf(false, true)
    api.nvim_win_set_buf(self.winid, self.bufnr)
    vim.fn.termopen(self.cmd .. (path or ''), {
      on_exit = function()
        self:delete_buffer()
        self.state = State.Closed
      end,
    })
    api.nvim_buf_set_option(self.bufnr, 'bufhidden', 'hide')
    api.nvim_buf_set_option(self.bufnr, 'filetype', 'lf')
  end
end

---Set buffer, cursor, start insert mode
function Private:post_open_setup()
  api.nvim_win_set_buf(self.winid, self.bufnr)
  -- Fixes the window sliding to the left
  api.nvim_win_set_cursor(self.winid, { 1, 0 })
  vim.schedule(function()
    api.nvim_set_current_win(self.winid)
    api.nvim_cmd({ cmd = 'startinsert' }, {})
  end)
end

function Private:create_window()
  self.prev_winid = api.nvim_get_current_win()
  local opts = {
    relative = 'editor',
    col = math.floor((1 - self.config.width) / 2 * vim.o.columns),
    row = math.floor((1 - self.config.height) / 2 * vim.o.lines),
    width = math.floor(self.config.width * vim.o.columns),
    height = math.floor(self.config.height * vim.o.lines),
    border = self.config.border,
  }
  self.winid = api.nvim_open_win(0, true, opts)
  api.nvim_win_set_option(self.winid, 'winhl', 'NormalFloat:LfNormal,FloatBorder:LfBorder')
  api.nvim_win_set_option(self.winid, 'sidescrolloff', 0)
  api.nvim_win_set_option(self.winid, 'number', false)
end

-- Public interface

---@class Public
local Public = {}

---Setup the plugin
---@param opts DefaultConfig|nil configuration
function Public.setup(opts)
  Private.config = vim.tbl_extend('force', Private.config, opts or {})

  if opts and opts.lfrc then
    Private.cmd = 'lf -config ' .. opts.lfrc .. ' '
  end

  api.nvim_create_user_command('LfOpen', function(arg)
    local path
    if arg.args ~= '' then
      path = arg.args
    end
    Public.open(path)
  end, { nargs = '?', complete = 'dir', desc = 'Open lf' })

  api.nvim_create_user_command('LfHide', function()
    Public.hide()
  end, { nargs = 0, desc = 'Hide lf' })

  api.nvim_create_user_command('LfToggle', function()
    if Private.state == State.Opened then
      Public.hide()
    else
      Public.open(nil)
    end
  end, { nargs = 0, desc = 'Toggle lf window' })

  api.nvim_set_hl(0, 'LfNormal', { link = 'NormalFloat', default = true })
  api.nvim_set_hl(0, 'LfBorder', { link = 'FloatBorder', default = true })
end

---Open lf
---If `path` is `nil` then open in cwd
---else (re)open in `path`
---@param path string|nil path to a folder
function Public.open(path)
  if path then
    Private:delete_buffer()
    -- Needed so on_exit does not close a new lf instance
    vim.wait(1000, function()
      return Private.state == State.Closed
    end, 50)
  end
  if Private.state ~= State.Opened then
    Private:create_window()
    Private:create_buffer(path)
    Private:post_open_setup()
    Private.state = State.Opened
  end
end

---Hide lf window
function Public.hide()
  Private:delete_window()
  Private.state = State.Hidden
end

---Edit file under cursor in lf
---`Should only be used with remote capabilities from lfrc`
---@param path string path to a file
---@param hide boolean whether to hide the window
function Public.edit_file(path, hide)
  api.nvim_cmd({
    cmd = 'edit',
    args = { path },
  }, {})
  local bufnr = api.nvim_win_get_buf(Private.winid)
  if api.nvim_win_is_valid(Private.prev_winid) then
    local nu = api.nvim_win_get_option(Private.prev_winid, 'number')
    local siso = api.nvim_win_get_option(Private.prev_winid, 'sidescrolloff')

    api.nvim_win_set_buf(Private.prev_winid, bufnr)

    api.nvim_win_set_option(Private.prev_winid, 'number', nu)
    api.nvim_win_set_option(Private.prev_winid, 'sidescrolloff', siso)
  end
  if hide or Private.config.hide then
    Public.hide()
  else
    api.nvim_win_set_buf(Private.winid, Private.bufnr)
  end
end

---Change nvim's cwd
---`Should only be called with remote capabilities from lfrc`
---@param path string directory
function Public.cd(path)
  api.nvim_cmd({
    cmd = 'cd',
    args = { path },
    mods = { silent = true },
  }, {})
end

return Public
