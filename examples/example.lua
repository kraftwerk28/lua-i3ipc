local version = _VERSION:match("%d+%.%d+")
package.path = package.path..";"..
  os.getenv("HOME").."/.luarocks/share/lua/"..version.."/?.lua;"
package.cpath = package.cpath..";"..
  os.getenv("HOME").."/.luarocks/lib/lua/"..version.."/?.so;"

local inspect = require"inspect"
local i3 = require"i3ipc"
local EVENT, COMMAND, Connection = i3.EVENT, i3.COMMAND, i3.Connection

i3.main(function()
  local conn = Connection:new()
  local function handler(event)
    conn:send(
      COMMAND.RUN_COMMAND,
      ("exec notify-send 'switched to workspace %d'"):format(event.current.name)
    )
  end
  conn:subscribe(EVENT.WORKSPACE, handler)
end)
