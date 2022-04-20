require("i3ipc.pkgpath")
local struct = require("struct")
local uv = require("luv")
local json = require("cjson")

local Reader = require("i3ipc.reader")
local wrap_node = require("i3ipc.node-mt")
local Cmd = require("i3ipc.cmd")
local p = require("i3ipc.protocol")

local Connection = {}
Connection.__index = Connection

local function is_builtin_event(e)
  if type(e) ~= "table" or #e ~= 2 then return false end
  for _, v in pairs(p.EVENT) do
    if v[1] == e[1] and v[2] == e[2] then return true end
  end
  return false
end

local function parse_header(raw)
  local magic, len, type = struct.unpack("< c6 i4 i4", raw)
  if magic ~= p.MAGIC then return false end
  return true, len, type
end

local function serialize(type, payload)
  payload = payload or ""
  return struct.pack("< c6 i4 i4", p.MAGIC, #payload, type)..payload
end

function Connection._get_sockpath()
  local sockpath = os.getenv("SWAYSOCK") or os.getenv("I3SOCK")
  if sockpath == nil then
    error("Neither of SWAYSOCK nor I3SOCK environment variables are set")
  end
  return sockpath
end

function Connection:new(opts)
  opts = opts or {}
  local pipe = uv.new_pipe(true)

  local ipc_reader = Reader:new(function(data)
    if #data < p.HEADER_SIZE then
      return nil
    end
    local _, msg_len, msg_type = parse_header(data:sub(1, p.HEADER_SIZE))
    local raw_payload = data:sub(p.HEADER_SIZE + 1, p.HEADER_SIZE + msg_len)
    if #raw_payload < msg_len then
      return nil
    end
    local ok, payload = pcall(json.decode, raw_payload)
    if not ok then
      return nil
    end
    local message = { type = msg_type, payload = payload }
    return message, data:sub(p.HEADER_SIZE + msg_len + 1)
  end)

  local conn = setmetatable({
    ipc_reader = ipc_reader,
    cmd_result_reader = Reader:new(),
    pipe = pipe,
    handlers = {},
    subscribed_to = {},
    main_finished = false,
  }, self)

  conn.cmd = Cmd:new(conn)

  coroutine.wrap(function()
    while true do
      local msg = conn.ipc_reader:recv()
      if bit.band(bit.rshift(msg.type, 31), 1) == 1 then
        local event_id = bit.band(msg.type, 0x7f)
        local handlers = conn.handlers[event_id] or {}
        for _, handler in pairs(handlers) do
          if handler.change == nil or msg.payload.change == handler.change then
            coroutine.wrap(function()
              handler.callback(msg.payload)
            end)()
          end
        end
      else
        conn.cmd_result_reader:push(msg.payload)
      end
    end
  end)()

  return conn
end

function Connection:connect_socket(sockpath)
  sockpath = sockpath or self:_get_sockpath()
  local co = coroutine.running()
  self.pipe:connect(sockpath, function()
    assert(coroutine.resume(co))
  end)
  coroutine.yield()
  self.pipe:read_start(function(err, chunk)
    if err ~= nil or chunk == nil then
      return
    end
    self.ipc_reader:push(chunk)
  end)
  self.cmd:setup()
end

function Connection:send(type, payload)
  local event_id = type
  local msg = serialize(event_id, payload)
  self.pipe:write(msg)
  return self.cmd_result_reader:recv()
end

local function resolve_event(event)
  if is_builtin_event(event) then
    -- i.e. EVENT.WINDOW
    return {{ id = event[1], name = event[2] }}
  elseif type(event) == "string" then
    -- i.e. "window::new" or just "window"
    local name, change = event:match("(%w+)::(%w+)")
    if name == nil then name = event end
    for _, v in pairs(p.EVENT) do
      if v[2] == name then
        return {{ id = v[1], name = v[2], change = change }}
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

function Connection:_has_subscriptions()
  for _, h in pairs(self.handlers) do
    if #h > 0 then return true end
  end
  return false
end

function Connection:_stop()
  self.pipe:read_stop()
  uv.stop()
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
    Connection[method:lower()] = function(ipc)
      return ipc:send(cmd)
    end
  end
end

function Connection:main(fn)
  coroutine.wrap(function()
    self:connect_socket()
    fn(self)
    if self:_has_subscriptions() then
      self.main_finished = true
    else
      self:_stop()
    end
  end)()
  local function handle_signal(signal)
    print("Received signal "..signal)
    self:_stop()
  end
  for _, signal in ipairs {"sigint", "sigterm"} do
    local s = uv.new_signal()
    s:start(signal, handle_signal)
  end
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
