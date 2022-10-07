local api = vim.api

local State = {
  Closed = 0,
  Hidden = 1,
  Opened = 2,
}

local Lf = {
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

function Lf:_close()
  self.state = State.Closed
  if api.nvim_win_is_valid(self.winid) then
    api.nvim_win_close(self.winid, true)
  end
  if api.nvim_buf_is_valid(self.bufnr) then
    api.nvim_buf_set_var(self.bufnr, 'bufhidden', 'wipe')
    api.nvim_buf_delete(self.bufnr, { force = true })
  end
end

function Lf:open()
  if self.state == State.Opened then
    self:_hide()
  else
    self.prev_winid = api.nvim_get_current_win()

    if self.state == State.Closed then
      self.bufnr = api.nvim_create_buf(false, true)
    end

    local opts = {
      relative = 'editor',
      col = math.floor((1 - self.config.width) / 2 * vim.o.columns),
      row = math.floor((1 - self.config.height) / 2 * vim.o.lines),
      width = math.floor(self.config.width * vim.o.columns),
      height = math.floor(self.config.height * vim.o.lines),
      border = self.config.border,
    }
    self.winid = api.nvim_open_win(self.bufnr, true, opts)
    api.nvim_win_set_option(self.winid, 'winhl', 'NormalFloat:LfNormal,FloatBorder:LfBorder')
    api.nvim_win_set_option(self.winid, 'sidescrolloff', 0)
    api.nvim_win_set_option(self.winid, 'number', false)

    if self.state == State.Closed then
      vim.fn.termopen(self.cmd, {
        on_exit = function()
          self:_close()
        end,
      })
      api.nvim_buf_set_option(self.bufnr, 'bufhidden', 'hide')
      api.nvim_buf_set_option(self.bufnr, 'filetype', 'lf')
      api.nvim_buf_set_name(self.bufnr, 'Lf')
    end

    api.nvim_win_set_cursor(self.winid, { 1, 0 })
    vim.schedule(vim.cmd.startinsert)
    self.state = State.Opened
  end
end

function Lf.setup(opts)
  Lf.config = vim.tbl_extend('force', Lf.config, opts or {})

  if opts and opts.lfrc then
    Lf.cmd = 'lf -config ' .. opts.lfrc
  else
    Lf.cmd = 'lf'
  end

  api.nvim_create_user_command('Lf', function()
    Lf:open()
  end, { nargs = 0, desc = 'Open lf' })

  api.nvim_set_hl(0, 'LfNormal', { link = 'NormalFloat', default = true })
  api.nvim_set_hl(0, 'LfBorder', { link = 'FloatBorder', default = true })
end

function Lf:_edit_file(path, hide)
  api.nvim_cmd({
    cmd = 'edit',
    args = { path },
  }, {})
  local bufnr = api.nvim_win_get_buf(self.winid)
  if api.nvim_win_is_valid(self.prev_winid) then
    local nu = api.nvim_win_get_option(self.prev_winid, 'number')
    local siso = api.nvim_win_get_option(self.prev_winid, 'sidescrolloff')

    api.nvim_win_set_buf(self.prev_winid, bufnr)

    api.nvim_win_set_option(self.prev_winid, 'number', nu)
    api.nvim_win_set_option(self.prev_winid, 'sidescrolloff', siso)
  end
  if hide or self.config.hide then
    self:_hide()
  else
    api.nvim_win_set_buf(self.winid, self.bufnr)
  end
end

function Lf:_hide()
  self.state = State.Hidden
  if api.nvim_win_is_valid(self.winid) then
    api.nvim_win_close(self.winid, true)
  end
end

function Lf:_cd(path)
  api.nvim_cmd({
    cmd = 'cd',
    args = { path },
    mods = { silent = true },
  }, {})
  api.nvim_buf_set_name(self.bufnr, 'Lf')
end

return Lf
