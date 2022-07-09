local transport = {}

local function begin()
  for i = 1,4 do
    if params:string("transport_start_play_voice_"..i) == "yes" then
      play_voice(i)
    end
  end
end

function clock.transport.start()
  if params:string("clock_source") == "link" then
    clock.run(
      function()
        clock.sync(1)
        begin()
        -- macros.reset_phase()
        -- tp.pending = false
        -- viz_metro_advance = 1
        -- if rec.transport_queued then
        --   tp.start_rec_from_transport()
        -- end
        print("starting transport: link")
      end
    )
  else
    print("starting transport: not Link")
    begin()
    -- macros.reset_phase()
    -- tp.pending = false
    -- if rec.transport_queued then
      -- tp.start_rec_from_transport()
    -- end
    -- viz_metro_advance = 1
  end
end

function clock.transport.stop()
  for i = 1,4 do
    if params:string("transport_stop_play_voice_"..i) == "yes" then
      print("should stop voice "..i)
      stop_voice(i)
    end
  end
end

return transport