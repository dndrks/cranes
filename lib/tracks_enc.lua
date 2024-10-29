local enc_actions = {}

function enc_actions.delta_track_pos(i, j, d, jump_page)
	if not jump_page then
		-- print("before", i, j, sequence[i][j].ui_position,tracks_ui.seq_page[i])
		if sequence[i][j].ui_position + d < 1 then
			local pre_change = tracks_ui.seq_page[i]
			tracks_ui.seq_page[i] = util.clamp(tracks_ui.seq_page[i] - 1, 1, 8)
			if pre_change ~= tracks_ui.seq_page[i] then
				sequence[i][tracks_ui.seq_page[i]].ui_position = 24
			end
		elseif sequence[i][j].ui_position + d > 24 then
			local pre_change = tracks_ui.seq_page[i]
			tracks_ui.seq_page[i] = util.clamp(tracks_ui.seq_page[i] + 1, 1, 8)
			if pre_change ~= tracks_ui.seq_page[i] then
				sequence[i][tracks_ui.seq_page[i]].ui_position = 1
			end
		else
			sequence[i][j].ui_position = util.clamp(sequence[i][j].ui_position + d, 1, 24)
		end
	else
		tracks_ui.seq_page[i] = util.clamp(tracks_ui.seq_page[i] + (d > 0 and 1 or -1), 1, 8)
	end
	-- print("after", i, j, sequence[i][j].ui_position, tracks_ui.seq_page[i])
end

function check_for_menu_condition(i)
	if (key1_hold or (#conditional_entry_steps.focus[i] > 0)) and ui.control_set == "edit" then
		return true
	else
		return false
	end
end

function enc_actions.parse(n, d)
	if ui.control_set == "step parameters" then
		_fkprm.enc(n, d)
	else
		-- local s_c = ui.screen_controls[ui.seq_focus][hills[ui.seq_focus].screen_focus]
		local s_c = ui.screen_controls[ui.seq_focus]
		local i = ui.seq_focus
		-- local j = hills[i].screen_focus
		local j = tracks_ui.seq_page[i]
		local s_q = ui.seq_controls[i]
		if n == 1 then
			if ui.control_set == "play" then
				ui.seq_focus = util.clamp(ui.seq_focus + d, 1, number_of_sequencers)
				if ui.seq_focus < 8 then
					if ui.menu_focus == 5 then
						ui.menu_focus = 4
					end
				end
        tracks_ui.seq_page[ui.seq_focus] = sequence[ui.seq_focus].page
			elseif ui.control_set == "edit" then
				if key1_hold then
					enc_actions.delta_track_pos(i, j, d)
				else
					ui.seq_focus = util.clamp(ui.seq_focus + d, 1, number_of_sequencers)
					if ui.seq_focus < 8 then
						if ui.menu_focus == 5 then
							ui.menu_focus = 4
						end
					end
				end
			end
		elseif n == 2 then
			if ui.control_set == "play" then
				-- if params:string("hill " .. i .. " sample output") == "yes" then
				-- 	ui.menu_focus = util.clamp(ui.menu_focus + d, 1, 5)
				-- else
				-- 	ui.menu_focus = util.clamp(ui.menu_focus + d, 1, ui.seq_focus <= 7 and 4 or 5)
				-- end
				ui.menu_focus = util.clamp(ui.menu_focus + d, 1, 5)
			elseif ui.control_set == "edit" then
        if ui.menu_focus == 1 then
          -- if key1_hold then
          if check_for_menu_condition(i) then
            ui.popup_focus.tracks[i][1] = util.clamp(ui.popup_focus.tracks[i][1] + d, 1, 5)
          else
            enc_actions.delta_track_pos(i, j, d)
          end
        elseif ui.menu_focus == 2 then
          if key1_hold then
            ui.popup_focus.tracks[i][2] = util.clamp(ui.popup_focus.tracks[i][2] + d, 1, 4)
          else
            s_c["bounds"]["focus"] = util.clamp(s_c["bounds"]["focus"] + d, 1, s_c["bounds"]["max"])
            -- for _hills = 1, 8 do
            --   ui.screen_controls[ui.seq_focus]["bounds"]["focus"] = s_c["bounds"]["focus"]
            -- end
          end
        elseif ui.menu_focus == 3 then
          if key1_hold then
            ui.popup_focus.tracks[i][3] = util.clamp(ui.popup_focus.tracks[i][3] + d, 1, 2)
          else
            enc_actions.delta_track_pos(i, j, d)
          end
        end
			elseif ui.control_set == "seq" then
				if ui.seq_menu_layer == "nav" then
					ui.seq_menu_focus = util.clamp(ui.seq_menu_focus + d, 1, 4)
				elseif ui.seq_menu_layer == "edit" then
					s_q["seq"]["focus"] = util.clamp(s_q["seq"]["focus"] + d, 1, 64)
				elseif ui.seq_menu_layer == "deep_edit" then
					s_q["trig_detail"]["focus"] =
						util.clamp(s_q["trig_detail"]["focus"] + d, 1, s_q["trig_detail"]["max"])
				end
			end
		elseif n == 3 then
			if ui.control_set ~= "seq" then
        local _pos = sequence[i][j].ui_position
        if ui.menu_focus == 1 then
          if ui.control_set == "edit" then
            -- if key1_hold then
            if check_for_menu_condition(i) then
              if ui.popup_focus.tracks[i][1] == 1 then
                _tUi.cycle_conditional(i, j, _pos, d)
              elseif ui.popup_focus.tracks[i][1] == 2 then
                _tUi.cycle_prob(i, j, _pos, d)
              elseif ui.popup_focus.tracks[i][1] == 3 then
                _tUi.cycle_retrig_count(i, j, _pos, d)
              elseif ui.popup_focus.tracks[i][1] == 4 then
                _tUi.cycle_retrig_time(i, j, _pos, d)
              elseif ui.popup_focus.tracks[i][1] == 5 then
                _tUi.cycle_retrig_vel(i, j, _pos, d)
              end
            else
              local _active = sequence[i]
              local _a = _active[tracks_ui.seq_page[i]]
              local focused_set = _a.focus == "main" and _a or _a.fill
              if d > 0 then
                if focused_set.trigs[_pos] == false then
                  _tracks.change_trig_state(
                    focused_set,
                    _pos,
                    true,
                    i,
                    j,
                    tracks_ui.seq_page[i]
                  )
                end
              else
                if focused_set.trigs[_pos] == true then
                  _tracks.change_trig_state(
                    focused_set,
                    _pos,
                    false,
                    i,
                    j,
                    tracks_ui.seq_page[i]
                  )
                end
              end
            end
          elseif ui.control_set == "play" then
            -- CHANGE EDIT POSITION
            -- hills[i].screen_focus = util.clamp(j + d, 1, #sequence[i])
            -- tracks_ui.seq_page[i] = math.ceil(sequence[i][hills[i].screen_focus].ui_position/16)
          end
        elseif ui.menu_focus == 2 and ui.control_set == "edit" then
          if key1_hold then
            if ui.popup_focus.tracks[i][2] == 1 then
              _tUi.cycle_er_param("pulses", i, j, d)
            elseif ui.popup_focus.tracks[i][2] == 2 then
              _tUi.cycle_er_param("steps", i, j, d)
            elseif ui.popup_focus.tracks[i][2] == 3 then
              _tUi.cycle_er_param("shift", i, j, d)
            end
          else
            local _page = tracks_ui.seq_page[i]
            if s_c["bounds"]["focus"] == 1 then
              sequence[i][_page].start_point =
                util.clamp(sequence[i][_page].start_point + d, 1, sequence[i][_page].end_point)
            elseif s_c["bounds"]["focus"] == 2 then
              sequence[i][_page].end_point =
                util.clamp(sequence[i][_page].end_point + d, sequence[i][_page].start_point, 24)
            end
          end
        elseif ui.menu_focus == 3 and ui.control_set == "edit" then
          if key1_hold then
            if ui.popup_focus.tracks[i][3] == 1 then
            elseif ui.popup_focus.tracks[i][3] == 2 then
              _tUi.cycle_chord_degrees(i, j, _pos, d)
            end
          else
            _t.track_transpose(i, j, tracks_ui.seq_page[i], sequence[i][j].ui_position, d)
          end
        end
			elseif ui.control_set == "seq" then
				if ui.seq_menu_focus == 1 then
					if ui.seq_menu_layer == "edit" then
						local current_focus = s_q["seq"]["focus"]
						local current_val = _p.get_note(i, current_focus)
						_p.delta_note(i, current_focus, true, d)
					elseif ui.seq_menu_layer == "deep_edit" then
						if ui.seq_controls[i]["trig_detail"]["focus"] == 1 then
							_p.delta_probability(i, s_q["seq"]["focus"], d, key1_hold)
						elseif ui.seq_controls[i]["trig_detail"]["focus"] == 2 then
							_p.delta_conditional(i, s_q["seq"]["focus"], "A", d, key1_hold)
						elseif ui.seq_controls[i]["trig_detail"]["focus"] == 3 then
							_p.delta_conditional(i, s_q["seq"]["focus"], "B", d, key1_hold)
						end
					end
				end
			end
		end
	end
end

function enc_actions.parse_highway(n, d)
	-- _hsteps.process_encoder(n,d)
end

return enc_actions