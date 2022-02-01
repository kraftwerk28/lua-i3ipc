#!/usr/bin/env luajit
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
