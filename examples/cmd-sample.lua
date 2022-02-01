local uv = require("luv")
local Cmd = require("i3ipc.cmd")

local p = Cmd:new()

coroutine.wrap(function()
  p:listen_socket("i3ipc.sock")
  p:on("foo", function(_, ...)
    print(("a = %s; b = %s"):format(...))
  end)
end)()
uv.run()
