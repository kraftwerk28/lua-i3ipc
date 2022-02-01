local uv = require("luv")
local Reader = require("i3ipc.reader")

local ExtCmd = {}
ExtCmd.__index = ExtCmd

function ExtCmd:new()
  local pipe = uv.new_pipe()
  local extcmd = setmetatable({
    pipe = pipe,
    line_reader = Reader:new(function(data)
      local idx = data:find("\n")
      if not idx then
        return data
      else
        return data:sub(1, idx - 1), data:sub(idx + 1)
      end
    end),
    subscriptions = {},
  }, self)
  coroutine.wrap(function()
    while true do
      local line = extcmd.line_reader:recv()
      local cmd, rest = line:match("^%s*(%S+)(.*)")
      rest = rest:gsub("^%s+", ""):gsub("%s+$", "")
      for handler in pairs(extcmd.subscriptions[cmd] or {}) do
        coroutine.wrap(function()
          handler(self, rest)
        end)()
      end
    end
  end)()
  return extcmd
end

function ExtCmd:listen_socket(sockpath)
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
        client_pipe:shutdown()
        client_pipe:close()
      end
    end)
  end)
  if status ~= 0 then
    print("listen error", err)
  end
end

function ExtCmd:on(command, callback)
  self.subscriptions[command] = self.subscriptions[command] or {}
  self.subscriptions[command][callback] = true
end

return ExtCmd
