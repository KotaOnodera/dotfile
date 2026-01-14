-- https://tubone-project24.xyz/2022/08/29/wezterm/


local wezterm = require 'wezterm';
local config = {}

-- config
if wezterm.config_builder then
  config = wezterm.config_builder()
end

config.font_size = 14
-- https://wezfurlong.org/wezterm/colorschemes/v/index.html?highlight=VibrantInk#vibrantink
config.color_scheme = 'VibrantInk'

config.default_prog = { 'zsh' }

config.window_background_opacity = 0.80
config.adjust_window_size_when_changing_font_size = false
config.window_close_confirmation = 'AlwaysPrompt'
config.animation_fps = 1
config.default_cursor_style = 'BlinkingBlock'
config.enable_scroll_bar = true


-- Equivalent to POSIX basename(3)
-- Given "/foo/bar" returns "bar"
-- Given "c:\\foo\\bar" returns "bar"
local function basename(s)
	return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

-- タブのカスタマイズ
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)

    -- プロセスに合わせてアイコン表示
	local nerd_icons = {
		nvim = wezterm.nerdfonts.custom_vim,
		vim = wezterm.nerdfonts.custom_vim,
		bash = wezterm.nerdfonts.dev_terminal,
		zsh = wezterm.nerdfonts.dev_terminal,
		ssh = wezterm.nerdfonts.mdi_server,
		top = wezterm.nerdfonts.mdi_monitor,
        docker = wezterm.nerdfonts.dev_docker,
        node = wezterm.nerdfonts.dev_nodejs_small,
	}
    local zoomed = ""
    if tab.active_pane.is_zoomed then
      zoomed = "[Z] "
    end
	local pane = tab.active_pane
	local process_name = basename(pane.foreground_process_name)
	local icon = nerd_icons[process_name]
	local index = tab.tab_index + 1
	local cwd = basename(pane.current_working_dir)
    
    -- 例) 1:project_dir | zsh
	local title = index .. ": " .. cwd .. "  | " .. process_name
	if icon ~= nil then
		title = icon .. "  " .. zoomed .. title
	end
	return {
		{ Text = " " .. title .. " " },
	}
end)


-- 右ステータスのカスタマイズ
wezterm.on("update-right-status", function(window, pane)
    local cells = {};
    -- 現在のディレクトリ
    local cwd_uri = pane:get_current_working_dir()
    if cwd_uri then
      cwd_uri = cwd_uri:sub(8);
      local slash = cwd_uri:find("/")
      local cwd = ""
      local hostname = ""
      local leader = ''
      if window:leader_is_active() then
        leader = 'LEADER'
      end
      -- paneの累計IDを取得
      local pane_id = pane:pane_id()
      if slash then
        hostname = cwd_uri:sub(1, slash-1)
        local dot = hostname:find("[.]")
        if dot then
          hostname = hostname:sub(1, dot-1)
        end
        cwd = cwd_uri:sub(slash)
  
        table.insert(cells, cwd);
        table.insert(cells, pane_id);
        table.insert(cells, leader);
      end
    end
  
    -- 時刻表示
    local date = wezterm.strftime("%m/%-d %H:%M:%S %a");
    table.insert(cells, wezterm.nerdfonts.mdi_clock .. '  ' .. date);
  
    -- バッテリー
    for _, b in ipairs(wezterm.battery_info()) do
      table.insert(cells, string.format("%.0f%%", b.state_of_charge * 100))
    end
  
    -- The powerline < symbol
    local LEFT_ARROW = utf8.char(0xe0b3);
    -- The filled in variant of the < symbol
    local SOLID_LEFT_ARROW = utf8.char(0xe0b2)
  
    -- Color palette for the backgrounds of each cell
    local colors = {
      "#3c1361",
      "#52307c",
      "#663a82",
      "#7c5295",
      "#b491c8",
    };
  
    -- Foreground color for the text across the fade
    local text_fg = "#c0c0c0";
  
    -- The elements to be formatted
    local elements = {};
    -- How many cells have been formatted
    local num_cells = 0;
  
    -- Translate a cell into elements
    function push(text, is_last)
      local cell_no = num_cells + 1
      table.insert(elements, {Foreground={Color=text_fg}})
      table.insert(elements, {Background={Color=colors[cell_no]}})
      table.insert(elements, {Text=" "..text.." "})
      if not is_last then
        table.insert(elements, {Foreground={Color=colors[cell_no+1]}})
        table.insert(elements, {Text=SOLID_LEFT_ARROW})
      end
      num_cells = num_cells + 1
    end
  
    while #cells > 0 do
      local cell = table.remove(cells, 1)
      push(cell, #cells == 0)
    end
  
    window:set_right_status(wezterm.format(elements));
  end);

-- その他のカスタマイズ
  return config