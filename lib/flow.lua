local flow_menu = {}

local f_m = flow_menu
local voices = {"[1]","[2]","[3]","[4]"}
local pattern_names = {"arp","grid","euclid"}
local pattern_banks = {"A","B","C","D","E","F","G","H"}
local _fm_;

function f_m.init()
  page = {}
  page.flow = {}
  page.flow.pages = {"PATTERN","SCENES","SONG"}
  page.flow.selected_page = "PADS"
  page.flow.main_sel = 1
  page.flow.menu_layer = 1
  page.flow.voice = 1
  page.flow.pads_page_sel = 1
  page.flow.song_line = {1,1,1,1}
  page.flow.song_col = {1,1,1,1}
  page.flow.scene_selected = {1,1,1,1}
  page.flow.scene_line_sel = 1
  page.flow.alt = false
  _fm_ = page.flow
end

function f_m.index_to_grid_pos(val,columns,i)
  local x = math.fmod(val-1,columns)+1
  local y = math.modf((val-1)/columns)+1
  return {x,y}
end

function f_m.draw_square(x,y)
  for i = 1,16 do
    screen.pixel(x+f_m.index_to_grid_pos(i,4)[1],y+f_m.index_to_grid_pos(i,4)[2])
  end
end

function f_m.draw_menu()
  screen.move(0,15)
  screen.font_size(15)
  screen.level(15)
  screen.text("flow")
  screen.font_size(8)
  if _fm_.menu_layer == 3 and _fm_.alt and _fm_.main_sel == 3 then
    screen.level(15)
    screen.move(0,30)
    screen.text("K1 + K2:")
    screen.move(0,40)
    screen.text("DELETE")
    screen.move(0,54)
    screen.text("K1 + K3:")
    screen.move(0,64)
    screen.text("DUPLICATE")
  else
    for i = 1,#_fm_.pages do
      screen.move(0,20+(10*i))
      screen.level(_fm_.main_sel == i and 15 or (_fm_.menu_layer == 1 and 3 or 1))
      screen.text(_fm_.main_sel == i and (_fm_.menu_layer == 1 and (_fm_.pages[i])) or _fm_.pages[i])
    end
  end
  if _fm_.menu_layer == 2 then
    for i = 1,4 do
      screen.move(40,20+(10*i))
      screen.level(_fm_.voice == i and 15 or 3)
      screen.text(voices[i])
    end
  elseif _fm_.menu_layer == 3 then
    for i = 1,4 do
      screen.move(40,12+(10*i))
      screen.level(_fm_.voice == i and 15 or 1)
      screen.text(voices[i])
    end
    screen.level(15)
    screen.move(56,0)
    screen.line(56,64)
    screen.stroke()
    if _fm_.main_sel == 1 then
      if _fm_.pads_page_sel <= 3 then
        screen.move(55,0)
        screen.line(55,32)
        screen.move(57,0)
        screen.line(57,32)
        screen.stroke()
        screen.level(_fm_.pads_page_sel == 1 and 15 or 3)
        screen.move(64,10)
        screen.text("live-quantize")
        screen.move(128,20)
        screen.text_right(params:string("pattern_".._fm_.voice.."_quantization") == "yes" and "ON" or "OFF")
        screen.level(_fm_.pads_page_sel == 2 and 15 or 3)
        screen.move(64,30)
        screen.text("pattern mode")
        screen.move(128,40)
        local mode_options = {"loose","bars: "..string.format("%.4g", grid_pat[_fm_.voice].rec_clock_time/4),"quant","quant+trim"}
        screen.text_right(string.upper(mode_options[grid_pat[_fm_.voice].playmode]))
        screen.level(_fm_.pads_page_sel == 3 and 15 or 3)
        screen.move(64,50)
        screen.text("random style")
        screen.move(128,60)
        local mode_options = {"keep rates","low rates", "mid rates", "hi rates", "full range"}
        screen.text_right(string.upper(mode_options[grid_pat[_fm_.voice].random_pitch_range]))
      elseif _fm_.pads_page_sel <= 6 then
        screen.move(55,32)
        screen.line(55,64)
        screen.move(57,32)
        screen.line(57,64)
        screen.stroke()
        screen.level(_fm_.pads_page_sel == 4 and 15 or 3)
        screen.move(64,10)
        screen.text("length -> bpm")
        screen.move(128,20)
        screen.text_right(string.upper(params:string("sync_clock_to_pattern_".._fm_.voice)))
      end
    elseif _fm_.main_sel == 2 then
      local id = track[_fm_.voice].snapshot.focus
      if _fm_.scene_line_sel <= 6 then
        screen.move(55,0)
        screen.line(55,32)
        screen.move(57,0)
        screen.line(57,32)
        screen.stroke()
        screen.level(_fm_.scene_line_sel == 1 and 15 or 3)
        screen.move(64,10)
        screen.text("SLOT: "..id)
        screen.level(_fm_.scene_line_sel > 1 and 15 or 3)
        screen.move(64,20)
        screen.text("~~ RESTORES ~~")
        screen.level(_fm_.scene_line_sel == 2 and 15 or 3)
        screen.move(64,28)
        screen.text("rate: "..(snapshots[_t][id].restore.rate and (snapshots[_t][id].rate_ramp and "Y (RAMP)" or "Y (SNAP)") or "N"))
        screen.level(_fm_.scene_line_sel == 3 and 15 or 3)
        screen.move(64,36)
        screen.text("loop start: "..(snapshots[_t][id].restore.start_point and "Y" or "N"))
        screen.level(_fm_.scene_line_sel == 4 and 15 or 3)
        screen.move(64,44)
        screen.text("loop end: "..(snapshots[_t][id].restore.end_point and "Y" or "N"))
        screen.level(_fm_.scene_line_sel == 5 and 15 or 3)
        screen.move(64,52)
        screen.text("level: "..(snapshots[_t][id].restore.level and "Y" or "N"))
        screen.level(_fm_.scene_line_sel == 6 and 15 or 3)
        screen.move(64,60)
        screen.text("filter: "..(snapshots[_t][id].restore.filter and "Y" or "N"))
      end
      -- for i = 1,4 do
      --   for j = 1,4 do
      --     screen.level(_fm_.scene_pad[_fm_.voice] == (i*j) and 15 or 2)
      --     f_m.draw_square(58+((j-1)*6),0+((i-1)*6))
      --     screen.fill()
      --   end
      -- end
    elseif _fm_.main_sel == 3 then
      screen.level(15)
      screen.move(60,6)
      screen.text("#")
      screen.move(76,6)
      screen.circle(76,5,2)
      screen.fill()
      screen.move(78,6)
      screen.line(78,0)
      screen.stroke()
      screen.move(95,6)
      screen.text_center("P")
      screen.move(112,6)
      screen.text_center(_fm_.alt and "t" or "S")
      screen.level(3)
      local sel_x = 70+(f_m.index_to_grid_pos(_fm_.song_col[_fm_.voice],3)[1]-1)*18
      local sel_y = 4+(10*util.wrap(_fm_.song_line[_fm_.voice],1,5))
      screen.rect(sel_x,sel_y,13,7)
      screen.fill()
      screen.move(56,10)
      screen.line(128,10)
      screen.stroke()
      local _v = _fm_.voice

      local page = f_m.index_to_grid_pos(_fm_.song_line[_fm_.voice],5)[2] - 1 -- only minus 1 cuz of reasons...

      -- local min_max = {{1,20},{21,40},{41,60},{61,80}}
      for i = 1+(15*page), 15+(15*page) do
        screen.move(76+(f_m.index_to_grid_pos(util.wrap(i,1,15),3)[1]-1)*18,10+(10*f_m.index_to_grid_pos(util.wrap(i,1,15),3)[2]))
        screen.level((_fm_.song_col[_fm_.voice] == f_m.index_to_grid_pos(i,3)[1] and _fm_.song_line[_fm_.voice] == f_m.index_to_grid_pos(i,3)[2]) and 0 or 15)
        if f_m.index_to_grid_pos(util.wrap(i,1,15),3)[1] == 1 and f_m.index_to_grid_pos(i,3)[2] <= song_atoms[_v].end_point then
          screen.text_center(song_atoms[_v].lane[f_m.index_to_grid_pos(i,3)[2]].beats)
          screen.level(15)
          screen.move(60+(f_m.index_to_grid_pos(util.wrap(i,1,15),3)[1]-1)*18,10+(10*f_m.index_to_grid_pos(util.wrap(i,1,15),3)[2]))
          screen.text(f_m.index_to_grid_pos(i,3)[2])
        elseif f_m.index_to_grid_pos(util.wrap(i,1,15),3)[1] == 2 and f_m.index_to_grid_pos(i,3)[2] <= song_atoms[_v].end_point then
        -- elseif f_m.index_to_grid_pos(i,3)[2] <= song_atoms[_v].end_point then
          local target = song_atoms[_v].lane[f_m.index_to_grid_pos(i,3)[2]][pattern_names[f_m.index_to_grid_pos(i,3)[1]-1]].target
          if target > 0 then
            -- target = (f_m.index_to_grid_pos(target,8)[1])
          else
            target = target == 0 and "-" or "xx"
          end
          screen.text_center(target)
        elseif f_m.index_to_grid_pos(util.wrap(i,1,15),3)[1] == 3 and f_m.index_to_grid_pos(i,3)[2] <= song_atoms[_v].end_point then
          if _fm_.alt then
            local target = song_atoms[_fm_.voice].lane[f_m.index_to_grid_pos(i,3)[2]].snapshot_restore_mod_index
            if target > 0 then
            else
              target = target == 0 and "-" or "xx"
            end
            screen.text_center(target.."*")
          else
            local target = song_atoms[_v].lane[f_m.index_to_grid_pos(i,3)[2]]["snapshot"].target
            if target > 0 then
            else
              target = target == 0 and "-" or "xx"
            end
            screen.text_center(target)
          end
        end
      end
      screen.level(15)
      if song_atoms[_fm_.voice].current > 5*page and song_atoms[_fm_.voice].current <= 5*(page+1) then
        screen.move(128,10+(10*(song_atoms[_fm_.voice].current - 5*page)))
        screen.text_right("<")
      end
      if page < f_m.index_to_grid_pos(song_atoms[_v].end_point,5)[2]-1 then
        screen.move(128,8)
        screen.text_right("▼")
      end
      if page > f_m.index_to_grid_pos(song_atoms[_v].start_point,5)[2]-1 then
        screen.move(128,4)
        screen.text_right("▲")
      end
    end
  end
end

function f_m.process_encoder(n,d)
  if _fm_.menu_layer == 1 then
    if n == 2 or n == 1 then
      page.flow.main_sel = util.clamp(page.flow.main_sel + d,1,#_fm_.pages)
    end
  -- elseif _fm_.menu_layer == 2 then
  --   if n == 2 then
  --     page.flow.voice = util.clamp(page.flow.voice + d,1,4)
  --   end
  elseif _fm_.menu_layer == 3 then
    if n == 1 then
      page.flow.voice = util.clamp(page.flow.voice + d,1,4)
    end
    if _fm_.main_sel == 1 then
      local pattern = get_grid_connected() and grid_pat[page.flow.voice] or midi_pat[page.flow.voice]
      if n == 2 then
        _fm_.pads_page_sel = util.clamp(_fm_.pads_page_sel + d,1,4)
      elseif n == 3 then
        if _fm_.pads_page_sel == 1 then
          params:delta("pattern_"..page.flow.voice.."_quantization",d)
        elseif _fm_.pads_page_sel == 2 then
          if pattern.rec ~= 1 then
            if not _fm_.alt then
              if pattern.play == 1 then -- actually, we won't want to allow change...
              else
                pattern.playmode = util.clamp(pattern.playmode+d,1,2)
              end
            elseif _fm_.alt and pattern.playmode == 2 then
              key1_hold_and_modify = true
              pattern.rec_clock_time = util.clamp(pattern.rec_clock_time+d,1,64)
            end
          end
        elseif _fm_.pads_page_sel == 3 then
          pattern.random_pitch_range = util.clamp(pattern.random_pitch_range+d,1,5)
        elseif _fm_.pads_page_sel == 4 then
          params:delta("sync_clock_to_pattern_"..page.flow.voice,d)
        end
      end
    elseif _fm_.main_sel == 2 then
      if n == 2 then
        _fm_.scene_line_sel = util.clamp(_fm_.scene_line_sel + d,1,6)
      elseif n == 3 then
        local id = track[_fm_.voice].snapshot.focus
        if _fm_.scene_line_sel == 1 then
          track[_t].snapshot.focus = util.clamp(track[_t].snapshot.focus + d,1,16)
        elseif _fm_.scene_line_sel == 2 then
          if d > 0 then
            if snapshots[_t][id].restore.rate and not snapshots[_t][id].rate_ramp then
              snapshots[_t][id].rate_ramp = true
            elseif not snapshots[_t][id].restore.rate then
              snapshots[_t][id].restore.rate = true
            end
          else
            if snapshots[_t][id].restore.rate and snapshots[_t][id].rate_ramp then
              snapshots[_t][id].rate_ramp = false
            elseif snapshots[_t][id].restore.rate and not snapshots[_t][id].rate_ramp then
              snapshots[_t][id].restore.rate = false
            end
          end
        elseif _fm_.scene_line_sel == 3 then
          snapshots[_t][id].restore.start_point = d > 0 and true or false
        elseif _fm_.scene_line_sel == 4 then
          snapshots[_t][id].restore.end_point = d > 0 and true or false
        elseif _fm_.scene_line_sel == 5 then
          snapshots[_t][id].restore.level = d > 0 and true or false
        elseif _fm_.scene_line_sel == 6 then
          snapshots[_t][id].restore.filter = d > 0 and true or false
        end
      end
    elseif _fm_.main_sel == 3 then
      if n == 1 then
        -- _fm_.song_line[_fm_.voice] = util.clamp(_fm_.song_line[_fm_.voice] + d,1,song_atoms[_fm_.voice].end_point)
      elseif n == 2 then
        if _fm_.song_col[_fm_.voice] == 3 then
          if d > 0 then
            local current_line = _fm_.song_line[_fm_.voice]
            _fm_.song_line[_fm_.voice] = util.clamp(_fm_.song_line[_fm_.voice] + d,1,song_atoms[_fm_.voice].end_point)
            if (_fm_.song_line[_fm_.voice] ~= song_atoms[_fm_.voice].start_point) and (_fm_.song_line[_fm_.voice] ~= song_atoms[_fm_.voice].end_point) then
              _fm_.song_col[_fm_.voice] = 1
            elseif current_line ~= _fm_.song_line[_fm_.voice] then
              _fm_.song_col[_fm_.voice] = 1
            end
          else
            _fm_.song_col[_fm_.voice] = util.clamp(_fm_.song_col[_fm_.voice] + d,1,4)
          end
        elseif _fm_.song_col[_fm_.voice] == 2 then
          _fm_.song_col[_fm_.voice] = util.clamp(_fm_.song_col[_fm_.voice] + d,1,4)
        else
          if d < 0 then
            local current_line = _fm_.song_line[_fm_.voice]
            _fm_.song_line[_fm_.voice] = util.clamp(_fm_.song_line[_fm_.voice] + d,1,song_atoms[_fm_.voice].end_point)
            if (_fm_.song_line[_fm_.voice] ~= song_atoms[_fm_.voice].start_point) and (_fm_.song_line[_fm_.voice] ~= song_atoms[_fm_.voice].end_point) then
              _fm_.song_col[_fm_.voice] = 3
            elseif current_line ~= _fm_.song_line[_fm_.voice] then
              _fm_.song_col[_fm_.voice] = 3
            end
          else
            _fm_.song_col[_fm_.voice] = util.clamp(_fm_.song_col[_fm_.voice] + d,1,4)
          end
        end
      elseif n == 3 then
        if _fm_.song_col[_fm_.voice] == 1 then
          song_atoms[_fm_.voice].lane[_fm_.song_line[_fm_.voice]].beats = util.clamp(song_atoms[_fm_.voice].lane[_fm_.song_line[_fm_.voice]].beats + d,1,128)
        elseif _fm_.song_col[_fm_.voice] == 2 then
          song_atoms[_fm_.voice].lane[_fm_.song_line[_fm_.voice]][pattern_names[_fm_.song_col[_fm_.voice]-1]].target = util.clamp(song_atoms[_fm_.voice].lane[_fm_.song_line[_fm_.voice]][pattern_names[_fm_.song_col[_fm_.voice]-1]].target + d,-1,8)
        elseif _fm_.song_col[_fm_.voice] == 3 then
          if _fm_.alt then
            song_atoms[_fm_.voice].lane[_fm_.song_line[_fm_.voice]].snapshot_restore_mod_index = util.clamp(song_atoms[_fm_.voice].lane[_fm_.song_line[_fm_.voice]].snapshot_restore_mod_index + d, 0,8)
          else
            song_atoms[_fm_.voice].lane[_fm_.song_line[_fm_.voice]].snapshot.target = util.clamp(song_atoms[_fm_.voice].lane[_fm_.song_line[_fm_.voice]].snapshot.target + d,-1,16)
          end
        end
      end
    end
  end
end

function f_m.process_key(n,z)
  if n == 3 and z == 1 then
    if _fm_.menu_layer == 1 then
      _fm_.menu_layer = 3
    elseif _fm_.menu_layer == 3 then
      if _fm_.main_sel == 3 then
        if not _fm_.alt then
          _song.add_line(_fm_.voice,_fm_.song_line[_fm_.voice])
        else
          _song.duplicate_line(_fm_.voice,_fm_.song_line[_fm_.voice])
        end
      end
    end
  elseif n == 2 and z == 1 then
    if _fm_.menu_layer == 1 then
      menu = 1
    elseif _fm_.menu_layer == 3 then
      if not _fm_.alt then
        _fm_.menu_layer = 1
      end
      if _fm_.main_sel == 3 then
        if _fm_.alt then
          _song.remove_line(_fm_.voice,_fm_.song_line[_fm_.voice])
        end
      end
    end
  elseif n == 1 then
    _fm_.alt = z == 1 and true or false
  end
end

return flow_menu