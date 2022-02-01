local Reader = {}
Reader.__index = Reader

local function pass_through(data) return data end

-- The `parse` function shall return either
-- - nil, if the message can't be parsed
-- - message, string, if message was parsed plus remaining data
function Reader:new(parse_fn)
  return setmetatable({
    parse = parse_fn or pass_through,
    partial = nil,
    coro_queue = {},
    message_queue = {},
  }, self)
end

function Reader:push(data, ...)
  if self.partial ~= nil then
    data = self.partial .. (data or "")
    self.partial = nil
  end
  repeat
    local msg, rest = self.parse(data, ...)
    if msg == nil then
      self.partial = data
      break
    else
      if self.coro_queue[1] then
        -- print("[Producer] Resume the waiting coroutine")
        assert(coroutine.resume(self.coro_queue[1], msg))
        table.remove(self.coro_queue, 1)
      else
        -- print("[Producer] No waiting coroutines, put message in a queue")
        table.insert(self.message_queue, msg)
      end
      data = rest
    end
  until data == nil or data == ""
end

function Reader:add_awaiter(co)
  if type(co) ~= "thread" then
    error("Argument `co` must be of type `coroutine`")
  end
  table.insert(self.coro_queue, 1, co)
end

function Reader:recv()
  if self.message_queue[1] then
    -- print("[Consumer] Receiving a message from the queue")
    local res = self.message_queue[1]
    table.remove(self.message_queue, 1)
    return res
  else
    -- print("[Consumer] No messages in the queue, yielding")
    table.insert(self.coro_queue, coroutine.running())
    return coroutine.yield()
  end
end

return Reader
