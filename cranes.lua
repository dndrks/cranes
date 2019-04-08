-- cranes
-- dual looper / delay
-- v2.0.1 @dan_derks
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
-- \\\\

-- counting ms between key 2 taps
-- sets loop length
function count()
  rec_time = rec_time + 0.01
end

-- track recording state
rec = 0

function init()
  softcut.buffer_clear()
  audio.level_cut(1)
  audio.level_adc_cut(1)
  audio.level_eng_cut(0)
  softcut.level(1,1.0)
  softcut.level(2,1.0)
  softcut.level_input_cut(1, 1, 1.0)
  softcut.level_input_cut(1, 2, 0.0)
  softcut.level_input_cut(2, 1, 0.0)
  softcut.level_input_cut(2, 2, 1.0)
  softcut.pan(1, 0.7)
  softcut.pan(2, 0.3)

  softcut.play(1, 1)
  softcut.rate(1, 1)
  softcut.loop_start(1, 0)
  softcut.loop_end(1, 60)
  softcut.loop(1, 1)
  softcut.fade_time(1, 0.1)
  softcut.rec(1, 1)
  softcut.rec_level(1, 1)
  softcut.pre_level(1, 1)
  softcut.position(1, 0)
  
  softcut.play(2, 1)
  softcut.rate(2, 1)
  softcut.loop_start(2, 0)
  softcut.loop_end(2, 60)
  softcut.loop(2, 1)
  softcut.fade_time(2, 0.1)
  softcut.rec(2, 1)
  softcut.rec_level(2, 1)
  softcut.pre_level(2, 1)
  softcut.position(2, 0)
  
  softcut.phase_quant(1,0.1)
  softcut.phase_quant(2,0.1)
  softcut.event_phase(phase)

  params:add_option("speed_voice_1","speed voice 1", speedlist)
  params:set("speed_voice_1", 7)
  params:set_action("speed_voice_1", function(x) softcut.rate(1, speedlist[params:get("speed_voice_1")]) end)
  params:add_option("speed_voice_2","speed voice 2", speedlist_2)
  params:set_action("speed_voice_2",
    function(x)
      softcut.rate(2, speedlist_2[params:get("speed_voice_2")])
      is_speed_negative()
    end)
  params:set("speed_voice_2", 7)
  params:add_separator()
  params:add_control("vol_1","vol voice 1",controlspec.new(0,5,'lin',0,5,''))
  params:set_action("vol_1", function(x) softcut.level(1, x) end)
  params:set("vol_1", 1.0)
  params:add_control("vol_2","vol voice 2",controlspec.new(0,5,'lin',0,5,''))
  params:set_action("vol_2", function(x) softcut.level(2, x) end)
  params:set("vol_2", 1.0)
  params:add_separator()
  params:add_control("pan_1","pan voice 1",controlspec.new(0,1,'lin',0,1,''))
  params:set_action("pan_1", function(x) softcut.pan(1, x) end)
  params:set("pan_1", 0.7)
  params:add_control("pan_2","pan voice 2",controlspec.new(0,1,'lin',0,1,''))
  params:set_action("pan_2", function(x) softcut.pan(2, x) end)
  params:set("pan_2", 0.3)
  params:add_separator()
  params:add_number("KEY3","KEY3 ( ~~, 0.5, 1.5, 2 )",0,3,0)
  params:set_action("KEY3", function(x) KEY3 = x end)
  
  counter = metro.init(count, 0.01, -1)
  rec_time = 0

  KEY3_hold = false
  KEY1_hold = false
  KEY1_press = 0
  local edit_mode = 2
  poll_position_1 = 0
  poll_position_2 = 0
  flying = 0
  clear_all()
end

phase = function(n, x)
  if n == 1 then
    poll_position_1 = x
  elseif n == 2 then
    poll_position_2 = x
  end
  redraw()
end

function is_speed_negative()
  if params:get("speed_voice_2") < 5 then
    neg_start = 0.2
    neg_end = 0.4
    if start_point_2 < 0.2 then
      start_point_2 = 0.2
      softcut.loop_start(2,0.2)
    end
    if end_point_2 < 0.5 then
      end_point_2 = 0.5
      softcut.loop_end(2,0.5)
    end
  else
    neg_start = 0.0
    neg_end = 0.0
  end
end

function warble()
  local bufSpeed1 = speedlist[params:get("speed_voice_1")]
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
    softcut.rate(1,ray)
    screen.move(0,30)
    screen.text(ray)
    screen.update()
end

function half_speed()
  ray = speedlist[params:get("speed_voice_1")] / 2
  softcut.rate_slew_time(1,0.6 + (math.random(-30,10)/100))
  softcut.rate(1,ray)
  screen.move(0,30)
  screen.text(ray)
  screen.update()
end

function oneandahalf_speed()
  ray = speedlist[params:get("speed_voice_1")] * 1.5
  softcut.rate_slew_time(1,0.6 + (math.random(-30,10)/100))
  softcut.rate(1,ray)
  screen.move(0,30)
  screen.text(ray)
  screen.update()
end

function double_speed()
  ray = speedlist[params:get("speed_voice_1")] * 2
  softcut.rate_slew_time(1,0.6 + (math.random(-30,10)/100))
  softcut.rate(1,ray)
  screen.move(0,30)
  screen.text(ray)
  screen.update()
end

function restore_speed()
  ray = speedlist[params:get("speed_voice_1")]
  softcut.rate_slew_time(1,0.6)
  softcut.rate(1,speedlist[params:get("speed_voice_1")])
  redraw()
end

function clear_all()
  softcut.poll_stop_phase()
  softcut.rec_level(1,1)
  softcut.rec_level(2,1)
  softcut.play(1,0)
  softcut.play(2,0)
  softcut.rate(1, 1)
  softcut.rate(2, 1)
  softcut.buffer_clear()
  ray = speedlist[params:get("speed_voice_1")]
  softcut.loop_start(1,0)
  softcut.loop_end(1,60)
  softcut.loop_start(2,0)
  softcut.loop_end(2,60)
  start_point_1 = 0
  start_point_2 = 0
  end_point_1 = 60
  end_point_2 = 60
  clear = 1
  rec_time = 0
  rec = 0
  crane_redraw = 0
  crane2_redraw = 0
  c2 = math.random(4,15)
  restore_speed()
  redraw()
  KEY3_hold = false
  softcut.position(1, 0)
  softcut.position(2, 0)
  softcut.enable(1,0)
  softcut.enable(2,0)
end

-- variable dump
down_time = 0
hold_time = 0
speedlist = {-2.0, -1.0, -0.5, -0.25, 0.25, 0.5, 1.0, 2.0, 4.0}
speedlist_2 = {-2.0, -1.0, -0.5, -0.25, 0.25, 0.5, 1.0, 2.0, 4.0}
start_point_1 = 0
start_point_2 = 0
end_point_1 = 60
end_point_2 = 60
over = 0
clear = 1
ray = 0.0
KEY3 = 0
crane_redraw = 0
crane2_redraw = 0
c2 = math.random(4,12)

-- key hardware interaction
function key(n,z)
  -- KEY 2
  if n == 2 and z == 1 then
      rec = rec + 1
        -- if the buffer is clear and key 2 is pressed:
        -- main recording will enable
        if rec % 2 == 1 and clear == 1 then
          softcut.buffer_clear()
          softcut.rate_slew_time(1,0.1)
          softcut.enable(1,1)
          softcut.enable(2,1)
          softcut.rate(1,1)
          softcut.rate(2,1)
          softcut.play(1,1)
          softcut.play(2,1)
          softcut.rec(1,1)
          softcut.rec(2,1)
          softcut.level(1,0)
          softcut.level(2,0)
          crane_redraw = 1
          redraw()
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
          end_point_1 = rec_time
          softcut.loop_end(1,end_point_1)
          -- voice 2's end point needs to adapt to the buffer size to avoid BOOM
            if end_point_1 > 0.5 then
              end_point_2 = end_point_1
            elseif end_point_1 > 0.25 then
              end_point_2 = 0.2 + end_point_1
            else
              end_point_2 = 0.3 + end_point_1
            end
          softcut.loop_end(2,end_point_2)
          softcut.loop_start(2,0)
          start_point_2 = 0
          crane_redraw = 0
          redraw()
          rec_time = 0
          softcut.level(1,1)
          softcut.level(2,1)
          softcut.rate(1,speedlist[params:get("speed_voice_1")])
          softcut.rate(2,speedlist_2[params:get("speed_voice_2")])
        end
        -- if the buffer is NOT clear and key 2 is pressed:
        -- overwrite/overdub behavior will enable
        if rec % 2 == 1 and clear == 0 and KEY1_press % 2 == 0 then
          softcut.rec_level(1,1)
          softcut.pre_level(1,math.abs(over-1))
          crane_redraw = 1
          crane2_redraw = 1
          redraw()
        -- if the buffer is NOT clear and key 2 is pressed again:
        -- overwrite/overdub behavior will disable
        elseif rec % 2 == 0 and clear == 0 and KEY1_press % 2 == 0 then
          softcut.rec_level(1,0)
          softcut.pre_level(1,1)
          crane_redraw = 0
          crane2_redraw = 0
          redraw()
        elseif rec % 2 == 1 and clear == 0 and KEY1_press % 2 == 1 then
          softcut.rec_level(2,1)
          softcut.pre_level(2,math.abs(over-1))
          crane_redraw = 1
          crane2_redraw = 1
          redraw()
        elseif rec % 2 == 0 and clear == 0 and KEY1_press % 2 == 1 then
          softcut.rec_level(2,0)
          softcut.pre_level(2,1)
          crane_redraw = 0
          crane2_redraw = 0
          redraw()
        end
  end

  -- KEY 3
  -- all based on Parameter choice
  if n == 3 and z == 1 and KEY3 == 0 then
    KEY3_hold = true
    warble()
  elseif n == 3 and z == 1 and KEY3 == 1 then
    KEY3_hold = true
    half_speed()
  elseif n == 3 and z == 1 and KEY3 == 2 then
    KEY3_hold = true
    oneandahalf_speed()
  elseif n == 3 and z == 1 and KEY3 == 3 then
    KEY3_hold = true
    double_speed()
  elseif n == 3 and z == 0 then
    KEY3_hold = false
    restore_speed()
  end

  -- KEY 1
  -- hold key 1 + key 3 to clear the buffers
  if n == 1 and z == 1 and KEY3_hold == true then
    clear_all()
    KEY1_hold = false
  elseif n == 1 and z == 1 then
    KEY1_press = KEY1_press + 1
    if KEY1_press % 2 == 1 and rec % 2 == 1 then
      rec = 0
      softcut.rec_level(1,0)
      softcut.pre_level(1,1)
      crane_redraw = 0
      crane2_redraw = 0
      redraw()
    elseif KEY1_press % 2 == 0 and rec % 2 == 1 then
      rec = 0
      softcut.rec_level(2,0)
      softcut.pre_level(2,1)
      crane_redraw = 0
      crane2_redraw = 0
      redraw()
    end
    KEY1_hold = true
    redraw()
  elseif n == 1 and z == 0 then
    KEY1_hold = false
    redraw()
  end
end

-- encoder hardware interaction
function enc(n,d)

  -- encoder 3: voice 1's loop end point
  if n == 3 and KEY1_press % 2 == 0 then
    end_point_1 = util.clamp((end_point_1 + d/10),0.0,60.0)
    --print("voice 1 loop end "..end_point_1)
    softcut.loop_end(1,end_point_1)
    redraw()

  -- encoder 2: voice 1's loop start point
  elseif n == 2 and KEY1_press % 2 == 0 then
    start_point_1 = util.clamp((start_point_1 + d/10),0.0,60.0)
    --print("voice 1 loop start "..start_point_1)
    softcut.loop_start(1,start_point_1)
    redraw()

-- encoder 3: voice 2's loop end point
  elseif n == 3 and KEY1_press % 2 == 1 then
    end_point_2 = util.clamp((end_point_2 + d/10),neg_end,60.0)
    --print("voice 2 loop end "..end_point_2)
    softcut.loop_end(2,end_point_2)
    redraw()

-- encoder 2: voice 2's loop start point
  elseif n == 2 and KEY1_press % 2 == 1 then
    start_point_2 = util.clamp((start_point_2 + d/10),neg_start,60.0)
    --print("voice 2 loop start "..start_point_2)
    softcut.loop_start(2,start_point_2)
    redraw()

  -- encoder 1: voice 1's overwrite/overdub amount
  -- 0 is full overdub
  -- 1 is full overwrite
  elseif n == 1 then
    over = util.clamp((over + d/100), 0.0,1.0)
    if KEY1_press % 2 == 0 and rec % 2 == 1 then
      softcut.pre_level(1,math.abs(over-1))
    elseif KEY1_press % 2 == 1 and rec % 2 == 1 then
      softcut.pre_level(2,math.abs(over-1))
    end
    redraw()
  end
end

-- displaying stuff on the screen
function redraw()
  screen.clear()
  screen.level(15)
  screen.move(0,50)
    if KEY1_press % 2 == 1 then
      screen.text("s2: "..start_point_2)
    elseif KEY1_press % 2 == 0 then
      screen.text("s1: "..start_point_1)
    end
  screen.move(0,60)
    if KEY1_press % 2 == 1 then
      screen.text("e2: "..math.ceil(end_point_2 * (10^2))/(10^2))
    elseif KEY1_press % 2 == 0 then
      screen.text("e1: "..math.ceil(end_point_1 * (10^2))/(10^2))
    end
  screen.move(0,40)
  screen.text("over: "..over)
  if crane_redraw == 1 then
    if crane2_redraw == 0 then
      crane()
    else
      crane2()
    end
  end
  screen.level(3)
  screen.move(0,10)
  screen.text("one: "..math.floor(poll_position_1*10)/10)
  screen.move(0,20)
  screen.text("two: "..math.floor(poll_position_2*10)/10)
  screen.update()
  end

-- ALL JUST CRANE DRAWING FROM HERE TO END!
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
  if poll_position_1 < 10 then
    screen.move(100-(poll_position_1 * 3),60-(poll_position_2))
  elseif poll_position_1 < 40 then
    screen.move(100-(poll_position_1 * 2),60-(poll_position_2))
  else
    screen.move(100-(poll_position_1),60-(poll_position_2))
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
