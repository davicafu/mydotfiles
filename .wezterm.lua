local wezterm = require("wezterm")
local config = {}

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- %%%                                    FONT                                      %%%
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

config.font = wezterm.font("Inconsolata Nerd Font")
config.font_size = 14.0

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- %%%                                  WINDOW                                      %%%
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

config.window_background_opacity = 0.95
config.macos_window_background_blur = 20
config.win32_system_backdrop = "Acrylic"

config.window_padding = {
	top = 5,
	right = 5,
	left = 5,
	bottom = 5,
}

config.enable_scroll_bar = false
-- config.enable_tab_bar = false
-- config.hide_tab_bar_if_only_one_tab = true

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- %%%                                  CURSOR                                      %%%
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

config.default_cursor_style = "SteadyBlock"
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- %%%                            NEOVIM OPTIMIZATIONS                              %%%
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-- Terminal & Colors
-- WSL doesn't have wezterm terminfo, so we use xterm-256color there
-- See: https://github.com/Gentleman-Programming/Gentleman.Dots/issues/117
if wezterm.target_triple:find("windows") then
	config.term = "xterm-256color"
else
	config.term = "wezterm"
end
config.enable_csi_u_key_encoding = true

-- Undercurl support (LSP diagnostics, spelling)
config.underline_thickness = 2
config.underline_position = -2

-- Scrollback
config.scrollback_lines = 10000

-- Performance
config.max_fps = 240

-- Image support
config.enable_kitty_graphics = true

-- Input handling
config.use_dead_keys = false
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- %%%                                  THEME                                       %%%
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-- config.color_scheme = "Tokyo Night",
config.colors = {
	-- Base Colors
	foreground = "#f3f6f9",
	background = "#06080f",

	-- Cursor
	cursor_bg = "#e0c15a",
	cursor_fg = "#06080f",
	cursor_border = "#e0c15a",

	-- Selection
	selection_fg = "#f3f6f9",
	selection_bg = "#263356",

	-- Normal Colors
	ansi = {
		"#06080f", -- black
		"#ff6b6b", -- red
		"#7fd65a", -- green
		"#ffe066", -- yellow
		"#61afef", -- blue
		"#ff8dd7", -- magenta
		"#5fd7d7", -- cyan
		"#f3f6f9", -- white
	},

	-- Bright Colors
	brights = {
		"#8a8fa3", -- black
		"#ff9a9a", -- red
		"#a5e87b", -- green
		"#fff0a0", -- yellow
		"#8cc8ff", -- blue
		"#ffaeea", -- magenta
		"#8ee8e8", -- cyan
		"#e5e7eb", -- white
	},
}

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- %%%                            WINDOWS (WSL)                                     %%%
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-- Uncomment for Windows/WSL:
config.default_domain = "WSL:Ubuntu"
config.front_end = "OpenGL"

return config
