-- cranes
-- dual looper / delay
-- (grid optional)
-- v220324 @dan_derks
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

_params = include 'lib/params'
snapshot = include 'lib/snapshot'
chitter = include 'lib/chitter'
_ca = include 'lib/clip'

DATA_DIR = _path.data.."cranes/"
AUDIO_DIR = _path.audio.."cranes/"
TRACKS = 2

function r()
  norns.script.load(norns.state.script)
end

-- counting ms between key 2 taps
-- sets loop length
function count()
  for i = 1,4 do
    if rec[i] == 1 then
      rec_time[i] = rec_time[i] + 0.005
    end
  end
end

-- track recording state
rec = {0,0,0,0}
clear = {1,1,1,1}
offset = {1,1,1,1}
pp = {0,0,0,0}

snapshots = {
  [1] = {},
  [2] = {},
  [3] = {},
  [4] = {}
}
for i = 1,4 do
  for j = 1,12 do
    snapshots[i][j] = {}
  end
end
-- snapshots[voice][coll].start_point = track[voice].start_point
snapshot_count = {0,0,0,0}
selected_snapshot = {0,0,0,0}
snapshot_mod = {["index"] = 0, ["held"] = {false,false,false,false,false,false}}

softcut_offsets = {0,0,100,100}

track = {}
for i=1,4 do
  track[i] = {}
  track[i].start_point = 0 + softcut_offsets[i]
  track[i].end_point = 60 + softcut_offsets[i]
  track[i].poll_position = 0 + softcut_offsets[i]
  track[i].pos_grid = -1
  track[i].rec_limit = 0
  track[i].snapshot = {["partial_restore"] = false}
  track[i].reverse = false
end

distance = {0,0}

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
  softcut.buffer(3,1)
  softcut.buffer(4,2)
  softcut.enable(5,0)
  softcut.enable(6,0)
  
  for i = 1, 4 do
    softcut.level(i,1.0)
    softcut.play(i, 0) -- TODO CONFIRM GOOD
    softcut.rate(i, 1*offset[i])
    softcut.loop_start(i, softcut_offsets[i])
    softcut.loop_end(i, 60+softcut_offsets[i])
    softcut.loop(i, 1)
    softcut.fade_time(i, 0.01)
    softcut.rec(i, 1) -- TODO CONFIRM GOOD
    softcut.rec_level(i, 0)
    softcut.pre_level(i, 1)
    softcut.position(i, softcut_offsets[i])
    softcut.phase_quant(i, 0.01)
    softcut.rec_offset(i, -0.0003)
  end
 
  softcut.event_phase(phase)
  _ca.init()
  _params.init()
  
  counter = metro.init(count, 0.005, -1)
  rec_time = {0,0,0,0}

  KEY3_hold = false
  KEY1_hold = false
  KEY1_press = 0

  voice_on_screen = 1

  for i = 1,4 do
    clear_track(i)
  end

  hardware_redraw = metro.init(
    function()
      draw_hardware()
    end
    , 1/30, -1)
  hardware_redraw:start()

  grid_dirty = true
  screen_dirty = true
  
  -- softcut.poll_start_phase()

  -- softcut.pre_filter_dry(1,1)
  -- softcut.pre_filter_dry(2,1)
  -- softcut.pre_filter_dry(3,1)
  -- softcut.pre_filter_dry(4,1)

  -- dev
  for i = 1,4 do
    params:set("loop_sizing_voice_"..i, 2)
    params:set("rec_trigger_voice_"..i, 3)
    track[i].end_point = softcut_offsets[i]+8
    softcut.recpre_slew_time(i,0.01)
    softcut.enable(i,1)
  end
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

function phase(n, x)
  if track[n].playing then
    track[n].poll_position = x
    if rec[n] == 1 and clear[n] == 1 then
      if x > track[n].rec_limit then
        track[n].rec_limit = x
      end
    elseif rec[n] == 1 and clear[n] == 0 then
      if (x > track[n].rec_limit) and (track[n].end_point > track[n].rec_limit) then
        track[n].rec_limit = track[n].end_point
      end
    end
    pp[n] = ((x - track[n].start_point) / (track[n].end_point - track[n].start_point))
    x = math.floor(pp[n] * 8)
    if x ~= track[n].pos_grid then
      track[n].pos_grid = x
    end
    grid_dirty = true
    screen_dirty = true
  end
end

function warble()
  local bufSpeed = speedlist[voice_on_screen][params:get("speed_voice_"..voice_on_screen)]
  if bufSpeed > 1.99 then
      ray = bufSpeed + (math.random(-15,15)/1000)
    elseif bufSpeed >= 1.0 then
      ray = bufSpeed + (math.random(-10,10)/1000)
    elseif bufSpeed >= 0.50 then
      ray = bufSpeed + (math.random(-4,5)/1000)
    else
      ray = bufSpeed + (math.random(-2,2)/1000)
  end
  softcut.rate_slew_time(voice_on_screen,0.6 + (math.random(-30,10)/100))
end

function half_speed()
  ray = speedlist[voice_on_screen][params:get("speed_voice_"..voice_on_screen)] / 2
  softcut.rate_slew_time(voice_on_screen,0.6 + (math.random(-30,10)/100))
end

function rev_speed()
  ray = speedlist[voice_on_screen][params:get("speed_voice_"..voice_on_screen)] * -1
  softcut.rate_slew_time(voice_on_screen,0.01)
end

function oneandahalf_speed()
  ray = speedlist[voice_on_screen][params:get("speed_voice_"..voice_on_screen)] * 1.5
  softcut.rate_slew_time(voice_on_screen,0.6 + (math.random(-30,10)/100))
end

function double_speed()
  ray = speedlist[voice_on_screen][params:get("speed_voice_"..voice_on_screen)] * 2
  softcut.rate_slew_time(voice_on_screen,0.6 + (math.random(-30,10)/100))
end

function restore_speed()
  ray = speedlist[voice_on_screen][params:get("speed_voice_"..voice_on_screen)]
  if params:get("KEY3") == 2 then
    softcut.rate_slew_time(voice_on_screen,0.01)
  else
    softcut.rate_slew_time(voice_on_screen,0.6)
  end
  softcut.rate(voice_on_screen,speedlist[voice_on_screen][params:get("speed_voice_"..voice_on_screen)]*offset[voice_on_screen])
end

function clear_track(_t)
  local scaled = {
    -- {buffer, start, end}
    {1,0,60},
    {params:get("voice_2_buffer"),0,60},
    {1,softcut_offsets[3],60 + softcut_offsets[3]},
    {2,softcut_offsets[4],60 + softcut_offsets[4]},
  }
  softcut.rec_level(_t, 0)
  softcut.level(_t, 0)
  softcut.play(_t, 0)
  track[_t].playing = false
  softcut.position(_t, scaled[_t][2])
  softcut.rate(_t, 1*offset[_t])
  softcut.loop_start(_t, scaled[_t][2])
  softcut.loop_end(_t, scaled[_t][3])
  softcut.position(_t, scaled[_t][2])
  softcut.enable(_t, 0)
  track[_t].rec_limit = 0
  softcut.buffer_clear_region_channel(scaled[_t][1],scaled[_t][2],60)

  ray = speedlist[1][params:get("speed_voice_1")] -- TODO FIX
  
  track[_t].start_point = scaled[_t][2]
  track[_t].end_point = scaled[_t][3]

  clear[_t] = 1
  rec_time[_t] = 0
  rec[_t] = 0
  recording_crane[_t] = 0
  overdub_crane[_t] = 0

  c2 = math.random(4,15) -- TODO FIX
  restore_speed()
  -- TODO FIX:
  -- for i = 1,16 do
  --   g:led(i,4,0)
  --   g:led(i,8,0)
  -- end
  g:refresh()
  screen_dirty = true
  KEY3_hold = false
  params:set("offset_".._t,0) -- TODO VERIFY IF NEEDED...
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

function record(_t,silent)

  if params:string("rec_trigger_voice_".._t) == "clock" then
    if rec[_t] == 0 and clear[_t] == 1 then
      holding_crane[_t]= 1
      screen_dirty = true
      clock.run(
        function()
          -- clock.sync(4,-1/16)
          clock.sync(4)
          record_execute(_t,silent)
          holding_crane[_t] = 0
        end
      )
    end
  else
    record_execute(_t,silent)
    holding_crane[_t] = 0
  end

end

function record_execute(_t,silent)
  if not silent then
    rec[_t] = rec[_t] == 0 and 1 or 0
  end
  -- if the buffer is clear and recording is enabled:
  -- main recording will enable
  if rec[_t] == 1 and clear[_t] == 1 then
    local scaled = {
      -- {buffer, start, end}
      {1,0},
      {params:get("voice_2_buffer"),0},
      {1,softcut_offsets[3]},
      {2,softcut_offsets[4]}
    }
    -- softcut.buffer_clear_region_channel(scaled[_t][1],scaled[_t][2],60)
    softcut.position(_t,track[_t].start_point)
    softcut.rate_slew_time(_t,0.01)
    -- softcut.enable(_t, 1)
    softcut.rate(_t, 1*offset[_t])
    softcut.play(_t, 1)
    -- softcut.rec(_t, 1)
    softcut.rec_level(_t,1)
    softcut.level(_t, 0)
    softcut.poll_start_phase()
    track[_t].playing = true
    recording_crane[_t] = 1
    screen_dirty = true
    counter:start()
  -- if the buffer is clear and key 2 is pressed again:
  -- main recording will disable, loop points set
  elseif rec[_t] == 0 and clear[_t] == 1 then
    clear[_t] = 0
    softcut.position(_t,track[_t].start_point)
    softcut.rec_level(_t,0)
    counter:stop()
    softcut.poll_start_phase()
    track[_t].playing = true
    -- track[_t].end_point = util.round(softcut_offsets[_t] + rec_time[_t],0.01)
    if params:string("loop_sizing_voice_".._t) == "dialed (w/encoders)" then
      -- track[_t].end_point = (softcut_offsets[_t] + rec_time[_t])
    else
      track[_t].end_point = (softcut_offsets[_t] + rec_time[_t])
    end
    print(_t,track[_t].end_point)
    softcut.loop_end(_t,track[_t].end_point)
    softcut.loop_start(_t,track[_t].start_point)
    -- track[2].start_point = 0
    recording_crane[_t] = 0
    screen_dirty = true
    rec_time[_t] = 0
    softcut.level(_t,params:get("vol_".._t))
    softcut.rate(_t,speedlist[_t][params:get("speed_voice_".._t)]*offset[_t])
    if track[_t].end_point > track[_t].rec_limit then
      track[_t].rec_limit = track[_t].end_point
    end
  end
  -- if the buffer is NOT clear and key 2 is pressed:
  -- overwrite/overdub behavior will enable
  if rec[_t] == 1 and clear[_t] == 0 then
    toggle_overdub(_t,"on")
  -- if the buffer is NOT clear and key 2 is pressed again:
  -- overwrite/overdub behavior will disable
  elseif rec[_t] == 0 and clear[_t] == 0 then
    toggle_overdub(_t,"off")
  end

  if params:string("loop_sizing_voice_".._t) == "dialed (w/encoders)" then
    print("eval loop")
    if rec[_t] == 1 and clear[_t] == 1 then
      clock.run(
        function()
          clock.sleep(track[_t].end_point - track[_t].start_point)
          print("yep")
          record_execute(_t)
        end
      )
    end
  end
end

function toggle_overdub(_t,state)
  if state == "on" then
    rec[_t] = 1
    softcut.rec_level(_t,1)
    softcut.pre_level(_t,math.abs(over[_t]-1))
    recording_crane[_t] = 1
    overdub_crane[_t] = 1
    -- if track[_t].end_point > track[_t].rec_limit then
    --   track[_t].rec_limit = track[_t].end_point
    -- end
  else
    rec[_t] = 0
    softcut.rec_level(_t,0)
    softcut.pre_level(_t,1)
    recording_crane[_t] = 0
    overdub_crane[_t] = 0
  end
  screen_dirty = true
end

-- variable dump
down_time = 0
hold_time = 0
speedlist = {
  {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4},
  {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4},
  {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4},
  {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4}
}
over = {0,0,0,0}
ray = 0.0
KEY3 = 1
recording_crane = {0,0,0,0}
overdub_crane = {0,0,0,0}
holding_crane = {0,0,0,0}
c2 = math.random(4,12)

-- key hardware interaction
function key(n,z)
  
  -- KEY 2
  if n == 2 and z == 1 then
    if voice_on_screen == 1 or voice_on_screen == 2 then
      if voice_on_screen == 1 and clear[1] == 0 then
        record(1)
      elseif voice_on_screen == 2 and clear[2] == 0 then
        record(2)
      elseif (voice_on_screen == 1 or voice_on_screen == 2) and (clear[1] == 1 and clear[2] == 1) then
        record(1)
        record(2)
      end
    else
      record(voice_on_screen)
    end
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
    softcut.rate(voice_on_screen,ray*offset[voice_on_screen])
  end

  -- KEY 1
  -- hold key 1 + key 3 to clear the buffers
  if n == 1 and z == 1 and KEY3_hold == true then
    clear_track(voice_on_screen)
    KEY1_hold = false
  elseif n == 1 and z == 1 then
    KEY1_press = KEY1_press + 1
    -- if rec[voice_on_screen] % 2 == 1 then
    --   rec[voice_on_screen] = 0
    --   if KEY1_press % 2 == 1 then
    --     softcut.rec_level(1,0)
    --     softcut.pre_level(1,1)
    --   elseif KEY1_press % 2 == 0 then
    --     softcut.rec_level(2,0)
    --     softcut.pre_level(2,1)
    --   end
    --   recording_crane[voice_on_screen] = 0
    --   overdub_crane[voice_on_screen] = 0
    --   screen_dirty = true
    -- end
    KEY1_hold = true
    screen_dirty = true
  elseif n == 1 and z == 0 then
    KEY1_hold = false
    screen_dirty = true
  end
end

-- encoder hardware interaction
function enc(n,d)
  -- local _t = KEY1_press % 2 == 0 and 1 or 2
  local _t = voice_on_screen
  -- encoder 3: voice 1's loop end point
  if n == 3 then
    if (math.abs(d) == 1) then
      d = d > 0 and 1/100 or -1/100
    else
      d = d > 0 and 1/10 or -1/10
    end
    track[_t].end_point = util.clamp((util.round(track[_t].end_point + d,0.01)), 0 + softcut_offsets[_t], 60 + softcut_offsets[_t])
    softcut.loop_end(_t,track[_t].end_point)

  -- encoder 2: voice 1's loop start point
  elseif n == 2 then
    if (math.abs(d) == 1) then
      d = d > 0 and 1/100 or -1/100
    else
      d = d > 0 and 1/10 or -1/10
    end
    track[_t].start_point = util.clamp((util.round(track[_t].start_point + d,0.01)), 0  + softcut_offsets[_t], 60  + softcut_offsets[_t])
    softcut.loop_start(_t,track[_t].start_point)

  -- encoder 1: voice 1's overwrite/overdub amount
  -- 0 is full overdub
  -- 1 is full overwrite
  elseif n == 1 then
    if KEY1_hold then
      voice_on_screen = util.clamp(voice_on_screen + d, 1, 4)
    else
      over[_t] = util.round(util.clamp((over[_t] + d/100), 0.0,1.0),0.01)
      if rec[voice_on_screen] % 2 == 1 then
        softcut.pre_level(_t,math.abs(over[_t]-1))
      end
    end
  end
  screen_dirty = true
  grid_dirty = true
end

-- displaying stuff on the screen
function redraw()
  screen.clear()
  if KEY1_hold then
    screen.font_size(22)
    for i = 1,4 do
      screen.move(10 + (20*i),35)
      screen.level(voice_on_screen == i and 15 or 4)
      screen.text_center(i)
    end
    screen.font_size(8)
    screen.move(64,50)
    screen.level(6)
    if voice_on_screen == 1 or voice_on_screen == 2 then
      screen.text_center("1 and 2 are")
      screen.move(64,58)
      screen.text_center("linked, live loopers")
    else
      screen.text_center("3 and 4 are")
      screen.move(64,58)
      screen.text_center("independent loopers/samplers")
    end
  else
    screen.font_size(8)
    screen.level(15)
    screen.move(0,50)
    -- local _t = KEY1_press % 2 == 0 and 1 or 2
    local _t = voice_on_screen
    screen.text("s".._t..": "..util.round(track[_t].start_point - softcut_offsets[_t],0.01).."s")
    screen.move(0,60)
    screen.text("e".._t..": "..util.round(track[_t].end_point - softcut_offsets[_t],0.01).."s")
    screen.move(0,40)
    screen.text("o".._t..": "..over[_t])
    if recording_crane[_t] == 1 then
      if overdub_crane[_t] == 0 then
        crane()
      else
        crane2()
      end
    end
    if holding_crane[_t] == 1 then
      screen.move(40,35)
      screen.text("WAITING FOR BEAT")
    end
    screen.level(3)
    screen.move(0,10)
    if voice_on_screen == 1 or voice_on_screen == 2 then
      screen.text("one: "..util.round(track[1].poll_position,0.1).."s")
      screen.move(0,20)
      screen.text("two: "..util.round(track[2].poll_position,0.1).."s")
    else
      screen.text((_t == 3 and "three: " or "four: ")..util.round(track[_t].poll_position - softcut_offsets[_t],0.1).."s")
    end
  end
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

if y >= 5 and y <= 8 and x <= 8 and z == 1 then
  local _t = y-4
  if rec[_t] == 0 or (rec[_t] == 1 and clear[_t] == 0) then
    local _block = (track[_t].end_point - track[_t].start_point) / 8
    local _cutposition = _block * (x-1) + softcut_offsets[_t]
    if params:string("chittering_mode_".._t) ~= "off" then
      chitter_stretch[_t].pos = _cutposition
    else
      softcut.position(_t,_cutposition)
    end
  end
elseif y >= 1 and y <= 4 and x <=6 and z == 1 then
  local _t = y
  if rec[_t] == 0 or (rec[_t] == 1 and clear[_t] == 0) then
    if not track[_t].reverse then
      params:set("speed_voice_".._t,x+5)
    else
      local reverse_key = {6,5,4,3,2,1}
      params:set("speed_voice_".._t,reverse_key[x])
    end
  end
elseif y >= 1 and y <= 4 and x == 7 and z == 1 then
  local _t = y
  if rec[_t] == 0 or (rec[_t] == 1 and clear[_t] == 0) then
    track[_t].reverse = not track[_t].reverse
    local reverse_current = {11,10,9,8,7,6,5,4,3,2,1}
    params:set("speed_voice_".._t,reverse_current[params:get("speed_voice_".._t)])
  end
elseif y >= 1 and y <= 4 and x == 8 and z == 1 then
  local _t = y
  record(_t)
elseif y >= 1 and y <= 4 and x >= 11 then
  local _t = y
  if z == 1 then
    if x >= 11 then
      x = x-10
      if tab.count(snapshots[_t][x]) == 0 then
        track[_t].snapshot.saver_clock = clock.run(snapshot.save_to_slot,_t,x)
        -- track[_t].snapshot_mod_index = i
      else
        -- local modifier, style = 0,"beats"
        -- if track[_t].restore_mod then
        --   modifier =  track[_t].snapshot[i].restore_times[track[_t].snapshot[i].restore_times.mode][track[_t].restore_mod_index]
        --   style = track[_t].snapshot[i].restore_times.mode
        -- end
        if snapshot_mod.index == 0 then
          snapshot.unpack(_t,x)
        else
          try_it(_t,x,snapshot_mod.index,"sec")
        end
        -- track[_t].snapshot_mod_index = i
      end
    end
  else
    if track[_t].snapshot.saver_clock ~= nil then
      clock.cancel(track[_t].snapshot.saver_clock)
    end
  end
elseif y == 5 and x >= 11 and x <= 16 then
  if z == 0 then
    snapshot_mod.held[x-10] = false
    if tab.contains(snapshot_mod.held,true) then
    else
      snapshot_mod.index = 0
    end
  else
    snapshot_mod.held[x-10] = true
    snapshot_mod.index = x-10
  end
elseif y == 8 and x >= 13 and x <= 16 and z == 1 then
  local _t = x-12
  voice_on_screen = _t
  screen_dirty = true
end

-- speed + direction
--   if (y == 1 or y == 5) and z == 1 then
--     local _t = y == 1 and 1 or 2
--     if x <= #speedlist[_t] then
--       params:set("speed_voice_".._t,x)
--     elseif x == 13 then
--       local other_track = _t == 1 and 2 or 1
--       softcut.position(_t,track[other_track].poll_position)
--     elseif x == 14 then
--       local other_track = _t == 1 and 2 or 1
--       track[_t].start_point = track[other_track].start_point
--       softcut.loop_start(_t,track[_t].start_point)
--       track[_t].end_point = track[other_track].end_point
--       softcut.loop_end(_t,track[_t].end_point)
--     elseif x == 15 then
--       softcut.position(_t,track[_t].start_point)
--     end
--     grid_dirty = true
-- -- snapshots
--   elseif (y == 2 or y == 6) then
--     local _t = y == 2 and 1 or 2
--     if z == 1 then
--       if x <= 8 then
--         if tab.count(snapshots[_t][x]) == 0 then
--           track[_t].snapshot.saver_clock = clock.run(snapshot.save_to_slot,_t,x)
--           -- track[_t].snapshot_mod_index = i
--         else
--           -- local modifier, style = 0,"beats"
--           -- if track[_t].restore_mod then
--           --   modifier =  track[_t].snapshot[i].restore_times[track[_t].snapshot[i].restore_times.mode][track[_t].restore_mod_index]
--           --   style = track[_t].snapshot[i].restore_times.mode
--           -- end
--           snapshot.unpack(_t,x)
--           -- track[_t].snapshot_mod_index = i
--         end
--       end
--     else
--       if track[_t].snapshot.saver_clock ~= nil then
--         clock.cancel(track[_t].snapshot.saver_clock)
--       end
--     end
--     grid_dirty = true
-- -- start point, end point, window
--   elseif (y == 3 or y == 7) and z == 1 then
--     window(y == 3 and 1 or 2, x)
  grid_dirty = true
end

-- hardware: grid redraw
function grid_redraw()
  g:all(0)

  for i = 11,16 do
    for j = 1,4 do
      local _t = j
      g:led(i,j,tab.count(snapshots[_t][i-10]) > 0 and 6 or 3)
      if selected_snapshot[_t] ~= 0 then
        g:led(selected_snapshot[_t]+10,j,12)
      end
    end
  end

  for j = 5,8 do
    for i = 1,8 do
      g:led(i,j,1)
    end
    local _t = j-4
    if track[_t].pos_grid >= 0 and pp[_t] < 1.000 then
      g:led(track[_t].pos_grid+1,j,15)
    end
  end

  for i = 1,4 do
    for j = 1,6 do
      g:led(j,i,3)
    end
    local _t = i
    if params:get("speed_voice_".._t) == 6 then
      g:led(1,i,12)
    elseif params:get("speed_voice_".._t) > 6 then
      g:led(params:get("speed_voice_".._t)-5,i,12)
      g:led(1,i,0)
    elseif params:get("speed_voice_".._t) < 6 then
      local reverse_led = {6,5,4,3,2}
      g:led(reverse_led[params:get("speed_voice_".._t)],i,12)
      g:led(1,i,0)
    end
    g:led(7,i,track[_t].reverse and 15 or 0)
    g:led(8,i,rec[_t] == 1 and 15 or (clear[_t] == 0 and 8 or 3) or 3)
  end

  for i = 1,4 do
    g:led(i+12,8,voice_on_screen == i and 12 or 3)
  end
  
  -- for i=1, snapshot_count[2] do
  --   g:led(i,6,5)
  -- end
  -- g:led(15,2,3)
  -- g:led(16,2,9)
  -- g:led(15,6,3)
  -- g:led(16,6,9)
  -- for i=13,15 do
  --   g:led(i,1,5)
  --   g:led(i,5,5)
  -- end

  -- if clear == 1 then
  --   for i = 1,16 do
  --     g:led(i,4,0)
  --     g:led(i,8,0)
  --   end
  -- end
  -- g:led(16,3,5)
  -- g:led(15,3,9)
  -- g:led(14,3,9)
  -- g:led(13,3,5)
  -- g:led(10,3,5)
  -- g:led(9,3,9)
  -- g:led(8,3,9)
  -- g:led(7,3,5)
  -- g:led(4,3,5)
  -- g:led(3,3,9)
  -- g:led(2,3,9)
  -- g:led(1,3,5)
  -- g:led(16,7,5)
  -- g:led(15,7,9)
  -- g:led(14,7,9)
  -- g:led(13,7,5)
  -- g:led(10,7,5)
  -- g:led(9,7,9)
  -- g:led(8,7,9)
  -- g:led(7,7,5)
  -- g:led(4,7,5)
  -- g:led(3,7,9)
  -- g:led(2,7,9)
  -- g:led(1,7,5)
  -- g:led(selected_snapshot[1],2,12)
  -- g:led(selected_snapshot[2],6,12)
  g:refresh()
end