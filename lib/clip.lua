local ca = {}

function ca.init()
  clip = {}
  for i = 1,4 do
    clip[i] = {}
    clip[i].length = 90
    clip[i].sample_length = global_duration
    clip[i].sample_rate = 48000
    clip[i].start_point = nil
    clip[i].end_point = nil
    clip[i].mode = 1
    clip[i].waveform_samples = {}
    clip[i].waveform_rendered = false
    clip[i].channel = 1
    clip[i].collage = false
  end
end

function ca.sample_callback(path,i,summed)
  if path ~= "cancel" and path ~= "" then
    ca.load_sample(path,i,summed)
    clip[i].collage = false
  end
end

function ca.load_sample(file,sample,summed)
  local old_min = clip[sample].min
  local old_max = clip[sample].max
  if file ~= "-" and file ~= "" then
    local ch, len, rate = audio.file_info(file)
    clip[sample].sample_rate = rate
    if clip[sample].sample_rate ~= 48000 then
      print("sample rate needs to be 48khz!")
      print(len/48000, len/rate)
    end
    if len/48000 < global_duration then
      clip[sample].sample_length = len/48000
    else
      clip[sample].sample_length = global_duration
    end
    clip[sample].original_length = len/48000
    clip[sample].original_bpm = chitter.derive_bpm(clip[sample])
    clip[sample].original_samplerate = rate/1000
    local im_ch = ch == 2 and clip[sample].channel-1 or 1
    local scaled = {
      -- {buffer, start, end}
      {1,softcut_offsets[1],clip[sample].sample_length + 0.05},
      {params:get("voice_2_buffer"),softcut_offsets[2],clip[sample].sample_length + 0.05},
      {1,softcut_offsets[3],clip[sample].sample_length + 0.05 + softcut_offsets[3]},
      {2,softcut_offsets[4],clip[sample].sample_length + 0.05 + softcut_offsets[4]},
    }

    set_softcut_param('buffer clear',{scaled[sample][1],scaled[sample][2],global_duration})
    set_softcut_param('buffer read file',{file, 0, scaled[sample][2], clip[sample].sample_length + 0.05, im_ch, scaled[sample][1]})
    -- //

    track[sample].end_point = (clip[sample].sample_length-FADE_TIME) + softcut_offsets[sample]
    track[sample].queued.end_point = track[sample].end_point
    set_softcut_param('rec_level',sample,0)
    if params:string("transport_start_play_voice_"..sample) == "no" then
      play_voice(sample)
    end
    clear[sample] = false
    track[sample].rec_limit = 0
  end
  if params:get("clip "..sample.." sample") ~= file then
    params:set("clip "..sample.." sample", file, 1)
  end
end

function ca.set_level(voice,l)
  local R_distributed = util.linlin(-1,1,0,l,params:get("pan_"..voice))
  local L_distributed = util.linlin(0,l,l,0,R_distributed)
  softcut.level(voice, L_distributed)
  softcut.level(voice+2, R_distributed)
end

function ca.set_pan(voice,p)
  local R_distributed = util.linlin(-1,1,0,params:get("vol_"..voice),p)
  local L_distributed = util.linlin(0,params:get("vol_"..voice),params:get("vol_"..voice),0,R_distributed)
  softcut.level(voice, L_distributed)
  softcut.level(voice+2, R_distributed)
end

function ca.clock_try()
  clock.run(
    function()
      clock.sync(4)
      for i = 1,4 do
        record(i)
      end
      clock.sleep(clock.get_beat_sec() * 16)
      for i = 1,4 do
        record(i)
      end
    end
  )
end

return ca