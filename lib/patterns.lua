local patterns = {}

function patterns.init()
  pattern = {}
  for i = 1,8 do
    pattern[i] = pattern_time.new()
    pattern[i].process = event
    pattern[i].rec_clock = nil
  end
end

function patterns.record_grid_press(e)
  for i = 1,8 do
    pattern[i]:watch(e)
  end
end

function patterns.start_recording(i)
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
  if pattern[i].rec_clock then
    clock.cancel(pattern[i].rec_clock)
  end
  pattern[i]:rec_stop()
  pattern[i]:start()
end

return patterns