if vim.g.lf_hijack_netrw then
  local api = vim.api
  local group = api.nvim_create_augroup('LfFileExplorer', {})

  api.nvim_create_autocmd('VimEnter', {
    pattern = '*',
    once = true,
    group = group,
    callback = function()
      vim.cmd('silent! autocmd! FileExplorer')
    end,
  })

  api.nvim_create_autocmd('VimEnter', {
    pattern = '*',
    once = true,
    group = group,
    callback = function(args)
      if vim.fn.isdirectory(args.match) == 1 then
        api.nvim_cmd({ cmd = 'bwipeout', args = { args.buf } }, {})
        require('lf').open(args.match)
      end
    end,
  })
end
