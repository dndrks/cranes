local snapshot = {}

function snapshot.pack(voice,coll)
  snapshots[voice][coll].start_point = track[voice].start_point
  snapshots[voice][coll].end_point = track[voice].end_point
  -- snapshots[voice][coll].poll_position = track[voice].poll_position
  snapshots[voice][coll].rate = params:get("speed_voice_"..voice)
  snapshots[voice][coll].level = params:get("vol_"..voice)
  snapshots[voice][coll].fc = params:get("post_filter_fc_"..voice)
  snapshots[voice][coll].lp = params:get("post_filter_lp_"..voice)
  snapshots[voice][coll].hp = params:get("post_filter_hp_"..voice)
  snapshots[voice][coll].bp = params:get("post_filter_bp_"..voice)
  snapshots[voice][coll].dry = params:get("post_filter_dry_"..voice)
  snapshots[voice][coll].rq = params:get("post_filter_rq_"..voice)
  selected_snapshot[voice] = coll
end

function snapshot.unpack(voice, coll)
  if track[voice].snapshot.partial_restore then
    clock.cancel(track[voice].snapshot.fnl)
    track[voice].snapshot.partial_restore = false
  end
  local change_position = false
  if track[voice].start_point ~= snapshots[voice][coll].start_point
  and track[voice].end_point ~= snapshots[voice][coll].end_point then
    change_position = true
  end
  track[voice].start_point = snapshots[voice][coll].start_point
  softcut.loop_start(voice,track[voice].start_point)
  track[voice].end_point = snapshots[voice][coll].end_point
  softcut.loop_end(voice,track[voice].end_point)
  -- softcut.position(voice,snapshots[voice][coll].poll_position)
  if change_position then
    softcut.position(voice,snapshots[voice][coll].start_point)
  end
  params:set("speed_voice_"..voice, snapshots[voice][coll].rate)
  params:set("vol_"..voice,snapshots[voice][coll].level)
  params:set("post_filter_fc_"..voice, snapshots[voice][coll].fc)
  params:set("post_filter_lp_"..voice, snapshots[voice][coll].lp)
  params:set("post_filter_hp_"..voice, snapshots[voice][coll].hp)
  params:set("post_filter_bp_"..voice, snapshots[voice][coll].bp)
  params:set("post_filter_dry_"..voice, snapshots[voice][coll].dry)
  params:set("post_filter_rq_"..voice, snapshots[voice][coll].rq)
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
  print("snapshot funnel done")
  snapshot.unpack(voice, coll)
  if track[voice].snapshot.partial_restore then
    track[voice].snapshot.partial_restore = false
  end
end


function try_it(_t,slot,sec,style)
  if track[_t].snapshot.partial_restore then
    clock.cancel(track[_t].snapshot.fnl)
    snapshot.funnel_done_action(_t,slot)
  end
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
  original_srcs.level = params:get("vol_".._t)
  original_srcs.fc = params:get("post_filter_fc_".._t)
  original_srcs.lp = params:get("post_filter_lp_".._t)
  original_srcs.hp = params:get("post_filter_hp_".._t)
  original_srcs.bp = params:get("post_filter_bp_".._t)
  original_srcs.dry = params:get("post_filter_dry_".._t)
  original_srcs.rq = params:get("post_filter_rq_".._t)
  track[_t].snapshot.fnl = snapshot.fnl(
    function(r_val)
      track[_t].snapshot.current_value = r_val
      track[_t].start_point = util.linlin(0,1,original_srcs.start_point,snapshots[_t][slot].start_point,r_val)
      track[_t].end_point = util.linlin(0,1,original_srcs.end_point,snapshots[_t][slot].end_point,r_val)
      params:set("vol_".._t, util.linlin(0,1,original_srcs.level,snapshots[_t][slot].level,r_val))
      params:set("post_filter_fc_".._t, util.linlin(0,1,original_srcs.fc,snapshots[_t][slot].fc,r_val))
      params:set("post_filter_lp_".._t, util.linlin(0,1,original_srcs.lp,snapshots[_t][slot].lp,r_val))
      params:set("post_filter_hp_".._t, util.linlin(0,1,original_srcs.hp,snapshots[_t][slot].hp,r_val))
      params:set("post_filter_bp_".._t, util.linlin(0,1,original_srcs.bp,snapshots[_t][slot].bp,r_val))
      params:set("post_filter_dry_".._t, util.linlin(0,1,original_srcs.dry,snapshots[_t][slot].dry,r_val))
      params:set("post_filter_rq_".._t, util.linlin(0,1,original_srcs.rq,snapshots[_t][slot].rq,r_val))
      softcut.loop_start(_t,track[_t].start_point)
      softcut.loop_end(_t,track[_t].end_point)
      -- softcut.position(_t,snapshots[_t][coll].poll_position)
      -- params:set("speed_voice_".._t, snapshots[_t][coll].rate)
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