local preview_win
local preview_path
local preview_augroup
local preview_source_buf
local preview_source_win
local fyler_win

local function show_line_numbers(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.wo[win].number = true
    vim.wo[win].relativenumber = false
  end
end

local function focus_fyler()
  if fyler_win and vim.api.nvim_win_is_valid(fyler_win) then
    vim.api.nvim_set_current_win(fyler_win)
  end
end

local function focus_preview()
  if preview_win and vim.api.nvim_win_is_valid(preview_win) then
    vim.api.nvim_set_current_win(preview_win)
  end
end

local function set_preview_window_style(kind)
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
    return
  end

  vim.wo[preview_win].wrap = false
  vim.wo[preview_win].number = kind == "file"
  vim.wo[preview_win].relativenumber = false
end

local function create_scratch_preview_buffer(name, lines, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_name(buf, name)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  if filetype then
    vim.bo[buf].filetype = filetype
  end
  return buf
end

local function is_binary_file(path)
  local file = io.open(path, "rb")
  if not file then
    return false
  end

  local chunk = file:read(1024) or ""
  file:close()
  return chunk:find("\0", 1, true) ~= nil
end

local function prepare_directory_preview_buffer(path)
  local entries = {}
  for name, entry_type in vim.fs.dir(path) do
    local suffix = entry_type == "directory" and "/" or ""
    table.insert(entries, {
      is_dir = entry_type == "directory",
      text = name .. suffix,
    })
  end

  table.sort(entries, function(left, right)
    if left.is_dir ~= right.is_dir then
      return left.is_dir
    end

    return left.text:lower() < right.text:lower()
  end)

  local lines = {}
  for _, entry in ipairs(entries) do
    table.insert(lines, entry.text)
  end

  if #lines == 0 then
    lines = { "" }
  end

  return create_scratch_preview_buffer("fyler-preview://" .. path, lines, "fyler")
end

local function prepare_file_preview_buffer(path)
  if is_binary_file(path) then
    return create_scratch_preview_buffer("fyler-preview://" .. path, { "" })
  end

  local source_buf = vim.fn.bufnr(path)
  local lines
  local filetype
  local syntax

  if source_buf ~= -1 and vim.api.nvim_buf_is_loaded(source_buf) then
    lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
    filetype = vim.bo[source_buf].filetype
    syntax = vim.bo[source_buf].syntax
  else
    local ok, file_lines = pcall(vim.fn.readfile, path)
    lines = ok and file_lines or { "" }
    filetype = vim.filetype.match({ filename = path })
  end

  local preview_buf = create_scratch_preview_buffer("fyler-preview://" .. path, lines, filetype)

  if syntax and syntax ~= "" then
    vim.bo[preview_buf].syntax = syntax
  elseif filetype and filetype ~= "" then
    vim.bo[preview_buf].syntax = filetype
  end

  pcall(vim.treesitter.start, preview_buf)

  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = preview_buf,
    once = true,
    callback = function()
      local winid = vim.api.nvim_get_current_win()
      local view = vim.api.nvim_win_call(winid, vim.fn.winsaveview)
      vim.schedule(function()
        if not vim.api.nvim_win_is_valid(winid) or vim.api.nvim_get_current_win() ~= winid then
          return
        end

        local ok, err = pcall(vim.cmd.edit, vim.fn.fnameescape(path))
        if not ok and err and not tostring(err):match("^Vim:E325:") then
          vim.notify(tostring(err), vim.log.levels.ERROR)
          return
        end

        local line_count = vim.api.nvim_buf_line_count(0)
        local restored = vim.deepcopy(view)
        restored.lnum = math.max(1, math.min(restored.lnum or 1, line_count))
        restored.topline = math.max(1, math.min(restored.topline or restored.lnum, line_count))
        pcall(vim.fn.winrestview, restored)

        if vim.wo.previewwindow then
          vim.bo.bufhidden = "wipe"
        end
      end)
    end,
  })

  return preview_buf
end

local close_preview

local function set_preview_keymaps(buf)
  vim.keymap.set("n", "<C-w>h", focus_fyler, { buffer = buf, silent = true })
  vim.keymap.set("n", "<C-p>", close_preview, { buffer = buf, silent = true })
end

local function update_preview(entry)
  if not entry then
    return
  end

  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
    return
  end

  if preview_path == entry.path then
    return
  end

  local kind = entry.type == "directory" and "directory" or "file"
  local buf = kind == "directory"
    and prepare_directory_preview_buffer(entry.path)
    or prepare_file_preview_buffer(entry.path)
  vim.api.nvim_win_set_buf(preview_win, buf)
  set_preview_window_style(kind)
  set_preview_keymaps(buf)
  preview_path = entry.path
end

close_preview = function()
  if preview_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, preview_augroup)
  end

  preview_augroup = nil
  preview_path = nil
  preview_source_buf = nil
  preview_source_win = nil

  if preview_win and vim.api.nvim_win_is_valid(preview_win) then
    vim.api.nvim_win_close(preview_win, true)
  end

  preview_win = nil
end

local function resolve_target_window(explorer)
  local candidates = {
    preview_source_win,
    explorer.win.old_winid,
  }

  for _, winid in ipairs(candidates) do
    if type(winid) == "number" and vim.api.nvim_win_is_valid(winid) and winid ~= explorer.win.winid and winid ~= preview_win then
      return winid
    end
  end

  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if winid ~= explorer.win.winid and winid ~= preview_win and vim.api.nvim_win_is_valid(winid) then
      local bufnr = vim.api.nvim_win_get_buf(winid)
      if vim.bo[bufnr].filetype ~= "fyler" then
        return winid
      end
    end
  end

  if type(explorer.win.winid) == "number" and vim.api.nvim_win_is_valid(explorer.win.winid) then
    return explorer.win.winid
  end
end

local function open_file_in_target(explorer, action)
  return function()
    local entry = explorer:cursor_node_entry()
    if not entry then
      return
    end

    if entry.type == "directory" then
      explorer:exec_action("n_select")
      return
    end

    local target_win = resolve_target_window(explorer)
    if not target_win then
      return
    end

    explorer.win.old_winid = target_win
    explorer.win.old_bufnr = vim.api.nvim_win_get_buf(target_win)

    if action == "tabedit" then
      close_preview()
      vim.api.nvim_set_current_win(target_win)
      vim.api.nvim_win_call(target_win, function()
        vim.cmd.tabedit(vim.fn.fnameescape(entry.path))
      end)
      return
    elseif action == "edit" then
      vim.api.nvim_set_current_win(target_win)
      vim.api.nvim_win_call(target_win, function()
        vim.cmd.edit(vim.fn.fnameescape(entry.path))
      end)
    elseif action == "vsplit" then
      vim.api.nvim_set_current_win(target_win)
      vim.cmd.vsplit(vim.fn.fnameescape(entry.path))
    elseif action == "split" then
      vim.api.nvim_set_current_win(target_win)
      vim.cmd.split(vim.fn.fnameescape(entry.path))
    end

    close_preview()
  end
end

local function close_preview_before_action(action)
  return function(explorer)
    if preview_source_win and vim.api.nvim_win_is_valid(preview_source_win) then
      explorer.win.old_winid = preview_source_win
    end
    if preview_source_buf and vim.api.nvim_buf_is_valid(preview_source_buf) then
      explorer.win.old_bufnr = preview_source_buf
    end
    close_preview()
    explorer:exec_action(action)
  end
end

local function close_preview_before_file_action(action)
  return function(explorer)
    local mapped_action = ({
      n_select = "edit",
      n_select_v_split = "vsplit",
      n_select_split = "split",
      n_select_tab = "tabedit",
    })[action]

    if mapped_action then
      open_file_in_target(explorer, mapped_action)()
      return
    end

    explorer:exec_action(action)
  end
end

local function toggle_preview(explorer)
  if preview_win and vim.api.nvim_win_is_valid(preview_win) then
    close_preview()
    return
  end

  local entry = explorer:cursor_node_entry()
  if not entry then
    return
  end

  if not explorer.win or not vim.api.nvim_win_is_valid(explorer.win.winid) then
    return
  end

  fyler_win = explorer.win.winid
  preview_source_buf = explorer.win.old_bufnr
  preview_source_win = explorer.win.old_winid
  show_line_numbers(fyler_win)

  vim.api.nvim_set_current_win(fyler_win)
  vim.cmd.vsplit()
  preview_win = vim.api.nvim_get_current_win()
  vim.wo[preview_win].previewwindow = true

  local kind = entry.type == "directory" and "directory" or "file"
  local buf = kind == "directory"
    and prepare_directory_preview_buffer(entry.path)
    or prepare_file_preview_buffer(entry.path)
  vim.api.nvim_win_set_buf(preview_win, buf)
  set_preview_window_style(kind)
  set_preview_keymaps(buf)
  preview_path = entry.path

  preview_augroup = vim.api.nvim_create_augroup("FylerPreview", { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = vim.api.nvim_win_get_buf(fyler_win),
    group = preview_augroup,
    callback = function()
      update_preview(explorer:cursor_node_entry())
    end,
  })

  vim.api.nvim_set_current_win(fyler_win)
end

return {
  {
    "A7Lavinraj/fyler.nvim",
    branch = "stable",
    lazy = false,
    dependencies = { "nvim-mini/mini.icons" },
    opts = {
      views = {
        finder = {
          close_on_select = false,
          watcher = { enabled = true },
          mappings = {
            ["q"] = close_preview_before_action("n_close"),
            ["<CR>"] = close_preview_before_file_action("n_select"),
            ["<C-s>"] = close_preview_before_file_action("n_select_v_split"),
            ["<C-h>"] = close_preview_before_file_action("n_select_split"),
            ["<C-t>"] = close_preview_before_file_action("n_select_tab"),
            ["<C-p>"] = toggle_preview,
            ["<C-w>l"] = focus_preview,
          },
        },
      },
    },
    config = function(_, opts)
      local fyler = require("fyler")
      fyler.setup(opts)

      pcall(vim.api.nvim_del_augroup_by_name, "fyler_augroup_global")
      local augroup = vim.api.nvim_create_augroup("fyler_augroup_global", { clear = true })
      local config = require("fyler.config")

      if config.values.views.finder.default_explorer then
        vim.cmd("silent! autocmd! FileExplorer *")
        vim.cmd("autocmd VimEnter * ++once silent! autocmd! FileExplorer *")

        vim.api.nvim_create_autocmd("BufEnter", {
          group = augroup,
          pattern = "*",
          desc = "Hijack NETRW commands",
          callback = function(arg)
            if vim.api.nvim_get_current_buf() ~= arg.buf then
              return
            end

            local path = vim.api.nvim_buf_get_name(0)
            if vim.fn.isdirectory(path) ~= 1 then
              return
            end

            vim.api.nvim_buf_delete(0, { force = true })
            fyler.open({ dir = path })
          end,
        })
      end

      vim.api.nvim_create_autocmd("ColorScheme", {
        group = augroup,
        desc = "Adjust highlight groups with respect to colorscheme",
        callback = function()
          require("fyler.lib.hl").setup()
        end,
      })

      if config.values.views.finder.follow_current_file then
        vim.api.nvim_create_autocmd("BufEnter", {
          group = augroup,
          desc = "Track current focused buffer in finder",
          callback = vim.schedule_wrap(function(arg)
            if vim.wo.previewwindow then
              return
            end
            fyler.navigate(arg.file)
          end),
        })
      end

      vim.api.nvim_create_autocmd("BufWinEnter", {
        group = augroup,
        desc = "Drop finder window when buffer inside it changes to NON FYLER BUFFER",
        callback = function()
          require("fyler.views.finder").recover()
        end,
      })
    end,
    init = function()
      vim.api.nvim_create_user_command("FylerHere", function(command_opts)
        local dir = command_opts.args ~= "" and command_opts.args or vim.fn.getcwd()
        require("fyler").open({ dir = dir, kind = "split_left" })
      end, {
        nargs = "?",
        complete = "dir",
        desc = "Open Fyler in the given directory",
      })
    end,
    keys = {
      {
        "<leader>ee",
        function()
          require("fyler").open({ kind = "split_left" })
        end,
        desc = "Open Fyler",
      },
    },
  },
}
