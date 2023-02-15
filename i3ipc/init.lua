local uv = require("luv")
local json = require("cjson")

local Parser = require("i3ipc.parser")
-- local Reader = require("i3ipc.reader")
local wrap_node = require("i3ipc.node-mt")
local Cmd = require("i3ipc.cmd")
local p = require("i3ipc.protocol")

local Connection = {}
Connection.__index = Connection

local function is_builtin_event(e)
  if type(e) ~= "table" or #e ~= 2 then
    return false
  end
  for _, v in pairs(p.EVENT) do
    if v[1] == e[1] and v[2] == e[2] then
      return true
    end
  end
  return false
end

local function resolve_event(event)
  if is_builtin_event(event) then
    -- i.e. EVENT.WINDOW
    return { { id = event[1], name = event[2] } }
  elseif type(event) == "string" then
    -- i.e. "window::new" or just "window"
    local name, change = event:match("(%w+)::(%w+)")
    if name == nil then
      name = event
    end
    for _, v in pairs(p.EVENT) do
      if v[2] == name then
        return { { id = v[1], name = v[2], change = change } }
      end
    end
  elseif type(event) == "table" then
    -- i.e. { EVENT.WINDOW, "workspace::focus" }
    local result = {}
    for _, v in ipairs(event) do
      local resolved = resolve_event(v)
      for _, r in ipairs(resolved) do
        table.insert(result, r)
      end
    end
    return result
  else
    error("Invalid event type")
  end
end

local function get_sockpath()
  local sockpath = os.getenv("SWAYSOCK") or os.getenv("I3SOCK")
  if sockpath == nil then
    error("Neither of SWAYSOCK nor I3SOCK environment variables are set")
  end
  return sockpath
end

function Connection:new()
  local pipe = uv.new_pipe(true)

  local parser = Parser:new()

  local conn = setmetatable({
    pipe = pipe,
    parser = parser,
    handlers = {},
    result_waiters = {},
    message_queue = {},
    -- Cache IPC subscriptions to avoid multiple calls to `subscribe` with the
    -- same update type
    subscribed_to = {},
    main_finished = false,
  }, self)

  conn.cmd = Cmd:new(conn)

  parser:on_message(function(msg)
    conn:_on_message(msg)
  end)

  conn.consumer_coro = coroutine.create(function()
    conn:_consume_events()
  end)
  coroutine.resume(conn.consumer_coro)

  return conn
end

--
-- Private methods:
--

function Connection:_consume_events()
  while true do
    coroutine.yield()
    while #self.message_queue > 0 do
      local msg = self.message_queue[1]
      -- MSB of msg.type == 1, so this is an event
      local handlers = self.handlers[msg.type] or {}
      for _, handler in pairs(handlers) do
        if handler.change == nil or msg.payload.change == handler.change then
          handler.callback(self, msg.payload)
        end
      end
      table.remove(self.message_queue, 1)
    end
  end
end

function Connection:_on_message(msg)
  local event_id = bit.band(msg.type, 0x7fffffff)
  if event_id == msg.type then
    -- This is a command result
    local waiter_coro = table.remove(self.result_waiters, 1)
    if waiter_coro then
      assert(coroutine.resume(waiter_coro, msg.payload))
    end
  else
    msg.type = event_id
    table.insert(self.message_queue, msg)
    if #self.message_queue == 1 then
      assert(coroutine.resume(self.consumer_coro))
    end
  end
end

function Connection:_has_subscriptions()
  for _, h in pairs(self.handlers) do
    if #h > 0 then
      return true
    end
  end
  return false
end

function Connection:_stop()
  self.pipe:read_stop()
  self.pipe:close(function()
    uv.stop()
  end)
end

function Connection:_is_subscribed_to(event)
  local evd = resolve_event(event)
  for _, e in ipairs(evd) do
    if not self.subscribed_to[e.name] then
      return false
    end
  end
  return true
end

function Connection:_connect_socket(sockpath)
  sockpath = sockpath or get_sockpath()
  local co = coroutine.running()
  self.pipe:connect(sockpath, function()
    assert(coroutine.resume(co))
  end)
  coroutine.yield()
  self.pipe:read_start(function(err, chunk)
    if err then
      self:_stop()
    elseif chunk then
      self.parser:parse(chunk)
    end
  end)
end

function Connection:_subscribe_shutdown()
  self:once(p.EVENT.SHUTDOWN, function(ipc)
    ipc:_stop()
  end)
end

--
-- Public methods:
--

function Connection:send(type, payload)
  local event_id = type
  local msg = Parser.serialize(event_id, payload)
  table.insert(self.result_waiters, coroutine.running())
  self.pipe:write(msg)
  return coroutine.yield()
end

function Connection:on(event, callback)
  local evd = resolve_event(event)
  local replies = {}
  for _, e in ipairs(evd) do
    e.callback = callback
    self.handlers[e.id] = self.handlers[e.id] or {}
    table.insert(self.handlers[e.id], e)
    if not self.subscribed_to[e.name] then
      local raw = json.encode({ e.name })
      local reply = self:send(p.COMMAND.SUBSCRIBE, raw)
      table.insert(replies, reply)
      self.subscribed_to[e.name] = true
    end
  end
  return replies
end

function Connection:off(event, callback)
  local evd = resolve_event(event)
  local nremoved = 0
  for _, e in ipairs(evd) do
    local new_handlers = {}
    for _, h in ipairs(self.handlers[e.id]) do
      if
        (callback ~= nil and e.callback ~= callback)
        and (e.change ~= nil and e.change ~= h.change)
      then
        table.insert(new_handlers, h)
      end
    end
    if #new_handlers > 0 then
      nremoved = nremoved + (#self.handlers[e.id] - #new_handlers)
      self.handlers[e.id] = new_handlers
    else
      nremoved = nremoved + #self.handlers[e.id]
      self.handlers[e.id] = nil
    end
  end
  if not self:_has_subscriptions() and self.main_finished then
    self:_stop()
  end
  return nremoved
end

function Connection:once(event, callback)
  local function handler(...)
    callback(...)
    local nremoved = self:off(event, handler)
    assert(nremoved > 0)
  end
  self:on(event, handler)
end

function Connection:command(command)
  return self:send(p.COMMAND.RUN_COMMAND, command)
end

function Connection:get_tree()
  local tree = self:send(p.COMMAND.GET_TREE)
  return wrap_node(tree)
end

-- Generate get_* methods for Connection
for method, cmd in pairs(p.COMMAND) do
  if method:match("^GET_") and method ~= "GET_TREE" then
    Connection[method:lower()] = function(self)
      return self:send(cmd)
    end
  end
end

function Connection:main(callback)
  local function handle_signal()
    coroutine.wrap(function()
      self:_stop()
    end)()
  end
  for _, signal in ipairs({ "sigint", "sigterm" }) do
    local s = uv.new_signal()
    s:start(signal, handle_signal)
  end
  coroutine.wrap(function()
    self:_connect_socket()
    self:_subscribe_shutdown()
    callback(self)
    if self:_has_subscriptions() then
      self.main_finished = true
    else
      self:_stop()
    end
  end)()
  uv.run()
end

local function main(fn)
  local conn = Connection:new()
  conn:main(fn)
end

return {
  Connection = Connection,
  main = main,
  COMMAND = p.COMMAND,
  EVENT = p.EVENT,
  wrap_node = wrap_node,
  Cmd = Cmd,
}
