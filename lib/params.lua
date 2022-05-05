local _params = {}

function _params.init()

  params:add_separator("cranes")
  params:add_group("clips",4)
  
  for i = 1,4 do
    params:add_file("clip "..i.." sample", "sample ["..i.."]", _path.audio)
    params:set_action("clip "..i.." sample", function(file) if file ~= _path.audio then _ca.load_sample(file,i) end end)
  end

  params:add_group("rates",12)

  params:add_separator("speed")
  for i = 1,4 do
    params:add_option("speed_voice_"..i,"speed voice "..i, speedlist[1])
    params:set("speed_voice_"..i, 9)
    params:set_action("speed_voice_"..i,
      function(x)
        -- softcut.rate(i, speedlist[i][params:get("speed_voice_"..i)]*offset[i])
        softcut.rate(i, get_total_pitch_offset(i))
        if x < 6 then
          if not track[i].reverse then track[i].reverse = true end
        elseif x > 6 then
          if track[i].reverse then track[i].reverse = false end
        end
        grid_dirty = true
      end
    )
  end
  
  params:add_separator("offset")
  
  for i = 1,4 do
    params:add_number("semitone_offset_"..i, "offset voice "..i, -24,24,0, function(param) return (param:get().." st") end)
    params:set_action("semitone_offset_"..i,
      function(value)
        offset[i] = math.pow(0.5, -value / 12)
        -- softcut.rate(i,speedlist[i][params:get("speed_voice_"..i)]*offset[i])
        softcut.rate(i, get_total_pitch_offset(i))
      end
    )
  end

  params:add_number("offset_all", "offset all voices", -24,24,0, function(param) return (param:get().." st") end)
  params:set_action("offset_all",
    function(value)
      for i = 1,4 do
        params:set("semitone_offset_"..i,value)
      end
    end
  )

  params:add_control("pitch_control","pitch control (global)",controlspec.new(-12,12,'lin',0,0,'%'))
  params:set_action("pitch_control",function(x)
    for i = 1,4 do
      softcut.rate(i,get_total_pitch_offset(i))
    end
  end)

  params:add_group("levels",23)
  --
  params:add_separator("in")
  for i = 1,4 do
    params:add_control("lvl_in_L_"..i, "lvl in L voice " .. i, controlspec.new(0,1,'lin',0,1,''))
    params:set_action("lvl_in_L_"..i, function(x) softcut.level_input_cut(1, i, x) end)
  end
  params:set("lvl_in_L_"..2, 0.0)
  for i = 1,4 do
    params:add_control("lvl_in_R_"..i, "lvl in R voice " .. i, controlspec.new(0,1,'lin',0,1,''))
    params:set_action("lvl_in_R_"..i, function(x) softcut.level_input_cut(2, i, x) end)
  end
  params:set("lvl_in_R_"..1, 0.0)

  params:add_separator("out")
  for i = 1,4 do
    params:add_control("vol_"..i,"lvl out voice "..i,controlspec.new(0,5,'lin',0,1,''))
    params:set_action("vol_"..i, function(x) softcut.level(i, x) end)
    -- params:set("vol_"..i, 1.0)
  end

  params:add_separator("cross")
  for i = 1,2 do
    params:add_control("cross_"..i.."_3","feed ["..i.."] into [3]",controlspec.new(0,5,'lin',0,0,''))
    params:set_action("cross_"..i.."_3", function(x)
      if params:get("cross_3_"..i) ~= 0 then
        params:set("cross_3_"..i,0)
      end
      softcut.level_cut_cut(i,3,x)
    end)
    params:add_control("cross_"..i.."_4","feed ["..i.."] into [4]",controlspec.new(0,5,'lin',0,0,''))
    params:set_action("cross_"..i.."_4", function(x)
      if params:get("cross_4_"..i) ~= 0 then
        params:set("cross_4_"..i,0)
      end
      softcut.level_cut_cut(i,4,x)
    end)
  end
  for i = 3,4 do
    params:add_control("cross_"..i.."_1","feed ["..i.."] into [1]",controlspec.new(0,5,'lin',0,0,''))
    params:set_action("cross_"..i.."_1", function(x)
      if params:get("cross_1_"..i) ~= 0 then
        params:set("cross_1_"..i,0)
      end
      softcut.level_cut_cut(i,1,x)
    end)
    params:add_control("cross_"..i.."_2","feed ["..i.."] into [2]",controlspec.new(0,5,'lin',0,0,''))
    params:set_action("cross_"..i.."_2", function(x)
      if params:get("cross_2_"..i) ~= 0 then
        params:set("cross_2_"..i,0)
      end
      softcut.level_cut_cut(i,2,x)
    end)
  end

  _lfos.add_params("vol_")

  params:add_group("panning",12)
  for i = 1,4 do
    local _di = util.wrap(i,1,4)
    local pan_defaults = {-1,1,0,0}
    params:add_separator("voice ".._di)
    params:add_control("pan_".._di,"pan",controlspec.new(-1,1,'lin',0.01,pan_defaults[_di],''))
    params:set_action("pan_".._di, function(x) softcut.pan(_di, x) end)
    params:add_control("pan_slew_".._di,"slew", controlspec.new(0, 20, "lin", 0.01, 1, ""))
    params:set_action("pan_slew_".._di, function(x) softcut.pan_slew_time(_di, x) end)
  end

  _lfos.add_params("pan_")

  params:add_group("filters",28)
  --
  -- local p = softcut.params() -- TODO VERIFY IF I NEED THIS?
  for i = 1,4 do
    params:add_separator("voice "..i)
    params:add_control("post_filter_fc_"..i,"filter cutoff",controlspec.new(20,12000,'exp',0.01,12000,''))
    params:set_action("post_filter_fc_"..i, function(x) softcut.post_filter_fc(i,x) end)
    params:add_control("post_filter_lp_"..i,"lopass",controlspec.new(0,1,'lin',0.01,0,''))
    params:set_action("post_filter_lp_"..i, function(x) softcut.post_filter_lp(i,x) end)
    params:add_control("post_filter_hp_"..i,"hipass",controlspec.new(0,1,'lin',0.01,0,''))
    params:set_action("post_filter_hp_"..i, function(x) softcut.post_filter_hp(i,x) end)
    params:add_control("post_filter_bp_"..i,"bandpass",controlspec.new(0,1,'lin',0.01,0,''))
    params:set_action("post_filter_bp_"..i, function(x) softcut.post_filter_bp(i,x) end)
    params:add_control("post_filter_dry_"..i,"dry",controlspec.new(0,1,'lin',0.01,1,''))
    params:set_action("post_filter_dry_"..i, function(x) softcut.post_filter_dry(i,x) end)
    params:add_control("post_filter_rq_"..i,"resonance (0 = high)",controlspec.new(0.01,2,'lin',0.01,2,''))
    params:set_action("post_filter_rq_"..i, function(x) softcut.post_filter_rq(i,x) end)
  end

  _lfos.add_params("post_filter_fc_")

  chitter.init_params()

  params:add_group("playback",5)
  params:add_separator("transport controls playback")
  for i = 1,4 do
    params:add_option("transport_start_play_voice_"..i, "voice ["..i.."]",{"no","yes"},1)
  end

  params:add_group("recording",15)
  params:add_separator("record trigger")
  for i = 1,4 do
    params:add_option("rec_trigger_voice_"..i, "voice ["..i.."]",{"free","clock","threshold"})
    params:set_action("rec_trigger_voice_"..i,function(x)
      if x == 1 and rec[i] == 0 and clear[i] == 1 then
        
      else
        
      end
    end)
  end
  params:add_separator("loop sizing")
  for i = 1,4 do
    params:add_option("loop_sizing_voice_"..i, "voice ["..i.."]",{"manual (w/K2)","dialed (w/encoders)"})
    params:set_action("loop_sizing_voice_"..i,function(x)
      if x == 1 and rec[i] == 0 and clear[i] == 1 then
        -- reset to 60 seconds or max beat count
      else
        -- reset to 8 seconds or 16 beats
      end
    end)
  end
  params:add_separator("rec cue window quantization")
  for i = 1,4 do
    params:add_option("queue_window_quant_voice_"..i, "voice ["..i.."]",{"free","fixed"},1)
  end

  params:add_group("patterns", 13)
  params:add_separator("recording start/stop")
  for i = 1,4 do
    params:add_option("pattern_rec_mode_"..i, "voice ["..i.."]", {'free','duration','clocked'}, 1)
    params:add_option("pattern_rec_start_"..i, "   start at", {"next beat","next bar"}, 1)
    params:add_number("pattern_rec_duration_"..i, "   duration", 1, 128, 1, function(param) return (param:get().." beats") end)
    params:set_action("pattern_rec_mode_"..i,
      function(x)
        if x == 1 then
          params:hide("pattern_rec_start_"..i)
          params:hide("pattern_rec_duration_"..i)
        elseif x == 2 then
          params:hide("pattern_rec_start_"..i)
          params:show("pattern_rec_duration_"..i)
        elseif x == 3 then
          params:show("pattern_rec_start_"..i)
          params:show("pattern_rec_duration_"..i)
        end
        _menu.rebuild_params()
      end
    )
  end

  params:add_group("snapshots", 5)
  params:add_separator("reset position w/restore?")
  for i = 1,4 do
    params:add_option("snapshot_restore_pos_"..i, "voice ["..i.."]", {'yes','no'}, 1)
  end

  params:add_group("misc",12)
  params:add_option("KEY3","KEY3", {"~~", "0.5", "-1", "1.5", "2"}, 1)
  params:set_action("KEY3", function(x) KEY3 = x end)
  params:add_number("voice_2_buffer","voice 2 buffer reference",1,2,2)
  params:set_action("voice_2_buffer", function(x) softcut.buffer(2,x) end)
  params:add_separator("loop point quantization")
  for i = 1,4 do
    params:add_option("loop_quant_"..i,"voice ["..i.."]",{"seconds","beats"},1)
  end
  params:add_separator("audio saving")
  for i = 1,4 do
    params:add_option("save_voice_"..i,"save voice ["..i.."] with PSET",{"no","yes"},2)
  end

  params:bang()

  params.action_write = function(filename,name)
    os.execute("mkdir -p "..AUDIO_DIR..name)
    local scaled = {
      -- {buffer, start, end}
      {1,0},
      {params:get("voice_2_buffer"),0},
      {1,softcut_offsets[3]},
      {2,softcut_offsets[4]}
    }
    -- TODO REMOVE OLD AUDIO FILES IF THERE
    for i = 1,4 do
      if track[i].rec_limit ~= 0 and params:string("save_voice_"..i) == "yes" then
        softcut.buffer_write_mono(AUDIO_DIR..name.."/"..i..".wav",scaled[i][2],track[i].rec_limit-scaled[i][2]+0.01,scaled[i][1])
      else
        local pre_exist = io.open(AUDIO_DIR..name.."/"..i..".wav","r")
        if pre_exist then
          io.close(pre_exist)
          os.remove(AUDIO_DIR..name.."/"..i..".wav")
        end
      end
    end

    os.execute("mkdir -p "..DATA_DIR..name)

    local track_parameters = {
      ["start_point"] = {track[1].start_point,track[2].start_point,track[3].start_point,track[4].start_point},
      ["end_point"] = {track[1].end_point,track[2].end_point,track[3].end_point,track[4].end_point},
      ["rec_limit"] = {track[1].rec_limit,track[2].rec_limit,track[3].rec_limit,track[4].rec_limit},
      ["over"] = {over[1],over[2],over[3],over[4]},
      ["rec"] = {rec[1],rec[2],rec[3],rec[4]},
      ["clear"] = {clear[1],clear[2],clear[3],clear[4]}
    }
    tab.save(track_parameters,DATA_DIR..name.."/track_parameters.data")
    tab.save(snapshots,DATA_DIR..name.."/snapshots.data")
  end

  function get_line(filename, line_number)
    local i = 0
    for line in io.lines(filename) do
      i = i + 1
      if i == line_number then
        return line
      end
    end
    return nil -- line not found
  end

  params.action_read = function(filename)
    local name = string.sub(get_line(filename,1), 4, -1)
    print(name)
    loading_from_pset = true
    for i = 1,4 do
      local audio_file = io.open(AUDIO_DIR..name.."/"..i..".wav","r")
      if audio_file then
        params:set("clip "..i.." sample",AUDIO_DIR..name.."/"..i..".wav")
        io.close(audio_file)
      end
    end
    snapshots = tab.load(DATA_DIR..name.."/snapshots.data")
    load_track_parameters = tab.load(DATA_DIR..name.."/track_parameters.data")
    for k,v in pairs(load_track_parameters) do
      if k == "start_point" or k == "end_point" or k == "rec_limit" then
        for i = 1,#v do
          track[i][k] = v[i]
        end
      elseif k == "over" then
        for i = 1,#v do
          over[i] = v[i]
        end
      elseif k == "rec" then
        for i = 1,#v do
          rec[i] = v[i]
        end
      elseif k == "clear" then
        for i = 1,#v do
          clear[i] = v[i]
        end
      end
    end
    for i = 1,4 do
      softcut.loop_start(i,track[i].start_point)
      softcut.loop_end(i,track[i].end_point)
      softcut.position(i,track[i].start_point)
      record(i,true)
    end
    loading_from_pset = false
  end
end

return _params