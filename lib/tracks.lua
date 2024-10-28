local track_actions = {}

sequence = {}

track_paste_style = 1

track_queues = {}

local function wrap(n, min, max)
	if max >= min then
		local y = n
		local d = max - min + 1
		while y > max do
			y = y - d
		end
		while y < min do
			y = y + d
		end
		return y
	else
		error("max needs to be greater than min")
	end
end

track_paramset = paramset.new()
local track_retrig_lookup = {
	1 / 64,
	1 / 48,
	1 / 40,
	1 / 32,
	1 / 24,
	1 / 16,
	1 / 12,
	1 / 10,
	1 / 8,
	1 / 6,
	1 / 5,
	3 / 16,
	1 / 4,
	5 / 16,
	1 / 3,
	3 / 8,
	1 / 2,
	2 / 3,
	3 / 4,
	1,
	4 / 3,
	1.5,
	2,
	8 / 3,
	3,
	4,
	5,
	6,
	8,
	10,
	12,
	16,
	24,
	32,
	40,
	48,
	64,
}

local function build_params(target, seq, page_number, i)
	track_paramset:add_option(
		"track_retrig_time_" .. target .. "_" .. seq .. "_" .. page_number .. "_" .. i,
		"",
		{
			"1/64",
			"1/48",
			"1/40",
			"1/32",
			"1/24",
			"1/16",
			"1/12",
			"1/10",
			"1/8",
			"1/6",
			"1/5",
			"3/16",
			"1/4",
			"5/16",
			"1/3",
			"3/8",
			"1/2",
			"2/3",
			"3/4",
			"1",
			"4/3",
			"1.5",
			"2",
			"8/3",
			"3",
			"4",
			"5",
			"6",
			"8",
			"10",
			"12",
			"16",
			"24",
			"32",
			"40",
			"48",
			"64",
		},
		13
	)
	track_paramset:set_action(
		"track_retrig_time_" .. target .. "_" .. seq .. "_" .. page_number .. "_" .. i,
		function(x)
			sequence[target][seq][page_number].conditional.retrig_time[i] = track_retrig_lookup[x]
		end
	)

	track_paramset:add_option(
		"track_fill_retrig_time_" .. target .. "_" .. seq .. "_" .. page_number .. "_" .. i,
		"",
		{
			"1/64",
			"1/48",
			"1/40",
			"1/32",
			"1/24",
			"1/16",
			"1/12",
			"1/10",
			"1/8",
			"1/6",
			"1/5",
			"3/16",
			"1/4",
			"5/16",
			"1/3",
			"3/8",
			"1/2",
			"2/3",
			"3/4",
			"1",
			"4/3",
			"1.5",
			"2",
			"8/3",
			"3",
			"4",
			"5",
			"6",
			"8",
			"10",
			"12",
			"16",
			"24",
			"32",
			"40",
			"48",
			"64",
		},
		13
	)
	track_paramset:set_action(
		"track_fill_retrig_time_" .. target .. "_" .. seq .. "_" .. page_number .. "_" .. i,
		function(x)
			sequence[target][seq][page_number].fill.conditional.retrig_time[i] = track_retrig_lookup[x]
		end
	)
end

function track_actions.init(target, seq, clear_reset)
	print("begin initialize sequence: " .. target .. ", " .. util.time())
	local build_clock = false
	local pre_clear_step
	if clear_reset and sequence[target].active_hill == seq then
		pre_clear_step = sequence[target][seq].step
	end
	if sequence[target] == nil then
		sequence[target] = {}
		sequence[target].scale = { source = {}, index = 1 }
		sequence[target].active_hill = 1
		-- sequence[target].song_mute = {}
		sequence[target].external_prm_change = {}
		sequence[target].rec = false
		sequence[target].rec_note_entry = false
		sequence[target].manual_note_entry = false
		sequence[target].mute_during_note_entry = false
		-- build_clock = true
	end

	sequence[target][seq] = {}
	sequence[target][seq].playing = false
	sequence[target][seq].time = 1 / 4
	if not clear_reset or (clear_reset and sequence[target].active_hill ~= seq) then
		sequence[target][seq].step = 1
	elseif clear_reset and sequence[target].active_hill == seq then
		sequence[target][seq].step = pre_clear_step
	end
	sequence[target][seq].ui_position = 1
	sequence[target][seq].page = 1
	sequence[target][seq].page_active = {
		true,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
	}
	sequence[target][seq].page_probability = {
		100,
		100,
		100,
		100,
		100,
		100,
		100,
		100,
	}
	sequence[target][seq].swing = 50
	sequence[target][seq].mode = "fwd"
	sequence[target][seq].loop = true
	sequence[target][seq].focus = "main"
	sequence[target][seq].page_chain = _sequins({ 1 })

	for pages = 1, 8 do
		sequence[target][seq][pages] = {}
		sequence[target][seq][pages].base_note = {}
		sequence[target][seq][pages].seed_default_note = {}
		sequence[target][seq][pages].chord_degrees = {}
		sequence[target][seq][pages].octave_offset = {}
		sequence[target][seq][pages].velocities = {}
		sequence[target][seq][pages].trigs = {}
		sequence[target][seq][pages].muted_trigs = {}
		sequence[target][seq][pages].accented_trigs = {}
		sequence[target][seq][pages].legato_trigs = {}
		sequence[target][seq][pages].lock_trigs = {}
		sequence[target][seq][pages].prob = {}
		sequence[target][seq][pages].micro = {}
		sequence[target][seq][pages].er = { pulses = 0, steps = 16, shift = 0 }
		sequence[target][seq][pages].last_condition = false
		sequence[target][seq][pages].conditional = {}
		sequence[target][seq][pages].conditional.cycle = 1
		sequence[target][seq][pages].conditional.A = {}
		sequence[target][seq][pages].conditional.B = {}
		sequence[target][seq][pages].conditional.mode = {}
		sequence[target][seq][pages].conditional.retrig_clock = nil
		sequence[target][seq][pages].conditional.retrig_count = {}
		sequence[target][seq][pages].conditional.retrig_time = {}
		sequence[target][seq][pages].conditional.retrig_slope = {}
		-- sequence[target][seq][pages].focus = "main"
		sequence[target][seq][pages].fill = {
			["base_note"] = {},
			["seed_default_note"] = {},
			["chord_degrees"] = {},
			["octave_offset"] = {},
			["velocities"] = {},
			["trigs"] = {},
			["muted_trigs"] = {},
			["accented_trigs"] = {},
			["legato_trigs"] = {},
			["lock_trigs"] = {},
			["prob"] = {},
			["er"] = { pulses = 0, steps = 16, shift = 0 },
			["conditional"] = {
				["A"] = {},
				["B"] = {},
				["mode"] = {},
				["retrig_count"] = {},
				["retrig_time"] = {},
				["retrig_slope"] = {},
			},
		}
		for i = 1, 24 do
			sequence[target][seq][pages].start_point = 1
			sequence[target][seq][pages].end_point = 24

			sequence[target][seq][pages].base_note[i] = -1
			sequence[target][seq][pages].seed_default_note[i] = true
			sequence[target][seq][pages].chord_degrees[i] = 1
			sequence[target][seq][pages].octave_offset[i] = 0
			sequence[target][seq][pages].velocities[i] = 127
			sequence[target][seq][pages].trigs[i] = false
			sequence[target][seq][pages].muted_trigs[i] = false
			sequence[target][seq][pages].accented_trigs[i] = false
			sequence[target][seq][pages].legato_trigs[i] = false
			sequence[target][seq][pages].lock_trigs[i] = false
			sequence[target][seq][pages].prob[i] = 100
			sequence[target][seq][pages].conditional.A[i] = 1
			sequence[target][seq][pages].conditional.B[i] = 1
			sequence[target][seq][pages].conditional.mode[i] = "A:B"
			sequence[target][seq][pages].conditional.retrig_count[i] = 0
			sequence[target][seq][pages].micro[i] = 0
			if not clear_reset then
				build_params(target, seq, pages, i)
			end
			sequence[target][seq][pages].conditional.retrig_time[i] = track_retrig_lookup[track_paramset:get(
				"track_retrig_time_" .. target .. "_" .. seq .. "_" .. pages .. "_" .. i
			)]
			sequence[target][seq][pages].conditional.retrig_slope[i] = 0

			sequence[target][seq][pages].fill.base_note[i] = -1
			sequence[target][seq][pages].fill.seed_default_note[i] = true
			sequence[target][seq][pages].fill.chord_degrees[i] = 1
			sequence[target][seq][pages].fill.octave_offset[i] = 0
			sequence[target][seq][pages].fill.velocities[i] = 127
			sequence[target][seq][pages].fill.trigs[i] = false
			sequence[target][seq][pages].fill.muted_trigs[i] = false
			sequence[target][seq][pages].fill.accented_trigs[i] = false
			sequence[target][seq][pages].fill.legato_trigs[i] = false
			sequence[target][seq][pages].fill.lock_trigs[i] = false
			sequence[target][seq][pages].fill.prob[i] = 100
			sequence[target][seq][pages].fill.conditional.A[i] = 1
			sequence[target][seq][pages].fill.conditional.B[i] = 1
			sequence[target][seq][pages].fill.conditional.mode[i] = "A:B"
			sequence[target][seq][pages].fill.conditional.retrig_count[i] = 0
			sequence[target][seq][pages].fill.conditional.retrig_time[i] = track_retrig_lookup[track_paramset:get(
				"track_fill_retrig_time_" .. target .. "_" .. seq .. "_" .. pages .. "_" .. i
			)]
			sequence[target][seq][pages].fill.conditional.retrig_slope[i] = 0
		end
	end

	if build_clock then
		sequence[target].clock = clock.run(track_actions.iterate, target)
	end

	print("initializing sequence: " .. target .. ", " .. util.time())
end

function track_actions.change_pattern(i, j, source)
	track_actions.stop_playback(i)
	if source ~= "from pattern" then
		sequence[i].active_hill = j
	end
	track_actions.start_playback(i, j)
end

function track_actions.check_page_probability(n, i, j)
	local _page = sequence[i][j].page
	if math.random(1, 100) <= sequence[i][j].page_probability[n] then
		-- if i == 1 then
		--   print("page "..n)
		-- end
		return n
	else
		if i == 1 then
			print("skip page " .. n)
		end
		return sequence[i][j].page_chain()
	end
end

function track_actions.change_page_probability(i, j, n, d)
	sequence[i][j].page_probability[n] = util.clamp(sequence[i][j].page_probability[n] + d, 1, 100)
	sequence[i][j].page_chain:map(track_actions.check_page_probability, i, j)
end

function track_actions.start_playback(i, j)
	local _page
	-- for p = 1,8 do
	--   if sequence[i][j].page_active[p] then
	--     _page = p
	--     break
	--   end
	-- end
	sequence[i][j].page_chain:map(track_actions.check_page_probability, i, j)
	sequence[i][j].page_chain:reset()
	_page = sequence[i][j].page_chain()
	sequence[i][j][_page].micro[0] = sequence[i][j][_page].micro[1]
	local track_start = {
		["fwd"] = sequence[i][j][_page].start_point - 1,
		["bkwd"] = sequence[i][j][_page].end_point + 1,
		["pend"] = sequence[i][j][_page].start_point,
		["rnd"] = sequence[i][j][_page].start_point - 1,
	}
	sequence[i][j].step = track_start[sequence[i][j].mode]
	sequence[i][j].playing = true
	if sequence[i][j].mode == "pend" then
		track_direction[i] = "negative"
	end
end

function track_actions.stop_playback(i)
	local j = sequence[i].active_hill
	local _page = sequence[i][j].page
	if clock.threads[sequence[i].clock] then
		clock.cancel(sequence[i].clock)
		sequence[i].clock = nil
	end
	sequence[i][j].playing = false
	sequence[i][j][_page].conditional.cycle = 1
	for p = 1, 8 do
		if sequence[i][j].page_active[p] then
			_page = p
			break
		end
	end
	local track_start = {
		["fwd"] = sequence[i][j][_page].start_point - 1,
		["bkwd"] = sequence[i][j][_page].end_point + 1,
		["pend"] = sequence[i][j][_page].start_point,
		["rnd"] = sequence[i][j][_page].start_point - 1,
	}
	sequence[i][j].step = track_start[sequence[i][j].mode]
end

function track_actions.sync_playheads()
	for i = 1, 8 do
		sequence[i][sequence[i].active_hill].step = sequence[i][sequence[i].active_hill][1].start_point
	end
end

function track_actions.jump_page(target, new_page, restart)
	sequence[target][sequence[target].active_hill].page = new_page
	if restart == true then
		sequence[target][sequence[target].active_hill].step = sequence[target][sequence[target].active_hill][new_page].start_point
	end
end

function track_actions.iterate(target)
	while true do
		local i, j = target, sequence[target].active_hill
		track_actions.tick(target)
		clock.sync(sequence[i][j].time, sequence[i][j][sequence[i][j].page].micro[sequence[i][j].step] / 384)
	end
end

function track_actions.tick(target)
	local _active = sequence[target][sequence[target].active_hill]
	local _a = _active[_active.page]
	if not _active.loop then
		if _active.step == _a.end_point then
			track_actions.stop_playback(target)
		end
	else
		if _active.swing > 50 then
			if _active.step % 2 == 1 then
				local base_time = (clock.get_beat_sec() * _active.time)
				local swung_time = base_time * util.linlin(50, 100, 0, 1, _active.swing)
				clock.run(function()
					clock.sleep(swung_time)
					track_actions.process(target)
				end)
			else
				track_actions.process(target)
			end
		else
			track_actions.process(target)
		end
		_active.playing = true
	end
	grid_dirty = true
	-- end
end

-- 230520 TODO: evaluate necessity of these (probably would be cool tho!):
-- function track_actions.prob_fill(target,s_p,e_p,value)
--   local _active = sequence[target][sequence[target].active_hill]
--   local focused_set = _active.focus == "main" and _active or _active.fill
--   for i = s_p,e_p do
--     focused_set.prob[i] = value
--   end
-- end

-- function track_actions.cond_fill(target,s_p,e_p,a_val,b_val) -- TODO: gets weird...
--   local _active = sequence[target][sequence[target].active_hill]
--   local focused_set = _active.focus == "main" and _active or _active.fill
--   if b_val ~= "meta" then
--     for i = s_p,e_p do
--       focused_set.conditional.A[i] = a_val
--       focused_set.conditional.B[i] = b_val
--       focused_set.conditional.mode[i] = "A:B"
--     end
--   else
--     for i = s_p,e_p do
--       focused_set.conditional.mode[i] = a_val
--     end
--   end
-- end

-- function track_actions.retrig_fill(target,s_p,e_p,val,type)
--   local _active = sequence[target][sequence[target].active_hill]
--   local focused_set = _active.focus == "main" and _active or _active.fill
--   if type == "retrig_count" then
--     for i = s_p,e_p do
--       focused_set.conditional[type][i] = val
--     end
--   else
--     for i = s_p,e_p do
--       track_paramset:set((_active.focus == "main" and "track_retrig_time_" or "track_fill_retrig_time_")..target.."_"..sequence[target].active_hill..'_'..i,val)
--     end
--   end
-- end

function track_actions.change_trig_state(target_track, target_step, state, i, j, _page)
	-- print('change_trig_state:',target_track,target_step,state, _page)
	target_track.trigs[target_step] = state
	if state == true then
		if tab.count(_fkprm.adjusted_params_lock_trigs[i][j][_page][target_step].params) > 0 then
			_fkprm.adjusted_params[i][j][_page][target_step].params =
				_t.deep_copy(_fkprm.adjusted_params_lock_trigs[i][j][_page][target_step].params)
		end
	end
end

function track_actions.process(target)
	local _active = sequence[target][sequence[target].active_hill]
	-- TODO: drunk walk!
	track_actions[_active.mode](target)
	screen_dirty = true
	track_actions.run(target, _active.step)
end

function track_actions.fwd(target)
	local _active = sequence[target][sequence[target].active_hill]
	local _a = _active[_active.page]
	_active.step = _active.step + 1
	if _active.step > _a.end_point then
		_active.page = _active.page_chain()
		_a = _active[_active.page]
		_active.step = _a.start_point
		_a.conditional.cycle = _a.conditional.cycle + 1
	end
end

function track_actions.bkwd(target)
	local _active = sequence[target][sequence[target].active_hill]
	local _a = _active[_active.page]
	_active.step = wrap(_active.step - 1, _a.start_point, _a.end_point)
	if _active.step == _a.end_point then
		_a.conditional.cycle = _a.conditional.cycle + 1
	end
end

function track_actions.rnd(target)
	local _active = sequence[target][sequence[target].active_hill]
	local _a = _active[_active.page]
	_active.step = math.random(_a.start_point, _a.end_point)
	if _active.step == _a.start_point or _active.step == _a.end_point then
		_a.conditional.cycle = _a.conditional.cycle + 1
	end
end

function track_actions.generate_er(i, j, _page)
	local _active = sequence[i][j]
	local _a = _active[_page]
	local focused_set = _active.focus == "main" and _a or _a.fill
	local generated = euclid.gen(focused_set.er.pulses, focused_set.er.steps, focused_set.er.shift)
	for length = focused_set.start_point, focused_set.end_point do
		_htracks.change_trig_state(focused_set, length, generated[length - (focused_set.start_point - 1)], i, j, _page)
	end
end

track_direction = {}

for i = 1, 8 do
	track_direction[i] = "positive"
end

function track_actions.pend(target)
	local _active = sequence[target][sequence[target].active_hill]
	local _a = _active[_active.page]
	if track_direction[target] == "positive" then
		_active.step = _active.step + 1
		if _active.step > _a.end_point then
			_active.step = _a.end_point
		end
	elseif track_direction[target] == "negative" then
		_active.step = _active.step - 1
		if _active.step == _a.start_point - 1 then
			_active.step = _a.start_point
		end
	end
	if _active.step == _a.end_point and _active.step ~= _a.start_point then
		track_direction[target] = "negative"
	elseif _active.step == _a.start_point then
		track_direction[target] = "positive"
	end
end

function track_actions.check_prob(target, step)
	local _active = sequence[target][sequence[target].active_hill]
	local _a = _active[_active.page]
	local _f = _active.focus == "main" and _a.prob[step] or _a.fill.prob[step]
	if _f == 0 then
		return false
	elseif _f >= math.random(1, 100) then
		return true
	else
		return false
	end
end

function track_actions.run(target, step)
	local _active = sequence[target][sequence[target].active_hill]
	local _a = _active[_active.page]
	if
		(
			_active.focus == "main"
			and (_a.trigs[step] == true or _a.lock_trigs[step] == true or _a.legato_trigs[step] == true)
		)
		or (
			_active.focus == "fill"
			and (_a.fill.trigs[step] == true or _a.fill.lock_trigs[step] == true or _a.fill.legato_trigs[step] == true)
		)
	then
		local should_happen = track_actions.check_prob(target, step)
		if should_happen then
			local A_step = _active.focus == "main" and _a.conditional.A[step] or _a.fill.conditional.A[step]
			local B_step = _active.focus == "main" and _a.conditional.B[step] or _a.fill.conditional.B[step]

			if _a.conditional.mode[step] == "A:B" then
				if _a.conditional.cycle < A_step then
					_a.last_condition = false
				elseif _a.conditional.cycle == A_step then
					track_actions.execute_step(target, step)
				elseif _a.conditional.cycle > A_step then
					if _a.conditional.cycle <= (A_step + B_step) then
						if _a.conditional.cycle % (A_step + B_step) == 0 then
							track_actions.execute_step(target, step)
						else
							_a.last_condition = false
						end
					else
						if (_a.conditional.cycle - A_step) % B_step == 0 then
							track_actions.execute_step(target, step)
						else
							_a.last_condition = false
						end
					end
				end
			elseif _a.conditional.mode[step] == "PRE" then
				if _a.last_condition then
					track_actions.execute_step(target, step)
				else
					_a.last_condition = false
				end
			elseif _a.conditional.mode[step] == "NOT PRE" then
				if _a.last_condition then
					_a.last_condition = false
				else
					track_actions.execute_step(target, step)
				end
			elseif _a.conditional.mode[step] == "NEI" then
				local neighbors = { 10, 1, 2, 3, 4, 5, 6, 7, 8, 9 }
				if sequence[neighbors[target]][sequence[target].active_hill].last_condition then
					track_actions.execute_step(target, step)
				else
					_a.last_condition = false
				end
			elseif _a.conditional.mode[step] == "NOT NEI" then
				local neighbors = { 10, 1, 2, 3, 4, 5, 6, 7, 8, 9 }
				if sequence[neighbors[target]][sequence[target].active_hill].last_condition then
					_a.last_condition = false
				else
					track_actions.execute_step(target, step)
				end
			end
		else
			_a.last_condition = false
		end
	end
end

function track_actions.execute_step(target, step)
	local _active = sequence[target][sequence[target].active_hill]
	local _a = _active[_active.page]
	local focused_trigs = {}
	local focused_notes = {}
	local focused_legato = {}
	if _active.focus == "main" then
		focused_trigs = _a.trigs[step]
		focused_notes = _a.base_note[step]
		focused_legato = _a.legato_trigs[step]
	else
		focused_trigs = _a.fill.trigs[step]
		focused_notes = _a.fill.base_note[step]
		focused_legato = _a.fill.legato_trigs[step]
	end
	local i, j = target, sequence[target].active_hill
	local note_check
	note_check = hills_base_note[i]
	pass_note(
		i,
		j,
		hills[i][j], -- seg
		focused_notes == -1 and note_check or focused_notes, -- note_val
		step, -- index
		0 -- retrig_index
	)
	-- TODO: should these be focuseD???
	if _a.trigs[step] then
		track_actions.retrig_step(target, step)
	end
	_a.last_condition = true
end

function track_actions.retrig_step(target, step)
	local _active = sequence[target][sequence[target].active_hill]
	local _a = _active[_active.page]
	if _a.conditional.retrig_clock ~= nil then
		clock.cancel(_a.conditional.retrig_clock)
		_a.conditional.retrig_clock = nil
	end
	local focused_set, focused_notes = {}, {}
	if _active.focus == "main" then
		focused_set = _a.conditional
		focused_notes = _a.base_note
	else
		focused_set = _a.fill.conditional
		focused_notes = _a.fill.base_note
	end
	if focused_set.retrig_count[step] > 0 then
		local base_time = (clock.get_beat_sec() * _active.time)
		local swung_time = base_time * util.linlin(50, 100, 0, 1, _active.swing)
		local i, j = target, sequence[target].active_hill
		_a.conditional.retrig_clock = clock.run(function()
			for retrigs = 1, focused_set.retrig_count[step] do
				clock.sleep(((clock.get_beat_sec() * _active.time) * focused_set.retrig_time[step]) + swung_time)
				local note_check
				note_check = hills_base_note[i]
				pass_note(
					i,
					j,
					hills[i][j], -- seg
					focused_notes[step] == -1 and note_check or focused_notes[step], -- note_val
					step, -- index
					retrigs
				)
			end
		end)
	end
end

function track_actions.clear(target, seq)
	track_actions.init(target, seq, true)
end

function track_actions.reset_note_to_default(i, j)
	local _active = sequence[i][j]
	local _a = _active[_active.page]
	local focused_set = _active.focus == "main" and _a or _a.fill
	local note_check
	note_check = hills_base_note[i]
	if focused_set.base_note[_active.ui_position] == note_check then
		focused_set.base_note[_active.ui_position] = -1
	end
end

function track_actions.savestate()
	local collection = params:get("collection")
	local dirname = _path.data .. "cheat_codes_yellow/sequence/"
	if os.rename(dirname, dirname) == nil then
		os.execute("mkdir " .. dirname)
	end

	local dirname = _path.data .. "cheat_codes_yellow/sequence/collection-" .. collection .. "/"
	if os.rename(dirname, dirname) == nil then
		os.execute("mkdir " .. dirname)
	end

	for i = 1, 3 do
		tab.save(sequence[i], _path.data .. "cheat_codes_yellow/sequence/collection-" .. collection .. "/" .. i .. ".data")
	end
	track_paramset:write(_path.data .. "cheat_codes_yellow/sequence/collection-" .. collection .. "/paramset.data")
end

function track_actions.loadstate()
	local collection = params:get("collection")
	for i = 1, 3 do
		if
			tab.load(_path.data .. "cheat_codes_yellow/sequence/collection-" .. collection .. "/" .. i .. ".data") ~= nil
		then
			sequence[i] =
				tab.load(_path.data .. "cheat_codes_yellow/sequence/collection-" .. collection .. "/" .. i .. ".data")
		end
	end
	track_paramset:read(_path.data .. "cheat_codes_yellow/sequence/collection-" .. collection .. "/paramset.data")
end

return track_actions