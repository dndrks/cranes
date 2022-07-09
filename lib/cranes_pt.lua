--- timed pattern event recorder/player
-- @module lib.pattern

local pattern = {}
pattern.__index = pattern

--- constructor
function pattern.new(id)
  local i = {}
  setmetatable(i, pattern)
  i.rec = 0
  i.play = 0
  i.overdub = 0
  i.prev_time = 0
  i.event = {}
  i.time = {}
  i.count = 0
  i.step = 0
  i.loop = 1
  i.time_factor = 1
  i.name = id

  i.metro = metro.init(function() i:next_event() end,1,1)

  i.process = function(_) print("event") end

  return i
end

--- clear this pattern
function pattern:clear()
  self.metro:stop()
  self.rec = 0
  self.play = 0
  self:set_overdub(0)
  self.prev_time = 0
  self.event = {}
  self.time = {}
  self.count = 0
  self.step = 0
  self.time_factor = 1
end

--- adjust the time factor of this pattern.
-- @tparam number f time factor
function pattern:set_time_factor(f)
  self.time_factor = f or 1
end

--- start recording
function pattern:rec_start()
  self.rec = 1
end

--- stop recording
function pattern:rec_stop()
  if self.rec == 1 then
    self.rec = 0
    if self.count ~= 0 then
      --print("count "..self.count)
      local t = self.prev_time
      self.prev_time = util.time()
      self.time[self.count] = self.prev_time - t
      --tab.print(self.time)
    end
  end
end

--- watch
function pattern:watch(e)
  if self.rec == 1 then
    self:rec_event(e)
  elseif self.overdub == 1 then
    self:overdub_event(e)
  end
end

--- record event
function pattern:rec_event(e)
  local c = self.count + 1
  if c == 1 then
    self.prev_time = util.time()
  else
    local t = self.prev_time
    self.prev_time = util.time()
    self.time[c-1] = self.prev_time - t
  end
  self.count = c
  self.event[c] = e
end

--- add overdub event
function pattern:overdub_event(e)
  local c = self.step + 1
  local t = self.prev_time
  self.prev_time = util.time()
  local a = self.time[c-1]
  self.time[c-1] = self.prev_time - t
  table.insert(self.time, c, a - self.time[c-1])
  table.insert(self.event, c, e)
  self.step = self.step + 1
  self.count = self.count + 1
end

--- start this pattern
function pattern:start()
  if self.count > 0 then
    --print("start pattern ")
    self.prev_time = util.time()
    self.process(self.event[1])
    self.play = 1
    self.step = 1
    self.metro.time = self.time[1] * self.time_factor
    self.metro:start()
  end
end

--- process next event
function pattern:next_event()
  self.prev_time = util.time()
  self.step = util.wrap(self.step+1,1,self.count)
  -- if self.step == self.count and self.loop == 1 then
  --   self.step = 1
  -- elseif self.step > self.count and self.loop == 1 then
  --   self.step = 1
  -- else
  --   self.step = self.step + 1
  -- end
  self.process(self.event[self.step])
  self.metro.time = self.time[self.step] * self.time_factor
  if self.step == self.count and self.loop == 0 then
    if self.play == 1 then
      self.play = 0
      self.metro:stop()
    end
  else
    self.metro:start()
  end
end

--- stop this pattern
function pattern:stop()
  if self.play == 1 then
    self.play = 0
    -- self.overdub = 0
    self:set_overdub(0)
    self.metro:stop()
  end
end

-- duplicate the pattern 
function pattern:duplicate()
  if self.count > 0 then
    for i = 1,self.count do
      self.event[i+self.count] = self.deep_copy(self.event[i])
      self.time[i+self.count] = self.deep_copy(self.time[i])
    end
    self.count = self.count * 2
  end
end

--- set overdub
function pattern:set_overdub(s)
  if s==1 and self.play == 1 and self.rec == 0 then
    self.overdub = 1
  else
    self.overdub = 0
  end
  if self.overdub_action ~= nil then
    self.overdub_action(self.name,self.overdub == 1 and true or false)
  end
end

function pattern.deep_copy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == "table" then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[pattern.deep_copy(orig_key)] = pattern.deep_copy(orig_value)
    end
    setmetatable(copy, pattern.deep_copy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

return pattern