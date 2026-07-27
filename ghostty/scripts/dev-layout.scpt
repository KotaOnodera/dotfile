-- Ghostty Dev Layout (System Events版)
-- 左40% / 右60%
-- 左: 上65%(yazi) / 下35%(gitui)
-- 右: 上45%(cage claude) / 下55%(シェル)
--
-- 既存のキーバインドを利用してSystem Events経由でレイアウトを構築

-- 調整用パラメータ（リサイズのキー送信回数）
property RESIZE_H_COUNT : 7 -- 左右分割の調整回数（左を狭くする）
property RESIZE_LV_COUNT : 3 -- 左ペインの上下調整回数（上を広くする）
property RESIZE_RV_COUNT : 1 -- 右ペインの上下調整回数（下を広くする）

tell application "System Events"
	tell process "Ghostty"
		-- 1. 右に分割 (opt+shift+enter)
		key code 36 using {option down, shift down}
		delay 0.3

		-- 右ペインに cage claude と入力
		keystroke "cage claude"
		key code 36
		delay 0.3

		-- 2. 左ペインに移動 (opt+left)
		key code 123 using {option down}
		delay 0.2

		-- 3. 左を40%に縮小 (opt+shift+left を繰り返す)
		repeat RESIZE_H_COUNT times
			key code 123 using {option down, shift down}
			delay 0.05
		end repeat
		delay 0.2

		-- 4. 左ペインを下に分割 (opt+enter)
		key code 36 using {option down}
		delay 0.3

		-- 左下ペインに gitui と入力
		keystroke "gitui"
		key code 36
		delay 0.3

		-- 5. 左上ペインに移動 (opt+up)
		key code 126 using {option down}
		delay 0.2

		-- 6. 左上を65%に拡大 (opt+shift+down を繰り返す)
		repeat RESIZE_LV_COUNT times
			key code 125 using {option down, shift down}
			delay 0.05
		end repeat
		delay 0.2

		-- 7. 左上ペインに yazi と入力
		keystroke "yazi"
		key code 36
		delay 0.3

		-- 8. 右上ペインに移動 (opt+right)
		key code 124 using {option down}
		delay 0.2

		-- 9. 右ペインを下に分割 (opt+enter)
		key code 36 using {option down}
		delay 0.3

		-- 10. 右下を55%に拡大 (opt+shift+up を繰り返す)
		repeat RESIZE_RV_COUNT times
			key code 126 using {option down, shift down}
			delay 0.05
		end repeat
		delay 0.2

		-- 右下ペイン（シェル）にフォーカスしたまま完了
	end tell
end tell
