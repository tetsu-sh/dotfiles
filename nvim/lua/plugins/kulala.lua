return {
	{
		"mistweaverco/kulala.nvim",
		ft = { "http", "rest" },
		keys = {
			{ "<leader>R", "", desc = "+Rest" },
			{
				"<leader>Ra",
				function()
					require("kulala").run_all()
				end,
				desc = "Send all requests",
				ft = { "http", "rest" },
			},
			{
				"<leader>Rb",
				function()
					require("kulala").scratchpad()
				end,
				desc = "Open scratchpad",
			},
			{
				"<leader>Rc",
				function()
					require("kulala").copy()
				end,
				desc = "Copy as cURL",
				ft = { "http", "rest" },
			},
			{
				"<leader>RC",
				function()
					require("kulala").from_curl()
				end,
				desc = "Paste from cURL",
				ft = { "http", "rest" },
			},
			{
				"<leader>Re",
				function()
					require("kulala").set_selected_env()
				end,
				desc = "Set environment",
				ft = { "http", "rest" },
			},
			{
				"<leader>Ri",
				function()
					require("kulala").inspect()
				end,
				desc = "Inspect request",
				ft = { "http", "rest" },
			},
			{
				"<leader>Rn",
				function()
					require("kulala").jump_next()
				end,
				desc = "Next request",
				ft = { "http", "rest" },
			},
			{
				"<leader>Ro",
				function()
					require("kulala").open()
				end,
				desc = "Open response UI",
				ft = { "http", "rest" },
			},
			{
				"<leader>Rp",
				function()
					require("kulala").jump_prev()
				end,
				desc = "Previous request",
				ft = { "http", "rest" },
			},
			{
				"<leader>Rq",
				function()
					require("kulala").close()
				end,
				desc = "Close response window",
				ft = { "http", "rest" },
			},
			{
				"<leader>Rr",
				function()
					require("kulala").replay()
				end,
				desc = "Replay last request",
			},
			{
				"<leader>Rs",
				function()
					require("kulala").run()
				end,
				desc = "Send request",
				ft = { "http", "rest" },
			},
			{
				"<leader>RS",
				function()
					require("kulala").show_stats()
				end,
				desc = "Show stats",
				ft = { "http", "rest" },
			},
			{
				"<leader>Rt",
				function()
					require("kulala").toggle_view()
				end,
				desc = "Toggle response view",
				ft = { "http", "rest" },
			},
		},
		opts = {
			default_env = "local",
			global_keymaps = false,
			global_keymaps_prefix = "<leader>R",
			kulala_keymaps_prefix = "",
			ui = {
				display_mode = "split",
				split_direction = "horizontal",
				default_view = "headers_body",
				show_request_summary = true,
				win_opts = {
					height = 18,
					wo = {
						wrap = true,
						linebreak = true,
					},
				},
			},
			lsp = {
				formatter = false,
			},
		},
		config = function(_, opts)
			require("kulala").setup(opts)
			local body_formatter = require("config.http_json_body_formatter")

			local augroup = vim.api.nvim_create_augroup("kulala-best-effort-format", { clear = true })

			local function collect_json_body_nodes(node, acc)
				acc = acc or {}
				if node:type() == "json_body" then
					table.insert(acc, node)
					return acc
				end
				for child in node:iter_children() do
					collect_json_body_nodes(child, acc)
				end
				return acc
			end

			vim.api.nvim_create_autocmd("FileType", {
				group = augroup,
				pattern = { "http", "rest" },
				callback = function(event)
					vim.b[event.buf].autoformat = false
				end,
			})

			vim.api.nvim_create_autocmd("BufWritePre", {
				group = augroup,
				pattern = { "*.http", "*.rest" },
				callback = function(event)
					local ok, parser = pcall(vim.treesitter.get_parser, event.buf, "kulala_http")
					if not ok or not parser then
						return
					end

					local tree = parser:parse()[1]
					if not tree then
						return
					end

					local json_nodes = collect_json_body_nodes(tree:root())
					for index = #json_nodes, 1, -1 do
						local node = json_nodes[index]
						local formatted = body_formatter.format_json_like_body(vim.treesitter.get_node_text(node, event.buf))
						if formatted then
							local start_row, start_col, end_row, end_col = node:range()
							local replacement = vim.split(formatted, "\n", { plain = true })
							local end_line = vim.api.nvim_buf_get_lines(event.buf, end_row, end_row + 1, false)[1] or ""
							if end_col == 0 and end_line ~= "" then
								table.insert(replacement, "")
							end
							pcall(vim.api.nvim_buf_set_text, event.buf, start_row, start_col, end_row, end_col, replacement)
						end
					end
				end,
			})
		end,
	},
}
