#!/usr/bin/env luajit
local i3ipc = require("i3ipc")
-- local uv = require("uv")
i3ipc.main(function(ipc)
  ipc.cmd:on("select", function(a, b)
    print(a, b)
  end)
end)
