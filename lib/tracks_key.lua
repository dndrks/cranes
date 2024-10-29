local key_actions = {}

function key_actions.parse(n, z)
	if ui.control_set == "step parameters" then
		_fkprm.key(n, z)
	elseif ui.control_set == "poly parameters" then
		_polyparams.key(n, z)
	else
		if z == 1 then
			-- local s_c = ui.screen_controls[ui.seq_focus][hills[ui.seq_focus].screen_focus]
			local i = ui.seq_focus
			if n == 1 then
				if ui.control_set == "edit" then
					key1_hold = not key1_hold
				else
					key1_hold = true
				end
			elseif n == 2 then
				if not key1_hold then
					if ui.control_set == "edit" or ui.control_set == "play" then
						key2_hold_counter:start()
					end
				else
					if ui.control_set == "edit" then
						if ui.menu_focus == 1 then
						elseif ui.menu_focus == 3 then
						-- _t.mute(i,j,s_c.notes.focus)
						elseif ui.menu_focus == 5 then
							_t.toggle_loop(i, j, s_c.samples.focus)
						end
					end
				end
			elseif n == 3 then
				if ui.control_set == "play" then
					if KEY2_hold and not key1_hold then
						_fkprm.flip_to_fkprm("play")
					else
						ui.control_set = "edit"
					end
				elseif ui.control_set == "edit" then
					if KEY2_hold and not key1_hold then
						_fkprm.flip_to_fkprm("edit")
					else
            if ui.menu_focus == 1 then
              -- print('k3 pressed')
              if not grid_conditional_entry then
                grid_conditional_entry = true
                conditional_entry_steps.focus[i] = { sequence[i][sequence[i].page].ui_position }
              else
                grid_conditional_entry = false
                conditional_entry_steps.focus[i] = {}
              end
            elseif ui.menu_focus == 2 then
              if key1_hold and ui.popup_focus.tracks[i][2] == 4 then
                _tracks.generate_er(i, j, tracks_ui.seq_page[i])
              end
            elseif ui.menu_focus == 3 then
              _tracks.reset_note_to_default(i, j)
            end
					end
				elseif ui.control_set == "step parameters" and hills[i].highway == false then
					ui.control_set = "edit"
				elseif ui.control_set == "seq" and hills[i].highway == false then
					if ui.seq_menu_layer == "edit" then
						ui.seq_menu_layer = "deep_edit"
					elseif ui.seq_menu_layer == "nav" then
						ui.seq_menu_layer = "edit"
					end
				end
			end
		elseif z == 0 then
			local i = ui.seq_focus
			if n == 1 and ui.control_set ~= "edit" then
				key1_hold = false
			elseif n == 2 and not ignore_key2_up then
				if KEY2_hold == false then
					key2_hold_counter:stop()
					if key1_hold then
						key1_hold = false
					else
						ui.control_set = ui.control_set ~= "play" and "play" or "song"
						grid_conditional_entry = false
						conditional_entry_steps.focus[i] = {}
					end
					if key1_hold and ui.control_set ~= "edit" then
						key1_hold = false
					end
				else
					KEY2_hold = false
				end
			elseif n == 2 and ignore_key2_up then
				ignore_key2_up = false
				KEY2_hold = false
			end
		end
	end
end

return key_actions
