#!/usr/bin/env luajit
local version = _VERSION:match("%d+%.%d+")
package.path = package.path..";"..
  os.getenv("HOME").."/.luarocks/share/lua/"..version.."/?.lua;"
package.cpath = package.cpath..";"..
  os.getenv("HOME").."/.luarocks/lib/lua/"..version.."/?.so;"

local i3 = require"i3ipc"
local EVENT = i3.EVENT, i3.COMMAND

i3.main(function(conn)
  -- conn:on(EVENT.WORKSPACE, function(_, event)
  --   conn:command(("exec notify-send 'switched to workspace %d'"):format(event.current.name))
  -- end)
  conn:on(EVENT.WORKSPACE, function(_, event)
    conn:command(("exec notify-send 'workspace: %s!'"):format(event.change))
  end)
  conn:on(EVENT.WINDOW, function(_, event)
    conn:command(("exec notify-send 'window: %s (%d)'"):format(event.change, event.container.id))
  end)
end)
