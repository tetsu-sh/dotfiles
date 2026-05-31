local preview_win
local preview_path
local preview_augroup
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

  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  vim.bo[buf].buflisted = false
  vim.bo[buf].modifiable = false

  if vim.bo[buf].filetype == "" then
    local filetype = vim.filetype.match({ filename = path, buf = buf })
    if filetype then
      vim.bo[buf].filetype = filetype
    end
  end

  if vim.bo[buf].syntax == "" and vim.bo[buf].filetype ~= "" then
    vim.bo[buf].syntax = vim.bo[buf].filetype
  end

  pcall(vim.treesitter.start, buf)
  return buf
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

  if preview_win and vim.api.nvim_win_is_valid(preview_win) then
    vim.api.nvim_win_close(preview_win, true)
  end

  preview_win = nil
end

local function close_preview_before_action(action)
  return function(explorer)
    close_preview()
    explorer:exec_action(action)
  end
end

local function close_preview_before_file_action(action)
  return function(explorer)
    local entry = explorer:cursor_node_entry()
    if entry and entry.type == "file" then
      close_preview()
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
  show_line_numbers(fyler_win)

  vim.api.nvim_set_current_win(fyler_win)
  vim.cmd.vsplit()
  preview_win = vim.api.nvim_get_current_win()

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
