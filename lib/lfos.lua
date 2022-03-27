local lfos = {}

lfos.NUM_LFOS = 11
lfos.LFO_MIN_TIME = 1 -- Secs
lfos.LFO_MAX_TIME = 60 * 60 * 24
lfos.LFO_UPDATE_FREQ = 128
lfos.LFO_RESOLUTION = 128 -- MIDI CC resolution
lfos.lfo_freqs = {}
lfos.lfo_progress = {}
lfos.lfo_values = {}

local lfo_rates = {1/4,5/16,1/3,3/8,1/2,3/4,1,1.5,2,3,4,6,8,16,32,64,128,256,512,1024}

function lfos.add_params()
  params:add_group("macros",8*8)
  for i = 1,8 do
    params:add_separator("~ macro "..i.." ~")
    params:add_number("macro "..i, "macro "..i.." current value", 0,127,0)
    params:set_action("macro "..i, function(x) if all_loaded then macro[i]:pass_value(x) end end)
    params:add_option("lfo_macro "..i,"macro "..i.." lfo",{"off","on"},1)
    params:set_action("lfo_macro "..i,function(x)
      Container.sync_lfos(i)
      Container.check_for_pans_lfo()
    end)
    params:add_option("lfo_mode_macro "..i, "lfo mode", {"beats","free"},1)
    params:set_action("lfo_mode_macro "..i,
      function(x)
        if x == 1 then
          params:hide("lfo_free_macro "..i)
          params:show("lfo_beats_macro "..i)
          Container.lfo_freqs[i] = 1/(get_the_beats() * lfo_rates[params:get("lfo_beats_macro "..i)] * 4)
        elseif x == 2 then
          params:hide("lfo_beats_macro "..i)
          params:show("lfo_free_macro "..i)
          Container.lfo_freqs[i] = params:get("lfo_free_macro "..i)
        end
        _menu.rebuild_params()
      end
      )
    params:add_option("lfo_beats_macro "..i, "lfo rate", {"1/4","5/16","1/3","3/8","1/2","3/4","1","1.5","2","3","4","6","8","16","32","64","128","256","512","1024"},7)
    params:set_action("lfo_beats_macro "..i,
      function(x)
        if params:string("lfo_mode_macro "..i) == "beats" then
          Container.lfo_freqs[i] = 1/(get_the_beats() * lfo_rates[x] * 4)
        end
      end
    )
    params:add {
      type='control',
      id="lfo_free_macro "..i,
      name="lfo rate",
      controlspec=controlspec.new(0.001,4,'exp',0.001,0.05,'hz',0.001)
    }
    params:set_action("lfo_free_macro "..i,
      function(x)
        if params:string("lfo_mode_macro "..i) == "free" then
          Container.lfo_freqs[i] = x
        end
      end
    )
    params:add_option("lfo_shape_macro "..i, "lfo shape", {"sine","square","random"},1)
    params:add_trigger("lfo_reset_macro "..i, "reset lfo")
    params:set_action("lfo_reset_macro "..i, function(x) Container.reset_phase(i) end)
    params:hide("lfo_free_macro "..i)
  end
  macros.reset_phase()
  macros.update_freqs()
  macros.lfo_update()
  metro.init(macros.lfo_update, 1 / macros.LFO_UPDATE_FREQ):start()
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

function lfos.sync_lfos(i)
  if params:get("lfo_mode_"..i) == 1 then
    lfos.lfo_freqs[i] = 1/(lfos.get_the_beats() * lfo_rates[params:get("lfo_beats_"..i)] * 4)
  else
    lfos.lfo_freqs[i] = params:get("lfo_free_"..i)
  end
end

function lfos.lfo_update()
  local delta = (1 / lfos.LFO_UPDATE_FREQ) * 2 * math.pi
  for i = 1, lfos.NUM_LFOS do
    lfos.lfo_progress[i] = lfos.lfo_progress[i] + delta * lfos.lfo_freqs[i]
    local value = util.round(util.linlin(-1, 1, 0, lfos.LFO_RESOLUTION - 1, math.sin(lfos.lfo_progress[i])))
    if value ~= lfos.lfo_values[i] then
      lfos.lfo_values[i] = value
      if params:string("lfo_"..i) == "on" then
        if params:string("lfo_shape_"..i) == "sine" then
          params:set("pan_"..i, value)
        elseif params:string("lfo_shape_"..i) == "square" then
          params:set("pan_"..i, value >= 63 and 127 or 0)
        elseif params:string("lfo_shape_"..i) == "random" then
          if value == 0 or value == 127 then
            params:set("pan_"..i, math.random(0,127))
          end
        end
      end
    end
  end
end

return lfos