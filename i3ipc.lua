local struct = require("struct")
local uv = require("luv")
local json = require("json")

local Connection = {}
Connection.__index = Connection

local MAGIC = "i3-ipc"
local HEADER_SIZE = #MAGIC+8

local COMMAND = {
  RUN_COMMAND = 0, -- Run the payload as an i3 command (like the commands you can bind to keys).
  GET_WORKSPACES = 1, -- Get the list of current workspaces.
  SUBSCRIBE = 2, -- Subscribe this IPC connection to the event types specified in the message payload. See [events].
  GET_OUTPUTS = 3, -- Get the list of current outputs.
  GET_TREE = 4, -- Get the i3 layout tree.
  GET_MARKS = 5, -- Gets the names of all currently set marks.
  GET_BAR_CONFIG = 6, -- Gets the specified bar configuration or the names of all bar configurations if payload is empty.
  GET_VERSION = 7, -- Gets the i3 version.
  GET_BINDING_MODES = 8, -- Gets the names of all currently configured binding modes.
  GET_CONFIG = 9, -- Returns the last loaded i3 config.
  SEND_TICK = 10, -- Sends a tick event with the specified payload.
  SYNC = 11, -- Sends an i3 sync event with the specified random value to the specified window.
  GET_BINDING_STATE = 12, -- Request the current binding state, i.e. the currently active binding mode name.
}

local EVENT = {
  WORKSPACE = {0, "workspace"}, -- Sent when the user switches to a different workspace, when a new workspace is initialized or when a workspace is removed (because the last client vanished).
  OUTPUT = {1, "output"}, -- Sent when RandR issues a change notification (of either screens, outputs, CRTCs or output properties).
  MODE = {2, "mode"}, -- Sent whenever i3 changes its binding mode.
  WINDOW = {3, "window"}, -- Sent when a client’s window is successfully reparented (that is when i3 has finished fitting it into a container), when a window received input focus or when certain properties of the window have changed.
  BARCONFIG_UPDATE = {4, "barconfig_update"}, -- Sent when the hidden_state or mode field in the barconfig of any bar instance was updated and when the config is reloaded.
  BINDING = {5, "binding"}, -- Sent when a configured command binding is triggered with the keyboard or mouse
  SHUTDOWN = {6, "shutdown"}, -- Sent when the ipc shuts down because of a restart or exit by user command
  TICK = {7, "tick"},
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
    incoming_messages = {},
    coro = co,
  }, self)
  conn:_start_read()
  return conn
end

function Connection:send(type, payload)
  local event_id = type
  local msg = serialize(event_id, payload)
  self.pipe:write(msg)
  local _, payload = coroutine.yield()
  return payload
end

function Connection:subscribe(event, callback)
  local event_id, event_name = event[1], event[2]
  local s = self.subscriptions
  s[event_id] = s[event_id] or {}
  s[event_id][callback] = true
  local raw = json.encode({event_name})
  return self:send(2, raw)
end

function Connection:unsubscribe(event, callback)
  local event_id = event[1]
  if (self.subscriptions[event_id] or {})[callback] then
    self.subscriptions[event_id][callback] = nil
    return true
  end
  return false
end

function Connection:subscribe_once(event, callback)
  local function handler(...)
    self:unsubscribe(event, handler)
    callback(...)
  end
  self:subscribe(event, handler)
end

function Connection:_get_sockpath()
  local sockpath = os.getenv("SWAYSOCK") or os.getenv("I3SOCK")
  if sockpath == nil then
    error("Neither of SWAYSOCK nor I3_SOCKE_PATH environment variables are defined")
  end
  return sockpath
end

function Connection:_process_message(type, raw_payload)
  local payload = json.decode(raw_payload)
  if bit.band(bit.rshift(type, 31), 1) == 1 then
    coroutine.wrap(function()
      local event_id = bit.band(type, 0x7f)
      -- local real_type = bit.band(type, 0x7f)
      for callback, _ in pairs(self.subscriptions[event_id] or {}) do
        callback(payload)
      end
    end)()
  else
    coroutine.resume(self.coro, type, payload)
  end
end

function Connection:_start_read()
  local partial_payload = ""
  local partial_remaining_length = 0
  local partial_type

  local function read_handler(err, chunk)
    if err ~= nil then
      return
    end
    if not chunk then
      return
    end
    if partial_remaining_length > 0 then
      local payload = partial_payload..chunk:sub(1, partial_remaining_length)
      chunk = chunk:sub(partial_remaining_length+1)
      partial_type = nil
      partial_remaining_length = 0
      partial_payload = ""
      coroutine.yield(partial_type, payload)
    end
    local header = chunk:sub(1, HEADER_SIZE)
    local header_parsed, payload_len, payload_type = parse_header(header)
    assert(header_parsed, "Failed to parse message header")
    local payload = chunk:sub(HEADER_SIZE+1, HEADER_SIZE+payload_len)
    local actual_len = #payload
    if actual_len < payload_len then
      partial_payload = payload
      partial_remaining_length = payload_len - actual_len
      partial_type = payload_type
    else
      self:_process_message(payload_type, payload)
    end
  end

  self.pipe:read_start(read_handler)
end

local function main(fn)
  coroutine.wrap(function()
    fn()
    -- uv.stop()
  end)()

  local s = uv.new_signal()
  s:start("sigint", function()
    print("Exiting...")
    uv.stop()
  end)

  uv.run()
end

return {
  Connection = Connection,
  main = main,
  COMMAND = COMMAND,
  EVENT = EVENT,
}
