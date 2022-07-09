local patterns = {}

function patterns.init()

  pattern = {}
  overdubbing_pattern = false
  overdub_toggle = false
  duplicate_toggle = false
  copy_toggle = false
  pattern_clipboard = {event = {}, time = {}, count = 0}
  pattern_overdub_state = {}

  for i = 1,8 do
    pattern[i] = _pt.new(i)
    pattern[i].process = rec_playback_event
    pattern[i].rec_clock = nil
    pattern_overdub_state[i] = false
    pattern[i].overdub_action =
    function(id,state)
      pattern_overdub_state[id] = state
      overdubbing_pattern = false
      for j = 1,8 do
        if pattern[j].overdub == 1 then
          overdubbing_pattern = true
          break
        end
      end
    end
  end

end

function patterns.record_grid_press(e)
  for i = 1,8 do
    pattern[i]:watch(e)
  end
end

function patterns.start_recording(i)
  print("start recording pattern "..i)
  pattern[i]:rec_start()
  if params:string("pattern_rec_mode_"..i) == "duration" or params:string("pattern_rec_mode_"..i) == "clocked" then
    pattern[i].rec_clock = clock.run(
      function()
        clock.sleep(params:get("pattern_rec_duration_"..i) * clock.get_beat_sec())
        pattern[i]:rec_stop()
        pattern[i]:start()
      end
    )
  end
end

function patterns.stop_recording(i)
  print("stop recording pattern "..i)
  if pattern[i].rec_clock then
    clock.cancel(pattern[i].rec_clock)
  end
  pattern[i]:rec_stop()
  pattern[i]:start()
end

function patterns.handle_grid_pat(i,alt)
  if not overdub_toggle and not loop_toggle and not duplicate_toggle and not copy_toggle and not alt then
    if pattern[i].rec == 1 then -- if we're recording...
      patterns.stop_recording(i)
    elseif pattern[i].count == 0 then -- otherwise, if there are no events recorded..
      patterns.start_recording(i) -- start recording
    elseif pattern[i].play == 1 then -- if we're playing...
      pattern[i]:stop() -- stop playing
    else -- if by this point, we're not playing...
      pattern[i]:start() -- start playing
    end
  elseif alt then
    pattern[i]:rec_stop() -- stops recording
    pattern[i]:stop() -- stops playback
    pattern[i]:clear() -- clears the pattern
  elseif overdub_toggle then
    pattern[i]:set_overdub(pattern[i].overdub == 0 and 1 or 0)
  elseif duplicate_toggle then
    pattern[i]:duplicate()
  elseif loop_toggle then
    pattern[i].loop = pattern[i].loop == 1 and 0 or 1
  elseif copy_toggle then
    if #pattern_clipboard.event == 0 and pattern[i].count > 0 then
      pattern_clipboard.event = pattern[i].deep_copy(pattern[i].event)
      pattern_clipboard.time = pattern[i].deep_copy(pattern[i].time)
      pattern_clipboard.count = pattern[i].count
    elseif #pattern_clipboard.event > 0 then
      pattern[i].event = pattern[i].deep_copy(pattern_clipboard.event)
      pattern[i].time = pattern[i].deep_copy(pattern_clipboard.time)
      pattern[i].count = pattern_clipboard.count
      pattern_clipboard.event = {}
      pattern_clipboard.time = {}
      pattern_clipboard.count = 0
    end
  end
end

return patterns