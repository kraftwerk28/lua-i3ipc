#!/usr/bin/env luajit
local i3 = require("i3ipc")

local ipc = i3.Connection:new()

ipc:main(function()
  ipc:on("window", function(event)
    print(event.change)
  end)
  ipc.cmd:on("tab", function(args)
    for i, arg in ipairs(args) do
      print(i.."arg "..arg)
    end
  end)
end)
