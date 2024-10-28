local step = {}

function step.init()
	step.current_view = "steps"
	step.curves = {
		"inSine",
		"outQuad",
		"inOutQuint",
		"outCirc",
	}
	step.seq_count = 3
	step.seq = {}

	for v = 1, step.seq_count do
		step.seq[v] = {}
		step.seq[v].ease_strength = 0
		step.seq[v].step_offset = 0
		step.seq[v].total_steps = 24
		step.seq[v].true_stamps = {}
		step.seq[v].steps = {
			start_point = 1,
			end_point = step.seq[v].total_steps,
		}
    step.seq[v].locks = {
      start_point = 1,
			end_point = step.seq[v].total_steps,
		}
		for s = 1, step.seq[v].total_steps do
			step.seq[v].steps[s] = {
				clickstamp = ((s - 1) * 24) + 1, -- whole values are "on grid"
				offstamp = ((s - 1) * 24) + 1, -- whole values are "on grid"
				offset = 0,
				active = false,
			}
      step.seq[v].locks[s] = {
        clickstamp = ((s - 1) * 24) + 1, -- whole values are "on grid"
				offstamp = ((s - 1) * 24) + 1, -- whole values are "on grid"
				offset = 0,
				active = false,
      }
		end
		step.seq[v].current_step = 24
		step.seq[v].current_click = ((step.seq[v].total_steps-1) * 24)+1
	end
end

function step.go()
	step.running = true
	step.show_playhead = true
	for v = 1, step.seq_count do
		step.seq[v].clock = clock.run(function()
			-- clock.sync(1)
			-- step_action(v, seq[v].steps.start_point)
			while true do
        local this_seq = step.seq[v]
				local this_step = this_seq.steps[this_seq.current_step]
        local this_lock = this_seq.locks[this_seq.current_step]
				if this_seq.current_click == this_step.clickstamp + this_step.offset then
					this_seq.current_step =
						util.wrap(this_seq.current_step + 1, this_seq.steps.start_point, this_seq.steps.end_point)
					step.trigger_action(v, this_seq.current_step)
				end
				this_seq.current_click = util.wrap(this_seq.current_click + 1, 1, (24 * this_seq.total_steps))
				hardware_dirty = true
				clock.sync(1 / 24)
			end
		end)
	end
end

function step.stop()
	step.running = false
	for v = 1, seq_count do
		clock.cancel(step.seq[v].clock)
		step.seq[v].current_click = 361
		step.seq[v].current_step = 16
	end
	step.show_playhead = false
	hardware_dirty = true
end

function step.draw_grid(v)
  if step.current_view == 'steps' then
    for s = step.seq[v].steps.start_point, step.seq[v].steps.end_point do
      local x = util.wrap(s,1,8)
      local batch = s <= 8 and 1 or (s<= 16 and 2 or 3)
      local brightness
      if step.seq[v].current_step == s and step.show_playhead then
        brightness = step.seq[v].steps[s].active and 15 or 10
      else
        brightness = step.seq[v].steps[s].active and 5 or 2
      end
      g:led(x+8, batch+8, brightness)
    end
  elseif step.current_view == 'locks' then
		for s = step.seq[v].locks.start_point, step.seq[v].locks.end_point do
			local x = util.wrap(s, 1, 8)
			local batch = s <= 8 and 1 or (s <= 16 and 2 or 3)
			local brightness
			if step.seq[v].current_step == s and step.show_playhead then
				brightness = step.seq[v].locks[s].active and 15 or 10
			else
				brightness = step.seq[v].locks[s].active and 5 or 2
			end
			g:led(x + 8, batch + 8, brightness)
		end
  elseif step.current_view == 'rotate' then
    for s = 0,15 do
      local brightness
      if s == math.abs(step.seq[v].step_offset) then
        brightness = step.seq[v].step_offset >= 0 and 10 or 0
      else
        brightness = step.seq[v].step_offset >= 0 and 3 or 10
      end
      g:led(s+1,v,brightness)
    end
  end
end

function step.trigger_action(v, s)
	if step.seq[v].steps[s].active then
		print('step triggered!')
	end
end

function step.lock_action(v, s)
	if step.seq[v].locks[s].active then
		print("lock triggered!")
	end
end

return step