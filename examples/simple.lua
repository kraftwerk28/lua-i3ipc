#!/usr/bin/env luajit
-- Switch to prev/next tab in topmost tabbed layout
local i3 = require("i3ipc")
local ipc = i3.Connection:new()
ipc:main(function()
  local ret = ipc:command([[exec notify-send "Hello, from i3ipc"]])
  print(require("inspect")(ret))
  local count = 0
  ipc:on("window", function(_, event)
    count = count + 1
    print(require("inspect")(event))
  end)
end)
