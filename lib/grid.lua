-- GRID --

-- hardware: grid connect
g = grid.connect()

grid_conditional_entry = false
conditional_entry_steps = { ["focus"] = {}, ["held"] = {} }
for i = 1, number_of_sequencers do
	conditional_entry_steps.focus[i] = {}
	conditional_entry_steps.held[i] = 0
end

-- hardware: grid event (eg 'what happens when a button is pressed')
g.key = function(x, y, z)
	-- speed + direction
	if y <= 8 then
    parse_cranes(x,y,z)
	elseif y >= 8 and y <= 12 then
		_tUi.parse_grid(x, y, z)
	elseif y >= 13 then
    parse_cheat(x,y,z)
  end
	hardware_dirty = true
end

grid_coordinates = {
  [256] = {
    squares = {
      [1] = {1,13},
      [2] = {7,13},
      [3] = {13,13},
    }
  }
}

function parse_cheat(x,y,z)
  local size = g.cols * g.rows
  if z == 1 then
    local bank_source
    if x <= 4 then
      bank_source = 1
    elseif x >= 7 and x <= 10 then
      bank_source = 2
    elseif x >= 13 and x <= 16 then
      bank_source = 3
    end
    y = size == 256 and y-8 or y
    if x >= grid_coordinates[size].squares[bank_source][1] and x <= grid_coordinates[size].squares[bank_source][1] + 3 then
      local which_pad = x - (6*(bank_source-1)) + (4*(y-5))
			_ca.trigger(bank_source,which_pad,127)
    end
  end
end

function parse_cranes(x,y,z)
  if (y == 1 or y == 5) and z == 1 then
		local voice = y == 1 and 1 or 2
		local other_voice = y == 1 and 2 or 1
		if x <= #speedlist[voice] then
			params:set("speed_voice_" .. voice, x)
		elseif x == 13 then
			softcut.position(voice, track[other_voice].poll_position)
		elseif x == 14 then
			track[voice].start_point = track[other_voice].start_point
			softcut.loop_start(voice, track[voice].start_point)
			track[voice].end_point = track[other_voice].end_point
			softcut.loop_end(voice, track[voice].end_point)
		elseif x == 15 then
			softcut.position(voice, track[voice].start_point)
		end
	-- presets
	elseif y == 2 or y == 6 then
		local voice = y == 2 and 1 or 2
		if z == 1 then
			if x < 14 and x <= preset_count[voice] then
				preset_unpack(voice, x)
			elseif x == 15 then
				preset_clear_counters[voice]:start()
			elseif x == 16 then
				preset_pack(voice)
			end
		elseif z == 0 then
			if x == 15 then
				preset_clear_counters[voice]:stop()
			end
		end
	-- start point, end point, window
	elseif y == 3 or 7 then
		local voice = y == 3 and 1 or 2
		if z == 1 then
			selected_window[voice] = x
			window_holds[voice]:start()
		elseif z == 0 then
			window_holds[voice]:stop()
		end
		if x == 5 or x == 12 then
			-- jump_step[voice] = z == 1
		end
  end
end

-- hardware: grid redraw
function grid_redraw()
	g:all(0)
  draw_cranes()
	draw_cheat(1, 13)
	draw_cheat(7, 13)
	draw_cheat(13, 13)
	_tUi.draw_grid(ui.seq_focus)
	g:refresh()
end

function draw_cheat(x,y)
  for i = x,x+3 do
    for j = y,y+3 do
      g:led(i,j,3)
    end
  end
end

function draw_cranes()
	for i = 1, preset_count[1] do
		g:led(i, 2, 5)
	end
	for i = 1, preset_count[2] do
		g:led(i, 6, 5)
	end
	g:led(15, 2, 3)
	g:led(16, 2, 9)
	g:led(15, 6, 3)
	g:led(16, 6, 9)
	for i = 1, #speedlist[1] do
		g:led(i, 1, 5)
	end
	for i = 1, #speedlist[2] do
		g:led(i, 5, 5)
	end
	for i = 13, 15 do
		g:led(i, 1, 5)
		g:led(i, 5, 5)
	end
	if voice_speeds[1] == 6 then
		g:led(6, 1, 12)
	else
		g:led(voice_speeds[1], 1, 12)
		g:led(6, 1, 0)
	end
	if voice_speeds[2] == 6 then
		g:led(6, 5, 12)
	else
		g:led(voice_speeds[2], 5, 12)
		g:led(6, 5, 0)
	end
	if track[1].pos_grid >= 0 and phase_position[1] < 1 then
		g:led(track[1].pos_grid + 1, 4, 15)
	else
		for i = 1, 16 do
			g:led(i, 4, 0)
		end
	end
	if track[2].pos_grid >= 0 and phase_position[2] < 1 then
		g:led(track[2].pos_grid + 1, 8, 15)
	else
		for i = 1, 16 do
			g:led(i, 8, 0)
		end
	end
	if clear == true then
		for i = 1, 16 do
			g:led(i, 4, 0)
			g:led(i, 8, 0)
		end
	end
	g:led(16, 3, 5)
	g:led(15, 3, 9)
	g:led(14, 3, 9)
	g:led(13, 3, 5)
	g:led(10, 3, 5)
	g:led(9, 3, 9)
	g:led(8, 3, 9)
	g:led(7, 3, 5)
	g:led(4, 3, 5)
	g:led(3, 3, 9)
	g:led(2, 3, 9)
	g:led(1, 3, 5)
	g:led(16, 7, 5)
	g:led(15, 7, 9)
	g:led(14, 7, 9)
	g:led(13, 7, 5)
	g:led(10, 7, 5)
	g:led(9, 7, 9)
	g:led(8, 7, 9)
	g:led(7, 7, 5)
	g:led(4, 7, 5)
	g:led(3, 7, 9)
	g:led(2, 7, 9)
	g:led(1, 7, 5)
	g:led(selected_preset[1], 2, 12)
	g:led(selected_preset[2], 6, 12)
end