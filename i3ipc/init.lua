local struct = require("struct")
local uv = require("luv")
local json = require("i3ipc.json")

local Connection = {}
Connection.__index = Connection

local MAGIC = "i3-ipc"
local HEADER_SIZE = #MAGIC+8

local COMMAND = {
  RUN_COMMAND       = 0,  -- Run the payload as an i3 command (like the commands you can bind to keys).
  GET_WORKSPACES    = 1,  -- Get the list of current workspaces.
  SUBSCRIBE         = 2,  -- Subscribe this IPC connection to the event types specified in the message payload. See [events].
  GET_OUTPUTS       = 3,  -- Get the list of current outputs.
  GET_TREE          = 4,  -- Get the i3 layout tree.
  GET_MARKS         = 5,  -- Gets the names of all currently set marks.
  GET_BAR_CONFIG    = 6,  -- Gets the specified bar configuration or the names of all bar configurations if payload is empty.
  GET_VERSION       = 7,  -- Gets the i3 version.
  GET_BINDING_MODES = 8,  -- Gets the names of all currently configured binding modes.
  GET_CONFIG        = 9,  -- Returns the last loaded i3 config.
  SEND_TICK         = 10, -- Sends a tick event with the specified payload.
  SYNC              = 11, -- Sends an i3 sync event with the specified random value to the specified window.
  GET_BINDING_STATE = 12, -- Request the current binding state, i.e. the currently active binding mode name.

  -- Sway-only
  GET_INPUTS        = 100,
  GET_SEATS         = 100,
}

local EVENT = {
  WORKSPACE        = {0, "workspace"       }, -- Sent when the user switches to a different workspace, when a new workspace is initialized or when a workspace is removed (because the last client vanished).
  OUTPUT           = {1, "output"          }, -- Sent when RandR issues a change notification (of either screens, outputs, CRTCs or output properties).
  MODE             = {2, "mode"            }, -- Sent whenever i3 changes its binding mode.
  WINDOW           = {3, "window"          }, -- Sent when a client’s window is successfully reparented (that is when i3 has finished fitting it into a container), when a window received input focus or when certain properties of the window have changed.
  BARCONFIG_UPDATE = {4, "barconfig_update"}, -- Sent when the hidden_state or mode field in the barconfig of any bar instance was updated and when the config is reloaded.
  BINDING          = {5, "binding"         }, -- Sent when a configured command binding is triggered with the keyboard or mouse
  SHUTDOWN         = {6, "shutdown"        }, -- Sent when the ipc shuts down because of a restart or exit by user command
  TICK             = {7, "tick"            },
}

local function parse_header(raw)
  local magic, len, type = struct.unpack("< c6 i4 i4", raw)
  if magic ~= MAGIC then return false end
  return true, len, type
end

local function serialize(type, payload)
  payload = payload or ""
  return struct.pack("< c6 i4 i4", MAGIC, #payload, type)..payload
end

function Connection:new()
  local pipe = uv.new_pipe(true)
  local sockpath = self:_get_sockpath()
  local co = coroutine.running()
  pipe:connect(sockpath, function()
    assert(coroutine.resume(co))
  end)
  local err = coroutine.yield()
  if err ~= nil then
    error("Failed to connect")
  end
  local conn = setmetatable({
    pipe = pipe,
    subscriptions = {},
    coro = co,
    send_awaiters = {},
    main_finished = false,
  }, self)
  conn:_start_read()
  return conn
end

function Connection:send(type, payload)
  local event_id = type
  local msg = serialize(event_id, payload)
  table.insert(self.send_awaiters, coroutine.running())
  self.pipe:write(msg)
  local _, response = coroutine.yield()
  return response
end

function Connection:on(event, callback)
  local event_id, event_name = event[1], event[2]
  local s = self.subscriptions
  s[event_id] = s[event_id] or {}
  s[event_id][callback] = true
  local raw = json.encode({event_name})
  return self:send(2, raw)
end

function Connection:off(event, callback)
  local event_id = event[1]
  if (self.subscriptions[event_id] or {})[callback] then
    self.subscriptions[event_id][callback] = nil
    if not self:_has_subscriptions() and self.main_finished then
      self:_stop()
    end
    return true
  end
  return false
end

function Connection:_has_subscriptions()
  for _, callbacks in pairs(self.subscriptions) do
    if next(callbacks) ~= nil then return true end
  end
  return false
end

function Connection:once(event, callback)
  local function handler(...)
    callback(...)
    assert(self:off(event, handler))
  end
  self:on(event, handler)
end

function Connection:_get_sockpath()
  local sockpath = os.getenv("SWAYSOCK") or os.getenv("I3SOCK")
  if sockpath == nil then
    error("Neither of SWAYSOCK nor I3SOCK environment variables are defined")
  end
  return sockpath
end

function Connection:_process_message(type, raw_payload)
  local payload = json.decode(raw_payload)
  if bit.band(bit.rshift(type, 31), 1) == 1 then
    local event_id = bit.band(type, 0x7f)
    if self.subscriptions[event_id] ~= nil then
      coroutine.wrap(function()
        for callback, _ in pairs(self.subscriptions[event_id]) do
          callback(self, payload)
        end
      end)()
    end
  else
    local co = table.remove(self.send_awaiters, 1)
    coroutine.resume(co, type, payload)
  end
end

function Connection:_process_chunk(chunk)
  local partial = self.read_partial
  if partial ~= nil then
    local needed_bytes_count = partial.len - #partial.payload
    if needed_bytes_count > #chunk then
      partial.payload = partial.payload .. chunk
    else
      self:_process_message(
        partial.type,
        partial.payload .. chunk:sub(1, needed_bytes_count)
      )
      self.read_partial = nil
      if #chunk > needed_bytes_count then
        self:_process_chunk(chunk:sub(needed_bytes_count+1))
      end
    end
    return
  end

  local parsed, msg_len, msg_type = parse_header(chunk:sub(1, HEADER_SIZE))
  assert(parsed, "Failed to parse the message")
  local raw_payload = chunk:sub(HEADER_SIZE+1)
  local actual_len = #raw_payload

  if actual_len < msg_len then
    -- Not enough payload, need more chunks
    self.read_partial = {type = msg_type, len = msg_len, payload = raw_payload}
  elseif actual_len == msg_len then
    self:_process_message(msg_type, raw_payload)
  else -- actual_len > msg_len
    self:_process_message(msg_type, raw_payload:sub(1, msg_len))
    self:_process_chunk(raw_payload:sub(msg_len + 1))
  end
end

function Connection:_start_read()
  self.pipe:read_start(function(err, chunk)
    if err ~= nil or chunk == nil then
      return
    end
    self:_process_chunk(chunk)
  end)
end

function Connection:_stop()
  uv.stop()
end

function Connection:command(command)
  return self:send(COMMAND.RUN_COMMAND, command)
end

function Connection:get_tree()
  local tree = self:send(COMMAND.GET_TREE)
  local tree_mt = {}

  function tree_mt:find_con(predicate)
    local queue = {self}
    while #queue > 0 do
      local cur = table.remove(queue, 1)
      if predicate(cur) then
        return cur
      end
      for _, con in ipairs(cur.nodes or {}) do
        table.insert(queue, con)
      end
      for _, con in ipairs(cur.floating_nodes or {}) do
        table.insert(queue, con)
      end
    end
  end

  function tree_mt:find_focused()
    return self:find_con(function(con) return con.focused end)
  end

  return setmetatable(tree, {__index = tree_mt})
end

-- Generate get_* methods for Connection
for method, cmd in pairs(COMMAND) do
  if method:match("^GET_") and method ~= "GET_TREE" then
    Connection[method:lower()] = function(ipc) return ipc:send(cmd) end
  end
end

local function main(fn)
  coroutine.wrap(function()
    local conn = Connection:new()
    fn(conn)
    if conn:_has_subscriptions() then
      conn.main_finished = true
    else
      conn:_stop()
    end
  end)()

  local function handle_signal()
    uv.stop()
  end
  for _, signal in ipairs{"sigint", "sigterm"} do
    local s = uv.new_signal()
    s:start(signal, handle_signal)
  end

  uv.run()
end

return {
  Connection = Connection,
  main = main,
  COMMAND = COMMAND,
  EVENT = EVENT,
}
