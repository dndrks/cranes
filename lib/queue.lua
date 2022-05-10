local queue = {}

function queue.seed_to_playing(_t)
  track[_t].start_point = track[_t].queued.start_point
  track[_t].end_point = track[_t].queued.end_point
  _loop.refresh_softcut_loops(_t)
end

function queue.record_to_queued(_t)

end

function queue.init()
  waveform_samples = {{},{},{},{}}
  interval = {{},{},{},{}}
  softcut.event_render(queue.on_render)
end

function queue.on_render(ch, start, i, s)
  local _t;
  if start < 100 then
    if ch <= 2 then
      _t = ch
    end
  else
    if ch <= 2 then
      _t = ch+2
    end
  end
  waveform_samples[_t] = s
  interval[_t] = i
  queue.crawl_audio(_t)
  -- print(queue.crawl_audio(_t)) -- this would be where we assign state to clear[_t]...
  -- local stuff = queue.crawl_audio(_t)
  -- clear[_t] = queue.crawl_audio(_t) and false or true
end

function just_returns(x)
  return(x)
end

function queue.average(t)
  local sum = 0
  for _,v in pairs(t) do -- Get the sum of all numbers in t
    sum = sum + v
  end
  return sum / #t
end

function queue.is_there_audio(_t)
  local buffers = {1,2,1,2}
  softcut.render_buffer(buffers[_t], track[_t].queued.start_point, track[_t].queued.end_point - track[_t].queued.start_point, 128)
  -- return util.round(_cue.average(waveform_samples[_t]),0.001) > 0.001
end

function queue.crawl_audio(_t)
  local stand_in = waveform_samples[_t]
  table.sort(stand_in)
  if math.abs(stand_in[1]) > 0.003 or math.abs(stand_in[128]) > 0.003 then
    clear[_t] = false
  else
    clear[_t] = true
  end
end

return queue