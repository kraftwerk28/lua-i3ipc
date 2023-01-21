local json = require("cjson")
local ffi = require("ffi")

local I3IPC_MAGIC = "i3-ipc"

ffi.cdef([[
  #pragma pack(1)
  struct i3ipc_header {
    char magic[6];
    uint32_t len;
    uint32_t type;
  };
]])

local header_ctor = ffi.typeof("struct i3ipc_header")
local header_size = ffi.sizeof(header_ctor)
print(header_size)

local Parser = {}
Parser.__index = Parser

function Parser:new()
  return setmetatable({
    handlers = {},
    buf = "",
  }, self)
end

function Parser:parse(buffer)
  self.buf = self.buf .. buffer
  while true do
    if not self:_parse_packet(buffer) then
      break
    end
  end
end

function Parser:_parse_packet()
  if #self.buf < header_size then
    return
  end
  local header = ffi.cast("struct i3ipc_header *", self.buf:sub(1, header_size))
  if #self.buf < header_size + header.len then
    -- Buffer still too small
    return
  end
  if ffi.string(header.magic, #I3IPC_MAGIC) ~= I3IPC_MAGIC then
    -- Invalid packet, skip
    self.buf = self.buf:sub(1 + header_size + header.len)
    return
  end
  local raw_payload = self.buf:sub(header_size + 1, header_size + header.len)
  local ok, payload = pcall(json.decode, raw_payload)
  local message = { type = header.type, payload = payload }
  self.buf = self.buf:sub(1 + header_size + header.len)
  if not ok then
    return
  end
  for _, handler in ipairs(self.handlers) do
    handler(message)
  end
  return true
end

function Parser:on_message(callback)
  table.insert(self.handlers, callback)
end

function Parser.serialize(type, payload)
  local header = header_ctor({
    magic = I3IPC_MAGIC,
    len = payload and #payload or 0,
    type = type,
  })
  local raw = ffi.string(header, header_size)
  if payload then
    raw = raw .. payload
  end
  return raw
end

return Parser
