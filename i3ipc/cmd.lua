local p = require("i3ipc.protocol")

local Cmd = {}
Cmd.__index = Cmd

function Cmd:new(conn)
  local c = setmetatable({
    conn = conn,
    -- { [command] = { handler1, handler2, ... } }
    handlers = {},
  }, self)
  return c
end

function Cmd:setup()
  self.conn:on(p.EVENT.BINDING, function(event)
    local words = {}
    for word in event.binding.command:gmatch("[^%s]+") do
      table.insert(words, word)
    end
    if words[1] ~= "nop" then return end
    table.remove(words, 1)
    if self.prefix ~= nil then
      if words[1] ~= self.prefix then
        return
      end
      table.remove(words, 1)
    end
    if #words == 0 then return end
    local cmd = table.remove(words, 1)
    for h, _ in pairs(self.handlers[cmd] or {}) do h(words) end
  end)
end

function Cmd:set_prefix(prefix)
  self.prefix = prefix
end

function Cmd:on(command, callback)
  self.handlers[command] = self.handlers[command] or {}
  self.handlers[command][callback] = true
end

return Cmd
