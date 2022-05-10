local chitter = {}

function chitter.init()
  chitter_stretch = {}
  for i = 1,4 do
    chitter_stretch[i] = {}
    chitter_stretch[i].enabled = false
    chitter_stretch[i].modes = {"off","woodcock","dove","starling"}
    chitter_stretch[i].mode = "off"
    chitter_stretch[i].inc = 12
    chitter_stretch[i].time = 12
    chitter_stretch[i].clock = nil
    chitter_stretch[i].fade_time = 6
    chitter_stretch[i].pos = track[i].poll_position
  end
end

function chitter.init_params()
  chitter.init()
  params:add_group("flight",16)
  local bank_names = {"[1]","[2]","[3]","[4]"}
  for i = 1,4 do
    params:add_option("chittering_mode_"..i,"flight mode "..bank_names[i],{"off","woodcock","dove","starling"},1)
    params:set_action("chittering_mode_"..i,function(x)
      if x == 1 then
        if chitter_stretch[i].clock ~= nil then
          clock.cancel(chitter_stretch[i].clock)
          chitter_stretch[i].enabled = false
          chitter_stretch[i].clock = nil
          softcut.fade_time(i,0.01)
          track[i].chitter_stretch = false
        end
        params:hide("chittering_step_"..i)
        params:hide("chittering_duration_"..i)
        params:hide("chittering_fade_"..i)
        _menu.rebuild_params()
      elseif x > 1 then
        if chitter_stretch[i].clock == nil then
          chitter_stretch[i].clock = clock.run(chitter.stretch,i)
          chitter_stretch[i].enabled = true
          track[i].chitter_stretch = true
        end
        params:show("chittering_step_"..i)
        params:show("chittering_duration_"..i)
        params:show("chittering_fade_"..i)
        _menu.rebuild_params()
      end
      if x == 2 then
        chitter_stretch[i].pos = track[i].poll_position
        local p_t =
        {
          {"chittering_step_",100},
          {"chittering_fade_",6}
        }
        for j = 1,#p_t do
          params:set(p_t[j][1]..i,p_t[j][2])
          local id = params.lookup[p_t[j][1]..i]
          if all_loaded then
            params.params[id]:bang()
          end
        end
      elseif x == 3 then
        chitter_stretch[i].pos = track[i].poll_position
        local p_t =
        {
          {"chittering_step_",100},
          {"chittering_duration_",8},
          {"chittering_fade_",30}
        }
        for j = 1,#p_t do
          params:set(p_t[j][1]..i,p_t[j][2])
          local id = params.lookup[p_t[j][1]..i]
          if all_loaded then
            params.params[id]:bang()
          end
        end
        -- chitter.scale_sample_to_main(i)
      elseif x == 4 then
        chitter_stretch[i].pos = track[i].poll_position
        local p_t =
        {
          {"chittering_step_",math.random(3,60)},
          {"chittering_duration_",math.random(6,105)},
          {"chittering_fade_",math.random(40,300)}
        }
        for j = 1,#p_t do
          params:set(p_t[j][1]..i,p_t[j][2])
          local id = params.lookup[p_t[j][1]..i]
          if all_loaded then
            params.params[id]:bang()
          end
        end
      end
    end)

    params:add_number("chittering_step_"..i,"    step time",1,300,12, function(param) return ("1/"..param:get()) end)
    params:set_action("chittering_step_"..i, function(x)
      chitter_stretch[i].inc = x
    end)
    params:add_number("chittering_duration_"..i,"    duration",1,300,12, function(param) return ("1/"..param:get()) end)
    params:set_action("chittering_duration_"..i, function(x)
      chitter_stretch[i].time = x
    end)
    params:add_number("chittering_fade_"..i,"    fade",0,300,1, function(param) return ((param:get()/100).."s") end)
    params:set_action("chittering_fade_"..i, function(x)
      chitter_stretch[i].fade_time = x
      softcut.fade_time(i,x/100)
    end)
  end
end

function chitter.stretch(i)
  while true do
    clock.sleep((1/chitter_stretch[i].time)*clock.get_beat_sec())
    -- clock.sync(1/chitter_stretch[i].time)
    if chitter_stretch[i].enabled and not clear[i] then
      softcut.position(i, chitter_stretch[i].pos)
      if chitter_stretch[i].pos + ((1/chitter_stretch[i].inc)*clock.get_beat_sec()) > (track[i].end_point - (chitter_stretch[i].fade_time/100))then
        chitter_stretch[i].pos = track[i].start_point - ((1/chitter_stretch[i].inc)*clock.get_beat_sec())
      end
      if params:get("chittering_mode_"..i) == 4 then
        local next_pos = math.random(0,1)
        next_pos = next_pos == 0 and -1 or 1
        chitter_stretch[i].pos = util.clamp(
          chitter_stretch[i].pos + ((next_pos/chitter_stretch[i].inc)*clock.get_beat_sec()),
          track[i].start_point,
          track[i].end_point)
        chitter.pgh_set("chittering_fade_",i)
        chitter.pgh_set("chittering_step_",i)
        chitter.pgh_set("chittering_duration_",i)
      else
        chitter_stretch[i].pos = chitter_stretch[i].pos + ((1/chitter_stretch[i].inc)*clock.get_beat_sec())
      end
    end
  end
end

function wrap(n, min, max)
  if max >= min then
    local y = n
    local d = max - min + 1
    while y > max do
      y = y - d
    end
    while y < min do
      y = y + d
    end
    return y
  else
    error("max needs to be greater than min")
  end
end

function chitter.pgh_set(param,i)
  local bounds =
  {
    ["chittering_fade_"] = {["min"]=1,["max"]=200},
    ["chittering_step_"] = {["min"]=3,["max"]=60},
    ["chittering_duration_"] = {["min"]=3,["max"]=105}
  }
  local current = params:get(param..i)
  local next_move = math.random(0,1)
  next_move = next_move == 0 and -1 or 1
  local next_step = wrap(current+next_move,bounds[param].min,bounds[param].max)
  params:set(param..i,next_step)
end

function chitter.toggle(i) -- this shouldn't call/cancel clock, it should gate it...
  if chitter_stretch[i].clock ~= nil then
    clock.cancel(chitter_stretch[i].clock)
    chitter_stretch[i].enabled = false
    for j = 1,16 do
      track[i].chitter_stretch = false
    end
    chitter_stretch[i].clock = nil
    softcut.fade_time(i,0.01)
  else
    softcut.fade_time(i,chitter_stretch[i].fade_time/100)
    chitter_stretch[i].pos = bank[i][bank[i].id].start_point
    chitter_stretch[i].clock = clock.run(chitter.stretch,i)
    chitter_stretch[i].enabled = true
    track[i].chitter_stretch = true
  end
end

function chitter.change(i,param,d)
  chitter_stretch[i][param] = util.clamp(chitter_stretch[i][param]+d,1,100)
  if param == "fade_time" then
    softcut.fade_time(i,util.clamp(chitter_stretch[i][param]+d/100,0.01,32))
  end
end

function chitter.derive_bpm(source)
  local dur = 0
  local pattern_id;
  if source.original_length ~= nil then
    dur = source.original_length
  end
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
    return util.round(derived_bpm,0.01)
  end
end

function chitter.scale_sample_to_main(i)
  -- print("stretching to time...")
  local sample_tempo = chitter.derive_bpm(clip[bank[i][bank[i].id].clip])
  local proj_tempo = clock.get_tempo()
  if sample_tempo ~= nil and proj_tempo ~= nil then
    local scale = util.round(sample_tempo/proj_tempo * 100,0.01)
    if clip[bank[i][bank[i].id].clip].sample_rate == 41000 then
      scale = scale / ((scale * (48000/41000))/100)
    end
    params:set("chittering_duration_"..i, 100)
    params:set("chittering_step_"..i, scale)
    -- chitter_stretch[i].time = 100
    -- chitter_stretch[i].inc = scale
    chitter_stretch[i].fade_time = params:get("chittering_fade_"..i)
    softcut.fade_time(i,chitter_stretch[i].fade_time/100)
  end
end

function chitter.cheat(i)
  local pad = bank[i][bank[i].id]
  if not chitter_stretch[i].enabled then
    softcut.fade_time(i,0.01)
    if pad.rate > 0 then
      -- softcut.position(b+1,pad.start_point+0.05)
      softcut.position(i,pad.start_point+0.01)
    elseif pad.rate < 0 then
        -- softcut.position(b+1,pad.end_point-0.01-0.05)
      softcut.position(i,pad.end_point-0.01-0.01)
    end
  else
    if pad.rate > 0 then
      chitter_stretch[i].pos = wrap(pad.start_point+chitter_stretch[i].fade_time,pad.start_point,pad.end_point)
    elseif pad.rate < 0 then
      chitter_stretch[i].pos = wrap(pad.end_point-chitter_stretch[i].fade_time-0.01,pad.start_point,pad.end_point)
    end
  end
end

return chitter