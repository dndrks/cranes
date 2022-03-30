local lfos = {}

lfos.NUM_LFOS = 8
lfos.LFO_MIN_TIME = 1 -- Secs
lfos.LFO_MAX_TIME = 60 * 60 * 24
lfos.LFO_UPDATE_FREQ = 128
lfos.LFO_RESOLUTION = 128 -- MIDI CC resolution
lfos.lfo_freqs = {}
lfos.lfo_progress = {}
lfos.lfo_values = {}

local lfo_rates = {1/16,1/8,1/4,5/16,1/3,3/8,1/2,3/4,1,1.5,2,3,4,6,8,16,32,64,128,256,512,1024}
local scaled_output = {["vol_"] = {0,1,0.5}, ["pan_"] = {-1,1,0}}

-- lfos 1-4: vol_
-- lfos 5-8: pan_

function lfos.add_params(style)
  local ivals = {["vol_"] = {1,4}, ["pan_"] = {5,8}}
  if style == "pan_" then
    params:add_group("panning",36)
  elseif style == "vol_" then
    params:add_group("output level lfos",28)
  end
  for i = ivals[style][1],ivals[style][2] do
    local _di = util.wrap(i,1,4)
    if style == "pan_" then
      local pan_defaults = {-1,1,0,0}
      params:add_separator("voice ".._di)
      params:add_control("pan_".._di,"pan",controlspec.new(-1,1,'lin',0.01,pan_defaults[_di],''))
      params:set_action("pan_".._di, function(x) softcut.pan(_di, x) end)
      params:add_control("pan_slew_".._di,"slew", controlspec.new(0, 20, "lin", 0.01, 1, ""))
      params:set_action("pan_slew_".._di, function(x) softcut.pan_slew_time(_di, x) end)
    elseif style == "vol_" then
      params:add_separator("voice ".._di)
    end
    params:add_option("lfo_"..style..i,"lfo",{"off","on"},1)
    params:set_action("lfo_"..style..i,function(x)
      lfos.sync_lfos(i,style)
    end)
    params:add_option("lfo_mode_"..style..i, "lfo mode", {"beats","free"},1)
    params:set_action("lfo_mode_"..style..i,
      function(x)
        if x == 1 then
          params:hide("lfo_free_"..style..i)
          params:show("lfo_beats_"..style..i)
          lfos.lfo_freqs[i] = 1/(lfos.get_the_beats() * lfo_rates[params:get("lfo_beats_"..style..i)] * 4)
        elseif x == 2 then
          params:hide("lfo_beats_"..style..i)
          params:show("lfo_free_"..style..i)
          lfos.lfo_freqs[i] = params:get("lfo_free_"..style..i)
        end
        _menu.rebuild_params()
      end
      )
    params:add_option("lfo_beats_"..style..i, "lfo rate", {"1/16","1/8","1/4","5/16","1/3","3/8","1/2","3/4","1","1.5","2","3","4","6","8","16","32","64","128","256","512","1024"},9)
    params:set_action("lfo_beats_"..style..i,
      function(x)
        if params:string("lfo_mode_"..style..i) == "beats" then
          lfos.lfo_freqs[i] = 1/(lfos.get_the_beats() * lfo_rates[x] * 4)
        end
      end
    )
    params:add{
      type='control',
      id="lfo_free_"..style..i,
      name="lfo rate",
      controlspec=controlspec.new(0.001,4,'exp',0.001,0.05,'hz',0.001)
    }
    params:set_action("lfo_free_"..style..i,
      function(x)
        if params:string("lfo_mode_"..style..i) == "free" then
          lfos.lfo_freqs[i] = x
        end
      end
    )
    params:add_option("lfo_shape_"..style..i, "lfo shape", {"sine","square","random"},1)
    params:add_trigger("lfo_reset_"..style..i, "reset lfo")
    params:set_action("lfo_reset_"..style..i, function(x) lfos.reset_phase(i) end)
    params:hide("lfo_free_"..style..i)
    if style == "vol_" then
      vol_lfos_loaded = true
    elseif style == "pan_" then
      pan_lfos_loaded = true
    end
  end
  lfos.reset_phase()
  lfos.update_freqs()
  lfos.lfo_update()
  metro.init(lfos.lfo_update, 1 / lfos.LFO_UPDATE_FREQ):start()
end

function lfos.update_freqs()
  for i = 1, lfos.NUM_LFOS do
    lfos.lfo_freqs[i] = 1 / util.linexp(1, lfos.NUM_LFOS, 1, 1, i)
  end
end

function lfos.reset_phase(which)
  if which == nil then
    for i = 1, lfos.NUM_LFOS do
      lfos.lfo_progress[i] = math.pi * 1.5
    end
  else
    lfos.lfo_progress[which] = math.pi * 1.5
  end
end

function lfos.get_the_beats()
  return 60 / params:get("clock_tempo")
end

function lfos.sync_lfos(i,style)
  if params:get("lfo_mode_"..style..i) == 1 then
    lfos.lfo_freqs[i] = 1/(lfos.get_the_beats() * lfo_rates[params:get("lfo_beats_"..style..i)] * 4)
  else
    lfos.lfo_freqs[i] = params:get("lfo_free_"..style..i)
  end
end

function lfos.lfo_update() -- 'pan_' or 'vol_'
  if pan_lfos_loaded then
    lfos.small("pan_")
  end
  if vol_lfos_loaded then
    lfos.small("vol_")
  end
  
end

function lfos.small(style)
  local delta = (1 / lfos.LFO_UPDATE_FREQ) * 2 * math.pi
  local ivals = {["vol_"] = {1,4}, ["pan_"] = {5,8}}
  for i = ivals[style][1],ivals[style][2] do
    local _t = util.round(util.linlin(ivals[style][1],ivals[style][2],1,4,i))
    lfos.lfo_progress[i] = lfos.lfo_progress[i] + delta * lfos.lfo_freqs[i]
    local value = util.linlin(-1,1,scaled_output[style][1],scaled_output[style][2],math.sin(lfos.lfo_progress[i]))
    if value ~= lfos.lfo_values[i] then
      lfos.lfo_values[i] = value
      if params:string("lfo_"..style..i) == "on" then
        if params:string("lfo_shape_"..style..i) == "sine" then
          params:set(style.._t, value)
        elseif params:string("lfo_shape_"..style..i) == "square" then
          params:set(style.._t, value >= scaled_output[style][3] and scaled_output[style][2] or scaled_output[style][1])
        elseif params:string("lfo_shape_"..style..i) == "random" then
          if value == scaled_output[style][1] or value == scaled_output[style][2] then
            params:set(style.._t, math.random(scaled_output[style][1]*100,scaled_output[style][2]*100)/100)
          end
        end
      end
    end
  end
end

return lfos