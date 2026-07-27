-- Ghostty Simple Split Layout (System Events版)
-- 左50%: シェル / 右50%: シェル

tell application "System Events"
	tell process "Ghostty"
		-- 右に分割 (opt+shift+enter)
		key code 36 using {option down, shift down}
		delay 0.3

		-- 左ペインに移動 (opt+left)
		key code 123 using {option down}
	end tell
end tell
