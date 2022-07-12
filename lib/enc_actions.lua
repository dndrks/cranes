local enc_actions = {}

function enc_actions.calc_accum(d)
  if (math.abs(d) == 1) then
    d = d > 0 and 1/100 or -1/100
  elseif (math.abs(d) < 3) then
    d = d > 0 and 1/10 or -1/10
  else
    d = d > 0 and 1 or -1
  end
  return d
end

function enc_actions.process_encoder(n,d)
  if not song_menu then
    local _t = voice_on_screen
    -- encoder 3: voice 1's loop end point
    if n == 3 then
      if not key1_hold then
        if not queue_menu.active then
          if rec[_t] and clear[_t] then
          else
            enc_actions.delta_end_point(_t,enc_actions.calc_accum(d),false)
            enc_actions.delta_end_point(_t,enc_actions.calc_accum(d),true)
          end
        else
          if queue_menu.sel == 1 then
            enc_actions.delta_window(_t,d,true)
          elseif queue_menu.sel == 2 then
            enc_actions.delta_start_point(_t,enc_actions.calc_accum(d),true)
          elseif queue_menu.sel == 3 then
            enc_actions.delta_end_point(_t,enc_actions.calc_accum(d),true)
          end
        end
      else
        _time.process_encoder(_t,n,d)
      end

    -- encoder 2: voice 1's loop start point
    elseif n == 2 then
      if not key1_hold then
        if not queue_menu.active then
          if rec[_t] and clear[_t] then
          else
            enc_actions.delta_start_point(_t,enc_actions.calc_accum(d),false)
            enc_actions.delta_start_point(_t,enc_actions.calc_accum(d),true)
          end
        else
          queue_menu.sel = util.clamp(queue_menu.sel+d,1,3)
        end
      else
        _time.process_encoder(_t,n,d)
      end

    -- encoder 1: voice 1's overwrite/overdub amount
    -- 0 is full overdub
    -- 1 is full overwrite
    elseif n == 1 then
      if key1_hold then
        voice_on_screen = util.clamp(voice_on_screen + d, 1, 4)
      else
        if not queue_menu.active then
          over[_t] = util.round(util.clamp((over[_t] + d/100), 0.0,1.0),0.01)
          if rec[voice_on_screen] then
            set_softcut_param('pre_level',_t,math.abs(over[_t]-1))
          end
        else
          enc_actions.delta_window(_t,d,queue_menu.active)
        end
      end
    end
  else
    _flow.process_encoder(n,d)
  end
  screen_dirty = true
  grid_dirty = true
end

function enc_actions.delta_start_point(_t,d,queue)
  if queue then
    track[_t].queued.start_point = util.clamp((util.round(track[_t].queued.start_point + d,0.01)), 0 + softcut_offsets[_t], track[_t].queued.end_point - 0.01)
  else
    track[_t].start_point = util.clamp((util.round(track[_t].start_point + d,0.01)), 0 + softcut_offsets[_t], track[_t].end_point - 0.01)
    set_softcut_param('loop_start',_t,track[_t].start_point)
  end
end

function enc_actions.delta_end_point(_t,d,queue)
  if queue then
    track[_t].queued.end_point = util.clamp((util.round(track[_t].queued.end_point + d,0.01)), track[_t].queued.start_point + 0.01, global_duration + softcut_offsets[_t])
  else
    track[_t].end_point = util.clamp((util.round(track[_t].end_point + d,0.01)), track[_t].start_point + 0.01, global_duration + softcut_offsets[_t])
    set_softcut_param('loop_end',_t,track[_t].end_point - FADE_TIME)
  end
end

function enc_actions.delta_window(_t,d,queue)
  if queue then
    if params:string("queue_window_quant_voice_".._t) == "free" then
      if track[_t].queued.end_point + enc_actions.calc_accum(d) <= global_duration + softcut_offsets[_t] and
      track[_t].queued.start_point + enc_actions.calc_accum(d) >= softcut_offsets[_t]
      then
        enc_actions.delta_start_point(_t,enc_actions.calc_accum(d),true)
        enc_actions.delta_end_point(_t,enc_actions.calc_accum(d),true)
      end
    else
      if d > 0 then
        if util.round(track[_t].queued.end_point + (math.abs(track[_t].queued.end_point - track[_t].queued.start_point)),0.0000001) <= global_duration + softcut_offsets[_t] then
          local original_start = track[_t].queued.start_point
          track[_t].queued.start_point = track[_t].queued.end_point + (params:get("queue_window_offset_voice_".._t))
          track[_t].queued.end_point = track[_t].queued.end_point + (math.abs(track[_t].queued.end_point - original_start)) + (params:get("queue_window_offset_voice_".._t))
        end
      elseif d < 0 then
        if util.round(track[_t].queued.start_point - (math.abs(track[_t].queued.end_point - track[_t].queued.start_point)),0.0000001) >= softcut_offsets[_t] then
          local original_end = track[_t].queued.end_point
          track[_t].queued.end_point = track[_t].queued.start_point - (params:get("queue_window_offset_voice_".._t))
          track[_t].queued.start_point = track[_t].queued.start_point - (math.abs(original_end - track[_t].queued.start_point)) - (params:get("queue_window_offset_voice_".._t))
        end
      end
    end
  end
  -- if queue then
  --   if d > 0 then
  --     if track[_t].queued.end_point + track[_t].queued.end_point <= global_duration + softcut_offsets[_t] then
  --       track[_t].queued.end_point = track[_t].queued.end_point + track[_t].queued.end_point
  --     end
  --   elseif d < 0 then
  --     if track[_t].queued.end_point - ((math.abs(track[_t].queued.end_point - track[_t].queued.start_point))/2) <= global_duration + softcut_offsets[_t] then
  --       track[_t].queued.end_point = track[_t].queued.end_point - ((math.abs(track[_t].queued.end_point - track[_t].queued.start_point))/2)
  --     end
  --   end
  -- else
  --   track[_t].end_point = new_val
  --   softcut.loop_end(_t,track[_t].end_point)
  -- end
end

return enc_actions