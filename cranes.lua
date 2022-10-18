-- cranes
-- dual looper / delay
-- (grid optional)
-- v2.2.1 @dan_derks
-- https://llllllll.co/t/21207
-- ---------------------
-- to start:
-- press key 2 to rec.
-- sounds are written to
-- two buffers.
-- one = left in.
-- two = right in.
-- press key 2 to play.
--
-- key 1 = toggle focus b/w
--         voice 1 + voice 2.
-- key 2 = toggle overwrite for
--         selected voice.
-- key 3 = voice 1 pitch bump.
-- keys 3 + 1 = erase all.
-- enc 1 = overwrite amount
--         (0 = add, 1 = clear)
-- enc 2 / 3 = loop point for
--             selected voice.
-- ////
-- head to params to find
-- speed, vol, pan
-- +
-- change buffer 2's reference
-- \\\\

-- counting ms between key 2 taps
-- sets loop length
function count()
  rec_time = rec_time + 0.01
end

-- track recording state
rec = 0
local offset=1

local cs = require 'controlspec'

local presets = {}
local presets_1 = {}
local presets_2 = {}

preset_count = {}
for i = 1,2 do
  preset_count[i] = 0
end

local TRACKS = 2
track = {}
for i=1,TRACKS do
  track[i] = {}
  track[i].start_point = 0
  track[i].end_point = 60
  track[i].poll_position = 0
  track[i].pos_grid = -1
end

distance = {}
for i = 1,2 do
  distance[i] = 0
end

selected_preset = {}
for i = 1,2 do
  selected_preset[i] = 0
end

function init()
  g = grid.connect()

  softcut.buffer_clear()
  --audio.level_cut(1)
  audio.level_adc_cut(1)
  audio.level_eng_cut(0)
  softcut.level_input_cut(1, 1, 1.0)
  softcut.level_input_cut(1, 2, 0.0)
  softcut.level_input_cut(2, 1, 0.0)
  softcut.level_input_cut(2, 2, 1.0)
  softcut.buffer(1,1)
  softcut.buffer(2,2)
  
  for i = 1, TRACKS do
    softcut.level(i,1.0)
    softcut.play(i, 1)
    softcut.rate(i, 1*offset)
    softcut.loop_start(i, 0)
    softcut.loop_end(i, 60)
    softcut.loop(i, 1)
    softcut.fade_time(i, 0.1)
    softcut.rec(i, 1)
    softcut.rec_level(i, 1)
    softcut.pre_level(i, 1)
    softcut.position(i, 0)
    softcut.phase_quant(i, 0.03)
    softcut.rec_offset(i, -0.0003)
  end
 
  softcut.event_phase(phase)

  params:add_option("speed_voice_1","speed voice 1", speedlist_1)
  params:set("speed_voice_1", 9)
  params:set_action("speed_voice_1",
    function(x)
      softcut.rate(1, speedlist_1[params:get("speed_voice_1")]*offset)
      params:set("speed1_midi", params:get("speed_voice_1"))
      grid_dirty = true
    end
  )
  params:add_option("speed_voice_2","speed voice 2", speedlist_2)
  params:set("speed_voice_2", 9)
  params:set_action("speed_voice_2",
    function(x)
      softcut.rate(2, speedlist_2[params:get("speed_voice_2")]*offset)
      params:set("speed2_midi", params:get("speed_voice_2"))
      grid_dirty = true
    end
  )
  params:add_separator()
  --
  params:add_control("speed1_midi","midi ctrl speed voice 1", controlspec.new(1,12,'exp',1,12,''))
  params:set_action("speed1_midi", function(x) params:set("speed_voice_1", x) end)
  params:set("speed1_midi", 9)
  params:add_control("speed2_midi","midi ctrl speed voice 2", controlspec.new(1,12,'exp',1,12,''))
  params:set_action("speed2_midi", function(x) params:set("speed_voice_2", x) end)
  params:set("speed2_midi", 9)
  params:add_separator()
  --
  params:add_control("offset", "global offset", controlspec.new(-24, 24, 'lin', 1, 0, "st"))
  params:set_action("offset",
    function(value)
      offset = math.pow(0.5, -value / 12)
      softcut.rate(1,speedlist_1[params:get("speed_voice_1")]*offset)
      softcut.rate(2,speedlist_2[params:get("speed_voice_2")]*offset)
    end
  )
  params:add_separator()
  --
  for i = 1,2 do
    params:add_control(i .. "lvl_in_L", "lvl in L voice " .. i, controlspec.new(0,1,'lin',0,1,''))
    params:set_action(i .. "lvl_in_L", function(x) softcut.level_input_cut(1, i, x) end)
  end
  params:set(2 .. "lvl_in_L", 0.0)
  for i = 1,2 do
    params:add_control(i .. "lvl_in_R", "lvl in R voice " .. i, controlspec.new(0,1,'lin',0,1,''))
    params:set_action(i .. "lvl_in_R", function(x) softcut.level_input_cut(2, i, x) end)
  end
  params:set(1 .. "lvl_in_R", 0.0)
  params:add_separator()
  --
  params:add_control("vol_1","lvl out voice 1",controlspec.new(0,5,'lin',0,5,''))
  params:set_action("vol_1", function(x) softcut.level(1, x) end)
  params:set("vol_1", 1.0)
  params:add_control("vol_2","lvl out voice 2",controlspec.new(0,5,'lin',0,5,''))
  params:set_action("vol_2", function(x) softcut.level(2, x) end)
  params:set("vol_2", 1.0)
  params:add_separator()
  --
  params:add_control("pan_1","pan voice 1",controlspec.new(-1,1,'lin',0.01,-1,''))
  params:set_action("pan_1", function(x) softcut.pan(1, x) end)
  params:add_control("pan_slew_1","pan slew 1", controlspec.new(0, 200, "lin", 0.01, 50, ""))
  params:set_action("pan_slew_1", function(x) softcut.pan_slew_time(1, x) end)
  params:add_control("pan_2","pan voice 2",controlspec.new(-1,1,'lin',0.01,1,''))
  params:set_action("pan_2", function(x) softcut.pan(2, x) end)
  params:add_control("pan_slew_2","pan slew 2", controlspec.new(0, 200, "lin", 0.01, 50, ""))
  params:set_action("pan_slew_2", function(x) softcut.pan_slew_time(2, x) end)
  params:add_separator()
  --
  local p = softcut.params()
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
  
  counter = metro.init(count, 0.01, -1)
  rec_time = 0

  KEY3_hold = false
  KEY1_hold = false
  KEY1_press = 0
  clear_all()

  hardware_redraw = metro.init(
    function()
      draw_hardware()
    end
    , 1/30, -1)
  hardware_redraw:start()
  
  grid_dirty = true
  screen_dirty = true
  
  softcut.poll_start_phase()
end

function grid.add()
  grid_dirty = true
end

function draw_hardware()
  if grid_dirty then
    grid_redraw()
    grid_dirty = false
  end
  if screen_dirty then
    redraw()
    screen_dirty = false
  end
end

phase = function(n, x)
  if n == 1 then
    track[1].poll_position = x
    pp = ((x - track[1].start_point) / (track[1].end_point - track[1].start_point))
    x = math.floor(pp * 16)
    if x ~= track[n].pos_grid then
      track[n].pos_grid = x
    end
  elseif n == 2 then
    track[2].poll_position = x
    pp = ((x - track[2].start_point) / (track[2].end_point - track[2].start_point))
    x = math.floor(pp * 16)
    if x ~= track[n].pos_grid then
      track[n].pos_grid = x
    end
  end
  grid_dirty = true
  screen_dirty = true
end

function preset_pack(voice)
  if voice == 1 then
    table.insert(presets_1, track[1].start_point)
    table.insert(presets_1, track[1].end_point)
    table.insert(presets_1, track[1].poll_position)
    table.insert(presets_1, params:get("speed_voice_1"))
    preset_pool_1 = { {presets_1[1],presets_1[2],presets_1[3],presets_1[4]},
                    {presets_1[5],presets_1[6],presets_1[7],presets_1[8]},
                    {presets_1[9],presets_1[10],presets_1[11],presets_1[12]},
                    {presets_1[13],presets_1[14],presets_1[15],presets_1[16]},
                    {presets_1[17],presets_1[18],presets_1[19],presets_1[20]},
                    {presets_1[21],presets_1[22],presets_1[23],presets_1[24]},
                    {presets_1[25],presets_1[26],presets_1[27],presets_1[28]},
                    {presets_1[29],presets_1[30],presets_1[31],presets_1[32]},
                    {presets_1[33],presets_1[34],presets_1[35],presets_1[36]},
                    {presets_1[37],presets_1[38],presets_1[39],presets_1[40]},
                    {presets_1[41],presets_1[42],presets_1[43],presets_1[44]},
                    {presets_1[45],presets_1[46],presets_1[47],presets_1[48]},
                    {presets_1[49],presets_1[50],presets_1[51],presets_1[52]} }
  elseif voice == 2 then
    table.insert(presets_2, track[2].start_point)
    table.insert(presets_2, track[2].end_point)
    table.insert(presets_2, track[2].poll_position)
    table.insert(presets_2, params:get("speed_voice_2"))
    preset_pool_2 = { {presets_2[1],presets_2[2],presets_2[3],presets_2[4]},
                    {presets_2[5],presets_2[6],presets_2[7],presets_2[8]},
                    {presets_2[9],presets_2[10],presets_2[11],presets_2[12]},
                    {presets_2[13],presets_2[14],presets_2[15],presets_2[16]},
                    {presets_2[17],presets_2[18],presets_2[19],presets_2[20]},
                    {presets_2[21],presets_2[22],presets_2[23],presets_2[24]},
                    {presets_2[25],presets_2[26],presets_2[27],presets_2[28]},
                    {presets_2[29],presets_2[30],presets_2[31],presets_2[32]},
                    {presets_2[33],presets_2[34],presets_2[35],presets_2[36]},
                    {presets_2[37],presets_2[38],presets_2[39],presets_2[40]},
                    {presets_2[41],presets_2[42],presets_2[43],presets_2[44]},
                    {presets_2[45],presets_2[46],presets_2[47],presets_2[48]},
                    {presets_2[49],presets_2[50],presets_2[51],presets_2[52]} }
  end
end

function preset_unpack(voice, set)
  if voice == 1 then
    track[1].start_point = preset_pool_1[set][1]
    softcut.loop_start(1,track[1].start_point)
    track[1].end_point = preset_pool_1[set][2]
    softcut.loop_end(1,track[1].end_point)
    softcut.position(1,preset_pool_1[set][3])
    params:set("speed_voice_1", preset_pool_1[set][4])
  elseif voice == 2 then
    track[2].start_point = preset_pool_2[set][1]
    softcut.loop_start(2,track[2].start_point)
    track[2].end_point = preset_pool_2[set][2]
    softcut.loop_end(2,track[2].end_point)
    softcut.position(2,preset_pool_2[set][3])
    params:set("speed_voice_2", preset_pool_2[set][4])
  end
  screen_dirty = true
  grid_dirty = true
end

function warble()
  local bufSpeed1 = speedlist_1[params:get("speed_voice_1")]
  if bufSpeed1 > 1.99 then
      ray = bufSpeed1 + (math.random(-15,15)/1000)
    elseif bufSpeed1 >= 1.0 then
      ray = bufSpeed1 + (math.random(-10,10)/1000)
    elseif bufSpeed1 >= 0.50 then
      ray = bufSpeed1 + (math.random(-4,5)/1000)
    else
      ray = bufSpeed1 + (math.random(-2,2)/1000)
  end
    softcut.rate_slew_time(1,0.6 + (math.random(-30,10)/100))
end

function half_speed()
  ray = speedlist_1[params:get("speed_voice_1")] / 2
  softcut.rate_slew_time(1,0.6 + (math.random(-30,10)/100))
end

function rev_speed()
  ray = speedlist_1[params:get("speed_voice_1")] * -1
  softcut.rate_slew_time(1,0.01)
end

function oneandahalf_speed()
  ray = speedlist_1[params:get("speed_voice_1")] * 1.5
  softcut.rate_slew_time(1,0.6 + (math.random(-30,10)/100))
end

function double_speed()
  ray = speedlist_1[params:get("speed_voice_1")] * 2
  softcut.rate_slew_time(1,0.6 + (math.random(-30,10)/100))
end

function restore_speed()
  ray = speedlist_1[params:get("speed_voice_1")]
  if params:get("KEY3") == 2 then
    softcut.rate_slew_time(1,0.01)
  else
    softcut.rate_slew_time(1,0.6)
  end
  softcut.rate(1,speedlist_1[params:get("speed_voice_1")]*offset)
end

function clear_all()
  for i = 1, TRACKS do
    softcut.rec_level(i, 1)
    softcut.level(i, 0)
    softcut.play(i, 0)
    softcut.rate(i, 1*offset)
    softcut.loop_start(i, 0)
    softcut.loop_end(i, 60)
    softcut.position(i, 0)
    softcut.enable(i, 0)
  end
  softcut.buffer_clear()
  ray = speedlist_1[params:get("speed_voice_1")]
  track[1].start_point = 0
  track[2].start_point = 0
  track[1].end_point = 60
  track[2].end_point = 60

  --Reset position after clearing
  --Mostly for UI
  track[1].poll_position = 0
  track[2].poll_position = 0
  softcut.position(1, 0)
  softcut.position(2, 0)

  clear = 1
  rec_time = 0
  rec = 0
  crane_redraw = 0
  crane2_redraw = 0
  c2 = math.random(4,15)
  restore_speed()
  -- for i = 1,16 do
  --   g:led(i,4,0)
  --   g:led(i,8,0)
  -- end
  -- g:refresh()
  grid_dirty = true
  screen_dirty = true
  KEY3_hold = false
  params:set("offset",0)
end

function window(voice,x)
  if x == 1 then
      if track[voice].start_point - 0.01 < 0 then
        track[voice].start_point = 0
      else
        track[voice].start_point = track[voice].start_point - 0.01
      end
    elseif x == 2 then
      if track[voice].start_point - 0.1 < 0 then
        track[voice].start_point = 0
      else
        track[voice].start_point = track[voice].start_point - 0.1
      end
    elseif x == 3 then
      track[voice].start_point = track[voice].start_point + 0.1
    elseif x == 4 then
      track[voice].start_point = track[voice].start_point + 0.01
    elseif x == 8 and track[voice].start_point > 0.009 then
      distance[voice] = math.abs(track[voice].start_point - track[voice].end_point)
      if track[voice].start_point < distance[voice] then
        track[voice].start_point = 0
      else
        track[voice].start_point = track[voice].start_point - distance[voice]
      end
      track[voice].end_point = track[voice].end_point - distance[voice]
    elseif x == 7 and track[voice].start_point > 0.009 then
      track[voice].start_point = track[voice].start_point - 0.01
      track[voice].end_point = track[voice].end_point - 0.01
    elseif x == 10 then
      track[voice].start_point = track[voice].start_point + 0.01
      track[voice].end_point = track[voice].end_point + 0.01
    elseif x == 9 then
      distance[voice] = math.abs(track[voice].start_point - track[voice].end_point)
      track[voice].start_point = track[voice].start_point + distance[voice]
      track[voice].end_point = track[voice].end_point + distance[voice]
    elseif x == 13 then
      if track[voice].end_point - 0.1 < 0 then
        track[voice].end_point = 0
      else
        track[voice].end_point = track[voice].end_point - 0.01
      end
    elseif x == 14 then
      if track[voice].end_point - 0.1 < 0 then
        track[voice].end_point = 0
      else
        track[voice].end_point = track[voice].end_point - 0.1
      end
    elseif x == 15 then
      track[voice].end_point = track[voice].end_point + 0.1
    elseif x == 16 then
      track[voice].end_point = track[voice].end_point + 0.01
  end
    softcut.loop_start(voice,track[voice].start_point)
    softcut.loop_end(voice,track[voice].end_point)
    screen_dirty = true
end

function record()
  rec = rec + 1
  -- if the buffer is clear and key 2 is pressed:
  -- main recording will enable
  if rec % 2 == 1 and clear == 1 then
    softcut.buffer_clear()
    softcut.rate_slew_time(1,0.01)
    for i = 1, TRACKS do
      softcut.enable(i, 1)
      softcut.rate(i, 1*offset)
      softcut.play(i, 1)
      softcut.rec(i, 1)
      softcut.level(i, 0)
    end
    crane_redraw = 1
    screen_dirty = true
    counter:start()
  -- if the buffer is clear and key 2 is pressed again:
  -- main recording will disable, loop points set
  elseif rec % 2 == 0 and clear == 1 then
    clear = 0
    softcut.position(1,0)
    softcut.position(2,0)
    softcut.rec_level(1,0)
    softcut.rec_level(2,0)
    counter:stop()
    softcut.poll_start_phase()
    track[1].end_point = rec_time
    track[2].end_point = rec_time
    softcut.loop_end(1,track[1].end_point)
    softcut.loop_end(2,track[2].end_point)
    softcut.loop_start(2,0)
    track[2].start_point = 0
    crane_redraw = 0
    screen_dirty = true
    rec_time = 0
    softcut.level(1,1)
    softcut.level(2,1)
    softcut.rate(1,speedlist_1[params:get("speed_voice_1")]*offset)
    softcut.rate(2,speedlist_2[params:get("speed_voice_2")]*offset)
  end
  -- if the buffer is NOT clear and key 2 is pressed:
  -- overwrite/overdub behavior will enable
  if rec % 2 == 1 and clear == 0 and KEY1_press % 2 == 0 then
    softcut.rec_level(1,1)
    softcut.pre_level(1,math.abs(over_1-1))
    crane_redraw = 1
    crane2_redraw = 1
    screen_dirty = true
  -- if the buffer is NOT clear and key 2 is pressed again:
  -- overwrite/overdub behavior will disable
  elseif rec % 2 == 0 and clear == 0 and KEY1_press % 2 == 0 then
    softcut.rec_level(1,0)
    softcut.pre_level(1,1)
    crane_redraw = 0
    crane2_redraw = 0
    screen_dirty = true
  elseif rec % 2 == 1 and clear == 0 and KEY1_press % 2 == 1 then
    softcut.rec_level(2,1)
    softcut.pre_level(2,math.abs(over_2-1))
    crane_redraw = 1
    crane2_redraw = 1
    screen_dirty = true
  elseif rec % 2 == 0 and clear == 0 and KEY1_press % 2 == 1 then
    softcut.rec_level(2,0)
    softcut.pre_level(2,1)
    crane_redraw = 0
    crane2_redraw = 0
    screen_dirty = true
  end
end

-- variable dump
down_time = 0
hold_time = 0
speedlist_1 = {-4.0, -2.0, -1.0, -0.5, -0.25, 0, 0.25, 0.5, 1.0, 2.0, 4.0}
speedlist_2 = {-4.0, -2.0, -1.0, -0.5, -0.25, 0, 0.25, 0.5, 1.0, 2.0, 4.0}
track[1].start_point = 0
track[2].start_point = 0
track[1].end_point = 60
track[2].end_point = 60
over = 0
over_1 = 0.0
over_2 = 0.0
clear = 1
ray = 0.0
KEY3 = 1
crane_redraw = 0
crane2_redraw = 0
c2 = math.random(4,12)

-- key hardware interaction
function key(n,z)
  
  -- KEY 2
  if n == 2 and z == 1 then
    record()
  end
  
  -- KEY 3
  -- all based on Parameter choice
  if n == 3 then
    if z == 1 then
      KEY3_hold = true
        if KEY3 == 1 then
          warble()
        elseif KEY3 == 2 then
          half_speed()
        elseif KEY3 == 3 then
          rev_speed()
        elseif KEY3 == 4 then
          oneandahalf_speed()
        elseif KEY3 == 5 then
          double_speed()
        end
    elseif z == 0 then
      KEY3_hold = false
      restore_speed()
    end
  softcut.rate(1,ray*offset)
  end

  -- KEY 1
  -- hold key 1 + key 3 to clear the buffers
  if n == 1 and z == 1 and KEY3_hold == true then
    clear_all()
    KEY1_hold = false

    -- Proposed fix to allow clear and re-record 
    softcut.buffer_clear()
    for i = 1, TRACKS do
      softcut.loop_start(i, 0)
      softcut.position(i, 0)
    end
    softcut.event_phase(phase)

  elseif n == 1 and z == 1 then
    KEY1_press = KEY1_press + 1
    if rec % 2 == 1 then
      rec = 0
      if KEY1_press % 2 == 1 then
        softcut.rec_level(1,0)
        softcut.pre_level(1,1)
      elseif KEY1_press % 2 == 0 then
        softcut.rec_level(2,0)
        softcut.pre_level(2,1)
      end
      crane_redraw = 0
      crane2_redraw = 0
      screen_dirty = true
    end
    KEY1_hold = true
    screen_dirty = true
  elseif n == 1 and z == 0 then
    KEY1_hold = false
    screen_dirty = true
  end
end

-- encoder hardware interaction
function enc(n,d)

  -- encoder 3: voice 1's loop end point
  if n == 3 and KEY1_press % 2 == 0 then
    track[1].end_point = util.clamp((track[1].end_point + d/10),0.0,60.0)
    softcut.loop_end(1,track[1].end_point)
    screen_dirty = true

  -- encoder 2: voice 1's loop start point
  elseif n == 2 and KEY1_press % 2 == 0 then
    track[1].start_point = util.clamp((track[1].start_point + d/10),0.0,60.0)
    softcut.loop_start(1,track[1].start_point)
    screen_dirty = true

-- encoder 3: voice 2's loop end point
  elseif n == 3 and KEY1_press % 2 == 1 then
    track[2].end_point = util.clamp((track[2].end_point + d/10),0.0,60.0)
    softcut.loop_end(2,track[2].end_point)
    screen_dirty = true

-- encoder 2: voice 2's loop start point
  elseif n == 2 and KEY1_press % 2 == 1 then
    track[2].start_point = util.clamp((track[2].start_point + d/10),0.0,60.0)
    softcut.loop_start(2,track[2].start_point)
    screen_dirty = true

  -- encoder 1: voice 1's overwrite/overdub amount
  -- 0 is full overdub
  -- 1 is full overwrite
  elseif n == 1 then
    if KEY1_press % 2 == 0 then
      over_1 = util.clamp((over_1 + d/100), 0.0,1.0)
      if rec % 2 == 1 then
        softcut.pre_level(1,math.abs(over_1-1))
      end
    elseif KEY1_press % 2 == 1 then
      over_2 = util.clamp((over_2 + d/100), 0.0,1.0)
        if rec % 2 == 1 then
          softcut.pre_level(2,math.abs(over_2-1))
        end
    end
    screen_dirty = true
  end
end

-- displaying stuff on the screen
function redraw()
  screen.clear()
  screen.level(15)
  screen.move(0,50)
    if KEY1_press % 2 == 1 then
      screen.text("s2: "..math.ceil(track[2].start_point * (10^2))/(10^2))
    elseif KEY1_press % 2 == 0 then
      screen.text("s1: "..math.ceil(track[1].start_point * (10^2))/(10^2))
    end
  screen.move(0,60)
    if KEY1_press % 2 == 1 then
      screen.text("e2: "..math.ceil(track[2].end_point * (10^2))/(10^2))
    elseif KEY1_press % 2 == 0 then
      screen.text("e1: "..math.ceil(track[1].end_point * (10^2))/(10^2))
    end
  screen.move(0,40)
    if KEY1_press % 2 == 1 then
      screen.text("o2: "..over_2)
    elseif KEY1_press % 2 == 0 then
      screen.text("o1: "..over_1)
    end
  if crane_redraw == 1 then
    if crane2_redraw == 0 then
      crane()
    else
      crane2()
    end
  end
  screen.level(3)
  screen.move(0,10)
  screen.text("one: "..math.floor(track[1].poll_position*10)/10)
  screen.move(0,20)
  screen.text("two: "..math.floor(track[2].poll_position*10)/10)
  screen.update()
  end

-- crane drawing
function crane()
  screen.level(13)
  screen.aa(1)
  screen.line_width(0.5)
  screen.move(50,60)
  screen.line(65,40)
  screen.move(65,40)
  screen.line(100,50)
  screen.move(100,50)
  screen.line(50,60)
  screen.move(60,47)
  screen.line(48,15)
  screen.move(48,15)
  screen.line(75,40)
  screen.move(73,43)
  screen.line(85,35)
  screen.move(85,35)
  screen.line(100,50)
  screen.move(100,50)
  screen.line(105,25)
  screen.move(105,25)
  screen.line(117,35)
  screen.move(117,35)
  screen.line(104,30)
  screen.move(105,25)
  screen.line(100,30)
  screen.move(100,30)
  screen.line(95,45)
  screen.move(97,40)
  screen.line(80,20)
  screen.move(80,20)
  screen.line(70,35)
  screen.stroke()
  screen.update()
end

function crane2()
  screen.level(3)
  screen.aa(1)
  screen.line_width(0.5)
  if track[1].poll_position < 10 then
    screen.move(100-(track[1].poll_position * 3),60-(track[2].poll_position))
  elseif track[1].poll_position < 40 then
    screen.move(100-(track[1].poll_position * 2),60-(track[2].poll_position))
  else
    screen.move(100-(track[1].poll_position),60-(track[2].poll_position))
  end
  if c2 > 30 then
    screen.text(" ^ ^ ")
  elseif c2 < 30 then
  screen.text(" v v ")
  else
    screen.text(" ^ ^ ")
  end
  screen.stroke()
  screen.update()
  c2 = math.random(29,31)
end

-- GRID --

-- hardware: grid connect
g = grid.connect()
-- hardware: grid event (eg 'what happens when a button is pressed')
g.key = function(x,y,z)
-- speed + direction
  if y == 1 and z == 1 then
    if x <= #speedlist_1 then
      params:set("speed_voice_1",x)
    elseif x == 13 then
      softcut.position(1,track[2].poll_position)
    elseif x == 14 then
      track[1].start_point = track[2].start_point
      softcut.loop_start(1,track[1].start_point)
      track[1].end_point = track[2].end_point
      softcut.loop_end(1,track[1].end_point)
    elseif x == 15 then
      softcut.position(1,track[1].start_point)
    end
    grid_dirty = true
  end
  if y == 5 and z == 1 then
    if x <=#speedlist_2 then
      params:set("speed_voice_2",x)
    elseif x == 13 then
      softcut.position(2,track[1].poll_position)
    elseif x == 14 then
      track[2].start_point = track[1].start_point
      softcut.loop_start(2,track[2].start_point)
      track[2].end_point = track[1].end_point
      softcut.loop_end(2,track[2].end_point)
    elseif x == 15 then
      softcut.position(2,track[2].start_point)
    end
    grid_dirty = true
  end
-- presets
  if y == 2 and z == 1 then
    if x < 14 and x < preset_count[1]+1 then
      preset_unpack(1, x)
      selected_preset[1] = x
    elseif x == 15 then
      presets_1 = {}
      preset_pool_1 = {}
      preset_count[1] = 0
      selected_preset[1] = 0
    elseif x == 16 then
      preset_pack(1)
      if preset_count[1] < 13 then
      preset_count[1] = preset_count[1] + 1
      end
    end
    grid_dirty = true
  end
  if y == 6 and z == 1 then
    if x < 14 and x < preset_count[2]+1 then
      preset_unpack(2, x)
      selected_preset[2] = x
    elseif x == 15 then
      presets_2 = {}
      preset_pool_2 = {}
      preset_count[2] = 0
      selected_preset[2] = 0
    elseif x == 16 then
      preset_pack(2)
      if preset_count[2] < 13 then
      preset_count[2] = preset_count[2] + 1
      end
    end
    grid_dirty = true
  end
-- start point, end point, window
  if y == 3 or 7 then
    if y == 3 and z == 1 then
      window(1,x)
    elseif y == 7 and z == 1 then
      window(2,x)
    end
  end
end

-- hardware: grid redraw
function grid_redraw()
  g:all(0)
  for i=1,preset_count[1] do
    g:led(i,2,5)
  end
  for i=1, preset_count[2] do
    g:led(i,6,5)
  end
  g:led(15,2,3)
  g:led(16,2,9)
  g:led(15,6,3)
  g:led(16,6,9)
  for i=1,#speedlist_1 do
    g:led(i,1,5)
  end
  for i=1,#speedlist_2 do
    g:led(i,5,5)
  end
  for i=13,15 do
    g:led(i,1,5)
    g:led(i,5,5)
  end
  if params:get("speed_voice_1") == 6 then
    g:led(6,1,12)
  else
    g:led(params:get("speed_voice_1"),1,12)
    g:led(6,1,0)
  end
  if params:get("speed_voice_2") == 6 then
    g:led(6,5,12)
  else
    g:led(params:get("speed_voice_2"),5,12)
    g:led(6,5,0)
  end
  if track[1].pos_grid >= 0 and pp < 1.000 then
    g:led(track[1].pos_grid+1,4,15)
  else
    for i = 1,16 do
      g:led(i,4,0)
    end
  end
  if track[2].pos_grid >= 0 and pp < 1.000 then
    g:led(track[2].pos_grid+1,8,15)
  else
    for i = 1,16 do
      g:led(i,8,0)
    end
  end
  if clear == 1 then
    for i = 1,16 do
      g:led(i,4,0)
      g:led(i,8,0)
    end
  end
  g:led(16,3,5)
  g:led(15,3,9)
  g:led(14,3,9)
  g:led(13,3,5)
  g:led(10,3,5)
  g:led(9,3,9)
  g:led(8,3,9)
  g:led(7,3,5)
  g:led(4,3,5)
  g:led(3,3,9)
  g:led(2,3,9)
  g:led(1,3,5)
  g:led(16,7,5)
  g:led(15,7,9)
  g:led(14,7,9)
  g:led(13,7,5)
  g:led(10,7,5)
  g:led(9,7,9)
  g:led(8,7,9)
  g:led(7,7,5)
  g:led(4,7,5)
  g:led(3,7,9)
  g:led(2,7,9)
  g:led(1,7,5)
  g:led(selected_preset[1],2,12)
  g:led(selected_preset[2],6,12)
  g:refresh()
end
