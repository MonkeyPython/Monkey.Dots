-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                          MONKEY DOTS - WEZTERM                               ║
-- ║                  Adapted from Gentleman.Dots, palette "monkey"              ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

local wezterm = require("wezterm")
local config = {}

-- ┌──────────────────────────────────────────────────────────────────────────────┐
-- │                                   FONT                                       │
-- └──────────────────────────────────────────────────────────────────────────────┘

config.font = wezterm.font("IosevkaTerm NF")
config.font_size = 14.0

-- ┌──────────────────────────────────────────────────────────────────────────────┐
-- │                                  WINDOW                                      │
-- └──────────────────────────────────────────────────────────────────────────────┘

config.window_background_opacity = 0.95
config.macos_window_background_blur = 20
config.win32_system_backdrop = "Acrylic"

config.window_padding = {
	top = 0,
	right = 0,
	left = 0,
	bottom = 0,
}

config.enable_scroll_bar = false
config.hide_tab_bar_if_only_one_tab = true

-- ┌──────────────────────────────────────────────────────────────────────────────┐
-- │                                  CURSOR                                      │
-- └──────────────────────────────────────────────────────────────────────────────┘

config.default_cursor_style = "SteadyBlock"
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- ┌──────────────────────────────────────────────────────────────────────────────┐
-- │                            NEOVIM OPTIMIZATIONS                              │
-- └──────────────────────────────────────────────────────────────────────────────┘

if wezterm.target_triple:find("windows") then
  config.term = "xterm-256color"
else
  config.term = "wezterm"
end
config.enable_csi_u_key_encoding = true

config.underline_thickness = 2
config.underline_position = -2

config.scrollback_lines = 10000
config.max_fps = 240

config.enable_kitty_graphics = true

config.use_dead_keys = false
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

-- ┌──────────────────────────────────────────────────────────────────────────────┐
-- │                            MONKEY THEME                                      │
-- │                                                                            │
-- │  Inspired by Gentleman palette. Two accents nudged to make it ours:        │
-- │    yellow  #FFE066 -> #F5A524  (warmer amber)                               │
-- │    mauve   #A3B5D6 -> #C792EA  (deeper violet)                              │
-- └──────────────────────────────────────────────────────────────────────────────┘

config.colors = {
	foreground = "#F3F6F9",
	background = "#06080F",

	cursor_bg = "#E0C15A",
	cursor_fg = "#06080F",
	cursor_border = "#E0C15A",

	selection_fg = "#F3F6F9",
	selection_bg = "#263356",

	ansi = {
		"#06080F", -- black
		"#CB7C94", -- red
		"#B7CC85", -- green
		"#F5A524", -- yellow  (monkey)
		"#7FB4CA", -- blue
		"#C792EA", -- magenta (monkey)
		"#7AA89F", -- cyan
		"#F3F6F9", -- white
	},

	brights = {
		"#8A8FA3", -- black
		"#DE8FA8", -- red
		"#D1E8A9", -- green
		"#FFC56B", -- yellow  (monkey)
		"#A3D4D5", -- blue
		"#D8B4FE", -- magenta (monkey)
		"#7FB4CA", -- cyan
		"#F3F6F9", -- white
	},
}

-- ┌──────────────────────────────────────────────────────────────────────────────┐
-- │                            WINDOWS (WSL)                                     │
-- └──────────────────────────────────────────────────────────────────────────────┘

-- Uncomment for Windows/WSL:
-- config.default_domain = 'WSL:Ubuntu'
-- config.front_end = "OpenGL"

return config
