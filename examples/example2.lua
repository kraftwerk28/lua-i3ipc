local version = _VERSION:match("%d+%.%d+")
package.path = package.path..";"..
  os.getenv("HOME").."/.luarocks/share/lua/"..version.."/?.lua;"
package.cpath = package.cpath..";"..
  os.getenv("HOME").."/.luarocks/lib/lua/"..version.."/?.so;"
local i3 = require"i3ipc"

i3.main(function(conn)
  conn:on(i3.EVENT.WINDOW, function(_, event)
    if
      event.container.app_id:match("Alacritty")
      and event.change == "focus"
    then
      conn:command("floating enable")
    end
  end)
end)
