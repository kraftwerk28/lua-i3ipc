# i3ipc-lua

A Lua (LuaJIT) library for controlling [i3wm](https://i3wm.org/)
and [Sway](https://swaywm.org/) through IPC.
Uses [libuv](https://github.com/luvit/luv) bindings for I/O.

Currently supports Lua 5.1 (LuaJIT 2.0.5)

### Note: this is a very alpha piece of software!


## Installation and running the script
_TODO_


## API

### `main(callback)`
The entry point of the library, which you typically would use
Takes a callback with one parameter, `Connection`

**Parameters:**
- `callback`: `function` - function with one parameter (`Connection`)

Example:
```lua
require"i3ipc".main(function(conn)
  -- Invoke methods on `conn`
end)
```

### `Connection`
A wrapper around [UDS](https://en.wikipedia.org/wiki/Unix_domain_socket)
connection to Sway/I3 socket.

### `Connection:new()`
Initialize connection

### `Connection:send(type, payload)`
Send a message to socket

**Parameters:**
- `type`: [i3.COMMAND](https://i3wm.org/docs/ipc.html#_sending_messages_to_i3)
- `payload`: `string` - raw payload

### `Connection:cmd(command)`
Send a command.
Equivalent to `Connection:send(i3.COMMAND.RUN_COMMAND, command)`.

**Parameters:**
- `command`: `string` - command to send

### `Connection:subscribe(event, callback)`
Subscribe to event.

**Parameters:**
- `event`: [i3.EVENT](https://i3wm.org/docs/ipc.html#_reply_format)
- `callback`: `function` - function with one parameter (event)

Example:
```lua
conn:subscribe(i3.EVENT.WINDOW, function(event)
  print(event.container.name)
end)
```

### `Connection:subscribe_once(event, callback)`
Subscribe to event, unsubscribe after one is received.

**Parameters:**
- `event`: [i3.EVENT](https://i3wm.org/docs/ipc.html#_reply_format)
- `callback`: `function` - function with one parameter (event)

### `Connection:unsubscribe(event, callback)`
Remove subscribtion to event.

**Parameters:**
- `event`: [i3.EVENT](https://i3wm.org/docs/ipc.html#_reply_format)
- `callback`: `function` - previously registered callback


## Example

```lua
local i3 = require"i3ipc"
local EVENT, COMMAND = i3.EVENT, i3.COMMAND

i3.main(function(conn)
  conn:subscribe_once(EVENT.WORKSPACE, function(event)
    local cmd = "exec notify-send 'switched to workspace %d'"
    conn:cmd(cmd:format(event.current.name))
  end)
end)
```

Also check out [examples](./examples) for more useful snippets.
