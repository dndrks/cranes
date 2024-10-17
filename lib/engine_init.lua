local CheatCranes = {}
local specs = {}
local ControlSpec = require 'controlspec'
-- CheatCranes.lfos = include 'kildare/lib/kildare_lfos'
local musicutil = require 'musicutil'

local samplers = {'sample','sample','sample','sample','sample','sample','sample','sample'}
CheatCranes.fx = {"delay", "feedback", "main"}
local fx = {"delay", "feedback", "main"}
CheatCranes.voice_state = {}
CheatCranes.allocVoice = {}

CheatCranes.soundfile_append = '' 

function send_to_engine(action, args)
  if osc_echo == nil then
    engine[action](table.unpack(args))
  else
    -- osc.send({osc_echo,57120},"/command",{action,table.unpack(args)})
    osc.send({osc_echo,57120},"/command/"..action,{table.unpack(args)})
  end
end

function load_file_in_engine(action, args)
  if osc_echo == nil then
    engine[action](table.unpack(args))
  else
    -- osc.send({osc_echo,57120},"/command",{action,table.unpack(args)})
    osc.send({osc_echo,57120},"/load_file_from_norns",{action,table.unpack(args)})
  end
end

local sox_installed = os.execute('which sox')

function round_form(param,quant,form)
  return(util.round(param,quant)..form)
end

function bipolar_as_pan_widget(param)
  local dots_per_side = 10
  local widget
  local function add_dots(num_dots)
    for i=1,num_dots do widget = (widget or "").."." end
  end
  local function add_bar()
    widget = (widget or "").."|"
  end
  local function format(param, value, units)
    return value.." "..(units or param.controlspec.units or "")
  end

  local value = type(param) == 'table' and param:get() or param
  local pan_side = math.abs(value)
  local pan_side_percentage = util.round(pan_side*100)
  local descr
  local dots_left
  local dots_right

  if value > 0 then
    dots_left = dots_per_side+util.round(pan_side*dots_per_side)
    dots_right = util.round((1-pan_side)*dots_per_side)
    if pan_side_percentage >= 1 then
      descr = "R"..pan_side_percentage
    end
  elseif value < 0 then
    dots_left = util.round((1-pan_side)*dots_per_side)
    dots_right = dots_per_side+util.round(pan_side*dots_per_side)
    if pan_side_percentage >= 1 then
     descr = "L"..pan_side_percentage
    end
  else
    dots_left = dots_per_side
    dots_right = dots_per_side
  end

  if descr == nil then
    descr = "MID"
  end

  add_bar()
  add_dots(dots_left)
  add_bar()
  add_dots(dots_right)
  add_bar()

  return format(param, descr.." "..widget, "")
end

function CheatCranes.folder_callback()
end

function CheatCranes.file_callback()
end

function CheatCranes.clear_callback()
end

function CheatCranes.voice_param_callback()
end

function CheatCranes.move_audio_into_perm(new_folder)
  local parent_folder = _path.audio..'cheatcranes/TEMP/'
  if util.file_exists(parent_folder) then
    if not util.file_exists(new_folder) then
      os.execute('mkdir -p '..new_folder)
    end
    for k,v in pairs(util.scandir(parent_folder)) do
      os.execute('cp -R '..parent_folder..v..' '..new_folder)
      for i = 1,3 do
        local split_at = string.match(params:get('sample'..i..'_sampleFile'), "^.*()/")
        local folder = string.sub(params:get('sample'..i..'_sampleFile'), 1, split_at)
        if folder == (parent_folder..v) then
          print('sample'..i..' is assigned to '..folder..', reassigning to '..new_folder..v)
          params:set('sample'..i..'_sampleFile', new_folder..v..util.scandir(new_folder..v)[1])
        end
      end
      os.execute('rm -r '..parent_folder..v)
    end
  end
end

function CheatCranes.purge_saved_audio()
  local parent_folder = _path.audio..'cheatcranes/TEMP/'
  if util.file_exists(parent_folder) then
    for k,v in pairs(util.scandir(parent_folder)) do
      os.execute('rm -r '..parent_folder..v)
    end
  end
end

local sample_speedlist = {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4}

local function get_resampled_rate(voice)
  local total_offset
  total_offset = params:get(voice..'_sample_playbackRateOffset')
  total_offset = math.pow(0.5, -total_offset / 12)
  if util.round(params:get(voice..'_sample_playbackPitchControl'),0.01) ~= 0 then
    total_offset = total_offset + (total_offset * (util.round(params:get(voice..'_sample_playbackPitchControl'),0.01)/100))
  end
  return (total_offset * sample_speedlist[params:get(voice..'_sample_playbackRateBase')])
end

function CheatCranes.init(track_count, poly)

  total_tracks = track_count

  for i = 1,track_count do
    CheatCranes.voice_state[i] = true
    CheatCranes.allocVoice[i] = 0
  end

  function percent_formatter(param)
    return ((type(param) == 'table' and param:get() or param).."%")
  end
  
  cheatcranes_params = {
    ['sample'] = {
      {type = 'separator', name = 'sample management'},
      {lfo_exclude = true, type = 'option', id = 'sampleMode', name = 'play mode', options = {"chop", "playthrough", "distribute"}, default = 1},
      {lfo_exclude = true, type = 'file', id = 'sampleFile', name = 'load', default = _path.audio},
      {lfo_exclude = true, type = 'binary', id = 'sampleClear', name = 'clear', behavior = 'momentary'},
      {lfo_exclude = true, type = 'control', id = 'sliceCount', name = 'slice count', min = 2, max = 48, warp = 'lin', default = 16, quantum = 1/46, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"")) end},
      {type = 'separator', name = 'voice params'},
      {id = 'amp', name = 'amp', type = 'control', min = 0, max = 1.25, warp = 'lin', default = 0.7, quantum = 1/125, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'loopAtk', name = 'loop attack', type = 'control', min = 0, max = 100, warp = 'lin', default = 5, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      {id = 'loopRel', name = 'loop release', type = 'control', min = 0, max = 100, warp = 'lin', default = 5, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      {id = 'envCurve', name = 'loop env curve', type = 'control', min = -12, max = 4, warp = 'lin', default = -4, quantum = 1/160, formatter = function(param) return (round_form(
        util.linlin(-12,4,0,100,(type(param) == 'table' and param:get() or param)),
        1,"%")) end},
      {id = 'sampleStart', name = 'sample start', type = 'control', min = 0, max = 1, warp = 'lin', default = 0, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param) * 100,1,"%")) end},
      {id = 'sampleEnd', name = 'sample end', type = 'control', min = 0, max = 1, warp = 'lin', default = 1, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param) * 100,1,"%")) end},
        {id = 'playbackRateBase', name = 'rate', type = 'control', min = 1, max = 11, warp = 'lin', default = 9, step = 1, quantum = 1/10, formatter = function(param) local rate_options = {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4} return rate_options[(type(param) == 'table' and param:get() or param)]..'x' end},
      {id = 'playbackRateOffset', name = 'offset', type = 'control', min = -24, max = 24, warp = 'lin', default = 0, step = 1, quantum = 1/48, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1," semitones")) end},
      {id = 'playbackPitchControl', name = 'pitch control', type = 'control', min = -12, max = 12, warp = 'lin', default = 0, step = 1/10, quantum = 1/240, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01,"%")) end},
      {id = 'loop', name = 'loop', type = 'control', min = 0, max = 1, warp = "lin", default = 0, quantum = 1, formatter = function(param) local modes = {"off","on"} return modes[(type(param) == 'table' and param:get() or param)+1] end},
      {type = 'separator', name = 'additional processing'},
      {id = 'amDepth', name = 'amp mod depth', type = 'control', min = 0, max = 1, warp = 'lin', default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'amHz', name = 'amp mod freq', type = 'control', min = 0.001, max = 12000, warp = 'exp', default = 8175.08, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'squishPitch', name = 'squish pitch', type = 'control', min = 1, max = 10, warp = 'lin', default = 1, quantum = 1/9, step = 1, formatter = function(param) if (type(param) == 'table' and param:get() or param) == 1 then return ("off") else return (round_form((type(param) == 'table' and param:get() or param),1,'')) end end},
      {id = 'squishChunk', name = 'squish chunkiness', type = 'control', min = 1, max = 10, warp = 'lin', default = 1, quantum = 1/9, step = 1, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,'')) end},
      {id = 'bitRate', name = 'bit rate', type = 'control', min = 20, max = 24000, warp = 'exp', default = 24000, formatter = function(param) return (util.round((type(param) == 'table' and param:get() or param),0.1).." Hz") end},
      {id = 'bitCount', name = 'bit depth', type = 'control', min = 1, max = 24, warp = 'lin', default = 24, quantum = 1/23, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1," bit")) end},
      {id = 'eqHz', name = 'eq freq', type = 'control', min = 20, max = 20000, warp = 'exp', default = 6000, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'eqAmp', name = 'eq gain', type = 'control', min = -2, max = 2, warp = 'lin', default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'lpHz', name = 'lo-pass freq', type = 'control', min = 20, max = 20000, warp = 'exp', default = 20000, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'hpHz', name = 'hi-pass freq', type = 'control', min = 20, max = 24000, warp = 'exp', default = 20, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'filterQ', name = 'filter q', type = 'control', min = 0, max = 100, warp = 'lin', default = 50, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      {id = 'pan', name = 'pan', type = 'control', min = -1, max = 1, warp = 'lin', default = 0, quantum = 1/200, formatter = function(param) return (bipolar_as_pan_widget(type(param) == 'table' and param:get() or param)) end},
      {type = 'separator', name = 'fx sends'},
      {id = 'delaySend', name = 'delay', type = 'control', min = 0, max = 1, warp = 'lin', default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'delayEnv', name = 'delay envelope', type = 'control', min = 0, max = 1, warp = "lin", default = 0,  step = 1, quantum = 1, formatter = function(param) local modes = {"off","on"} return modes[(type(param) == 'table' and param:get() or param)+1] end},
      {id = 'delayAtk', name = 'delay send attack', type = 'control', min = 0.001, max = 10, warp = 'exp', default = 0.001, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," s")) end},
      {id = 'delayRel', name = 'delay send release', type = 'control', min = 0.001, max = 10, warp = 'exp', default = 2, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," s")) end},
      {id = 'delayCurve', name = 'delay env curve', type = 'control', min = -12, max = 4, warp = 'lin', default = -4, quantum = 1/160, formatter = function(param) return (round_form(
        util.linlin(-12,4,0,100,(type(param) == 'table' and param:get() or param)),
        1,"%")) end},
      {id = 'feedbackSend', name = 'feedback', type = 'control', min = 0, max = 1, warp = 'lin', default = 0,  formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'feedbackEnv', name = 'feedback envelope', type = 'control', min = 0, max = 1, warp = "lin", default = 0,  step = 1, quantum = 1, formatter = function(param) local modes = {"off","on"} return modes[(type(param) == 'table' and param:get() or param)+1] end},
      {id = 'feedbackAtk', name = 'feedback send attack', type = 'control', min = 0.001, max = 10, warp = 'exp', default = 0.001, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," s")) end},
      {id = 'feedbackRel', name = 'feedback send release', type = 'control', min = 0.001, max = 10, warp = 'exp', default = 2, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," s")) end},
      {id = 'feedbackCurve', name = 'feedback env curve', type = 'control', min = -12, max = 4, warp = 'lin', default = -4, quantum = 1/160, formatter = function(param) return (round_form(
        util.linlin(-12,4,0,100,(type(param) == 'table' and param:get() or param)),
        1,"%")) end},
    }
  }

  local feedback_channels = {'a','b','c'}

  fx_params = {
    ["delay"] = {
      {type = 'separator', name = 'delay settings'},
      {id = 'time', name = 'time', type = 'control', min = 1, max = 128, warp = 'lin', default = 64, quantum = 1/127, formatter = function (param) return round_form((type(param) == 'table' and param:get() or param),1,"/128") end},
      {id = 'level', name = 'level', type = 'control', min = 0, max = 2, warp = 'lin', default = 1, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'feedback', name = 'feedback', type = 'control', min = 0, max = 1, warp = 'lin', default = 0.7, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'spread', name = 'spread', type = 'control', min = 0, max = 1, warp = 'lin', default = 1, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'pan', name = 'pan', type = 'control', min = -1, max = 1, warp = 'lin', default = 0, quantum = 1/200, formatter = function(param) return (bipolar_as_pan_widget(type(param) == 'table' and param or param)) end},
      {type = 'separator', name = 'additional processing'},
      {id = 'lpHz', name = 'lo-pass freq', type = 'control', min = 20, max = 20000, warp = 'exp', default = 20000, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'hpHz', name = 'hi-pass freq', type = 'control', min = 20, max = 24000, warp = 'exp', default = 20, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'filterQ', name = 'filter q', type = 'control', min = 0, max = 100, warp = 'lin', default = 50, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      -- {id = 'feedbackSend', name = 'send to feedback', type = 'control', min = 0, max = 1, warp = 'lin', default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
    },
    ["feedback"] = {
      {type = 'separator', name = 'mix'},
      {id = 'mainMixer_mixLevel', name = 'main output level', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 1, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'mainMixer_mixSpread', name = 'stereo spread', type = 'control', min = 0, max = 1, warp = 'lin', step = 0.01, quantum = 0.01, default = 1, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'mainMixer_mixCenter', name = 'stereo center', type = 'control', min = -1, max = 1, warp = 'lin', default = 0, quantum = 1/200, formatter = function(param) return (bipolar_as_pan_widget(type(param) == 'table' and param or param)) end},
      {id = 'mainMixer_lSHz', name = 'main low shelf', type = 'control', min = 20, max = 12000, warp = 'exp', default = 600, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'mainMixer_lSdb', name = 'main low shelf gain', type = 'control', min = -15, max = 15, warp = 'lin', default = 0, quantum = 1/30, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," dB")) end},
      {id = 'mainMixer_lSQ', name = 'main low shelf q', type = 'control', min = 0, max = 100, warp = 'lin', default = 50, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      {id = 'mainMixer_hSHz', name = 'main hi shelf', type = 'control', min = 80, max = 19000, warp = 'exp', default = 19000, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'mainMixer_hSdb', name = 'main hi shelf gain', type = 'control', min = -15, max = 15, warp = 'lin', default = 0, quantum = 1/30, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," dB")) end},
      {id = 'mainMixer_hSQ', name = 'main hi shelf q', type = 'control', min = 0, max = 100, warp = 'lin', default = 50, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      {type = 'separator', name = 'A'},
      {id = 'aMixer_inAmp', name = 'A <- engine', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'mainMixer_inA', name = 'A -> mixer', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'aMixer_inA', name = 'A feedback', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'aMixer_outB', name = 'A -> B', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'aMixer_outC', name = 'A -> C', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'aMixer_inB', name = 'A <- B', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'aMixer_inC', name = 'A <- C', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'aProcess_delayTime', name = 'A delay time', type = 'control', min = 0.005, max = 3, warp = 'lin', step = 0.01, quantum = 0.01, default = 0.1, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," sec")) end},
      {id = 'aProcess_shiftFreq', name = 'A frequency shift', type = 'control', min = 0, max = 1200, warp = 'lin', default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'aProcess_lSHz', name = 'A low shelf', type = 'control', min = 20, max = 12000, warp = 'exp', default = 600, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'aProcess_lSdb', name = 'A low shelf gain', type = 'control', min = -15, max = 15, warp = 'lin', default = 0, quantum = 1/30, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," dB")) end},
      {id = 'aProcess_lSQ', name = 'A low shelf q', type = 'control', min = 0, max = 100, warp = 'lin', default = 50, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      {id = 'aProcess_hSHz', name = 'A hi shelf', type = 'control', min = 80, max = 19000, warp = 'exp', default = 19000, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'aProcess_hSdb', name = 'A hi shelf gain', type = 'control', min = -15, max = 15, warp = 'lin', default = 0, quantum = 1/30, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," dB")) end},
      {id = 'aProcess_hSQ', name = 'A hi shelf q', type = 'control', min = 0, max = 100, warp = 'lin', default = 50, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      {type = 'separator', name = 'B'},
      {id = 'bMixer_inAmp', name = 'B <- engine', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'mainMixer_inB', name = 'B -> mixer', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'bMixer_inB', name = 'B feedback', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'bMixer_outA', name = 'B -> A', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'bMixer_outC', name = 'B -> C', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'bMixer_inA', name = 'B <- A', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'bMixer_inC', name = 'B <- C', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'bProcess_delayTime', name = 'B delay time', type = 'control', min = 0.005, max = 3, warp = 'lin', step = 0.01, quantum = 0.01, default = 0.1, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," sec")) end},
      {id = 'bProcess_shiftFreq', name = 'B frequency shift', type = 'control', min = 0, max = 1200, warp = 'lin', default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'bProcess_lSHz', name = 'B low shelf', type = 'control', min = 20, max = 12000, warp = 'exp', default = 600, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'bProcess_lSdb', name = 'B low shelf gain', type = 'control', min = -15, max = 15, warp = 'lin', default = 0, quantum = 1/30, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," dB")) end},
      {id = 'bProcess_lSQ', name = 'B low shelf q', type = 'control', min = 0, max = 100, warp = 'lin', default = 50, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      {id = 'bProcess_hSHz', name = 'B hi shelf', type = 'control', min = 80, max = 19000, warp = 'exp', default = 19000, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'bProcess_hSdb', name = 'B hi shelf gain', type = 'control', min = -15, max = 15, warp = 'lin', default = 0, quantum = 1/30, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," dB")) end},
      {id = 'bProcess_hSQ', name = 'B hi shelf q', type = 'control', min = 0, max = 100, warp = 'lin', default = 50, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      {type = 'separator', name = 'C'},
      {id = 'cMixer_inAmp', name = 'C <- engine', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'mainMixer_inC', name = 'C -> mixer', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'cMixer_inC', name = 'C feedback', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'cMixer_outA', name = 'C -> A', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'cMixer_outB', name = 'C -> B', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'cMixer_inA', name = 'C <- A', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'cMixer_inB', name = 'C <- B', type = 'control', min = 0, max = 2, warp = 'lin', step = 0.01, quantum = 0.01, default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'cProcess_delayTime', name = 'C delay time', type = 'control', min = 0.005, max = 3, warp = 'lin', step = 0.01, quantum = 0.01, default = 0.1, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," sec")) end},
      {id = 'cProcess_shiftFreq', name = 'C frequency shift', type = 'control', min = 0, max = 1200, warp = 'lin', default = 0, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'cProcess_lSHz', name = 'C low shelf', type = 'control', min = 20, max = 12000, warp = 'exp', default = 600, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'cProcess_lSdb', name = 'C low shelf gain', type = 'control', min = -15, max = 15, warp = 'lin', default = 0, quantum = 1/30, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," dB")) end},
      {id = 'cProcess_lSQ', name = 'C low shelf q', type = 'control', min = 0, max = 100, warp = 'lin', default = 50, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      {id = 'cProcess_hSHz', name = 'C hi shelf', type = 'control', min = 80, max = 19000, warp = 'exp', default = 19000, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'cProcess_hSdb', name = 'C hi shelf gain', type = 'control', min = -15, max = 15, warp = 'lin', default = 0, quantum = 1/30, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," dB")) end},
      {id = 'cProcess_hSQ', name = 'C hi shelf q', type = 'control', min = 0, max = 100, warp = 'lin', default = 50, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
    },
    ["main"] = {
      {type = 'separator', name = 'main output settings'},
      {id = 'lSHz', name = 'low shelf', type = 'control', min = 20, max = 12000, warp = 'exp', default = 600, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'lSdb', name = 'low shelf gain', type = 'control', min = -15, max = 15, warp = 'lin', default = 0, quantum = 1/30, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," dB")) end},
      {id = 'lSQ', name = 'low shelf q', type = 'control', min = 0, max = 100, warp = 'lin', default = 50, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      {id = 'hSHz', name = 'hi shelf', type = 'control', min = 800, max = 19000, warp = 'exp', default = 19000, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'hSdb', name = 'hi shelf gain', type = 'control', min = -15, max = 15, warp = 'lin', default = 0, quantum = 1/30, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," dB")) end},
      {id = 'hSQ', name = 'hi shelf q', type = 'control', min = 0, max = 100, warp = 'lin', default = 50, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      {id = 'eqHz', name = 'eq', type = 'control', min = 20, max = 24000, warp = 'exp', default = 6000, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," Hz")) end},
      {id = 'eqdb', name = 'eq gain', type = 'control', min = -30, max = 15, warp = 'lin', default = 0, quantum = 1/45, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),0.01," dB")) end},
      {id = 'eqQ', name = 'eq q', type = 'control', min = 0, max = 100, warp = 'lin', default = 50, quantum = 1/100, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param),1,"%")) end},
      {id = 'limiterLevel', name = 'limiter level', type = 'control', min = 0, max = 2, warp = 'lin', default = 0.5, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
      {id = 'level', name = 'final output level', type = 'control', min = 0, max = 2, warp = 'lin', default = 1, formatter = function(param) return (round_form((type(param) == 'table' and param:get() or param)*100,1,"%")) end},
    }
  }

  params:add_separator("cheatcranes_voice_header","cheatcranes voices")

  -- if engine.name ~= "CheatCranes" then
  --   params:add_option("no_kildare","----- kildare not loaded -----",{" "})
  -- end

  local custom_actions = {
    'delayEnv',
    'feedbackEnv',
    'sampleMode',
    'sampleFile',
    'sampleClear',
    'playbackRateBase',
    'playbackRateOffset',
    'playbackPitchControl',
    'loop'
  }
  
  how_many_params = 0
	how_many_params = tab.count(cheatcranes_params["sample"])

  local queued_inits = {}

  local function add_to_init_queue(i,model)
    queued_inits[#queued_inits+1] = {voice = i, model = model}
  end

  init_clock = clock.run(
    function()
      while true do
        clock.sleep(0.1)
        if #queued_inits > 0 then
          local i = queued_inits[1].voice
          local model = queued_inits[1].model
          -- engine.init_voice(i, 'kildare_'..model)
          send_to_engine('init_voice', {i, 'sample'})
          print('activating voice '..i)
          table.remove(queued_inits,1)
        end
      end
    end
  )

  for i = 1,track_count do
    local osc_params_count = 4
    params:add_group('sample_group_'..i, 'voice '..i, how_many_params + osc_params_count)
    
    params:add_separator('voice_management_'..i, 'voice management')
    params:add_binary(i..'_voice_state', 'active?', 'toggle', 1)
    params:set_action(i..'_voice_state',
    function(x)
      if x == 0 then
        -- engine.free_voice(i)
        send_to_engine('free_voice', {i})
      else
        add_to_init_queue(i,'sample')
      end
    end)
    params:add_number(i..'_poly_voice_count', 'voice count', 1, 8, 1)
    params:set_action(i..'_poly_voice_count', function(x)
      send_to_engine('set_voice_limit', {i,x})
      CheatCranes.allocVoice[i] = 0
    end)
    params:add_option(i..'_poly_param_style', 'poly params', {'all voices','current voice','next voice'}, 1)
    params:set_action(i..'_poly_param_style', function(x)
      send_to_engine('set_poly_param_style', {i, params:string(i..'_poly_param_style')})
    end)

		for prms, d in pairs(cheatcranes_params['sample']) do
      local v = 'sample'
			if d.type == "control" then
				local quantum_size = 0.01
				if d.quantum ~= nil then
					quantum_size = d.quantum
				end
				local step_size = 0
				if d.step ~= nil then
					step_size = d.step
				end
				if d.id == "carHz" then
					quantum_size = 1 / math.abs(d.max - d.min)
				end
				params:add_control(
					i .. "_" .. v .. "_" .. d.id,
					d.name,
					ControlSpec.new(d.min, d.max, d.warp, step_size, d.default, nil, quantum_size),
					d.formatter
				)
			elseif d.type == "number" then
				params:add_number(i .. "_" .. v .. "_" .. d.id, d.name, d.min, d.max, d.default, d.formatter)
			elseif d.type == "option" then
				params:add_option(i .. "_" .. v .. "_" .. d.id, d.name, d.options, d.default)
			elseif d.type == "separator" then
				params:add_separator(i .. "_separator_" .. v .. "_" .. d.name, d.name)
			elseif d.type == "file" then
				params:add_file(i .. "_" .. v .. "_" .. d.id, d.name, d.default)
			elseif d.type == "binary" then
				params:add_binary(i .. "_" .. v .. "_" .. d.id, d.name, d.behavior)
			end
			-- build actions:
			if d.type ~= "separator" then
				if not tab.contains(custom_actions, d.id) then
					params:set_action(i .. "_" .. v .. "_" .. d.id, function(x)
						-- if engine.name == "CheatCranes" then
            send_to_engine("set_voice_param", { i, d.id, x })
            CheatCranes.voice_param_callback(i, d.id, x)
            CheatCranes.last_adjusted_param = { i, v, d.id }
						-- end
					end)
				elseif d.id == "delayEnv" then
					params:set_action(i .. "_" .. v .. "_" .. d.id, function(x)
						-- if engine.name == "CheatCranes" then
            if x == 1 then
              params:show(i .. "_" .. v .. "_delayAtk")
              params:show(i .. "_" .. v .. "_delayRel")
              params:show(i .. "_" .. v .. "_delayCurve")
            elseif x == 0 then
              params:hide(i .. "_" .. v .. "_delayAtk")
              params:hide(i .. "_" .. v .. "_delayRel")
              params:hide(i .. "_" .. v .. "_delayCurve")
            end
            menu_rebuild_queued = true
            send_to_engine("set_voice_param", { i, d.id, x })
            CheatCranes.voice_param_callback(i, d.id, x)
            CheatCranes.last_adjusted_param = { i, v, d.id }
						-- end
					end)
				elseif d.id == "feedbackEnv" then
					params:set_action(i .. "_" .. v .. "_" .. d.id, function(x)
						-- if engine.name == "CheatCranes" then
            if x == 1 then
              params:show(i .. "_" .. v .. "_feedbackAtk")
              params:show(i .. "_" .. v .. "_feedbackRel")
              params:show(i .. "_" .. v .. "_feedbackCurve")
            elseif x == 0 then
              params:hide(i .. "_" .. v .. "_feedbackAtk")
              params:hide(i .. "_" .. v .. "_feedbackRel")
              params:hide(i .. "_" .. v .. "_feedbackCurve")
            end
            menu_rebuild_queued = true
            send_to_engine("set_voice_param", { i, d.id, x })
            CheatCranes.voice_param_callback(i, d.id, x)
            CheatCranes.last_adjusted_param = { i, v, d.id }
						-- end
					end)
				elseif d.id == "sampleMode" then
					params:set_action(i .. "_" .. v .. "_" .. d.id, function(x)
            if x == 3 then
              if all_loaded then
                send_to_engine("set_sample_mode", { i, "sampleFolder" })
              end
              params:hide(i .. "_" .. v .. "_loopAtk")
              params:hide(i .. "_" .. v .. "_loopRel")
              params:hide(i .. "_" .. v .. "_sampleStart")
              params:hide(i .. "_" .. v .. "_sampleEnd")
            elseif x == 2 then
              if all_loaded then
                send_to_engine("set_sample_mode", { i, "samplePlaythrough" })
              end
              params:show(i .. "_" .. v .. "_loopAtk")
              params:show(i .. "_" .. v .. "_loopRel")
              params:show(i .. "_" .. v .. "_sampleStart")
              params:show(i .. "_" .. v .. "_sampleEnd")
            elseif x == 1 then
              if all_loaded then -- TODO: NOT ACTUALLY WHAT I WANT...
                send_to_engine("set_sample_mode", { i, "sample" })
              end
              params:show(i .. "_" .. v .. "_loopAtk")
              params:show(i .. "_" .. v .. "_loopRel")
              params:hide(i .. "_" .. v .. "_sampleStart")
              params:hide(i .. "_" .. v .. "_sampleEnd")
            end
            CheatCranes.last_adjusted_param = { i, v, d.id }
            menu_rebuild_queued = true
					end)
				elseif d.id == "sampleFile" then
					params:set_action(i .. "_" .. v .. "_" .. d.id, function(file)
						if file ~= _path.audio then
							if params:string(i .. "_" .. v .. "_sampleMode") == "distribute" then
								local split_at = string.match(file, "^.*()/")
								local folder = string.sub(file, 1, split_at)
								-- engine.load_folder(i,folder)
								send_to_engine("load_folder", { i, folder })
								CheatCranes.folder_callback(i, folder)
							else
								-- send_to_engine('load_file', {i,file})
								load_file_in_engine("load_file", { i, file })
								CheatCranes.file_callback(i, file)
							end
						end
					end)
				elseif d.id == "sampleClear" then
					params:set_action(i .. "_" .. v .. "_" .. d.id, function(x)
						print(x)
						if x == 1 then
							print(params:string(i .. "_" .. v .. "_sampleFile"))
							-- engine.clear_samples(i)
							send_to_engine("clear_samples", { i })
							params:set(i .. "_" .. v .. "_sampleFile", _path.audio, silent)
							CheatCranes.clear_callback(i)
						end
					end)
				elseif d.id == "playbackRateBase" or d.id == "playbackRateOffset" or d.id == "playbackPitchControl" then
					params:set_action(i .. "_" .. v .. "_" .. d.id, function(x)
						send_to_engine("set_voice_param", { i, "rate", get_resampled_rate(i) })
						CheatCranes.last_adjusted_param = { i, v, d.id }
						-- for j = 1,8 do
						--   send_to_engine('set_sample_rate',{i,j,get_resampled_rate(i)})
						-- end
					end)
				elseif d.id == "loop" then
					params:set_action(i .. "_" .. v .. "_" .. d.id, function(x)
						send_to_engine("set_voice_param", { i, "loop", x })
						CheatCranes.last_adjusted_param = { i, v, d.id }
						if
							(x == 0 and params:get(i .. "_poly_param_style") == 1)
							or (x == 0 and params:get(i .. "_poly_voice_count") == 1)
						then
							for j = 1, 8 do
								send_to_engine("set_sample_loop", { i, j })
							end
						end
					end)
				end
			end
		end

    -- print('end of the road!')

  end

  local function build_slices(path,slices,sample_voice)
    local ch, len, smp = audio.file_info(path)
    local dur = len/smp
    local per_slice_dur = dur/slices
    local split_at = string.match(path, "^.*()/")
    local folder = string.sub(path, 1, split_at)
    local filename = path:match("^.+/(.+)$")
    local filename_raw = filename:match("(.+)%..+")

    if params:string('chop_length') == 'current bpm' then
      local synced_length = util.round_up((dur) - (dur * ((slices-1)/slices)), clock.get_beat_sec())
      if clock.get_beat_sec()*slices > dur then
        if (clock.get_beat_sec()/2)*slices > dur then
          if (clock.get_beat_sec()/3)*slices > dur then
            if (clock.get_beat_sec()/4)*slices > dur then
              synced_length = synced_length / 4
              -- print('sixteenth notes')
            end
          else
            synced_length = synced_length / 3
            -- print('twelfth notes')
          end
        else
          synced_length = synced_length / 2
          -- print('eighth notes')
        end
      else
        -- print('quarter notes')
      end
      per_slice_dur = synced_length
    end

    if per_slice_dur > 0.02 then
      print(folder, filename_raw)
      local parent_folder = _path.audio..'cheatcranes/TEMP/'..filename_raw..'-'..os.date("%Y%m%d_%H-%M-%S")..'/'
      if util.file_exists(parent_folder) then
        norns.system_cmd('rm -r '..parent_folder)
      end
      norns.system_cmd('mkdir -p '..parent_folder)
      local new_name = parent_folder..filename_raw..'%2n.flac'
      norns.system_cmd('sox '..path..' '..new_name..' trim 0 '..per_slice_dur..' fade 0:00.01 -0 0:00.01 : newfile : restart')
      clock.run(function()
        clock.sleep(0.3)
        params:set(sample_voice..'_sampleClear',1)
        params:set(sample_voice..'_sampleClear',0)
        params:set(sample_voice..'_sampleMode',3)
        params:set(sample_voice..'_sampleFile',parent_folder..filename_raw..'01.flac')
      end)
    else
      print('kildare: sample duration too small to fade')
    end
  end

  if sox_installed then
    params:add_group('st_header','sample tools',6)
    params:add_separator('st_notice', "for 'distribute' sample mode")
    params:add_text('st_info', '')
    params:hide('st_info')
    -- _menu.rebuild_params()
    menu_rebuild_queued = true
    params:add_file('st_chop','chop w/ fade', _path.audio)
    params:set_action('st_chop',
    function(file)
      if file ~= _path.audio and file ~= '' then
        build_slices(file, params:get('chop_count'), params:string('preload'))
        params:set('st_chop', '', true)
        params:set('st_info', '~~~ chopping '..file:match("^.+/(.+)$"))
        params:show('st_info')
        -- _menu.rebuild_params()
        menu_rebuild_queued = true
        clock.run(function()
          clock.sleep(2)
          params:set('st_info', '  ~~~ chopped! ~~~')
          clock.sleep(2)
          params:hide('st_info')
          -- _menu.rebuild_params()
          menu_rebuild_queued = true
        end)
      end
    end)
    params:add_number('chop_count', '   chop count', 2, 48, 16)
    params:add_option('chop_length', '   length factor', {'even chops', 'current bpm'})
    local load_destinations = {}
    for l = 1,track_count do
      load_destinations[l] = 'sample'..l
    end
    params:add_option('preload', '   preload to ', load_destinations, 1)
  end

  params:add_separator("fx_header"," fx")

  for j = 1,#CheatCranes.fx do
    local k = CheatCranes.fx[j]
    params:add_group('fx_'..k, k, #fx_params[k])
    for i = 1, #fx_params[k] do
      local d = fx_params[k][i]
      if d.type == 'control' then
        local quantum_size = 0.01
        if d.quantum ~= nil then
          quantum_size = d.quantum
        end
        local step_size = 0
        if d.step ~= nil then
          step_size = d.step
        end
        params:add_control(
          k.."_"..d.id,
          d.name,
          ControlSpec.new(d.min, d.max, d.warp, step_size, d.default, nil, quantum_size),
          d.formatter
        )
      elseif d.type == 'number' then
        params:add_number(
          k.."_"..d.id,
          d.name,
          d.min,
          d.max,
          d.default,
          d.formatter
        )
      elseif d.type == "option" then
        params:add_option(
          k.."_"..d.id,
          d.name,
          d.options,
          d.default
        )
      elseif d.type == 'separator' then
        params:add_separator('fx_params_'..d.name, d.name)
      end
      if d.type ~= 'separator' then
        params:set_action(k.."_"..d.id, function(x)
            if k == "delay" and d.id == "time" then
              send_to_engine("set_"..k.."_param", {d.id, clock.get_beat_sec() * x/128})
              CheatCranes.last_adjusted_param = {nil, k, d.id}
            elseif k ~= 'feedback' then
              send_to_engine("set_"..k.."_param", {d.id, x})
              CheatCranes.last_adjusted_param = {nil, k, d.id}
            elseif k == 'feedback' then
              local sub = '_'
              local keys = {}
              for str in string.gmatch(d.id, "([^"..sub.."]+)") do
                table.insert(keys,str)
              end
              local targetKey = keys[1]
              local paramKey = keys[2]
              local targetLine = string.upper(string.sub(targetKey, 1, 1))
              if paramKey == 'outA' then
                params:set('feedback_aMixer_in'..targetLine, x)
              elseif paramKey == 'outB' then
                params:set('feedback_bMixer_in'..targetLine, x)
              elseif paramKey == 'outC' then
                params:set('feedback_cMixer_in'..targetLine, x)
              end
              send_to_engine('set_feedback_param', {targetKey, paramKey, x})
              CheatCranes.last_adjusted_param = {nil, k, d.id}
            end
          -- end
        end)
      end
    end
  end

  params:hide('feedback_aMixer_inB')
  params:hide('feedback_aMixer_inC')
  params:hide('feedback_bMixer_inA')
  params:hide('feedback_bMixer_inC')
  params:hide('feedback_cMixer_inA')
  params:hide('feedback_cMixer_inB')

  menu_rebuild_queued = true

  -- params:add_separator("kildare_lfo_header","kildare lfos")
  -- CheatCranes.lfos.add_params(track_count, CheatCranes.fx ,poly)

  -- params:bang()

  CheatCranes.loaded = true
  
end

function CheatCranes.reset_params()
  for i = 1,total_tracks do
    for k,v in pairs(samplers) do
      for prms,d in pairs(cheatcranes_params[v]) do
        if d.type ~= 'separator' and d.default ~= nil then
          params:set(i..'_'..v..'_'..d.id, d.default)
        end
      end
    end
  end
end

return CheatCranes