local api = vim.api

local State = {
  Closed = 0,
  Hidden = 1,
  Opened = 2,
}

local Private = {
  state = State.Closed,
  bufnr = nil,
  winid = nil,
  prev_winid = nil,
  cmd = nil,
  config = {
    hide = false,
    width = 0.9,
    height = 0.9,
    border = 'none',
  },
}

local Public = {}

function Private:close()
  self.state = State.Closed
  if api.nvim_win_is_valid(self.winid) then
    api.nvim_win_close(self.winid, true)
  end
  if api.nvim_buf_is_valid(self.bufnr) then
    api.nvim_buf_set_var(self.bufnr, 'bufhidden', 'wipe')
    api.nvim_buf_delete(self.bufnr, { force = true })
  end
end

function Private:create_buffer()
  self.bufnr = api.nvim_create_buf(false, true)
  api.nvim_win_set_buf(self.winid, self.bufnr)
  vim.fn.termopen(self.cmd, {
    on_exit = function()
      self:close()
    end,
  })
  api.nvim_buf_set_option(self.bufnr, 'bufhidden', 'hide')
  api.nvim_buf_set_option(self.bufnr, 'filetype', 'lf')
end

function Private:post_open_setup()
  api.nvim_win_set_buf(self.winid, self.bufnr)
  api.nvim_win_set_cursor(self.winid, { 1, 0 })
  vim.schedule(vim.cmd.startinsert)
end

function Private:create_window()
  Private.prev_winid = api.nvim_get_current_win()
  local opts = {
    relative = 'editor',
    col = math.floor((1 - Private.config.width) / 2 * vim.o.columns),
    row = math.floor((1 - Private.config.height) / 2 * vim.o.lines),
    width = math.floor(Private.config.width * vim.o.columns),
    height = math.floor(Private.config.height * vim.o.lines),
    border = Private.config.border,
  }
  Private.winid = api.nvim_open_win(0, true, opts)
  api.nvim_win_set_option(Private.winid, 'winhl', 'NormalFloat:LfNormal,FloatBorder:LfBorder')
  api.nvim_win_set_option(Private.winid, 'sidescrolloff', 0)
  api.nvim_win_set_option(Private.winid, 'number', false)
end

function Public:open()
  if Private.state ~= State.Opened then
    Private:create_window()
    if Private.state == State.Closed then
      Private:create_buffer()
    end
    Private:post_open_setup()
    Private.state = State.Opened
  end
end

function Public.setup(opts)
  Private.config = vim.tbl_extend('force', Private.config, opts or {})

  if opts and opts.lfrc then
    Private.cmd = 'lf -config ' .. opts.lfrc
  else
    Private.cmd = 'lf'
  end

  api.nvim_create_user_command('Lf', function()
    Public:open()
  end, { nargs = 0, desc = 'Open lf' })

  api.nvim_set_hl(0, 'LfNormal', { link = 'NormalFloat', default = true })
  api.nvim_set_hl(0, 'LfBorder', { link = 'FloatBorder', default = true })
end

function Public:edit_file(path, hide)
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
    Private:hide()
  else
    api.nvim_win_set_buf(Private.winid, Private.bufnr)
  end
end

function Public:hide()
  Private.state = State.Hidden
  if api.nvim_win_is_valid(Private.winid) then
    api.nvim_win_close(Private.winid, true)
  end
end

function Public:cd(path)
  api.nvim_cmd({
    cmd = 'cd',
    args = { path },
    mods = { silent = true },
  }, {})
end

return Public
