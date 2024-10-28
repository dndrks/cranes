local ca = {}

local sample_speedlist = {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4}

function ca.init(track_count)
  sample_info = {}
  chosen_mode = {'chop','chop','chop'}

  sample_loop_info = {}
  for i = 1,track_count do
    sample_loop_info[i] = {clocks = {}, count = 0}
  end

  function CheatCranes.folder_callback(voice,folder)
    sample_info[voice] = {}
    sample_info[voice].sample_rates = {}
    sample_info[voice].sample_lengths = {}
    sample_info[voice].sample_frames = {}
    sample_info[voice].sample_count = 0
    local wavs = util.scandir(folder)
    for index, data in ipairs(wavs) do
      local ch, len, rate = audio.file_info(folder..data)
      if rate ~= 0 then
        sample_info[voice].sample_count = sample_info[voice].sample_count + 1
        sample_info[voice].sample_rates[sample_info[voice].sample_count] = rate
        sample_info[voice].sample_lengths[sample_info[voice].sample_count] = len/rate
        sample_info[voice].sample_frames[sample_info[voice].sample_count] = len
      end
    end
		params:hide(voice .. "_sample_sliceCount")
		menu_rebuild_queued = true
    chosen_mode[voice] = 'folder'
  end

  function CheatCranes.file_callback(voice,file)
    sample_info[voice] = {}
    sample_info[voice].sample_rates = {}
    sample_info[voice].sample_lengths = {}
    sample_info[voice].sample_frames = {}
    sample_info[voice].sample_count = 0
    local ch, len, rate = audio.file_info(file)
    if rate ~= 0 and len ~= 0 then
      sample_info[voice].sample_rates[1] = rate
      sample_info[voice].sample_lengths[1] = len/rate
      sample_info[voice].sample_frames[1] = len
			if params:string(voice .. "_sample_sampleMode") == "chop" then
				params:show(voice .. "_sample_sliceCount")
			else
				params:hide(voice .. "_sample_sliceCount")
			end
			menu_rebuild_queued = true
    end
		chosen_mode[voice] = "chop"
  end

  function CheatCranes.clear_callback(voice)
    print(voice ..' getting a sample cleared')
    sample_info[voice] = {}
    sample_info[voice].sample_rates = {}
    sample_info[voice].sample_lengths = {}
    sample_info[voice].sample_frames = {}
    sample_info[voice].sample_count = 0
    for i = 1,sample_loop_info[voice].count do
      if clock.threads[sample_loop_info[voice].clocks[i]] then
        clock.cancel(sample_loop_info[voice].clocks[i])
      end
    end
		params:hide(voice .. "_sample_sliceCount")
		-- params:hide('hill '..i..' sample slice count')
		menu_rebuild_queued = true
        -- _menu.rebuild_params()
  end

end

-- function ca.sample_callback(path,i,summed)
--   if path ~= "cancel" and path ~= "" then
--     ca.load_sample(path,i,summed)
--     clip[i].collage = false
--   end
-- end
---
function ca.folder_callback(file,dest)
  
  local split_at = string.match(file, "^.*()/")
  local folder = string.sub(file, 1, split_at)
  file = string.sub(file, split_at + 1)
  
  -- ca.collage(folder,dest,1)

end

function getParentPath(_path)
  return string.match(_path, "^(.+)/")
end

function ca.stop_sample(sample)
  -- engine.stop_sample(sample)
  send_to_engine('stop_sample',{sample})
end

function ca.set_rate(sample,r)
  -- engine.set_voice_param(sample,'rate',r)
  send_to_engine('set_voice_param',{sample,'rate',r})
end

function ca.derive_bpm(source)
  local dur = 0
  local pattern_id
  if source.original_length ~= nil then
    dur = source.original_length
  end
  if dur > 0 then
    local quarter = dur/4
    local derived_bpm = 60/quarter
    while derived_bpm < 70 do
      derived_bpm = derived_bpm * 2
      if derived_bpm > 160 then break end
    end
    while derived_bpm > 160 do
      derived_bpm = derived_bpm/2
      if derived_bpm <= 70 then break end
    end
    return util.round(derived_bpm,0.01)
  end
end

function ca.get_resampled_rate(voice, pitched)
  local total_offset
  total_offset = params:get(voice..'_sample_playbackRateOffset')
	-- TODO: per-pad values
	-- local step_rate = hills[i][j].sample_controls.rate[hills[i][hills[i].segment].index]
	local step_rate = 9
  total_offset = math.pow(0.5, -total_offset / 12) * sample_speedlist[step_rate]  
  if pitched then
    total_offset = total_offset * pitched
  end
  if util.round(params:get(voice..'_sample_playbackPitchControl'),0.01) ~= 0 then
    total_offset = total_offset + (total_offset * (util.round(params:get(voice..'_sample_playbackPitchControl'),0.01)/100))
  end
  return (total_offset * sample_speedlist[params:get(voice..'_sample_playbackRateBase')])
end

function ca.get_pitched_rate(target,i,j,played_note)
  local note_distance = (played_note - 60)
  local rates_from_notes = {
    1,
    1.05946,
    1.12246,
    1.18920,
    1.25992,
    1.33484,
    1.41421,
    1.49830,
    1.58740,
    1.68179,
    1.78179,
    1.88774,
  }
  local octave_distance = 0
  octave_distance = math.floor((played_note - 60)/12)
  if played_note == (60 + ((octave_distance+1)*11) + octave_distance) then
    return (ca.get_resampled_rate(target,i,j,rates_from_notes[12] * (2^octave_distance)))
  else
    return (ca.get_resampled_rate(target,i,j,rates_from_notes[util.wrap(note_distance+1,1,#rates_from_notes)] * (2^octave_distance)))
  end
end

function ca.play_slice(target, slice, velocity, played_note, retrig_index)
  if params:get(target..'_sample_sampleFile') ~= _path.audio then
    local i = target
    CheatCranes.allocVoice[i] = util.wrap(CheatCranes.allocVoice[i]+1, 1, params:get(i..'_poly_voice_count'))
    local slice_count = params:get(i..'_sample_sliceCount')
    local sampleEnd = (slice)/slice_count
    local sampleStart = (slice-1)/slice_count
    send_to_engine('set_sample_bounds',{target,'sampleStart',(slice-1)/slice_count, CheatCranes.allocVoice[i]})
    send_to_engine('set_sample_bounds',{target,'sampleEnd',(slice)/slice_count, CheatCranes.allocVoice[i]})
    print('sample points: '..(slice-1)/slice_count,(slice)/slice_count)
    if params:string(target..'_sample_loop') == 'off' then
			-- TODO: individualize per pad...
			-- send_to_engine('set_voice_param',{target,'loop',hills[i][j].sample_controls.loop[hills[i][j].index] and 1 or 0})
			send_to_engine("set_voice_param", { target, "loop", 0 })
    else
      send_to_engine('set_voice_param',{target,'loop',1})
    end
    local rate
    if params:string(i..'_sample_repitch') == "yes" and played_note ~= nil then
      rate = ca.get_pitched_rate(target,i,j,played_note)
    else
      rate = ca.get_resampled_rate(target)
    end
    send_to_engine('set_voice_param',{target, 'rate', rate})
    if retrig_index == 0 or retrig_index == nil then
      send_to_engine('trig',{target,velocity,'false',CheatCranes.allocVoice[i]})
      -- print('no trig '..CheatCranes.allocVoice[i])
    else
      send_to_engine('trig',{target,velocity,'true',CheatCranes.allocVoice[i]})
      -- print('yes trig '..CheatCranes.allocVoice[i])
    end
    -- TODO: confirm this is still useful...230312
    if params:get(i..'_poly_voice_count') ~= 1 then
      local check_rate_change = _polyparams.adjusted_params[i][CheatCranes.allocVoice[i]].params[i..'_sample_playbackRateBase']
      if check_rate_change ~= nil then
        local rate = params:lookup_param(i..'_sample_playbackRateBase'):map_value(check_rate_change)
        rate = sample_speedlist[rate]
        send_to_engine('set_poly_voice_param',{i, CheatCranes.allocVoice[i], 'rate', rate})
      end
    end
  end
end

function ca.play_index(target, index, velocity, played_note, retrig_index)
  if params:get(target..'_sample_sampleFile') ~= _path.audio then
		local i = target
    CheatCranes.allocVoice[i] = util.wrap(CheatCranes.allocVoice[i]+1, 1, params:get(i..'_poly_voice_count'))
    send_to_engine('change_sample',{target,index})
    send_to_engine('set_voice_param',{target,'sampleStart',0})
    send_to_engine('set_voice_param',{target,'sampleEnd',1})
    if params:string(target..'_sample_loop') == 'off' then
			-- TODO: individualize per pad...
      -- send_to_engine('set_voice_param',{target,'loop',hills[i][j].sample_controls.loop[hills[i][j].index] and 1 or 0})
			send_to_engine("set_voice_param", { target, "loop", 0 })
    else
      send_to_engine('set_voice_param',{target,'loop',1})
    end
    local rate
    -- TODO: allow repitching...
    if params:string(i..'_sample_repitch') == "yes" and played_note ~= nil then
      rate = ca.get_pitched_rate(target,i,j,played_note)
    else
      rate = ca.get_resampled_rate(target)
    end
    send_to_engine('set_voice_param',{target, 'rate', rate})
    if retrig_index == 0 then
      send_to_engine('trig',{target,velocity,'false',CheatCranes.allocVoice[i]})
    else
      send_to_engine('trig',{target,velocity,'true',CheatCranes.allocVoice[i]})
    end
  end
end

function ca.play_transient(target,slice,velocity,i,j, played_note, retrig_index)
  if params:get(target..'_sample_sampleFile') ~= _path.audio then
    CheatCranes.allocVoice[i] = util.wrap(CheatCranes.allocVoice[i]+1, 1, params:get(i..'_poly_voice_count'))
    local slice_count = params:get('hill '..i..' sample slice count')
    local start_time_as_percent = cursors[slice]/sample_info[target].sample_lengths[1]
    local end_time_as_percent = slice ~= slice_count and ((cursors[slice+1]/sample_info[target].sample_lengths[1])-0.01) or 1
    
    -- engine.set_voice_param(target,'sampleStart',start_time_as_percent)
    send_to_engine('set_voice_param',{target,'sampleStart',start_time_as_percent})
    -- engine.set_voice_param(target,'sampleEnd',end_time_as_percent)
    send_to_engine('set_voice_param',{target,'sampleEnd',end_time_as_percent})
    if params:string(target..'_sample_loop') == 'off' then
      -- engine.set_voice_param(target,'loop',hills[i][j].sample_controls.loop[hills[i][j].index] and 1 or 0)
      send_to_engine('set_voice_param',{target,'loop',hills[i][j].sample_controls.loop[hills[i][j].index] and 1 or 0})
    else
      -- engine.set_voice_param(target,'loop',1)
      send_to_engine('set_voice_param',{target,'loop',1})
    end
    local rate
    if params:string('hill '..i..' sample repitch') == "yes" and played_note ~= nil then
      rate = ca.get_pitched_rate(target,i,j,played_note)
    else
      rate = ca.get_resampled_rate(target, i, j)
    end
    -- engine.set_voice_param(target, 'rate', rate)
    send_to_engine('set_voice_param',{target, 'rate', rate})
    if retrig_index == 0 then
      -- engine.trig(target,velocity,'false',CheatCranes.allocVoice[i])
      send_to_engine('trig',{target,velocity,'false',CheatCranes.allocVoice[i]})
    else
      -- engine.trig(target,velocity,'true',CheatCranes.allocVoice[i])
      send_to_engine('trig',{target,velocity,'true',CheatCranes.allocVoice[i]})
    end
  end
end

function ca.play_through(target,velocity,i,j, played_note, retrig_index)
  CheatCranes.allocVoice[i] = util.wrap(CheatCranes.allocVoice[i]+1, 1, params:get(i..'_poly_voice_count'))
  -- send_to_engine('set_voice_param',{target,'sampleStart',params:get(target..'_sample_sampleStart')})
  -- send_to_engine('set_voice_param',{target,'sampleEnd',params:get(target..'_sample_sampleEnd')})
  if params:string(target..'_sample_loop') == 'off' then
    send_to_engine('set_voice_param',{target,'loop',hills[i][j].sample_controls.loop[hills[i][j].index] and 1 or 0})
  else
    send_to_engine('set_voice_param',{target,'loop',1})
  end
  local rate
  if params:string('hill '..i..' sample repitch') == "yes" and played_note ~= nil then
    rate = ca.get_pitched_rate(target,i,j,played_note)
  else
    rate = ca.get_resampled_rate(target, i, j)
  end
  send_to_engine('set_voice_param',{target, 'rate', rate})
  if retrig_index == 0 then
    send_to_engine('trig',{target,velocity,'false',CheatCranes.allocVoice[i]})
  else
    send_to_engine('trig',{target,velocity,'true',CheatCranes.allocVoice[i]})
  end
end

function ca.sc_to_SC(ch, voice, chop)
  local yymmdd = os.date("%y%m%d")
  local hms = os.date("%H%M%S")
  local folder = _path.audio..'cheatcranes/'..yymmdd
  util.make_dir(folder)
  if not clear then
		softcut.buffer_write_mono(folder .. "/" .. hms .. '.wav', track[ch].start_point, track[ch].end_point - 1, ch)
  end
  clock.run(
    function()
      clock.sleep(0.25)
      if chop == true then
        params:set(voice .. "_sample_sampleMode", 1)
      else
        params:set(voice .. "_sample_sampleMode", 2)
      end
      params:set(voice .. "_sample_sampleFile", folder .. "/" .. hms .. ".wav")
    end
  )
end

return ca