#!/usr/bin/env luajit
local version = _VERSION:match("%d+%.%d+")
package.path = package.path..";"..
  os.getenv("HOME").."/.luarocks/share/lua/"..version.."/?.lua;"
package.cpath = package.cpath..";"..
  os.getenv("HOME").."/.luarocks/lib/lua/"..version.."/?.so;"

local i3 = require"i3ipc"

i3.main(function(conn)
  conn:on(i3.EVENT.WORKSPACE, function(_, event)
    conn:command(("exec notify-send 'workspace %s'"):format(event.change))
  end)
  conn:on(i3.EVENT.WINDOW, function(_, event)
    conn:command(("exec notify-send 'window: %s (%s)'"):format(
      event.change,
      event.container.app_id
    ))
  end)
end)
