local snapshot = {}

function snapshot.pack(voice,coll)
  snapshots[voice][coll].start_point = track[voice].start_point
  snapshots[voice][coll].end_point = track[voice].end_point
  -- snapshots[voice][coll].poll_position = track[voice].poll_position
  snapshots[voice][coll].rate = params:get("speed_voice_"..voice)
  snapshots[voice][coll].vol = params:get("vol_"..voice)
  snapshots[voice][coll].pan = params:get("pan_"..voice)
  snapshots[voice][coll].post_filter_fc = params:get("post_filter_fc_"..voice)
  snapshots[voice][coll].lp = params:get("post_filter_lp_"..voice)
  snapshots[voice][coll].hp = params:get("post_filter_hp_"..voice)
  snapshots[voice][coll].bp = params:get("post_filter_bp_"..voice)
  snapshots[voice][coll].dry = params:get("post_filter_dry_"..voice)
  snapshots[voice][coll].rq = params:get("post_filter_rq_"..voice)
  snapshots[voice][coll].speed = tonumber(params:string("speed_voice_"..voice))
  
  snapshots[voice][coll].lfos = {}
  for k,v in pairs(_lfos.parent_strings) do
    snapshots[voice][coll].lfos[v] = {}
    snapshots[voice][coll].lfos[v].enabled = params:get('lfo '..v..' '..voice)
    snapshots[voice][coll].lfos[v].depth = params:get('lfo depth '..v..' '..voice)
    snapshots[voice][coll].lfos[v].min = params:get('lfo min '..v..' '..voice)
    snapshots[voice][coll].lfos[v].max = params:get('lfo max '..v..' '..voice)
    snapshots[voice][coll].lfos[v].position = params:get('lfo position '..v..' '..voice)
    snapshots[voice][coll].lfos[v].mode = params:get('lfo mode '..v..' '..voice)
    snapshots[voice][coll].lfos[v].bars = params:get('lfo bars '..v..' '..voice)
    snapshots[voice][coll].lfos[v].shape = params:get('lfo shape '..v..' '..voice)
    snapshots[voice][coll].lfos[v].reset_target = params:get('lfo reset target '..v..' '..voice)
  end

  selected_snapshot[voice] = coll
end

function snapshot.seed_restore_state_to_all(voice,coll,_p)
  print(voice,coll,_p)
  if type(_p) == "table" then
    for i = 1,tab.count(_p) do
      local feeder = snapshots[voice][coll].restore[_p[i]]
      for j = 1,#snapshots[voice] do
        snapshots[voice][j].restore[_p[i]] = feeder
      end
    end
  else
    local feeder = snapshots[voice][coll].restore[_p]
    for j = 1,#snapshots[voice] do
      snapshots[voice][j].restore[_p] = feeder
    end
  end
end

function snapshot.unpack(voice, coll)
  if track[voice].snapshot.partial_restore then
    clock.cancel(track[voice].snapshot.fnl)
    print("partial restore unpack",voice,coll)
    track[voice].snapshot.partial_restore = false
  end
  local change_position = false
  if snapshots[voice][coll].restore.start_point and snapshots[voice][coll].restore.end_point then
    if track[voice].start_point ~= snapshots[voice][coll].start_point
    and track[voice].end_point ~= snapshots[voice][coll].end_point then
      change_position = true
    end
  end
  if snapshots[voice][coll].restore.start_point then
    track[voice].start_point = snapshots[voice][coll].start_point
    -- softcut.loop_start(voice,track[voice].start_point)
    set_softcut_param('loop_start',voice,track[voice].start_point - FADE_TIME)
  end
  if snapshots[voice][coll].restore.end_point then
    track[voice].end_point = snapshots[voice][coll].end_point
    -- softcut.loop_end(voice,track[voice].end_point)
    set_softcut_param('loop_end',voice,track[voice].end_point - FADE_TIME)
  end
  -- softcut.position(voice,snapshots[voice][coll].poll_position)
  if (change_position and params:string("snapshot_restore_pos_"..voice) == "no") or
  (not change_position and params:string("snapshot_restore_pos_"..voice) == "yes") then
    -- softcut.position(voice,snapshots[voice][coll].start_point)
    set_softcut_param('position',voice,snapshots[voice][coll].start_point - FADE_TIME)
  end
  if snapshots[voice][coll].restore.rate then
    params:set("speed_voice_"..voice, snapshots[voice][coll].rate) -- TODO: could '.rate' be '.speed'?
  end
  
  if snapshots[voice][coll].restore.lfo then
    for k,v in pairs(_lfos.parent_strings) do
      params:set('lfo '..v..' '..voice, snapshots[voice][coll].lfos[v].enabled)
      params:set('lfo depth '..v..' '..voice, snapshots[voice][coll].lfos[v].depth)
      params:set('lfo min '..v..' '..voice, snapshots[voice][coll].lfos[v].min)
      params:set('lfo max '..v..' '..voice, snapshots[voice][coll].lfos[v].max)
      params:set('lfo position '..v..' '..voice, snapshots[voice][coll].lfos[v].position)
      params:set('lfo mode '..v..' '..voice, snapshots[voice][coll].lfos[v].mode)
      params:set('lfo bars '..v..' '..voice, snapshots[voice][coll].lfos[v].bars)
      params:set('lfo shape '..v..' '..voice, snapshots[voice][coll].lfos[v].shape)
      params:set('lfo reset target '..v..' '..voice, snapshots[voice][coll].lfos[v].reset_target)
    end
  end
  
  local lfo_param_pairs = {levels = 'vol', panning = 'pan', ['filter cutoff'] = 'post_filter_fc'}
  
  for k,v in pairs(lfo_param_pairs) do
    if params:string('lfo '..k..' '..voice) == "off" then
      if snapshots[voice][coll].restore[v] then
        params:set(v.."_"..voice,snapshots[voice][coll][v])
      end
    end
  end

  if snapshots[voice][coll].restore.post_filter_fc then
    params:set("post_filter_fc_"..voice, snapshots[voice][coll].post_filter_fc)
    params:set("post_filter_lp_"..voice, snapshots[voice][coll].lp)
    params:set("post_filter_hp_"..voice, snapshots[voice][coll].hp)
    params:set("post_filter_bp_"..voice, snapshots[voice][coll].bp)
    params:set("post_filter_dry_"..voice, snapshots[voice][coll].dry)
    params:set("post_filter_rq_"..voice, snapshots[voice][coll].rq)
  end
  screen_dirty = true
  grid_dirty = true
  selected_snapshot[voice] = coll
end

function snapshot.save_to_slot(_t,slot)
  clock.sleep(0.25)
  track[_t].snapshot.saver_active = true
  if track[_t].snapshot.saver_active then
    if not grid_alt then
      print("saved snap",_t,slot)
      snapshot.pack(_t,slot)
    else
      snapshot.clear(_t,slot)
    end
    grid_dirty = true
  end
  track[_t].snapshot.saver_active = false
end

function snapshot.clear(_t,slot)
  local pre_clear_restore = snapshots[_t][slot].restore
  snapshots[_t][slot] = {}
  snapshots[_t][slot].restore = pre_clear_restore
  if selected_snapshot[_t] == slot then
    selected_snapshot[_t] = 0
  end
end

function snapshot.fnl(fn, origin, dest_ms, fps)
  return clock.run(function()
    fps = fps or 15 -- default
    local spf = 1 / fps -- seconds per frame
    fn(origin)
    for _,v in ipairs(dest_ms) do
      local count = math.floor(v[2] * fps) -- number of iterations
      local stepsize = (v[1]-origin) / count -- how much to increment by each iteration
      while count > 0 do
        clock.sleep(spf)
        origin = origin + stepsize -- move toward destination
        count = count - 1 -- count iteration
        fn(origin)
      end
    end
  end)
end

snapshot.funnel_done_action = function(voice,coll)
  print("snapshot funnel done",voice,coll)
  snapshot.unpack(voice, coll)
  if track[voice].snapshot.partial_restore then
    track[voice].snapshot.partial_restore = false
  end
end


function try_it(_t,slot,sec,style)
  print("trying")
  if track[_t].snapshot.partial_restore then
    clock.cancel(track[_t].snapshot.fnl)
    print("partial restore try_it",_t,slot)
    snapshot.funnel_done_action(_t,slot)
  end
  print("doing try it for ".._t)
  track[_t].snapshot.partial_restore = true
  if style ~= nil then
    if style == "beats" then
      sec = clock.get_beat_sec()*sec
    elseif style == "time" then
      sec = sec
    end
  end
  local original_srcs = {}
  original_srcs.start_point = track[_t].start_point
  original_srcs.end_point = track[_t].end_point
  original_srcs.vol = params:get("vol_".._t)
  original_srcs.pan = params:get("pan_".._t)
  original_srcs.post_filter_fc = params:get("post_filter_fc_".._t)
  original_srcs.lp = params:get("post_filter_lp_".._t)
  original_srcs.hp = params:get("post_filter_hp_".._t)
  original_srcs.bp = params:get("post_filter_bp_".._t)
  original_srcs.dry = params:get("post_filter_dry_".._t)
  original_srcs.rq = params:get("post_filter_rq_".._t)
  -- original_srcs.speed = tonumber(params:string("speed_voice_".._t))
  original_srcs.speed = get_total_pitch_offset(_t)
  track[_t].snapshot.fnl = snapshot.fnl(
    function(r_val)
      track[_t].snapshot.current_value = r_val
      if snapshots[_t][slot].restore.start_point then
        track[_t].start_point = util.linlin(0,1,original_srcs.start_point,snapshots[_t][slot].start_point,r_val)
      end
      if snapshots[_t][slot].restore.end_point then
        track[_t].end_point = util.linlin(0,1,original_srcs.end_point,snapshots[_t][slot].end_point,r_val)
      end
      
      local lfo_param_pairs = {levels = 'vol', panning = 'pan', ['filter cutoff'] = 'post_filter_fc'}
  
      for k,v in pairs(lfo_param_pairs) do
        if params:string('lfo '..k..' '.._t) == "off" then
          if snapshots[_t][slot].restore[v] then
            params:set(v.."_".._t,util.linlin(0,1,original_srcs[v],snapshots[_t][slot][v],r_val))
          end
        end
      end

      if snapshots[_t][slot].restore.post_filter_fc then
        params:set("post_filter_fc_".._t, util.linlin(0,1,original_srcs.post_filter_fc,snapshots[_t][slot].post_filter_fc,r_val))
        params:set("post_filter_lp_".._t, util.linlin(0,1,original_srcs.lp,snapshots[_t][slot].lp,r_val))
        params:set("post_filter_hp_".._t, util.linlin(0,1,original_srcs.hp,snapshots[_t][slot].hp,r_val))
        params:set("post_filter_bp_".._t, util.linlin(0,1,original_srcs.bp,snapshots[_t][slot].bp,r_val))
        params:set("post_filter_dry_".._t, util.linlin(0,1,original_srcs.dry,snapshots[_t][slot].dry,r_val))
        params:set("post_filter_rq_".._t, util.linlin(0,1,original_srcs.rq,snapshots[_t][slot].rq,r_val))
      end
      if snapshots[_t][slot].restore.start_point then
        -- softcut.loop_start(_t,track[_t].start_point)
        set_softcut_param('loop_start',_t,track[_t].start_point)
      end
      if snapshots[_t][slot].restore.end_point then
        -- softcut.loop_end(_t,track[_t].end_point)
        set_softcut_param('loop_end',_t,track[_t].end_point)
      end
      -- softcut.position(_t,snapshots[_t][coll].poll_position)
      if snapshots[_t][slot].restore.rate_ramp then
        -- softcut.rate(_t,util.linlin(0,1,original_srcs.speed,snapshots[_t][slot].speed,r_val))
        set_softcut_param('rate',_t,util.linlin(0,1,original_srcs.speed,snapshots[_t][slot].speed,r_val))
        print(util.linlin(0,1,original_srcs.speed,snapshots[_t][slot].speed,r_val))
      end
      screen_dirty = true
      grid_dirty = true
      if track[_t].snapshot.current_value ~= nil and util.round(track[_t].snapshot.current_value,0.001) == 1 then
        snapshot.funnel_done_action(_t,slot)
      end
    end,
    0,
    {{1,sec}},
    60
  )
end

return snapshot