local Reader = {}
Reader.__index = Reader

local function pass_through(data)
  return data
end

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
      local waiting_coro = table.remove(self.coro_queue, 1)
      if waiting_coro ~= nil then
        assert(coroutine.resume(waiting_coro, msg))
      else
        -- print("[Producer] No waiting coroutines, put message in a queue")
        table.insert(self.message_queue, msg)
      end
      data = rest
    end
  until data == nil or data == ""
end

function Reader:add_awaiter(co)
  assert(type(co) == "thread", "Argument `co` must be of type `coroutine`")
  table.insert(self.coro_queue, 1, co)
end

function Reader:recv()
  local waiting_msg = table.remove(self.message_queue, 1)
  if waiting_msg then
    return waiting_msg
  else
    table.insert(self.coro_queue, coroutine.running())
    return coroutine.yield()
  end
end

return Reader
