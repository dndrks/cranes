local loop = {}

function loop.queue_record(_t,silent)
  print("rec: "..tostring(rec[_t]), "clear: "..tostring(clear[_t]))
  if not rec_queued[_t] then
    if not rec[_t] and clear[_t] then
      if params:string("rec_enable_voice_".._t) == "clock" then
        holding_crane[_t]= 1
        screen_dirty = true
        track[_t].rec_on_clock = clock.run(
          function()
            if clock.get_beats() < 1 then
              clock.sync(4)
            else
              clock.sync(4,-1/100)
            end
            loop.execute_record(_t,silent)
            holding_crane[_t] = 0
          end
        )
      elseif params:string("rec_enable_voice_".._t) == "free" then
        loop.execute_record(_t,silent)
        holding_crane[_t] = 0
      end
    elseif rec[_t] and clear[_t] then
      if params:string("rec_disable_voice_".._t) == "clock" and params:string("loop_sizing_voice_".._t) == "manual (w/K3)" then
        holding_crane[_t] = 1
        screen_dirty = true
        track[_t].rec_off_clock = clock.run(
          function()
            clock.sync(4)
            print("holding here: "..clock.get_beats())
            loop.execute_record(_t,silent)
            holding_crane[_t] = 0
          end
        )
      elseif params:string("rec_disable_voice_".._t) == "free" and params:string("loop_sizing_voice_".._t) == "manual (w/K3)" then
        loop.execute_record(_t,silent)
      else
        print("unknown.")
      end
      -- if params:string("loop_sizing_voice_".._t) == "manual (w/K3)" then
      --   print("not recording, executing")
      --   loop.execute_record(_t,silent)
      -- end
    elseif not clear[_t] then
      loop.execute_record(_t)
    end

  elseif rec_queued[_t] then
    holding_crane[_t]= 1
    screen_dirty = true
    track[_t].rec_on_clock = clock.run(
      function()
        print("queued record on ".._t, clock.get_beats())
        -- clock.sync(4,-1/128)
        clock.sync(4)
        loop.execute_record(_t,silent)
        holding_crane[_t] = 0
      end
    )
  end

end

function loop.execute_record(_t,silent)
  print("executing rec: "..clock.get_beats())
  local queued_executed = false;
  if not silent then
    rec[_t] = not rec[_t]
    -- print("not silent")
  end
  -- check to see if the cue section is meant to be recorded into
  -- if so, enforce it
  if rec_queued[_t] then
    track[_t].start_point = track[_t].queued.start_point
    track[_t].end_point = track[_t].queued.end_point
    set_softcut_param('loop_start',_t,track[_t].queued.start_point - FADE_TIME)
    set_softcut_param('loop_end',_t,track[_t].queued.end_point - FADE_TIME)
    set_softcut_param('position',_t,track[_t].queued.start_point - FADE_TIME)
    -- _cue.is_there_audio(_t)
    clear[_t] = false
    rec_queued[_t] = false
    queued_executed = false
    rec[_t] = true
    print("is clear: "..(tostring(clear[_t])), track[_t].start_point, track[_t].end_point)
    track[_t].overdub_off_clock = clock.run(
        function()
          clock.sleep(track[_t].end_point - track[_t].start_point)
          print("yep, overdub clock")
          loop.execute_record(_t)
        end
      )
  end
  -- if the buffer is clear and recording is enabled:
  -- main recording will enable
  if rec[_t] and clear[_t] then
    local scaled = {
      -- {buffer, start, end}
      {1,softcut_offsets[1]},
      {params:get("voice_2_buffer"),softcut_offsets[2]},
      {1,softcut_offsets[3]},
      {2,softcut_offsets[4]}
    }
    -- if rec_queued[_t] then
    --   track[_t].start_point = track[_t].queued.start_point
    --   track[_t].end_point = track[_t].queued.end_point
    --   softcut.loop_start(_t,track[_t].start_point)
    --   softcut.loop_end(_t,track[_t].end_point)
    --   rec_queued[_t] = false
    -- end
    set_softcut_param('position',_t,track[_t].start_point - FADE_TIME)
    set_softcut_param('rate_slew_time',_t,0)
    set_softcut_param('rate',_t,1) -- TODO CONFIRM THIS IS OKAY
    set_softcut_param('play',_t,1)
    set_softcut_param('rec_level',_t,1)
    set_softcut_param('level',_t,0)
    softcut.poll_start_phase()
    counter[_t]:start()
    track[_t].playing = true
    recording_crane[_t] = 1
    screen_dirty = true
  -- if the buffer is clear and key 2 is pressed again:
  -- main recording will disable, loop points set
  elseif not rec[_t] and clear[_t] then
    -- clear[_t] = false
    _cue.is_there_audio(_t)
    -- softcut.position(_t,track[_t].start_point)
    set_softcut_param('position',_t,track[_t].start_point - FADE_TIME)
    -- softcut.rec_level(_t,0)
    set_softcut_param('rec_level',_t,0)
    counter[_t]:stop()
    softcut.poll_start_phase()
    track[_t].playing = true
    -- track[_t].end_point = util.round(softcut_offsets[_t] + rec_time[_t],0.01)
    if params:string("loop_sizing_voice_".._t) == "dialed (w/encoders)" then
      -- track[_t].end_point = (softcut_offsets[_t] + rec_time[_t])
    else
      if params:string("rec_disable_voice_".._t) == "clock" then
        local rounded_beat_dur = util.round(rec_time[_t]/clock.get_beat_sec())
        local rounded_time_dur = clock.get_beat_sec()*rounded_beat_dur
        track[_t].end_point = (softcut_offsets[_t] + rounded_time_dur)
      else
        track[_t].end_point = (softcut_offsets[_t] + rec_time[_t])
      end
    end
    print(_t,track[_t].end_point, rec_time[_t])
    set_softcut_param('loop_end',_t,track[_t].end_point - FADE_TIME)
    set_softcut_param('loop_start',_t,track[_t].start_point - FADE_TIME)
    track[_t].queued.start_point = track[_t].start_point
    track[_t].queued.end_point = track[_t].end_point
    -- track[2].start_point = 0
    recording_crane[_t] = 0
    screen_dirty = true
    rec_time[_t] = 0
    -- softcut.level(_t,params:get("vol_".._t))
    set_softcut_param('level',_t,params:get("vol_".._t))
    -- softcut.rate(_t,speedlist[_t][params:get("speed_voice_".._t)]*offset[_t])
    -- softcut.rate(_t, get_total_pitch_offset(_t))
    set_softcut_param('rate',_t, get_total_pitch_offset(_t))
    if track[_t].end_point > track[_t].rec_limit then
      track[_t].rec_limit = track[_t].end_point
    end
  end
  -- if the buffer is NOT clear and key 2 is pressed:
  -- overwrite/overdub behavior will enable
  if rec[_t] and not clear[_t] and not queued_executed then
    print("would toggle overdub on", "| queued: "..tostring(rec_queued[_t]))
    loop.toggle_overdub(_t,"on")
  -- if the buffer is NOT clear and key 2 is pressed again:
  -- overwrite/overdub behavior will disable
  elseif not rec[_t] and not clear[_t] and not queued_executed then
    print("would toggle overdub off")
    loop.toggle_overdub(_t,"off")
  end

  if params:string("loop_sizing_voice_".._t) == "dialed (w/encoders)" then
    print("eval loop")
    if rec[_t] and clear[_t] then
      track[_t].rec_off_clock = clock.run(
        function()
          clock.sleep(track[_t].end_point - track[_t].start_point)
          print("yep")
          loop.execute_record(_t)
        end
      )
    end
  end
end

function loop.jump_to_cue(_t)
  if track[_t].queue_jump_clock then
    clock.cancel(track[_t].queue_jump_clock)
  end
  track[_t].queue_jump_clock = clock.run(
    function()
      if params:string("queue_quant_voice_".._t) == 'clock' then
        clock.sync(4)
      end
      track[_t].start_point = track[_t].queued.start_point
      track[_t].end_point = track[_t].queued.end_point
      set_softcut_param('loop_start',_t,track[_t].start_point - FADE_TIME)
      set_softcut_param('loop_end',_t,track[_t].end_point - FADE_TIME)
    end
  )
end

function loop.toggle_overdub(_t,state)
  if state == "on" then
    rec[_t] = true
    -- softcut.rec_level(_t,1)
    set_softcut_param('rec_level',_t, 1)
    -- softcut.pre_level(_t,math.abs(over[_t]-1))
    set_softcut_param('pre_level',_t, math.abs(over[_t]-1))
    recording_crane[_t] = 1
    overdub_crane[_t] = 1
    -- if track[_t].end_point > track[_t].rec_limit then
    --   track[_t].rec_limit = track[_t].end_point
    -- end
  else
    rec[_t] = false
    -- softcut.rec_level(_t,0)
    set_softcut_param('rec_level',_t,0)
    -- softcut.pre_level(_t,1)
    set_softcut_param('pre_level',_t,1)
    recording_crane[_t] = 0
    overdub_crane[_t] = 0
  end
  screen_dirty = true
end

function loop.clear_track(_t)
  track[_t].clear_count = track[_t].clear_count+1
  local scaled = {
    -- {buffer, start, end}
    {1,softcut_offsets[1],softcut_offsets[1] + global_duration},
    {params:get("voice_2_buffer"),softcut_offsets[2],softcut_offsets[2] + global_duration},
    {1,softcut_offsets[3],global_duration + softcut_offsets[3]},
    {2,softcut_offsets[4],global_duration + softcut_offsets[4]},
  }
  if track[_t].rec_on_clock ~= nil then
    clock.cancel(track[_t].rec_on_clock)
  end
  if track[_t].rec_off_clock ~= nil then
    clock.cancel(track[_t].rec_off_clock)
  end
  -- softcut.rec_level(_t, 0)
  set_softcut_param('rec_level',_t,0)
  -- softcut.level(_t, 0)
  set_softcut_param('level',_t,0)
  -- softcut.play(_t, 1)
  set_softcut_param('play',_t,1)
  track[_t].playing = false
  -- softcut.rate(_t, 1) -- TODO CONFIRM THIS IS OK
  set_softcut_param('rate',_t,1)
  set_softcut_param('loop_start',_t,scaled[_t][2])
  set_softcut_param('loop_end',_t,scaled[_t][3])
  set_softcut_param('position',_t,scaled[_t][2])
  track[_t].rec_limit = 0

  set_softcut_param('buffer clear', {scaled[_t][1],scaled[_t][2],global_duration})

  ray = speedlist[1][params:get("speed_voice_1")] -- TODO FIX
  
  track[_t].start_point = scaled[_t][2]
  track[_t].end_point = scaled[_t][3]

  -- clear[_t] = true
  _cue.is_there_audio(_t)
  rec_time[_t] = 0
  rec[_t] = false
  recording_crane[_t] = 0
  overdub_crane[_t] = 0

  c2 = math.random(4,15) -- TODO FIX
  restore_speed()
  -- TODO FIX:
  -- for i = 1,16 do
  --   g:led(i,4,0)
  --   g:led(i,8,0)
  -- end
  g:refresh()
  screen_dirty = true
  KEY3_hold = false
  params:set("semitone_offset_".._t,0) -- TODO VERIFY IF NEEDED...
  track[_t].pos_grid = -1
  if track[_t].clear_count == 2 then
    track[_t].clear_count = 0
  end
end

function loop.move_window(_t,direction)
  local current_size = track[_t].end_point - track[_t].start_point
  local dir_mult = direction == "+" and 1 or -1
  if (track[_t].start_point + (dir_mult * current_size)) >= softcut_offsets[_t] and (track[_t].end_point + (dir_mult * current_size)) <= softcut_offsets[_t] + global_duration then
    track[_t].start_point = track[_t].start_point + (dir_mult * current_size)
    track[_t].end_point = track[_t].end_point + (dir_mult * current_size)
    loop.refresh_softcut_loops(_t)
  end
  screen_dirty = true
end

function loop.refresh_softcut_loops(_t)
  set_softcut_param('loop_start',_t,track[_t].start_point)
  set_softcut_param('loop_end',_t,track[_t].end_point)
end

function loop.window(voice,x)
  if x == 1 then
    if track[voice].start_point - 0.01 < 0 then
      track[voice].start_point = 0
    else
      track[voice].start_point = track[voice].start_point - 0.01
    end
  elseif x == 2 then
    if track[voice].start_point - 0.1 < 0 then
      track[voice].start_point = 0
    else
      track[voice].start_point = track[voice].start_point - 0.1
    end
  elseif x == 3 then
    track[voice].start_point = track[voice].start_point + 0.1
  elseif x == 4 then
    track[voice].start_point = track[voice].start_point + 0.01
  elseif x == 8 and track[voice].start_point > 0.009 then
    distance[voice] = math.abs(track[voice].start_point - track[voice].end_point)
    if track[voice].start_point < distance[voice] then
      track[voice].start_point = 0
    else
      track[voice].start_point = track[voice].start_point - distance[voice]
    end
    track[voice].end_point = track[voice].end_point - distance[voice]
  elseif x == 7 and track[voice].start_point > 0.009 then
    track[voice].start_point = track[voice].start_point - 0.01
    track[voice].end_point = track[voice].end_point - 0.01
  elseif x == 10 then
    track[voice].start_point = track[voice].start_point + 0.01
    track[voice].end_point = track[voice].end_point + 0.01
  elseif x == 9 then
    distance[voice] = math.abs(track[voice].start_point - track[voice].end_point)
    track[voice].start_point = track[voice].start_point + distance[voice]
    track[voice].end_point = track[voice].end_point + distance[voice]
  elseif x == 13 then
    if track[voice].end_point - 0.1 < 0 then
      track[voice].end_point = 0
    else
      track[voice].end_point = track[voice].end_point - 0.01
    end
  elseif x == 14 then
    if track[voice].end_point - 0.1 < 0 then
      track[voice].end_point = 0
    else
      track[voice].end_point = track[voice].end_point - 0.1
    end
  elseif x == 15 then
    track[voice].end_point = track[voice].end_point + 0.1
  elseif x == 16 then
    track[voice].end_point = track[voice].end_point + 0.01
  end
  loop.refresh_softcut_loops(voice)
  screen_dirty = true
end

-- --
-- -- osc
-- --
function osc_in(path, args, from)
  if path == "onset" then
    -- for i=1,6 do
    --   if uS.recording[i]==1 and (params:get("input type")==1 or params:get("input type")>=4) then
    --     -- print("incoming signal = "..val)
    --     tape_rec(i)
    --   end
    -- end
    -- loop.execute_record(1,silent)
    if all_loaded then
      for i = 1,2 do
        if not rec[i] and clear[i] then
          loop.execute_record(i,silent)
        end
      end
      all_loaded = false
    end
  end
end

return loop