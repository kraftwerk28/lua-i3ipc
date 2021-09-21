# i3ipc-lua

A Lua (LuaJIT) library for controlling [i3wm](https://i3wm.org/) and [Sway](https://swaywm.org/) through IPC.
Uses [libuv](https://github.com/luvit/luv) bindings for I/O.

Currently supports Lua 5.1 (LuaJIT 2.0.5)

### This is a very alpha piece of software!

## Installation
_TODO_

## Example

```lua
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
```

Also check out [examples](./examples) for more useful snippets.
