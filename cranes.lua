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
_lfos = include 'lib/lfos'
_flow = include 'lib/flow'
_song = include 'lib/song'
_time = include 'lib/time'
_ea = include 'lib/enc_actions'
_pat = include 'lib/patterns'
_loop = include 'lib/loop'
_cue = include 'lib/queue'
_transport = include 'lib/transport'
_pt = include 'lib/cranes_pt'

-- engine.name="SimpleDelay"
osc.event = osc_in

DATA_DIR = _path.data.."cranes/"
AUDIO_DIR = _path.audio.."cranes/"
TRACKS = 2
grid_alt = false

function r()
  norns.script.load(norns.state.script)
end

-- track recording state
rec = {false,false,false,false}
rec_queued = {false,false,false,false}
clear = {true,true,true,true}
offset = {1,1,1,1}
pp = {0,0,0,0}

snapshots = {}
for i = 1,4 do
  snapshots[i] = {}
  for j = 1,12 do
    snapshots[i][j] = {}
    snapshots[i][j].restore = {
      rate = true,
      rate_ramp = false,
      start_point = true,
      end_point = true,
      vol = true,
      pan = true,
      post_filter_fc = true,
      lfo = true
    }
  end
end
-- snapshots[voice][coll].start_point = track[voice].start_point
snapshot_count = {0,0,0,0}
selected_snapshot = {0,0,0,0}
snapshot_mod = {["index"] = 0, ["held"] = {false,false,false,false,false,false}}

softcut_offsets = {1,1,101,201}
global_duration = 60

track = {}
for i=1,4 do
  track[i] = {}
  track[i].start_point = 0 + softcut_offsets[i]
  track[i].end_point = global_duration + softcut_offsets[i]
  track[i].poll_position = 0 + softcut_offsets[i]
  track[i].queued = {
    start_point = 0 + softcut_offsets[i],
    end_point = global_duration + softcut_offsets[i],
    position = 0 + softcut_offsets[i]
  }
  track[i].pos_grid = -1
  track[i].rec_limit = 0
  track[i].snapshot = {["partial_restore"] = false}
  track[i].snapshot.restore_times = {["beats"] = {1,2,4,8,16,32,64,128}, ["time"] = {1,2,4,8,16,32,64,128}, ["mode"] = "beats"}
  track[i].snapshot.mod_index = 0
  track[i].snapshot.focus = 1
  track[i].reverse = false
  track[i].clear_count = -1
end

distance = {0,0}
quantize_events = {}
quantize = 1

function grid.add(dev)
  grid_dirty = true
end

-- counting ms between key 2 taps
-- sets loop length
for i = 1,4 do
  _G["count_"..i] = 
  function()
    if rec[i] then
      rec_time[i] = rec_time[i] + 0.005
    end
  end
end

function set_softcut_param(param,args,val)
  if param == 'level_input_cut' then
    
  elseif param == 'level_cut_cut' then
    softcut[param](args[1],args[2],val)
    if args[2] > 2 then
      softcut[param](args[1],args[2]+2,val)
    end
  elseif param == 'buffer clear' then
    if args[2] > 100 then
      softcut.buffer_clear_region(args[2],args[3])
    else
      softcut.buffer_clear_region_channel(args[1],args[2],args[3])
    end
  elseif param == 'buffer read file' then
    if args[3] > 100 then
      softcut.buffer_read_stereo(args[1], args[2], args[3], args[4])
    else
      softcut.buffer_read_mono(table.unpack(args))
    end
  elseif param == 'pan' then
    if args > 2 then
      local R_distributed = util.linlin(-1,1,0,params:get("vol_"..args),val)
      local L_distributed = util.linlin(0,params:get("vol_"..args),params:get("vol_"..args),0,R_distributed)
      softcut.level(args, L_distributed)
      softcut.level(args+2, R_distributed)
    else
      softcut[param](args,val)
    end
  elseif param == 'level' then
    if args > 2 then
      local R_distributed = util.linlin(-1,1,0,val,params:get("pan_"..args))
      local L_distributed = util.linlin(0,val,val,0,R_distributed)
      softcut.level(args, L_distributed)
      softcut.level(args+2, R_distributed)
    else
      softcut[param](args,val)
    end
  elseif param == 'position' then
    softcut[param](args,val)
    softcut.voice_sync(args+2,args,0)
  else
    softcut[param](args,val)
    if args > 2 then
      softcut[param](args+2,val)
    end
  end
end

function init()
  _pat.init()
  _cue.init()
  g = grid.connect()

  _ca.init()
  _params.init()
  _flow.init()
  _song.init()
  _time.init()

  softcut.buffer_clear()
  --audio.level_cut(1)
  audio.level_adc_cut(1)
  audio.level_eng_cut(0)
  softcut.level_input_cut(1, 1, 1.0)
  softcut.level_input_cut(1, 2, 0.0)
  softcut.level_input_cut(1, 3, 1.0)
  softcut.level_input_cut(1, 4, 1.0)
  softcut.level_input_cut(1, 5, 0.0)
  softcut.level_input_cut(1, 6, 0.0)
  softcut.level_input_cut(2, 1, 0.0)
  softcut.level_input_cut(2, 2, 1.0)
  softcut.level_input_cut(2, 3, 0.0)
  softcut.level_input_cut(2, 4, 0.0)
  softcut.level_input_cut(2, 5, 1.0)
  softcut.level_input_cut(2, 6, 1.0)
  softcut.buffer(1,1)
  softcut.buffer(2,2)
  softcut.buffer(3,1)
  softcut.buffer(4,1)
  softcut.buffer(5,2)
  softcut.buffer(6,2)
  
  for i = 1,4 do
    set_softcut_param('level',i,1.0)
    set_softcut_param('play',i,1)
    set_softcut_param('rate',i,1)
    set_softcut_param('loop_start',i,softcut_offsets[i])
    set_softcut_param('loop_end',i,global_duration+softcut_offsets[i])
    set_softcut_param('loop',i,1)
    set_softcut_param('fade_time',i,0.015)
    set_softcut_param('recpre_slew_time',i,0.015)
    set_softcut_param('rec',i,1) -- TODO CONFIRM GOOD
    set_softcut_param('rec_level',i,0)
    set_softcut_param('pre_level',i,1)
    set_softcut_param('position',i,softcut_offsets[i])
    set_softcut_param('phase_quant',i,0.01)
    set_softcut_param('rec_offset',i,-0.0003)
  end

  softcut.pan(1,-1)
  softcut.pan(2,1)
  softcut.pan(3,-1)
  softcut.pan(4,-1)
  softcut.pan(5,1)
  softcut.pan(6,1)
 
  softcut.event_phase(phase)
  
  -- counter = metro.init(count, 0.005, -1)
  counter = {}
  for i = 1,4 do
    counter[i] = metro.init(_G["count_"..i], 0.005, -1)
  end
  rec_time = {0,0,0,0}

  KEY3_hold = false
  key1_hold = false
  prelim_key2_hold = false
  key2_hold = false

  key2_hold_counter = metro.init()
  key2_hold_counter.time = 0.25
  key2_hold_counter.count = 1
  key2_hold_counter.event = function()
    -- if not queue_menu.active then queue_menu.active = true end
    prelim_key2_hold = true
    key2_hold = true
    screen_dirty = true
  end

  voice_on_screen = 1

  for i = 1,4 do
    _loop.clear_track(i)
  end

  hardware_redraw = metro.init(
    function()
      draw_hardware()
    end
    , 1/30, -1)
  hardware_redraw:start()

  clock.run(update_q_clock)

  grid_dirty = true
  screen_dirty = true

  -- dev
  for i = 1,4 do
    params:set("loop_sizing_voice_"..i, 1)
    params:set("rec_enable_voice_"..i, 2)
    params:set("rec_disable_voice_"..i, 2)
    -- track[i].end_point = softcut_offsets[i]+8
    track[i].queued.end_point = track[i].end_point
    set_softcut_param('enable',i,1)
  end
  -- engine.threshold(-30)
end

function get_total_pitch_offset(_t)
  local total_offset;
  total_offset = params:get("semitone_offset_".._t)
  local sample_rate_compensation;
  if (48000/clip[_t].sample_rate) > 1 then
    sample_rate_compensation = ((1200 * math.log(48000/clip[_t].sample_rate,2))/-100)
  else
    sample_rate_compensation = ((1200 * math.log(clip[_t].sample_rate/48000,2))/100)
  end
  total_offset = total_offset + sample_rate_compensation
  total_offset = math.pow(0.5, -total_offset / 12) * speedlist[_t][params:get("speed_voice_".._t)]
  if params:get("pitch_control") ~= 0 then
    return (total_offset + (total_offset * (params:get("pitch_control")/100)))
  else
    return (total_offset)
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
  if n <= 4 then
    if track[n].playing then
      track[n].poll_position = x
      if rec[n] and clear[n] then
        if x > track[n].rec_limit then
          track[n].rec_limit = x
        end
      elseif rec[n] and not clear[n] then
        if (x > track[n].rec_limit) and (track[n].end_point > track[n].rec_limit) then
          track[n].rec_limit = track[n].end_point
        end
      end
      pp[n] = ((x - track[n].start_point) / (track[n].end_point - track[n].start_point))
      x = math.floor(pp[n] * 8)
      -- x = math.floor(util.round(pp[n],0.01) * 8)
      -- x = util.round(util.round(pp[n],0.01) * 8,1)
      if x ~= track[n].pos_grid then
        track[n].pos_grid = x
      end
      grid_dirty = true
      screen_dirty = true
    end
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
  set_softcut_param('rate_slew_time',voice_on_screen,0.6 + (math.random(-30,10)/100))
end

function half_speed()
  ray = speedlist[voice_on_screen][params:get("speed_voice_"..voice_on_screen)] / 2
  set_softcut_param('rate_slew_time',voice_on_screen,0.6 + (math.random(-30,10)/100))
end

function rev_speed()
  ray = speedlist[voice_on_screen][params:get("speed_voice_"..voice_on_screen)] * -1
  set_softcut_param('rate_slew_time',voice_on_screen,0.01)
end

function oneandahalf_speed()
  ray = speedlist[voice_on_screen][params:get("speed_voice_"..voice_on_screen)] * 1.5
  set_softcut_param('rate_slew_time',voice_on_screen,0.6 + (math.random(-30,10)/100))
end

function double_speed()
  ray = speedlist[voice_on_screen][params:get("speed_voice_"..voice_on_screen)] * 2
  set_softcut_param('rate_slew_time',voice_on_screen,0.6 + (math.random(-30,10)/100))
end

function restore_speed()
  ray = speedlist[voice_on_screen][params:get("speed_voice_"..voice_on_screen)]
  set_softcut_param('rate_slew_time',voice_on_screen,get_total_pitch_offset(voice_on_screen))
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
over = {0.0,0.0,0.0,0.0}
ray = 0.0
KEY3 = 1
recording_crane = {0,0,0,0}
overdub_crane = {0,0,0,0}
holding_crane = {0,0,0,0}
c2 = math.random(4,12)

queue_menu = {}
queue_menu.active = false
queue_menu.sel = 1

-- key hardware interaction
function key(n,z)
  if not song_menu then
    local _t = voice_on_screen
  
    -- KEY 2
    if n == 2 then
      if not key1_hold then
        if z == 1 then
          key2_hold = false
          key2_hold_counter:start()
          -- if queue_menu.active and not key2_hold then
          --   key2_hold_counter:start()
          -- end
          -- if not queue_menu.active then
          --   queue_menu.active = true
          --   prelim_key2_hold = true
          -- end
        else
          if not key2_hold then
            queue_menu.active = not queue_menu.active
          end
          key2_hold_counter:stop()
          key2_hold = false
          -- if queue_menu.active then
          --   key2_hold_counter:stop()
          --   if prelim_key2_hold == false and key2_hold == false then
          --     queue_menu.active = false
          --   end
          --   prelim_key2_hold = false
          --   key2_hold = false
          -- else
          --   if key2_hold then key2_hold = false end
          -- end
        end
      elseif z == 1 then
        song_menu = true
        key1_hold = false
      end
    
    -- KEY 3
    -- all based on Parameter choice
    elseif n == 3 then
      if not key2_hold and queue_menu.active and z == 1 then
        rec_queued[_t] = true
      end
      if key1_hold then
        _time.process_key(_t,n,z)
      elseif key2_hold and queue_menu.active and z == 1 then
        _loop.jump_to_cue(_t)
      elseif key2_hold and not queue_menu.active and z == 1 then
        _loop.clear_track(_t)
      else
        if z == 1 then
          if _t == 1 or _t == 2 then
            if _t == 1 and not clear[1] then
              _loop.queue_record(1)
            elseif _t == 2 and not clear[2] then
              _loop.queue_record(2)
            elseif (_t == 1 or _t == 2) and (clear[1] and clear[2]) then
              _loop.queue_record(1)
              _loop.queue_record(2)
            end
          else
            _loop.queue_record(_t)
          end
        end
      end
      key3_hold = z == 1 and true or false

    -- KEY 1
    -- hold key 1 + key 3 to clear the buffers
    elseif n == 1 and z == 1 and KEY3_hold == true then
      _loop.clear_track(_t)
      key1_hold = false
    elseif n == 1 and z == 1 then
      key1_hold = true
    elseif n == 1 and z == 0 then
      key1_hold = false
    end
  else
    _flow.process_key(n,z)
  end
  screen_dirty = true
end

-- encoder hardware interaction
function enc(n,d)
  _ea.process_encoder(n,d)
end

-- displaying stuff on the screen
function redraw()
  screen.clear()
  if not song_menu then
    if key1_hold then
      screen.font_size(22)
      for i = 1,4 do
        screen.move(10 + (20*i),42)
        screen.level(voice_on_screen == i and 15 or 4)
        screen.text_center(i)
      end
      screen.font_size(8)
      screen.move(64,10)
      screen.level(3)
      if voice_on_screen == 1 or voice_on_screen == 2 then
        screen.text_center("1 and 2 are")
        screen.move(64,20)
        screen.text_center("linked, live loopers")
      else
        screen.text_center("3 and 4 are")
        screen.move(64,20)
        screen.text_center("independent loopers/samplers")
      end
      screen.move(0,55)
      screen.level(15)
      if queue_menu.active then
        screen.text("quantize cue: ")
      else
        screen.text("quantize loop: ")
      end
      screen.level(_time.menu.sel == 1 and 15 or 4)
      screen.move(screen.text_extents("quantize loop: ")+4,55)
      screen.text(_time.menu.div_mult[voice_on_screen])
      screen.move(screen.text_extents("quantize loop: ".._time.menu.div_mult[voice_on_screen]),55)
      screen.level(_time.menu.sel == 2 and 15 or 4)
      screen.text(_time.menu.div_options[_time.menu.div_selection[voice_on_screen]])
      screen.move(screen.text_extents("quantize loop: ".._time.menu.div_mult[voice_on_screen].._time.menu.div_options[_time.menu.div_selection[voice_on_screen]])+5,55)
      screen.level(15)
      screen.text("(K3)")
    else
      screen.font_size(8)
      screen.level(15)
      local _t = voice_on_screen
      
      
      if queue_menu.active then
        screen.move(0,30)
        screen.text(key2_hold and "K3: jump to cue points" or "")
        screen.move(0,40)
        screen.level(queue_menu.sel == 1 and 15 or 3)
        screen.text("move cue window ("..params:string("queue_window_quant_voice_".._t)..")")
        screen.move(0,50)
        screen.level(queue_menu.sel == 2 and 15 or 3)
        screen.text("(cue) s".._t..": "..util.round(track[_t].queued.start_point - softcut_offsets[_t],0.01).."s")
        screen.move(0,60)
        screen.level(queue_menu.sel == 3 and 15 or 3)
        screen.text("(cue) e".._t..": "..util.round(track[_t].queued.end_point - softcut_offsets[_t],0.01).."s")
      else
        screen.move(0,30)
        screen.text(key2_hold and "K3: erase loop" or "")
        screen.move(0,40)
        screen.text("o".._t..": "..over[_t])
        screen.move(0,50)
        screen.text("s".._t..": "..util.round(track[_t].start_point - softcut_offsets[_t],0.01).."s")
        screen.move(0,60)
        screen.text("e".._t..": "..util.round(track[_t].end_point - softcut_offsets[_t],0.01).."s")
      end

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
        screen.text("one: "..util.round(track[1].poll_position - softcut_offsets[1],0.1).."s")
        screen.move(0,20)
        screen.text("two: "..util.round(track[2].poll_position - softcut_offsets[2],0.1).."s")
      else
        screen.text((_t == 3 and "three: " or "four: ")..util.round(track[_t].poll_position - softcut_offsets[_t],0.1).."s")
      end
    end
  else
    _flow.draw_menu()
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
    screen.move(100-(track[1].poll_position * 3),global_duration-(track[2].poll_position))
  elseif track[1].poll_position < 40 then
    screen.move(100-(track[1].poll_position * 2),global_duration-(track[2].poll_position))
  else
    screen.move(100-(track[1].poll_position),global_duration-(track[2].poll_position))
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

function rec_playback_event(e)
  grid_event(e,true)
end

function grid_event(e,silent)
  if quantize == 1 then
    e.silent = silent
    table.insert(quantize_events,e)
  else
    if not silent then
      _pat.record_grid_press(e)
    end
    event_exec(e)
  end
end

function update_q_clock()
  while true do
    clock.sync(1 / 4)
    event_q_clock()
  end
end

function event_q_clock()
  if #quantize_events > 0 then
    for k,e in pairs(quantize_events) do
      if not e.silent then
        _pat.record_grid_press(e)
      end
      event_exec(e)
    end
    quantize_events = {}
  end
end

function event_exec(e)
  local _t = e.voice
  -- tab.print(e)
  if e.section == "CUT" then
    if not rec[_t] or (rec[_t] and not clear[_t]) then
      local _block = (track[_t].end_point - track[_t].start_point) / 8
      local _cutposition = _block * (e.x-1) + softcut_offsets[_t]
      if params:string("chittering_mode_".._t) ~= "off" then
        chitter_stretch[_t].pos = _cutposition
      else
        set_softcut_param('position',_t,_cutposition)
      end
    end
  elseif e.section == "SNAP" then
    -- if snapshot_mod.index == 0 then
    --   snapshot.unpack(_t,e.x)
    -- else
    --   try_it(_t,e.x,snapshot_mod.index,"time")
    -- end
    if e.mod_index == 0 then
      snapshot.unpack(_t,e.x)
    else
      try_it(_t,e.x,e.mod_index,"time")
    end
  elseif e.section == "PITCHES" then
    if not rec[_t] or (rec[_t] and not clear[_t]) then
      if not track[_t].reverse then
        params:set("speed_voice_".._t,e.x+5)
      else
        local reverse_key = {6,5,4,3,2,1}
        params:set("speed_voice_".._t,reverse_key[e.x])
      end
    end
  elseif e.section == "REVERSE" then
    if not rec[_t] or (rec[_t] and not clear[_t]) then
      track[_t].reverse = not track[_t].reverse
      local reverse_current = {11,10,9,8,7,6,5,4,3,2,1}
      params:set("speed_voice_".._t,reverse_current[params:get("speed_voice_".._t)])
    end
  end
end

function play_voice(_t)
  print("playing voice: ".._t)
  -- set_softcut_param('level_slew_time',_t,0.3)
  track[_t].playing = true
  softcut.poll_start_phase()
  set_softcut_param('loop_start',_t,track[_t].start_point)
  set_softcut_param('loop_end',_t,track[_t].end_point)
  set_softcut_param('position',_t,track[_t].start_point)
  set_softcut_param('rate_slew_time',_t,0.01)
  set_softcut_param('rate',_t, get_total_pitch_offset(_t)) -- TODO CONFIRM THIS IS OKAY
  set_softcut_param('play',_t,1)
  set_softcut_param('level',_t,params:get("vol_".._t))
  chitter_stretch[_t].pos = track[_t].start_point
  screen_dirty = true
  grid_dirty = true
end

function stop_voice(_t)
  print("stopping voice: ".._t)
  track[_t].playing = false
  -- set_softcut_param('level_slew_time',_t,0.001)
  set_softcut_param('level',_t,0)
  set_softcut_param('position',_t,track[_t].start_point)
  chitter_stretch[_t].pos = track[_t].start_point
  screen_dirty = true
  grid_dirty = true
end

-- hardware: grid connect
g = grid.connect()
-- hardware: grid event (eg 'what happens when a button is pressed')
g.key = function(x,y,z)

if y >= 5 and y <= 8 and x <= 8 and z == 1 then
  local _t = y-4
  local _e = {section = "CUT", voice = _t, x = x, y = y, z = z}
  grid_event(_e)
elseif y >= 1 and y <= 4 and x <=6 and z == 1 then
  local _t = y
  local _e = {section = "PITCHES", voice = _t, x = x, y = y, z = z}
  grid_event(_e)
elseif y >= 1 and y <= 4 and x == 7 and z == 1 then
  local _t = y
  local _e = {section = "REVERSE", voice = _t, x = x, y = y, z = z}
  grid_event(_e)
elseif y >= 1 and y <= 4 and x == 8 and z == 1 then
  local _t = y
  if grid_alt then
    _loop.clear_track(_t)
  else
    _loop.queue_record(_t)
  end
elseif y >= 1 and y <= 4 and x >= 11 then
  local _t = y
  if z == 1 then
    if x >= 11 then
      x = x-10
      if tab.count(snapshots[_t][x]) < 2 then
        track[_t].snapshot.saver_clock = clock.run(snapshot.save_to_slot,_t,x)
        track[_t].snapshot.focus = x
      else
        -- local modifier, style = 0,"beats"
        -- if track[_t].restore_mod then
        --   modifier =  track[_t].snapshot[i].restore_times[track[_t].snapshot[i].restore_times.mode][track[_t].restore_mod_index]
        --   style = track[_t].snapshot[i].restore_times.mode
        -- end
        if grid_alt then
          track[_t].snapshot.saver_clock = clock.run(snapshot.save_to_slot,_t,x)
        else
          local _e = {section = "SNAP", voice = _t, x = x, mod_index = snapshot_mod.index}
          -- tab.print(_e)
          grid_event(_e)
          -- if snapshot_mod.index == 0 then
          --   snapshot.unpack(_t,x)
          -- else
          --   try_it(_t,x,snapshot_mod.index,"time")
          -- end
        end
        track[_t].snapshot.focus = x
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
elseif y == 8 and x == 13 then
  overdub_toggle = z == 1 and true or false
elseif y == 8 and x == 14 then
  loop_toggle = z == 1 and true or false
elseif y == 8 and x == 15 then
  duplicate_toggle = z == 1 and true or false
elseif y == 8 and x == 16 then
  copy_toggle = z == 1 and true or false
elseif y == 8 and x == 9 then
  grid_alt = z == 1 and true or false
elseif (y == 6 or y == 7) and x >= 13 and z == 1 then
  local target = (x-12)+(4*(y-6))
  _pat.handle_grid_pat(target,grid_alt)
end

  grid_dirty = true
end

-- hardware: grid redraw
function grid_redraw()
  g:all(0)

  for i = 11,16 do
    for j = 1,4 do
      local _t = j
      g:led(i,j,tab.count(snapshots[_t][i-10]) > 1 and 6 or 3)
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
    g:led(8,i,rec[_t] and 15 or (not clear[_t] and 8 or 3) or 3)
  end

  for i = 1,8 do
    local led_level
    if pattern[i].count == 0 and pattern[i].rec == 0 then
      led_level = 3
    elseif pattern[i].rec == 1 then
      led_level = 10
    elseif pattern[i].play == 1 and pattern[i].overdub == 0 then
      led_level = 15
    else
      if pattern[i].overdub == 1 then
        -- led_level = 15 - (util.round(clock.get_beats() % 4)*3)
        led_level = 15 - util.round((util.round(clock.get_beats() % 4,0.5) * 3))
      else
        led_level = 8
      end
    end
    if loop_toggle then
      led_level = pattern[i].loop == 1 and 12 or 3
    end
    g:led(_flow.index_to_grid_pos(i,4)[1]+12,_flow.index_to_grid_pos(i,4)[2]+5,led_level)
  end

  -- for i = 1,4 do
    -- g:led(i+12,8,voice_on_screen == i and 12 or 3)
  -- end

  g:led(13,8,overdub_toggle and 15 or 6)
  g:led(14,8,loop_toggle and 15 or 6)
  g:led(15,8,duplicate_toggle and 15 or 6)
  g:led(16,8,copy_toggle and 15 or 6)

  g:led(9,8,grid_alt and 15 or 5)

  g:refresh()
end