# i3ipc-lua

A Lua (LuaJIT) library for controlling [i3wm](https://i3wm.org/)
and [Sway](https://swaywm.org/) through IPC.
Uses [libuv](https://github.com/luvit/luv) bindings for I/O.

Currently supports Lua 5.1 (LuaJIT 2.0.5)


## Installation and running the script
_TODO_


## API


### `main(callback)`
The entry point of the library, which you typically would use
Takes a callback with one parameter, `Connection`

**Parameters:**
- `callback`: `function` - function with one parameter (`Connection`)

**Example:**
```lua
require"i3ipc".main(function(conn)
  -- Invoke methods on `conn`
end)
```


### `Connection`
A wrapper around [unix socket](https://en.wikipedia.org/wiki/Unix_domain_socket)
connection to Sway/I3 socket.


### `Connection:new()`
Initialize connection.

**Returns:** `Connection`.


### `Connection:send(type, payload)`
Send a message to socket.

**Parameters:**
- `type`: [i3.COMMAND](https://i3wm.org/docs/ipc.html#_sending_messages_to_i3)
- `payload`: `string` - raw payload

**Returns:** reply, (e.g. `{ {success = true} }`).


### `Connection:command(command)`
Send a command.
Equivalent to `Connection:send(i3.COMMAND.RUN_COMMAND, command)`.

**Parameters:**
- `command`: `string` - command to send

**Returns:** command reply, (e.g. `{ {success = true} }`).


### `Connection:on(event, callback)`
Subscribe to event.

**Parameters:**
- `event`: [i3.EVENT](https://i3wm.org/docs/ipc.html#_reply_format)
- `callback`: `function` - function with two parameters: `Connection` and event

**Example:**
```lua
conn:on(i3.EVENT.WINDOW, function(event)
  print(event.container.name)
end)
```


### `Connection:once(event, callback)`
Subscribe to event, unsubscribe after one is received.

**Parameters:**
- `event`: [i3.EVENT](https://i3wm.org/docs/ipc.html#_reply_format)
- `callback`: `function` - function with two parameters: `Connection` and event


### `Connection:off(event, callback)`
Remove subscription to event.

**Parameters:**
- `event`: [i3.EVENT](https://i3wm.org/docs/ipc.html#_reply_format)
- `callback`: `function` - previously registered callback


### `Connection:get_tree()`
Get layout tree.

**Returns:** `Tree`.


### `Tree`
A Lua table, representing tree layout, with additional methods that are
accessible via metatable.


### `Tree:find_con(predicate)`
Find `con` by predicate.

**Parameters:**
- `predicate`: `function` - function with parameter that represents `con`
and return true if that `con` matches

**Returns:** matched `con`, or `nil`.

**Example:**
```lua
i3.main(function(ipc)
  local firefox = ipc:get_tree():find_con(function(con)
    return con.app_id == "firefox"
  end)
end)
```


### `Tree:find_focused()`
Find focused node.

**Returns:** focused `con`.


### `Connection:get_*`
Bound methods for `Connection` in lowercase that correspond to `GET_*`
commands in the [spec (Table #1)](https://i3wm.org/docs/ipc.html#_sending_messages_to_i3).


## Example

```lua
local i3 = require"i3ipc"
local EVENT, COMMAND = i3.EVENT, i3.COMMAND

i3.main(function(conn)
  conn:once(EVENT.WORKSPACE, function(event)
    local cmd = "exec notify-send 'switched to workspace %d'"
    conn:command(cmd:format(event.current.name))
  end)
end)
```

Also check out [examples](./examples) for more useful snippets.
