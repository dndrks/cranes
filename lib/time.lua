local time = {}

local notes_to_durs =
  {
    [" bar(s)"] = 0.25,
    ["/2"] = 0.5,
    ["/2d"] = 1/3,
    ["/2t"] = 3/4,
    ["/4"] = 1
  , ["/4d"] = 2/3
  , ["/4t"] = 3/2
  , ["/8"] = 2
  , ["/8d"] = 4/3
  , ["/8t"] = 3
  , ["/16"] = 4
  , ["/16d"] = 8/3
  , ["/16t"] = 6
  , ["/32"] = 8
  , ["/32d"] = 16/3
  , ["/32t"] = 12
  }

function time.init()
  time.menu = {}
  time.menu.beat_count = {{16},{16},{16},{16}}
  time.menu.signature = {}
  time.menu.signature.num = {4,4,4,4}
  time.menu.signature.denum = {4,4,4,4}
  time.menu.div_options = {" bar(s)","/2","/2d","/2t","/4","/4d","/4t","/8","/8d","/8t","/16","/16d","/16t","/32","/32d","/32t"}
  time.menu.div_selection = {1,1,1,1}
  time.menu.div_mult = {1,1,1,1}
  time.menu.sel = 1
  time.menu.displayed = false
end

function time.get_beats(_t)
  local sel = time.menu.div_selection[_t]
  local base_dur = notes_to_durs[time.menu.div_options[sel]]
  local total_time = (clock.get_beat_sec() / base_dur) * (time.menu.signature.num[_t] / time.menu.signature.denum[_t]) * time.menu.div_mult[_t]
  return total_time
end

function time.snap_loop_to_beats(_t,beats)
  -- local scaled_time = clock.get_beat_sec() * beats
  local scaled_time = time.get_beats(_t)
  track[_t].end_point = track[_t].start_point + scaled_time
  softcut.loop_end(_t,track[_t].end_point)
  screen_dirty = true
  grid_dirty = true
end

function time.set_bpm_from_loop(_t)
  local dur = track[_t].end_point - track[_t].start_point
  if dur > 0 then
    local quarter = dur/4
    local derived_bpm = 60/quarter
    while derived_bpm < 70 do
      derived_bpm = derived_bpm * 2
      if derived_bpm > 160 then break end
    end
    while derived_bpm > 160 do
      derived_bpm = derived_bpm/2
      if derived_bpm <= 70 then break end
    end
    params:set("clock_tempo", util.round(derived_bpm,0.01))
  end
end

function time.process_encoder(_t,n,d)
  if n == 3 then
    if time.menu.sel == 1 then
      time.menu.div_mult[_t] = util.clamp(time.menu.div_mult[_t]+d,1,99)
    elseif time.menu.sel == 2 then
      time.menu.div_selection[_t] = util.clamp(time.menu.div_selection[_t]+d,1,tab.count(time.menu.div_options))
    end
  elseif n == 2 then
    time.menu.sel = util.clamp(time.menu.sel+d,1,2)
  end
end

function time.process_key(_t,n,z)
  if n == 3 and z == 1 then
    time.snap_loop_to_beats(_t,time.get_beats(_t))
  end
end

return time