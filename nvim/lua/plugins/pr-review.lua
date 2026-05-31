return {
  {
    "sindrets/diffview.nvim",
    lazy = true,
    cmd = {
      "DiffviewFileHistory",
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
      "DiffviewToggleFiles",
      "PRDiff",
    },
    init = function()
      vim.api.nvim_create_user_command("PRDiff", function(opts)
        local pr = opts.args ~= "" and opts.args or nil
        local view_cmd = { "gh", "pr", "view" }
        if pr then
          table.insert(view_cmd, pr)
        end
        vim.list_extend(view_cmd, { "--json", "baseRefName,headRefName,number,url", "--jq", "[.baseRefName,.headRefName] | @tsv" })

        vim.system(view_cmd, { text = true }, function(result)
          if result.code ~= 0 then
            vim.schedule(function()
              vim.notify((result.stderr ~= "" and result.stderr or result.stdout):gsub("%s+$", ""), vim.log.levels.ERROR)
            end)
            return
          end

          local base, head = result.stdout:match("([^\t]+)\t([^\n]+)")
          if not base or not head then
            vim.schedule(function()
              vim.notify("Failed to resolve PR base/head refs", vim.log.levels.ERROR)
            end)
            return
          end

          vim.schedule(function()
            require("lazy").load({ plugins = { "diffview.nvim" } })
            vim.cmd("DiffviewOpen origin/" .. base .. "...origin/" .. head)
          end)
        end)
      end, {
        nargs = "?",
        desc = "Open Diffview for a PR",
      })
    end,
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
      { "<leader>gD", "<cmd>DiffviewClose<cr>", desc = "Diffview Close" },
      { "<leader>gp", "<cmd>PRDiff<cr>", desc = "PR Diffview" },
    },
  },
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "folke/snacks.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Octo",
    opts = {
      picker = "snacks",
      review = {
        auto_show_threads = true,
        focus = "right",
      },
      file_panel = {
        size = 12,
        use_icons = true,
      },
    },
    keys = {
      { "<leader>go", "<cmd>Octo pr list<cr>", desc = "Octo PR List" },
      { "<leader>gr", "<cmd>Octo review start<cr>", desc = "Octo Review Start" },
      { "<leader>gc", "<cmd>Octo review comments<cr>", desc = "Octo Review Comments" },
      { "<leader>gs", "<cmd>Octo review submit<cr>", desc = "Octo Review Submit" },
    },
  },
}
