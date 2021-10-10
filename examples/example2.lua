local version = _VERSION:match("%d+%.%d+")
package.path = package.path..";"..
  os.getenv("HOME").."/.luarocks/share/lua/"..version.."/?.lua;"
package.cpath = package.cpath..";"..
  os.getenv("HOME").."/.luarocks/lib/lua/"..version.."/?.so;"
local i3 = require"i3ipc"

i3.main(function(conn)
  conn:on(i3.EVENT.WINDOW, function(_, event)
    if event.container.name:match("Alacritty") then
      -- conn:command(("[con_id=%d] focus"):format(event.container.id))
      conn:command("floating enable")
    end
  end)
end)
