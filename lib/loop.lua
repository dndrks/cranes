local loop = {}

function loop.queue_record(_t,silent)

  if params:string("rec_trigger_voice_".._t) == "clock" then
    if rec[_t] == 0 and clear[_t] == 1 then
      holding_crane[_t]= 1
      screen_dirty = true
      track[_t].rec_on_clock = clock.run(
        function()
          -- clock.sync(4,-1/16)
          clock.sync(4)
          loop.execute_record(_t,silent)
          holding_crane[_t] = 0
        end
      )
    end
  else
    loop.execute_record(_t,silent)
    holding_crane[_t] = 0
  end

end

function loop.execute_record(_t,silent)
  if not silent then
    rec[_t] = rec[_t] == 0 and 1 or 0
  end
  -- if the buffer is clear and recording is enabled:
  -- main recording will enable
  if rec[_t] == 1 and clear[_t] == 1 then
    local scaled = {
      -- {buffer, start, end}
      {1,0},
      {params:get("voice_2_buffer"),0},
      {1,softcut_offsets[3]},
      {2,softcut_offsets[4]}
    }
    -- softcut.buffer_clear_region_channel(scaled[_t][1],scaled[_t][2],60)
    softcut.position(_t,track[_t].start_point)
    softcut.rate_slew_time(_t,0.01)
    -- softcut.enable(_t, 1)
    -- softcut.rate(_t, 1*offset[_t])
    softcut.rate(_t, 1) -- TODO CONFIRM THIS IS OKAY
    softcut.play(_t, 1)
    -- softcut.rec(_t, 1)
    softcut.rec_level(_t,1)
    softcut.level(_t, 0)
    softcut.poll_start_phase()
    track[_t].playing = true
    recording_crane[_t] = 1
    screen_dirty = true
    counter:start()
  -- if the buffer is clear and key 2 is pressed again:
  -- main recording will disable, loop points set
  elseif rec[_t] == 0 and clear[_t] == 1 then
    clear[_t] = 0
    softcut.position(_t,track[_t].start_point)
    softcut.rec_level(_t,0)
    counter:stop()
    softcut.poll_start_phase()
    track[_t].playing = true
    -- track[_t].end_point = util.round(softcut_offsets[_t] + rec_time[_t],0.01)
    if params:string("loop_sizing_voice_".._t) == "dialed (w/encoders)" then
      -- track[_t].end_point = (softcut_offsets[_t] + rec_time[_t])
    else
      track[_t].end_point = (softcut_offsets[_t] + rec_time[_t])
    end
    print(_t,track[_t].end_point)
    softcut.loop_end(_t,track[_t].end_point)
    softcut.loop_start(_t,track[_t].start_point)
    -- track[2].start_point = 0
    recording_crane[_t] = 0
    screen_dirty = true
    rec_time[_t] = 0
    softcut.level(_t,params:get("vol_".._t))
    -- softcut.rate(_t,speedlist[_t][params:get("speed_voice_".._t)]*offset[_t])
    softcut.rate(_t, get_total_pitch_offset(_t))
    if track[_t].end_point > track[_t].rec_limit then
      track[_t].rec_limit = track[_t].end_point
    end
  end
  -- if the buffer is NOT clear and key 2 is pressed:
  -- overwrite/overdub behavior will enable
  if rec[_t] == 1 and clear[_t] == 0 then
    loop.toggle_overdub(_t,"on")
  -- if the buffer is NOT clear and key 2 is pressed again:
  -- overwrite/overdub behavior will disable
  elseif rec[_t] == 0 and clear[_t] == 0 then
    loop.toggle_overdub(_t,"off")
  end

  if params:string("loop_sizing_voice_".._t) == "dialed (w/encoders)" then
    print("eval loop")
    if rec[_t] == 1 and clear[_t] == 1 then
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

function loop.toggle_overdub(_t,state)
  if state == "on" then
    rec[_t] = 1
    softcut.rec_level(_t,1)
    softcut.pre_level(_t,math.abs(over[_t]-1))
    recording_crane[_t] = 1
    overdub_crane[_t] = 1
    -- if track[_t].end_point > track[_t].rec_limit then
    --   track[_t].rec_limit = track[_t].end_point
    -- end
  else
    rec[_t] = 0
    softcut.rec_level(_t,0)
    softcut.pre_level(_t,1)
    recording_crane[_t] = 0
    overdub_crane[_t] = 0
  end
  screen_dirty = true
end

function loop.clear_track(_t)
  local scaled = {
    -- {buffer, start, end}
    {1,0,global_duration},
    {params:get("voice_2_buffer"),0,global_duration},
    {1,softcut_offsets[3],global_duration + softcut_offsets[3]},
    {2,softcut_offsets[4],global_duration + softcut_offsets[4]},
  }
  if track[_t].rec_on_clock ~= nil then
    clock.cancel(track[_t].rec_on_clock)
  end
  if track[_t].rec_off_clock ~= nil then
    clock.cancel(track[_t].rec_off_clock)
  end
  softcut.rec_level(_t, 0)
  softcut.level(_t, 0)
  softcut.play(_t, 1)
  track[_t].playing = false
  softcut.position(_t, scaled[_t][2])
  -- softcut.rate(_t, 1*offset[_t])
  softcut.rate(_t, 1) -- TODO CONFIRM THIS IS OK
  softcut.loop_start(_t, scaled[_t][2])
  softcut.loop_end(_t, scaled[_t][3])
  softcut.position(_t, scaled[_t][2])
  track[_t].rec_limit = 0
  softcut.buffer_clear_region_channel(scaled[_t][1],scaled[_t][2],global_duration)

  ray = speedlist[1][params:get("speed_voice_1")] -- TODO FIX
  
  track[_t].start_point = scaled[_t][2]
  track[_t].end_point = scaled[_t][3]

  clear[_t] = 1
  rec_time[_t] = 0
  rec[_t] = 0
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
  softcut.loop_start(_t,track[_t].start_point)
  softcut.loop_end(_t,track[_t].end_point)
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
  softcut.loop_start(voice,track[voice].start_point)
  softcut.loop_end(voice,track[voice].end_point)
  screen_dirty = true
end

return loop