local version = _VERSION:match("%d+%.%d+")
package.path = package.path..";"..
  os.getenv("HOME").."/.luarocks/share/lua/"..version.."/?.lua;"
package.cpath = package.cpath..";"..
  os.getenv("HOME").."/.luarocks/lib/lua/"..version.."/?.so;"

local inspect = require"inspect"
local i3 = require"i3ipc"
local EVENT, CMD = i3.EVENT, i3.COMMAND

i3.main(function(conn)
  conn:subscribe_once(EVENT.WORKSPACE, function(event)
    conn:send(
      CMD.RUN_COMMAND,
      ("exec notify-send 'switched to workspace %d'"):format(event.current.name)
    )
  end)
end)
