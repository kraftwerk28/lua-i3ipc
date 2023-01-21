local p = require("i3ipc.protocol")

local Cmd = {}
Cmd.__index = Cmd

function Cmd:new(conn)
  return setmetatable({
    conn = conn,
    -- { [command] = { handler1, handler2, ... } }
    handlers = {},
    subscribed_to_binding = false,
  }, self)
end

-- local function split_command(str)
--   local singleq, doubleq, escape = false, false, false
--   local endpos = 1
--   local ret = {}
--   while true do
--     local part = str:sub(endpos)
--     local sp_pos = part:find("[\"';,]")
--     if sp_pos == nil then
--       break
--     end
--     sp_pos = sp_pos + endpos - 1
--     local sp = str:sub(sp_pos, sp_pos)
--     if sp == '"' and not singleq and not escape then
--       doubleq = not doubleq
--       endpos = sp_pos + 1
--     elseif sp == "'" and not doubleq and not escape then
--       singleq = not singleq
--       endpos = sp_pos + 1
--     elseif not doubleq and not singleq and not escape then
--       table.insert(ret, str:sub(1, sp_pos - 1))
--       str = str:sub(sp_pos + 1)
--     else
--       endpos = sp_pos + 1
--     end
--   end
--   table.insert(ret, str)
--   return ret
-- end

function Cmd:setup()
  self.conn:on(p.EVENT.BINDING, function(_, event)
    local words = {}
    -- TODO: Respect quotes when splitting words (i.e. shlex)
    for word in event.binding.command:gmatch("[^%s]+") do
      table.insert(words, word)
    end
    if words[1] ~= "nop" then
      return
    end
    table.remove(words, 1)
    if self.prefix ~= nil then
      if words[1] ~= self.prefix then
        return
      end
      table.remove(words, 1)
    end
    if #words == 0 then
      return
    end
    local cmd = table.remove(words, 1)
    local cmd_handlers = self.handlers[cmd]
    if cmd_handlers == nil then
      return
    end
    for handler, _ in pairs(cmd_handlers) do
      handler(self.conn, unpack(words))
    end
  end)
  return self
end

function Cmd:set_prefix(prefix)
  self.prefix = prefix
  return self
end

function Cmd:on(command, callback)
  if not self.subscribed_to_binding then
    self:setup()
  end
  self.handlers[command] = self.handlers[command] or {}
  self.handlers[command][callback] = true
  return self
end

return Cmd
