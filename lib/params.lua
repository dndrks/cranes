local _params = {}

function _params.init()

  params:add_separator("cranes")
  params:add_group("clips",2)
  
  for i = 1,TRACKS do
    params:add_file("clip "..i.." sample", "sample ["..i.."]")
    params:set_action("clip "..i.." sample", function(file) _ca.load_sample(file,i) end)
  end

  params:add_group("rates",3)
  
  for i = 1,TRACKS do
    params:add_option("speed_voice_"..i,"speed voice "..i, speedlist[1])
    params:set("speed_voice_"..i, 9)
    params:set_action("speed_voice_"..i,
      function(x)
        softcut.rate(i, speedlist[i][params:get("speed_voice_"..i)]*offset)
        grid_dirty = true
      end
    )
  end

  params:add_number("offset", "global offset", -24,24,0, function(param) return (param:get().." st") end)
  params:set_action("offset",
    function(value)
      offset = math.pow(0.5, -value / 12)
      softcut.rate(1,speedlist[1][params:get("speed_voice_1")]*offset)
      softcut.rate(2,speedlist[2][params:get("speed_voice_2")]*offset)
    end
  )
  params:add_group("levels",8)
  --
  params:add_separator("in")
  for i = 1,TRACKS do
    params:add_control("lvl_in_L_"..i, "lvl in L voice " .. i, controlspec.new(0,1,'lin',0,1,''))
    params:set_action("lvl_in_L_"..i, function(x) softcut.level_input_cut(1, i, x) end)
  end
  params:set("lvl_in_L_"..2, 0.0)
  for i = 1,TRACKS do
    params:add_control("lvl_in_R_"..i, "lvl in R voice " .. i, controlspec.new(0,1,'lin',0,1,''))
    params:set_action("lvl_in_R_"..i, function(x) softcut.level_input_cut(2, i, x) end)
  end
  params:set("lvl_in_R_"..1, 0.0)

  params:add_separator("out")
  for i = 1,TRACKS do
    params:add_control("vol_"..i,"lvl out voice "..i,controlspec.new(0,5,'lin',0,1,''))
    params:set_action("vol_"..i, function(x) softcut.level(i, x) end)
    -- params:set("vol_"..i, 1.0)
  end
  params:add_group("panning",6)
  --
  for i = 1,TRACKS do
    params:add_separator("voice "..i)
    params:add_control("pan_"..i,"pan",controlspec.new(-1,1,'lin',0.01,0,''))
    params:set_action("pan_"..i, function(x) softcut.pan(i, x) end)
    params:add_control("pan_slew_"..i,"slew", controlspec.new(0, 200, "lin", 0.01, 10, ""))
    params:set_action("pan_slew_"..i, function(x) softcut.pan_slew_time(i, x) end)
  end

  params:add_group("filters",14)
  --
  -- local p = softcut.params() -- TODO VERIFY IF I NEED THIS?
  for i = 1,TRACKS do
    params:add_separator("voice "..i)
    params:add_control("post_filter_fc_"..i,"filter cutoff",controlspec.new(0,12000,'lin',0.01,12000,''))
    params:set_action("post_filter_fc_"..i, function(x) softcut.post_filter_fc(i,x) end)
    params:add_control("post_filter_lp_"..i,"lopass",controlspec.new(0,1,'lin',0,0,''))
    params:set_action("post_filter_lp_"..i, function(x) softcut.post_filter_lp(i,x) end)
    params:add_control("post_filter_hp_"..i,"hipass",controlspec.new(0,1,'lin',0.01,0,''))
    params:set_action("post_filter_hp_"..i, function(x) softcut.post_filter_hp(i,x) end)
    params:add_control("post_filter_bp_"..i,"bandpass",controlspec.new(0,1,'lin',0.01,0,''))
    params:set_action("post_filter_bp_"..i, function(x) softcut.post_filter_bp(i,x) end)
    params:add_control("post_filter_dry_"..i,"dry",controlspec.new(0,1,'lin',0.01,1,''))
    params:set_action("post_filter_dry_"..i, function(x) softcut.post_filter_dry(i,x) end)
    params:add_control("post_filter_rq_"..i,"resonance (0 = high)",controlspec.new(0,2,'lin',0.01,2,''))
    params:set_action("post_filter_rq_"..i, function(x) softcut.post_filter_rq(i,x) end)
  end

  chitter.init_params()

  params:add_group("misc",2)
  params:add_option("KEY3","KEY3", {"~~", "0.5", "-1", "1.5", "2"}, 1)
  params:set_action("KEY3", function(x) KEY3 = x end)
  params:add_number("voice_2_buffer","voice 2 buffer reference",1,2,2)
  params:set_action("voice_2_buffer", function(x) softcut.buffer(2,x) end)

  params:bang()

  params.action_write = function(filename,name)
    os.execute("mkdir -p "..AUDIO_DIR)
    softcut.buffer_write_mono(AUDIO_DIR..name.."-clip_1.wav",0,track[1].rec_limit,1)
    softcut.buffer_write_mono(AUDIO_DIR..name.."-clip_2.wav",0,track[2].rec_limit,2)
  end

  params.action_read = function(filename)

  end
end

return _params