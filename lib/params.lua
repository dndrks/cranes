local _params = {}

function _params.init()
  for i = 1,2 do
    params:add_option("speed_voice_"..i,"speed voice "..i, speedlist[1])
    params:set("speed_voice_"..i, 9)
    params:set_action("speed_voice_"..i,
      function(x)
        softcut.rate(i, speedlist[i][params:get("speed_voice_"..i)]*offset)
        -- params:set("speed_midi_"..i, params:get("speed_voice_"..i))
        grid_dirty = true
      end
    )
  end

  -- params:add_separator()
  --
  -- for i = 1,2 do
  --   params:add_control("speed_midi_"..i,"midi ctrl speed voice "..i, controlspec.new(1,12,'exp',1,12,''))
  --   params:set_action("speed_midi_"..i, function(x) params:set("speed_voice_"..i, x) end)
  --   params:set("speed_midi_"..i, 9)
  -- end

  params:add_separator()
  --
  params:add_control("offset", "global offset", controlspec.new(-24, 24, 'lin', 1, 0, "st"))
  params:set_action("offset",
    function(value)
      offset = math.pow(0.5, -value / 12)
      softcut.rate(1,speedlist[1][params:get("speed_voice_1")]*offset)
      softcut.rate(2,speedlist[2][params:get("speed_voice_2")]*offset)
    end
  )
  params:add_separator()
  --
  for i = 1,2 do
    params:add_control("lvl_in_L_"..i, "lvl in L voice " .. i, controlspec.new(0,1,'lin',0,1,''))
    params:set_action("lvl_in_L_"..i, function(x) softcut.level_input_cut(1, i, x) end)
  end
  params:set("lvl_in_L_"..2, 0.0)
  for i = 1,2 do
    params:add_control("lvl_in_R_"..i, "lvl in R voice " .. i, controlspec.new(0,1,'lin',0,1,''))
    params:set_action("lvl_in_R_"..i, function(x) softcut.level_input_cut(2, i, x) end)
  end
  params:set("lvl_in_R_"..1, 0.0)
  params:add_separator()
  --
  for i = 1,2 do
    params:add_control("vol_"..i,"lvl out voice "..i,controlspec.new(0,5,'lin',0,5,''))
    params:set_action("vol_"..i, function(x) softcut.level(i, x) end)
    params:set("vol_"..i, 1.0)
  end
  params:add_separator()
  --
  for i = 1,2 do
    params:add_control("pan_"..i,"pan voice "..i,controlspec.new(-1,1,'lin',0.01,-1,''))
    params:set_action("pan_"..i, function(x) softcut.pan(i, x) end)
    params:add_control("pan_slew_"..i,"pan slew "..i, controlspec.new(0, 200, "lin", 0.01, 50, ""))
    params:set_action("pan_slew_"..i, function(x) softcut.pan_slew_time(i, x) end)
  end

  params:add_separator()
  --
  -- local p = softcut.params() -- TODO VERIFY IF I NEED THIS?
  for i = 1,2 do
    params:add_control("post_filter_fc_"..i,i.." filter cutoff",controlspec.new(0,12000,'lin',0.01,12000,''))
    params:set_action("post_filter_fc_"..i, function(x) softcut.post_filter_fc(i,x) end)
    params:add_control("post_filter_lp_"..i,i.." lopass",controlspec.new(0,1,'lin',0,1,''))
    params:set_action("post_filter_lp_"..i, function(x) softcut.post_filter_lp(i,x) end)
    params:add_control("post_filter_hp_"..i,i.." hipass",controlspec.new(0,1,'lin',0.01,0,''))
    params:set_action("post_filter_hp_"..i, function(x) softcut.post_filter_hp(i,x) end)
    params:add_control("post_filter_bp_"..i,i.." bandpass",controlspec.new(0,1,'lin',0.01,0,''))
    params:set_action("post_filter_bp_"..i, function(x) softcut.post_filter_bp(i,x) end)
    params:add_control("post_filter_dry_"..i,i.." dry",controlspec.new(0,1,'lin',0.01,0,''))
    params:set_action("post_filter_dry_"..i, function(x) softcut.post_filter_dry(i,x) end)
    params:add_control("post_filter_rq_"..i,i.." resonance (0 = high)",controlspec.new(0,2,'lin',0.01,2,''))
    params:set_action("post_filter_rq_"..i, function(x) softcut.post_filter_rq(i,x) end)
  end
  params:add_separator()
  params:add_option("KEY3","KEY3", {"~~", "0.5", "-1", "1.5", "2"}, 1)
  params:set_action("KEY3", function(x) KEY3 = x end)
  params:add_control("voice_2_buffer","voice 2 buffer reference",controlspec.new(1,2,'lin',1,0,''))
  params:set_action("voice_2_buffer", function(x) softcut.buffer(2,x) end)
  params:set("voice_2_buffer",2)

  params:bang()
end

return _params