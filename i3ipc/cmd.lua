local uv = require("luv")
local Reader = require("i3ipc.reader")

local Cmd = {}
Cmd.__index = Cmd

function Cmd:new()
  local pipe = uv.new_pipe()
  local extcmd = setmetatable({
    pipe = pipe,
    line_reader = Reader:new(function(data, is_eof)
      if not is_eof then
        return nil
      end
      return data
    end),
    subscriptions = {},
  }, self)
  coroutine.wrap(function()
    while true do
      local args = {}
      for line in extcmd.line_reader:recv():gmatch("[^\n]+") do
        table.insert(args, line)
      end
      local cmd = table.remove(args, 1)
      for handler in pairs(extcmd.subscriptions[cmd] or {}) do
        coroutine.wrap(function()
          handler(self, unpack(args))
        end)()
      end
    end
  end)()
  return extcmd
end

function Cmd:listen_socket(sockpath)
  if not sockpath then
    sockpath = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/lua-i3ipc.sock"
  end
  uv.fs_unlink(sockpath)
  self.pipe:bind(sockpath)
  local status, err = self.pipe:listen(64, function(err)
    local client_pipe = uv.new_pipe()
    self.pipe:accept(client_pipe)
    client_pipe:read_start(function(err, data)
      if err ~= nil then
        print(err)
      end
      if data then
        self.line_reader:push(data)
      else
        self.line_reader:push(nil, true)
        client_pipe:shutdown()
        client_pipe:close()
      end
    end)
  end)
  if status ~= 0 then
    print("listen error", err)
  end
end

function Cmd:on(command, callback)
  self.subscriptions[command] = self.subscriptions[command] or {}
  self.subscriptions[command][callback] = true
end

return Cmd
