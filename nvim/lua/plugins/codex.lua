local function build_codex_cmd(prompt)
  local cmd = {}

  if (vim.env.GITHUB_PAT_TOKEN_MCP == nil or vim.env.GITHUB_PAT_TOKEN_MCP == "")
      and vim.env.GITHUB_PAT ~= nil
      and vim.env.GITHUB_PAT ~= "" then
    cmd = {
      "env",
      "GITHUB_PAT_TOKEN_MCP=" .. vim.env.GITHUB_PAT,
    }
  end

  vim.list_extend(cmd, {
    "codex",
    "--no-alt-screen",
    "-C",
    vim.fn.getcwd(),
  })

  if prompt ~= nil and prompt ~= "" then
    table.insert(cmd, prompt)
  end

  return table.concat(vim.tbl_map(vim.fn.shellescape, cmd), " ")
end

local function setup_disposable_terminal()
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
end

local function open_codex_terminal(layout_cmd, prompt)
  if layout_cmd and layout_cmd ~= "" then
    vim.cmd(layout_cmd)
  end

  vim.cmd("terminal " .. build_codex_cmd(prompt))
  setup_disposable_terminal()
  vim.cmd("startinsert")
end

local function resolve_tab(target)
  if target == nil or target == 0 then
    local current = vim.api.nvim_get_current_tabpage()
    return current, vim.api.nvim_tabpage_get_number(current)
  end

  if type(target) == "number" then
    local ok = pcall(vim.api.nvim_tabpage_get_number, target)
    if ok then
      return target, vim.api.nvim_tabpage_get_number(target)
    end

    for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
      if vim.api.nvim_tabpage_get_number(tabpage) == target then
        return tabpage, target
      end
    end
  end
end

local function is_terminal_only_tab(tabpage)
  if not tabpage or not vim.api.nvim_tabpage_is_valid(tabpage) then
    return false
  end

  local wins = vim.api.nvim_tabpage_list_wins(tabpage)
  if #wins == 0 then
    return false
  end

  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype ~= "terminal" then
      return false
    end
  end

  return true
end

local function close_tab_safely(target)
  local tabpage, tabnr = resolve_tab(target)
  if not tabnr then
    vim.notify("Could not resolve tab to close", vim.log.levels.ERROR)
    return
  end

  local ok, err = pcall(vim.cmd, "tabclose " .. tabnr)
  if ok then
    return
  end

  if is_terminal_only_tab(tabpage) then
    local force_ok, force_err = pcall(vim.cmd, tabnr .. "tabclose!")
    if force_ok then
      return
    end
    err = force_err
  end

  vim.notify(err, vim.log.levels.ERROR)
end

return {
  {
    "milanglacier/minuet-ai.nvim",
    enabled = false,
    event = "InsertEnter",
    opts = {
      provider = "openai",
      request_timeout = 12,
      throttle = 1200,
      debounce = 400,
      notify = "debug",
      virtualtext = {
        auto_trigger_ft = {
          "lua",
          "javascript",
          "typescript",
          "javascriptreact",
          "typescriptreact",
          "json",
          "yaml",
          "markdown",
          "python",
          "go",
          "rust",
          "sh",
          "zsh",
        },
        keymap = {
          accept = "<A-y>",
          accept_line = "<A-l>",
          next = "<A-]>",
          prev = "<A-[>",
          dismiss = "<A-e>",
        },
      },
      provider_options = {
        openai = {
          model = "gpt-5-nano",
          api_key = "OPENAI_API_KEY",
          end_point = "https://api.openai.com/v1/chat/completions",
          stream = false,
          optional = {
            max_completion_tokens = 96,
            reasoning_effort = "minimal",
          },
        },
      },
    },
    config = function(_, opts)
      if vim.env.OPENAI_API_KEY == nil or vim.env.OPENAI_API_KEY == "" then
        vim.schedule(function()
          vim.notify(
            "Minuet is disabled until OPENAI_API_KEY is set. Codex chat still works with :CodexChat.",
            vim.log.levels.WARN
          )
        end)
        return
      end

      require("minuet").setup(opts)
    end,
  },
  {
    "LazyVim/LazyVim",
    keys = {
      {
        "<leader>cc",
        function()
          open_codex_terminal("botright 15split")
        end,
        desc = "Codex Chat",
      },
      {
        "<leader>cC",
        function()
          open_codex_terminal("tabnew")
        end,
        desc = "Codex Chat Tab",
      },
      {
        "<leader><tab>d",
        function()
          close_tab_safely()
        end,
        desc = "Close Tab",
      },
    },
    init = function()
      vim.api.nvim_create_user_command("CodexChat", function(opts)
        open_codex_terminal("botright 15split", opts.args)
      end, {
        nargs = "*",
        desc = "Open Codex CLI in a split",
      })
    end,
  },
  {
    "akinsho/bufferline.nvim",
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.close_command = close_tab_safely
      opts.options.right_mouse_command = close_tab_safely
    end,
  },
}
