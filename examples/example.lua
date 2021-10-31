#!/usr/bin/env luajit
local i3 = require"i3ipc"

i3.main(function(conn)
  conn:on(i3.EVENT.WORKSPACE, function(_, event)
    conn:command(("exec notify-send 'workspace %s'"):format(event.change))
  end)
  conn:on("window::focus", function(_, event)
    conn:command(("exec notify-send 'window: %s (%s)'"):format(
      event.change,
      event.container.app_id
    ))
  end)
end)
