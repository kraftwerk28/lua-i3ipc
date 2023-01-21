local struct = require("struct")
local json = require("cjson")

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

local HEADER_LEN = 6 + 4 + 4

function Parser:_parse_packet()
  if #self.buf < HEADER_LEN then
    return
  end
  local raw_header = self.buf:sub(1, HEADER_LEN)
  local magic, len, type = struct.unpack("< c6 i4 i4", raw_header)
  if #self.buf < HEADER_LEN + len then
    return
  end
  local raw_payload = self.buf:sub(HEADER_LEN + 1, HEADER_LEN + len)
  local ok, payload = pcall(json.decode, raw_payload)
  local message = { type = type, payload = payload }
  self.buf = self.buf:sub(HEADER_LEN + len + 1)
  if not ok then
    return
  end
  if magic ~= "i3-ipc" then
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

return Parser
