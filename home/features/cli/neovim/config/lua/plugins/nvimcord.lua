-- discord.lua

return {
	"ObserverOfTime/nvimcord",
	opts = {
		-- Start the RPC manually (boolean)
		autostart = true,

		-- Set the client ID (string)
		client_id = "655423421110550558",

		-- Update workspace on chdir (boolean)
		dynamic_workspace = true,

		-- Use the filetype as the large icon (boolean)
		large_file_icon = true,

		-- Set the log level (vim.log.levels.*)
		log_level = vim.log.levels.INFO,

		-- Get the workspace name (function|string)
		workspace_name = function()
			return [[pwd | sed 's:.*/::']]
		end,

		-- Get the workspace URL (function|string)
		workspace_url = function()
			return [[git remote get-url origin]]
		end,
	},
}
