local frm = require 'formatters'

local lfos = {}

lfos.max_per_group = 8

local function new_lfo_table()
  return
  {
    available = lfos.max_per_group,
    parent_group = {},
    targets = {},
    actions = {},
    progress = {},
    freqs = {},
    values = {},
    rand_values = {},
    update = {},
    counter = nil,
    param_types = {},
  }
end

lfos.groups = {}
lfos.parent_strings = {}

lfos.rates = {1/16,1/8,1/4,5/16,1/3,3/8,1/2,3/4,1,1.5,2,3,4,6,8,16,32,64,128,256,512,1024}
lfos.rates_as_strings = {"1/16","1/8","1/4","5/16","1/3","3/8","1/2","3/4","1","1.5","2","3","4","6","8","16","32","64","128","256","512","1024"}

local update_freq = 128
local main_header_added = false
local clock_action_appended = false
local tempo_updater_clock;
local lfos_all_loaded = {}

local function lfo_params_visibility(state, group, i)
  if lfos_all_loaded[group] then
    params[state](params, "lfo position "..group.." "..i)
    params[state](params, "lfo depth "..group.." "..i)
    params[state](params, "lfo mode "..group.." "..i)
    if state == "show" then
      if params:get("lfo mode "..group.." "..i) == 1 then
        params:hide("lfo free "..group.." "..i)
        params:show("lfo bars "..group.." "..i)
      elseif params:get("lfo mode "..group.." "..i) == 2 then
        params:hide("lfo bars "..group.." "..i)
        params:show("lfo free "..group.." "..i)
      end
    else
      params:hide("lfo bars "..group.." "..i)
      params:hide("lfo free "..group.." "..i)
    end
    params[state](params, "lfo shape "..group.." "..i)
    params[state](params, "lfo min "..group.." "..i)
    params[state](params, "lfo max "..group.." "..i)
    params[state](params, "lfo reset "..group.." "..i)
    params[state](params, "lfo reset target "..group.." "..i)
    _menu.rebuild_params()
  end
end

local function return_param_to_baseline(group,i)
  -- when an LFO is turned off, the affected parameter will return to its pre-enabled value,
  --   if it was registered with 'param action'
  params:lookup_param(lfos.groups[group].targets[i]):bang()
end

local function get_lfo_spec(group,i,bound)
  local lfo_target = lfos.groups[group].targets[i]
  local param_spec = params:lookup_param(lfo_target)

  -- number:
  if param_spec.t == 1 then
    return {
      spec = controlspec.new(
        param_spec.min,
        param_spec.max,
        'lin',
        0,
        (bound == nil and param_spec.value or (bound == 'min' and param_spec.min or (bound == 'current' and params:get(lfo_target) or param_spec.max))),
        nil,
        (param_spec.t == 1 and 1/(param_spec.max - param_spec.min) or 1),
        param_spec.wrap
      ),
      formatter = function(param) return(
        (util.round(param:get(),1))
      ) end
    }
  -- option:
  elseif param_spec.t == 2 then
    return {
      spec = controlspec.new(
        1,
        param_spec.count,
        'lin',
        1,
        (bound == nil and param_spec.value or (bound == 'min' and 1 or (bound == 'current' and params:get(lfo_target) or param_spec.count))),
        nil,
        1/(param_spec.count-1)
      ),
      formatter = function(param) return(
        param_spec.options[param:get()]
      ) end
    }
  -- control:
  elseif param_spec.t == 3 then
    return {
      spec = controlspec.new(
        param_spec.controlspec.minval,
        param_spec.controlspec.maxval,
        param_spec.controlspec.warp,
        param_spec.controlspec.step,
        (bound == nil and param_spec.controlspec.default or (bound == 'min' and param_spec.controlspec.minval or (bound == 'current' and params:get(lfo_target) or param_spec.controlspec.maxval))),
        param_spec.controlspec.units,
        param_spec.controlspec.quantum,
        param_spec.controlspec.wrap
      ),
      formatter = param_spec.formatter
    }
  -- taper:
  elseif param_spec.t == 5 then
    return {
      spec = controlspec.new(
        (param_spec.t == 1 and param_spec.min or 1),
        (param_spec.t == 1 and param_spec.max or param_spec.count),
        'lin',
        0,
        (bound == nil and param_spec.value or (bound == 'min' and param_spec.min or (bound == 'current' and params:get(lfo_target) or param_spec.max))),
        nil,
        (param_spec.t == 1 and 1/(param_spec.max - param_spec.min) or 1),
        param_spec.wrap
      ),
      formatter = function(param)
        local v = param:get()
        local absv = math.abs(v)
      
        if absv >= 100 then
          format = "%.0f "..string.gsub(self.units, "%%", "%%%%")
        elseif absv >= 10 then
          format = "%.1f "..string.gsub(self.units, "%%", "%%%%")
        elseif absv >= 1 then
          format = "%.2f "..string.gsub(self.units, "%%", "%%%%")
        elseif absv >= 0.001 then
          format = "%.3f "..string.gsub(self.units, "%%", "%%%%")
        else
          format = "%.0f "..string.gsub(self.units, "%%", "%%%%")
        end
      
        return string.format(format, v)
      end
    }
  -- binary:
  elseif param_spec.t == 9 then
    return {
      spec = controlspec.new(
        0,
        1,
        'lin',
        1,
        (bound == nil and param_spec.value or (bound == 'min' and 0 or (bound == 'current' and params:get(lfo_target) or 1))),
        nil,
        1,
        nil
      ),
      formatter = function(param) return(
        param:get() == 1 and "on" or "off")
      end
    }
  end
end

local function update_lfo_freqs(group)
  for i = 1,#lfos.groups[group].targets do
    lfos.groups[group].freqs[i] = 1 / util.linexp(1, #lfos.groups[group].targets, 1, 1, i)
  end
end

local function reset_lfo_phase(group,which)
  if which == nil then
    for i = 1, #lfos.groups[group].targets do
      lfos.groups[group].progress[i] = math.pi * (params:string("lfo reset target "..group.." "..i) == "floor" and 1.5 or 2.5)
    end
  else
    lfos.groups[group].progress[which] = math.pi * (params:string("lfo reset target "..group.." "..which) == "floor" and 1.5 or 2.5)
  end
end

local function get_beat_time()
  return 60 / params:get("clock_tempo")
end

local function sync_lfos(group, i)
  if params:get("lfo mode "..group.." "..i) == 1 then
    lfos.groups[group].freqs[i] = 1/(get_beat_time() * lfos.rates[params:get("lfo bars "..group.." "..i)] * 4)
  else
    lfos.groups[group].freqs[i] = params:get("lfo free "..group.." "..i)
  end
end

local function process_lfo(group)
  local delta = (1 / update_freq) * 2 * math.pi
  local lfo_parent = lfos.groups[group]
  if lfos_all_loaded[group] then
    for i = 1,#lfo_parent.targets do
      
      local _t = i
      lfo_parent.progress[i] = lfo_parent.progress[i] + delta * lfo_parent.freqs[i]
      local min = params:get("lfo min "..group.." "..i)
      local max = params:get("lfo max "..group.." "..i)
      if min > max then
        local old_min = min
        local old_max = max
        min = old_max
        max = old_min
      end

      local mid = (min+max)/2
      local percentage = math.abs(min-max) * (params:get("lfo depth "..group.." "..i)/100)

      local scaled_min = min
      local scaled_max = min + percentage
      local value = util.linlin(-1,1,scaled_min,scaled_max,math.sin(lfo_parent.progress[i]))
      mid = util.linlin(min,max,scaled_min,scaled_max,mid)

      if value ~= lfo_parent.values[i] and (params:get("lfo depth "..group.." "..i)/100 > 0) then
        lfo_parent.values[i] = value
        if params:string("lfo "..group.." "..i) == "on" then

          if params:string("lfo position "..group.." "..i) == 'from center' then
            mid = (min+max)/2
            local centroid_mid = math.abs(min-max) * ((params:get("lfo depth "..group.." "..i)/100)/2)
            scaled_min = mid - centroid_mid
            scaled_max = mid + centroid_mid
            value = util.linlin(-1,1,scaled_min, scaled_max, math.sin(lfo_parent.progress[i]))
          elseif params:string("lfo position "..group.." "..i) == 'from max' then
            mid = (min+max)/2
            value = max - value
            scaled_min = max - (math.abs(min-max) * (params:get("lfo depth "..group.." "..i)/100))
            scaled_max = max
            mid = math.abs(util.linlin(min,max,scaled_min,scaled_max,mid))
            value = util.linlin(-1,1,scaled_min, scaled_max, math.sin(lfo_parent.progress[i]))
          elseif params:string("lfo position "..group.." "..i) == 'from current' then
            mid = params:get(lfo_parent.targets[i])
            local centroid_mid = math.abs(min-max) * ((params:get("lfo depth "..group.." "..i)/100)/2)
            scaled_min = mid - centroid_mid
            scaled_max = mid + centroid_mid
            value = util.linlin(-1,1,scaled_min, scaled_max, math.sin(lfo_parent.progress[i]))
          end

          if params:string("lfo shape "..group.." "..i) == "sine" then
            if lfo_parent.param_types[i] == 1 or lfo_parent.param_types[i] == 2 or lfo_parent.param_types[i] == 9 then
              value = util.round(value,1)
            end
            value = util.clamp(value,min,max)
            lfo_parent.actions[lfo_parent.targets[i]](value)
          elseif params:string("lfo shape "..group.." "..i) == "square" then
            local square_value;
            square_value = value >= mid and max or min
            square_value = util.linlin(min,max,scaled_min,scaled_max,square_value)
            square_value = util.clamp(square_value,min,max)
            lfo_parent.actions[lfo_parent.targets[i]](square_value)
          elseif params:string("lfo shape "..group.." "..i) == "random" then
            local prev_value = lfo_parent.rand_values[i]
            lfo_parent.rand_values[i] = value >= mid and max or min
            local rand_value;
            if prev_value ~= lfo_parent.rand_values[i] then
              rand_value = util.linlin(min,max,scaled_min,scaled_max,math.random(math.floor(min*100),math.floor(max*100))/100)
              if lfo_parent.param_types[i] == 1 or lfo_parent.param_types[i] == 2 or lfo_parent.param_types[i] == 9 then
                rand_value = util.round(rand_value,1)
              end
              rand_value = util.clamp(rand_value,min,max)
              lfo_parent.actions[lfo_parent.targets[i]](rand_value)
            end
          end

        end
      end
    end
  end
end

function lfos:register(param, parent_group, fn)

  if self.groups[parent_group] == nil then
    lfos.groups[parent_group] = new_lfo_table()
    table.insert(lfos.parent_strings, parent_group)
  end
  if #self.groups[parent_group].targets < self.max_per_group then
    table.insert(self.groups[parent_group].targets, param)
    self.groups[parent_group].available = self.groups[parent_group].available - 1
  else
    print("LFO ERROR: limit of "..lfos.max_per_group.." entries per LFO group, ignoring "..parent_group.." / "..param)
    goto done
  end

  if not fn or fn == 'map param' then
    fn = function(val) params:set(param, val) end
  elseif fn == 'param action' then
    fn = function(val) params:lookup_param(param).action(val) end
  end

  self.groups[parent_group].actions[param] = fn

  ::done::

end

function lfos:set_action(param, parent_group, fn)
  self.groups[parent_group].actions[param] = fn
end

function lfos:add_params(parent_group, separator_name, silent)

  if not main_header_added and separator_name ~= nil then
    params:add_separator(separator_name)
    main_header_added = true
  end

  local group = parent_group
  params:add_group(group, 12 * #self.groups[group].targets)

  for i = 1,#self.groups[group].targets do

    self.groups[group].param_types[i] = params:lookup_param(self.groups[group].targets[i]).t

    params:add_separator(params:lookup_param(self.groups[group].targets[i]).name)

    params:add_option("lfo "..group.." "..i,"lfo",{"off","on"},1)
    params:set_action("lfo "..group.." "..i,function(x)
      sync_lfos(group, i)
      if x == 1 then
        return_param_to_baseline(group, i)
        lfo_params_visibility("hide", group, i)
      elseif x == 2 then
        lfo_params_visibility("show", group, i)
      end
    end)
    params:add_number("lfo depth "..group.." "..i,"depth",0,100,0,function(param) return (param:get().."%") end)
    params:set_action("lfo depth "..group.." "..i, function(x)
      if x == 0 then
        return_param_to_baseline(group, i)
      end
    end)

    params:add{
      type='control',
      id="lfo min "..group.." "..i,
      name="lfo min",
      controlspec = get_lfo_spec(group,i,"min").spec,
      formatter =  get_lfo_spec(group,i).formatter
    }

    params:add{
      type='control',
      id="lfo max "..group.." "..i,
      name="lfo max",
      controlspec = get_lfo_spec(group,i,"max").spec,
      formatter = get_lfo_spec(group,i).formatter
    }

    params:add_option("lfo position "..group.." "..i, "lfo position", {"from min", "from center", "from max", "from current"},1)

    params:add_option("lfo mode "..group.." "..i, "lfo mode", {"bars","free"},1)
    params:set_action("lfo mode "..group.." "..i,
      function(x)
        if x == 1 and params:string("lfo "..group.." "..i) == "on" then
          params:hide("lfo free "..group.." "..i)
          params:show("lfo bars "..group.." "..i)
          self.groups[group].freqs[i] = 1/(get_beat_time() * self.rates[params:get("lfo bars "..group.." "..i)] * 4)
        elseif x == 2 and params:string("lfo "..group.." "..i) == "on" then
          params:hide("lfo bars "..group.." "..i)
          params:show("lfo free "..group.." "..i)
          self.groups[group].freqs[i] = params:get("lfo free "..group.." "..i)
        end
        _menu.rebuild_params()
      end
      )
    params:add_option("lfo bars "..group.." "..i, "lfo rate", self.rates_as_strings, 9)
    params:set_action("lfo bars "..group.." "..i,
      function(x)
        if params:string("lfo mode "..group.." "..i) == "bars" then
          self.groups[group].freqs[i] = 1/(get_beat_time() * self.rates[x] * 4)
        end
      end
    )
    params:add{
      type='control',
      id="lfo free "..group.." "..i,
      name="lfo rate",
      controlspec=controlspec.new(0.001,4,'exp',0.001,0.05,'hz',0.001)
    }
    params:set_action("lfo free "..group.." "..i,
      function(x)
        if params:string("lfo mode "..group.." "..i) == "free" then
          self.groups[group].freqs[i] = x
        end
      end
    )
    params:add_option("lfo shape "..group.." "..i, "lfo shape", {"sine","square","random"},1)
    params:add_trigger("lfo reset "..group.." "..i, "reset lfo")
    params:set_action("lfo reset "..group.." "..i, function(x) reset_lfo_phase(group,i) end)
    params:add_option("lfo reset target "..group.." "..i, "reset lfo to", {"floor","ceiling"}, 1)
    params:hide("lfo free "..group.." "..i)
  end

  lfos_all_loaded[group] = true
  
  if not silent then
    params:bang()
  end

  self.groups[group].update = function()
    process_lfo(group)
  end

  self.groups[group].counter = metro.init(self.groups[group].update, 1 / update_freq)
  self.groups[group].counter:start()

  reset_lfo_phase(group)
  update_lfo_freqs(group)

  if not clock_action_appended then
    local system_tempo_change_handler = params:lookup_param("clock_tempo").action

    local lfo_change_handler = function(bpm)
      system_tempo_change_handler(bpm)
      if tempo_updater_clock then
        clock.cancel(tempo_updater_clock)
      end
      tempo_updater_clock = clock.run(
        function()
          clock.sleep(0.05)
          for k,v in pairs(self.groups) do
            for i = 1,#lfos.groups[k].freqs do
              sync_lfos(k, i)
            end
          end
        end
      )
    end

    params:set_action("clock_tempo", lfo_change_handler)
    -- since clock params get rebuilt as part of a script clear,
    --  it seems okay to append without re-establishing:
    --  https://github.com/monome/norns/blob/main/lua/core/script.lua#L100

    clock_action_appended = true

  end

end

return lfos