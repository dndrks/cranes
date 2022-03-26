local ca = {}

function ca.init()
  clip = {}
  for i = 1,4 do
    clip[i] = {}
    clip[i].length = 90
    clip[i].sample_length = 60
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
  if file ~= "-" then
    local ch, len, rate = audio.file_info(file)
    clip[sample].sample_rate = rate
    if clip[sample].sample_rate ~= 48000 then
      print("sample rate needs to be 48khz!")
      print(len/48000, len/rate)
    end
    if len/48000 < 60 then
      clip[sample].sample_length = len/48000
    else
      clip[sample].sample_length = 60
    end
    clip[sample].original_length = len/48000
    clip[sample].original_bpm = chitter.derive_bpm(clip[sample])
    clip[sample].original_samplerate = rate/1000
    local im_ch = ch == 2 and clip[sample].channel-1 or 1
    local scaled = {
      -- {buffer, start, end}
      {1,0,clip[sample].sample_length + 0.05},
      {params:get("voice_2_buffer"),0,clip[sample].sample_length + 0.05},
      {1,softcut_offsets[3],clip[sample].sample_length + 0.05 + softcut_offsets[3]},
      {2,softcut_offsets[4],clip[sample].sample_length + 0.05 + softcut_offsets[4]},
    }
    softcut.buffer_clear_region_channel(scaled[sample][1],scaled[sample][2],60)
    softcut.buffer_read_mono(file, 0, scaled[sample][2], clip[sample].sample_length + 0.05, im_ch, scaled[sample][1])
    track[sample].end_point = clip[sample].sample_length + softcut_offsets[sample]
    softcut.enable(sample, 1)
    softcut.play(sample, 1)
    softcut.rec_level(sample,0)
    softcut.level(sample, 1)
    softcut.loop_start(sample,track[sample].start_point)
    softcut.loop_end(sample,track[sample].end_point)
    softcut.position(sample,track[sample].start_point)
    chitter_stretch[sample].pos = track[sample].start_point
    clear[sample] = 0
    track[sample].rec_limit = 0
  end
  if params:get("clip "..sample.." sample") ~= file then
    params:set("clip "..sample.." sample", file, 1)
  end
end

return ca