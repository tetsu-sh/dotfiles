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
				formatter = {
					quote_json_variables = false,
				},
			},
		},
	},
}
