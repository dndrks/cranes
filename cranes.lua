-- cranes
-- dual looper / delay
-- (grid optional)
-- v2.3 @dani_derks
-- https://llllllll.co/t/21207
-- ---------------------
-- to start:
-- press key 2 to rec.
-- sounds are written to
-- two buffers.
-- one = left in.
-- two = right in.
-- press key 2 to play.
--
-- key 1 = toggle focus b/w
--         voice 1 + voice 2.
-- key 2 = toggle overwrite for
--         selected voice.
-- key 3 = voice 1 pitch bump.
-- keys 3 + 1 = erase all.
-- enc 1 = overwrite amount
--         (0 = add, 1 = clear)
-- enc 2 / 3 = loop point for
--             selected voice.
-- ////
-- head to params to find
-- speed, vol, pan
-- +
-- change buffer 2's reference
-- \\\\

frm = require("formatters")

function r()
	norns.rerun()
end

-- counting ms between key 2 taps
-- sets loop length
function count()
	rec_time = rec_time + 0.01
end

-- track recording state
recording = false
semitone_offset = 1

preset_count = { 0, 0 }
presets = {
	[1] = {},
	[2] = {},
}
preset_clear_counters = {}
window_holds = {}
selected_window = {}
jump_step = { false, false }

TRACKS = 2

for i = 1, TRACKS do
	preset_clear_counters[i] = metro.init(function()
		presets[i] = {}
		preset_count[i] = 0
		selected_preset[i] = 0
		grid_dirty = true
	end, 1.5, 1)
	window_holds[i] = metro.init(function(x)
		if x == 1 then
			window(i, selected_window[i])
		elseif x > 10 then
			window(i, selected_window[i])
		end
	end, 0.05, -1)
end

track = {}
distance = {}
selected_preset = {}
voice_speeds = {}
phase_position = {}
for i = 1, TRACKS do
	track[i] = {}
	track[i].start_point = 1
	track[i].end_point = 61
	track[i].poll_position = 1
	track[i].pos_grid = -1
	distance[i] = 0
	selected_preset[i] = 0
end

speedlist = {
	{ -4.0, -2.0, -1.0, -0.5, -0.25, 0, 0.25, 0.5, 1.0, 2.0, 4.0 },
	{ -4.0, -2.0, -1.0, -0.5, -0.25, 0, 0.25, 0.5, 1.0, 2.0, 4.0 },
}
overdub_strength = { 0.0, 0.0 }
clear = true
wiggle = 0.0
KEY3 = 1
crane_redraw = { 0, 0 }

function init_voices()
	softcut.poll_stop_phase()
	softcut.buffer_clear()
	for i = 1, TRACKS do
		softcut.enable(i, 1)
		softcut.buffer(i, i)
		softcut.play(i, 1)
		softcut.rec(i, 1)

		softcut.level(i, 0.0)
		softcut.pre_level(i, 0)
		softcut.rec_level(i, 0.0)
		softcut.level_slew_time(i, 0.01)
		softcut.rate_slew_time(i, 0.01)

		softcut.rate(i, 1)
		softcut.loop_start(i, 1)
		softcut.loop_end(i, 61)
		softcut.loop(i, 1)
		softcut.fade_time(i, 0.01)
		softcut.position(i, 1)
		softcut.phase_quant(i, 0.01)
	end
	softcut.event_phase(phase)
end

function init()
	g = grid.connect()

	audio.level_adc_cut(1)
	audio.level_eng_cut(0)
	softcut.level_input_cut(1, 1, 1.0)
	softcut.level_input_cut(1, 2, 0.0)
	softcut.level_input_cut(2, 1, 0.0)
	softcut.level_input_cut(2, 2, 1.0)

	init_voices()

	params:add_separator("playback rate")
	params:add_number("speed_voice_1", "speed voice 1", 1, 11, 9, function(prm)
		return speedlist[1][prm:get()] .. "x"
	end)
	params:set_action("speed_voice_1", function(x)
		voice_speeds[1] = x
		if all_loaded then
			softcut.rate(1, speedlist[1][x] * semitone_offset)
			grid_dirty = true
		end
	end)
	params:add_number("speed_voice_2", "speed voice 2", 1, 11, 9, function(prm)
		return speedlist[2][prm:get()] .. "x"
	end)
	params:set_action("speed_voice_2", function(x)
		voice_speeds[2] = x
		if all_loaded then
			softcut.rate(2, speedlist[2][x] * semitone_offset)
			grid_dirty = true
		end
	end)
	--
	params:add_number("offset", "global offset", -24, 24, 0, function(param)
		return (param:get() .. " st")
	end)
	params:set_action("offset", function(value)
		if all_loaded then
			semitone_offset = math.pow(0.5, -value / 12)
			softcut.rate(1, speedlist[1][voice_speeds[1]] * semitone_offset)
			softcut.rate(2, speedlist[2][voice_speeds[2]] * semitone_offset)
		end
	end)
	params:add_separator("levels")
	--
	for i = 1, 2 do
		params:add_control(
			i .. "lvl_in_L",
			"L level in: voice " .. i,
			controlspec.new(0, 1, "lin", 0, 1, ""),
			function(prm)
				return (prm:get() * 100) .. "%"
			end
		)
		params:set_action(i .. "lvl_in_L", function(x)
			softcut.level_input_cut(1, i, x)
		end)
	end
	params:set(2 .. "lvl_in_L", 0.0)
	for i = 1, 2 do
		params:add_control(
			i .. "lvl_in_R",
			"R level in: voice " .. i,
			controlspec.new(0, 1, "lin", 0, 1, ""),
			function(prm)
				return (prm:get() * 100) .. "%"
			end
		)
		params:set_action(i .. "lvl_in_R", function(x)
			softcut.level_input_cut(2, i, x)
		end)
	end
	params:set(1 .. "lvl_in_R", 0.0)
	params:add_control("vol_1", "level out voice 1", controlspec.new(0, 5, "lin", 0, 1, ""), function(prm)
		return (prm:get() * 100) .. "%"
	end)
	params:set_action("vol_1", function(x)
		softcut.level(1, x)
	end)
	params:add_control("vol_2", "level out voice 2", controlspec.new(0, 5, "lin", 0, 1, ""), function(prm)
		return (prm:get() * 100) .. "%"
	end)
	params:set_action("vol_2", function(x)
		softcut.level(2, x)
	end)
	--
	params:add_separator("panning")
	params:add_control("pan_1", "pan voice 1", controlspec.new(-1, 1, "lin", 0.01, -1, ""), frm.bipolar_as_pan_widget)
	params:set_action("pan_1", function(x)
		softcut.pan(1, x)
	end)
	params:add_control("pan_slew_1", "pan slew 1", controlspec.new(0, 200, "lin", 0.01, 0, "s"))
	params:set_action("pan_slew_1", function(x)
		softcut.pan_slew_time(1, x)
	end)
	params:add_control("pan_2", "pan voice 2", controlspec.new(-1, 1, "lin", 0.01, 1, ""), frm.bipolar_as_pan_widget)
	params:set_action("pan_2", function(x)
		softcut.pan(2, x)
	end)
	params:add_control("pan_slew_2", "pan slew 2", controlspec.new(0, 200, "lin", 0.01, 0, "s"))
	params:set_action("pan_slew_2", function(x)
		softcut.pan_slew_time(2, x)
	end)
	--
	params:add_separator("filters")
	for i = 1, 2 do
		params:add_control(
			"post_filter_fc_" .. i,
			i .. " filter cutoff",
			controlspec.new(0, 12000, "lin", 0.01, 12000, "hz")
		)
		params:set_action("post_filter_fc_" .. i, function(x)
			softcut.post_filter_fc(i, x)
		end)
		params:add_control("post_filter_lp_" .. i, i .. " lopass", controlspec.new(0, 1, "lin", 0, 1, ""), function(prm)
			return (prm:get() * 100) .. "%"
		end)
		params:set_action("post_filter_lp_" .. i, function(x)
			softcut.post_filter_lp(i, x)
		end)
		params:add_control("post_filter_hp_" .. i, i .. " hipass", controlspec.new(0, 1, "lin", 0, 0, ""), function(prm)
			return (prm:get() * 100) .. "%"
		end)
		params:set_action("post_filter_hp_" .. i, function(x)
			softcut.post_filter_hp(i, x)
		end)
		params:add_control(
			"post_filter_bp_" .. i,
			i .. " bandpass",
			controlspec.new(0, 1, "lin", 0, 0, ""),
			function(prm)
				return (prm:get() * 100) .. "%"
			end
		)
		params:set_action("post_filter_bp_" .. i, function(x)
			softcut.post_filter_bp(i, x)
		end)
		params:add_control("post_filter_dry_" .. i, i .. " dry", controlspec.new(0, 1, "lin", 0, 0, ""), function(prm)
			return (prm:get() * 100) .. "%"
		end)
		params:set_action("post_filter_dry_" .. i, function(x)
			softcut.post_filter_dry(i, x)
		end)
		params:add_control(
			"post_filter_rq_" .. i,
			i .. " RQ (0% = high)",
			controlspec.new(0, 2, "lin", 0, 2, ""),
			function(prm)
				return (prm:get() * 100) .. "%"
			end
		)
		params:set_action("post_filter_rq_" .. i, function(x)
			softcut.post_filter_rq(i, x)
		end)
	end
	params:add_separator("etc")
	params:add_option("KEY3", "KEY3", { "~~", "0.5", "-1", "1.5", "2" }, 1)
	params:set_action("KEY3", function(x)
		KEY3 = x
	end)
	params:add_number("voice_2_buffer", "voice 2 buffer reference", 1, 2, 2)
	params:set_action("voice_2_buffer", function(x)
		voice_2_buffer = x
		softcut.buffer(2, x)
		check_record_head_collision()
	end)

	params:bang()
	clock.run(function()
		clock.sleep(1)
		all_loaded = true
	end)

	counter = metro.init(count, 0.01, -1)
	rec_time = 0

	KEY3_hold = false
	KEY1_hold = false
	KEY1_press = 0

	hardware_redraw = metro.init(function()
		draw_hardware()
	end, 1 / 30, -1)
	hardware_redraw:start()

	grid_dirty = true
	screen_dirty = true
end

function grid.add()
	grid_dirty = true
end

function draw_hardware()
	if grid_dirty then
		grid_redraw()
		grid_dirty = false
	end
	if screen_dirty then
		redraw()
		screen_dirty = false
	end
end

phase = function(n, x)
	track[n].poll_position = x
	phase_position[n] = ((x - track[n].start_point) / (track[n].end_point - track[n].start_point))
	local spot = math.floor(phase_position[n] * 16)
	if spot ~= track[n].pos_grid then
		track[n].pos_grid = spot
	end
	grid_dirty = true
	screen_dirty = true
end

function preset_pack(voice)
	preset_count[voice] = util.clamp(preset_count[voice] + 1, 1, 13)
	local set = preset_count[voice]
	presets[voice][set] = {
		start_point = track[voice].start_point,
		end_point = track[voice].end_point,
		poll_position = track[voice].poll_position,
		speed = voice_speeds[voice],
	}
end

function preset_unpack(voice, set)
	track[voice].start_point = presets[voice][set].start_point
	softcut.loop_start(voice, track[voice].start_point)
	track[voice].end_point = presets[voice][set].end_point
	softcut.loop_end(voice, track[voice].end_point)
	softcut.position(voice, presets[voice][set].poll_position)
	params:set("speed_voice_" .. voice, presets[voice][set].speed)
	selected_preset[voice] = set
	screen_dirty = true
	grid_dirty = true
end

function warble()
	local bufSpeed1 = speedlist[1][voice_speeds[1]]
	if bufSpeed1 > 1.99 then
		wiggle = bufSpeed1 + (math.random(-15, 15) / 1000)
	elseif bufSpeed1 >= 1.0 then
		wiggle = bufSpeed1 + (math.random(-10, 10) / 1000)
	elseif bufSpeed1 >= 0.50 then
		wiggle = bufSpeed1 + (math.random(-4, 5) / 1000)
	else
		wiggle = bufSpeed1 + (math.random(-2, 2) / 1000)
	end
	softcut.rate_slew_time(1, 0.6 + (math.random(-30, 10) / 100))
end

function half_speed()
	wiggle = speedlist[1][voice_speeds[1]] / 2
	softcut.rate_slew_time(1, 0.6 + (math.random(-30, 10) / 100))
end

function rev_speed()
	wiggle = speedlist[1][voice_speeds[1]] * -1
	softcut.rate_slew_time(1, 0.01)
end

function oneandahalf_speed()
	wiggle = speedlist[1][voice_speeds[1]] * 1.5
	softcut.rate_slew_time(1, 0.6 + (math.random(-30, 10) / 100))
end

function double_speed()
	wiggle = speedlist[1][voice_speeds[1]] * 2
	softcut.rate_slew_time(1, 0.6 + (math.random(-30, 10) / 100))
end

function restore_speed()
	wiggle = speedlist[1][voice_speeds[1]]
	if KEY3 == 2 then
		softcut.rate_slew_time(1, 0.01)
	else
		softcut.rate_slew_time(1, 0.6)
	end
	softcut.rate(1, speedlist[1][voice_speeds[1]] * semitone_offset)
end

function clear_all()
	init_voices()
	wiggle = speedlist[1][voice_speeds[1]]
	track[1].start_point = 1
	track[2].start_point = 1
	track[1].end_point = 61
	track[2].end_point = 61

	clear = true
	rec_time = 0
	recording = false
	crane_redraw = { 0, 0 }
	grid_dirty = true
	screen_dirty = true
	KEY3_hold = false
	track[1].poll_position = 1
	track[2].poll_position = 1
end

function window(voice, x)
	local jump = jump_step[voice] and 10 or 1
	if x == 1 then
		track[voice].start_point = util.clamp(track[voice].start_point - 0.01 / jump, 1, track[voice].end_point)
	elseif x == 2 then
		track[voice].start_point = util.clamp(track[voice].start_point - 0.1 * jump, 1, track[voice].end_point)
	elseif x == 3 then
		track[voice].start_point = util.clamp(track[voice].start_point + 0.1 * jump, 1, track[voice].end_point)
	elseif x == 4 then
		track[voice].start_point = util.clamp(track[voice].start_point + 0.01 / jump, 1, track[voice].end_point)
	elseif x == 8 then
		distance[voice] = math.abs(track[voice].start_point - track[voice].end_point)
		if util.round(track[voice].start_point - distance[voice], 0.01) >= 1 then
			track[voice].start_point = util.clamp(track[voice].start_point - distance[voice], 1, 61)
			track[voice].end_point = util.clamp(track[voice].end_point - distance[voice], 1, 61)
		end
	elseif x == 7 then
		if util.round(track[voice].start_point - 0.01, 0.01) >= 1 then
			track[voice].start_point = util.clamp(track[voice].start_point - 0.01, 1, 61)
			track[voice].end_point = util.clamp(track[voice].end_point - 0.01, 1, 61)
		end
	elseif x == 10 then
		if util.round(track[voice].end_point + 0.01, 0.01) <= 61 then
			track[voice].start_point = util.clamp(track[voice].start_point + 0.01, 1, 61)
			track[voice].end_point = util.clamp(track[voice].end_point + 0.01, 1, 61)
		end
	elseif x == 9 then
		distance[voice] = math.abs(track[voice].start_point - track[voice].end_point)
		if util.round(track[voice].end_point + distance[voice], 0.01) <= 61 then
			track[voice].start_point = util.clamp(track[voice].start_point + distance[voice], 1, 61)
			track[voice].end_point = util.clamp(track[voice].end_point + distance[voice], 1, 61)
		end
	elseif x == 13 then
		track[voice].end_point =
			util.clamp(track[voice].end_point - 0.01 / jump, track[voice].start_point + 0.01 / jump, 61)
	elseif x == 14 then
		track[voice].end_point =
			util.clamp(track[voice].end_point - 0.1 * jump, track[voice].start_point + 0.1 * jump, 61)
	elseif x == 15 then
		track[voice].end_point =
			util.clamp(track[voice].end_point + 0.1 * jump, track[voice].start_point + 0.1 * jump, 61)
	elseif x == 16 then
		track[voice].end_point =
			util.clamp(track[voice].end_point + 0.01 / jump, track[voice].start_point + 0.01 / jump, 61)
	end
	softcut.loop_start(voice, track[voice].start_point)
	softcut.loop_end(voice, track[voice].end_point)
	screen_dirty = true
end

function check_record_head_collision()
	if voice_2_buffer == 1 and track[2].poll_position == track[1].poll_position then
		softcut.position(2, track[2].poll_position - 0.001)
	end
end

function record()
	recording = not recording
	-- if the buffer is clear and key 2 is pressed:
	-- main recording will enable
	if recording == true and clear == true then
		for i = 1, TRACKS do
			softcut.level(i, 0)
			softcut.position(i, 1)
			softcut.rec_level(i, 1)
			softcut.rate_slew_time(i, 0)
			softcut.rate(i, 1 * semitone_offset)
		end
		crane_redraw[1] = 1
		counter:start()
		softcut.poll_start_phase()
	-- if the buffer is clear and key 2 is pressed again:
	-- main recording will disable, loop points set
	elseif recording == false and clear == true then
		clear = false
		counter:stop()
		for i = 1, TRACKS do
			softcut.position(i, 1)
			softcut.rec_level(i, 0)
			softcut.pre_level(i, 1)
			track[i].end_point = rec_time + 1
		end
		softcut.poll_start_phase()
		softcut.loop_end(1, track[1].end_point)
		softcut.loop_end(2, track[2].end_point)
		softcut.loop_start(2, 1)
		track[2].start_point = 1
		crane_redraw[1] = 0
		rec_time = 0
		softcut.level(1, 1.0)
		softcut.level(2, 1.0)
		softcut.rate(1, speedlist[1][voice_speeds[1]] * semitone_offset)
		softcut.rate(2, speedlist[2][voice_speeds[2]] * semitone_offset)
	end
	-- if the buffer is NOT clear and key 2 is pressed:
	-- overwrite/overdub behavior will enable
	if recording == true and clear == false and KEY1_press % 2 == 0 then
		check_record_head_collision()
		softcut.rec_level(1, 1)
		softcut.pre_level(1, math.abs(overdub_strength[1] - 1))
		crane_redraw[1] = 1
		crane_redraw[2] = 1
	-- if the buffer is NOT clear and key 2 is pressed again:
	-- overwrite/overdub behavior will disable
	elseif recording == false and clear == false and KEY1_press % 2 == 0 then
		softcut.rec_level(1, 0)
		softcut.pre_level(1, 1)
		crane_redraw[1] = 0
		crane_redraw[2] = 0
	elseif recording == true and clear == false and KEY1_press % 2 == 1 then
		softcut.rec_level(2, 1)
		softcut.pre_level(2, math.abs(overdub_strength[2] - 1))
		crane_redraw[1] = 1
		crane_redraw[2] = 1
	elseif recording == false and clear == false and KEY1_press % 2 == 1 then
		softcut.rec_level(2, 0)
		softcut.pre_level(2, 1)
		crane_redraw[1] = 0
		crane_redraw[2] = 0
	end
	screen_dirty = true
end

-- key hardware interaction
function key(n, z)
	-- KEY 2
	if n == 2 and z == 1 then
		record()
	end

	-- KEY 3
	-- all based on Parameter choice
	if n == 3 then
		if z == 1 then
			KEY3_hold = true
			if KEY3 == 1 then
				warble()
			elseif KEY3 == 2 then
				half_speed()
			elseif KEY3 == 3 then
				rev_speed()
			elseif KEY3 == 4 then
				oneandahalf_speed()
			elseif KEY3 == 5 then
				double_speed()
			end
		elseif z == 0 then
			KEY3_hold = false
			restore_speed()
		end
		softcut.rate(1, wiggle * semitone_offset)
	end

	-- KEY 1
	-- hold key 1 + key 3 to clear the buffers
	if n == 1 and z == 1 and KEY3_hold == true then
		clear_all()
		KEY1_hold = false
	elseif n == 1 and z == 1 then
		KEY1_press = KEY1_press + 1
		if recording == true then
			recording = false
			if KEY1_press % 2 == 1 then
				softcut.rec_level(1, 0)
				softcut.pre_level(1, 1)
			elseif KEY1_press % 2 == 0 then
				softcut.rec_level(2, 0)
				softcut.pre_level(2, 1)
			end
			crane_redraw[1] = 0
			crane_redraw[2] = 0
			screen_dirty = true
		end
		KEY1_hold = true
		screen_dirty = true
	elseif n == 1 and z == 0 then
		KEY1_hold = false
		screen_dirty = true
	end
end

-- encoder hardware interaction
function enc(n, d)
	if all_loaded then
		-- encoder 3: voice 1's loop end point
		if n == 3 and KEY1_press % 2 == 0 then
			track[1].end_point = util.clamp((track[1].end_point + d / 10), 1.0, 61.0)
			softcut.loop_end(1, track[1].end_point)
			screen_dirty = true

		-- encoder 2: voice 1's loop start point
		elseif n == 2 and KEY1_press % 2 == 0 then
			track[1].start_point = util.clamp((track[1].start_point + d / 10), 1.0, 61.0)
			softcut.loop_start(1, track[1].start_point)
			screen_dirty = true

		-- encoder 3: voice 2's loop end point
		elseif n == 3 and KEY1_press % 2 == 1 then
			track[2].end_point = util.clamp((track[2].end_point + d / 10), 1.0, 61.0)
			softcut.loop_end(2, track[2].end_point)
			screen_dirty = true

		-- encoder 2: voice 2's loop start point
		elseif n == 2 and KEY1_press % 2 == 1 then
			track[2].start_point = util.clamp((track[2].start_point + d / 10), 1.0, 61.0)
			softcut.loop_start(2, track[2].start_point)
			screen_dirty = true

		-- encoder 1: voice 1's overwrite/overdub amount
		-- 0 is full overdub
		-- 1 is full overwrite
		elseif n == 1 then
			if KEY1_press % 2 == 0 then
				overdub_strength[1] = util.clamp((overdub_strength[1] + d / 100), 0.0, 1.0)
				if recording == true then
					softcut.pre_level(1, math.abs(overdub_strength[1] - 1))
				end
			elseif KEY1_press % 2 == 1 then
				overdub_strength[2] = util.clamp((overdub_strength[2] + d / 100), 0.0, 1.0)
				if recording == true then
					softcut.pre_level(2, math.abs(overdub_strength[2] - 1))
				end
			end
			screen_dirty = true
		end
	end
end

-- displaying stuff on the screen
function redraw()
	screen.clear()
	screen.level(15)
	screen.move(0, 50)
	if KEY1_press % 2 == 1 then
		screen.text("s2: " .. util.round(track[2].start_point - 1, 0.01))
	elseif KEY1_press % 2 == 0 then
		screen.text("s1: " .. util.round(track[1].start_point - 1, 0.01))
	end
	screen.move(0, 60)
	if KEY1_press % 2 == 1 then
		screen.text("e2: " .. util.round(track[2].end_point - 1, 0.01))
	elseif KEY1_press % 2 == 0 then
		screen.text("e1: " .. util.round(track[1].end_point - 1, 0.01))
	end
	screen.move(0, 40)
	if KEY1_press % 2 == 1 then
		screen.text("o2: " .. overdub_strength[2])
	elseif KEY1_press % 2 == 0 then
		screen.text("o1: " .. overdub_strength[1])
	end
	if crane_redraw[1] == 1 then
		if crane_redraw[2] == 0 then
			crane()
		else
			crane2()
		end
	end
	screen.level(3)
	screen.move(0, 10)
	screen.text("one: " .. (math.floor(track[1].poll_position * 10) / 10) - 1)
	screen.move(0, 20)
	screen.text("two: " .. (math.floor(track[2].poll_position * 10) / 10) - 1)
	screen.update()
end

-- crane drawing
function crane()
	screen.level(13)
	screen.aa(1)
	screen.line_width(0.5)
	screen.move(50, 60)
	screen.line(65, 40)
	screen.move(65, 40)
	screen.line(100, 50)
	screen.move(100, 50)
	screen.line(50, 60)
	screen.move(60, 47)
	screen.line(48, 15)
	screen.move(48, 15)
	screen.line(75, 40)
	screen.move(73, 43)
	screen.line(85, 35)
	screen.move(85, 35)
	screen.line(100, 50)
	screen.move(100, 50)
	screen.line(105, 25)
	screen.move(105, 25)
	screen.line(117, 35)
	screen.move(117, 35)
	screen.line(104, 30)
	screen.move(105, 25)
	screen.line(100, 30)
	screen.move(100, 30)
	screen.line(95, 45)
	screen.move(97, 40)
	screen.line(80, 20)
	screen.move(80, 20)
	screen.line(70, 35)
	screen.stroke()
	screen.update()
end

function crane2()
	screen.level(3)
	screen.aa(1)
	screen.line_width(0.5)
	if track[1].poll_position < 11 then
		screen.move(101 - (track[1].poll_position * 3), 61 - track[2].poll_position)
	elseif track[1].poll_position < 41 then
		screen.move(101 - (track[1].poll_position * 2), 61 - track[2].poll_position)
	else
		screen.move(101 - track[1].poll_position, 61 - track[2].poll_position)
	end
	local c2 = math.random(29, 31)
	if c2 > 30 then
		screen.text(" ^ ^ ")
	elseif c2 < 30 then
		screen.text(" v v ")
	else
		screen.text(" ^ ^ ")
	end
	screen.stroke()
	screen.update()
end

-- GRID --

-- hardware: grid connect
g = grid.connect()
-- hardware: grid event (eg 'what happens when a button is pressed')
g.key = function(x, y, z)
	-- speed + direction
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
	grid_dirty = true
end

-- hardware: grid redraw
function grid_redraw()
	g:all(0)
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
	if selected_preset[1] ~= 0 then
		g:led(selected_preset[1], 2, 12)
	end
	if selected_preset[2] ~= 0 then
		g:led(selected_preset[2], 6, 12)
	end
	g:refresh()
end