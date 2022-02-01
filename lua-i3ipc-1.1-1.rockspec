package = "lua-i3ipc"
version = "1.1-1"
source = {
   url = "git+ssh://git@github.com/kraftwerk28/i3ipc-lua.git",
   tag = "v1.1",
}
description = {
   summary = "A Lua (LuaJIT) library for controlling i3wm and Sway through IPC",
   homepage = "https://github.com/kraftwerk28/lua-i3ipc",
   license = "MIT"
}
dependencies = {
   "lua ~> 5.1",
   "luv >= 1.42.0",
   "struct >= 1.4",
   "lua-cjson >= 2.1.0.6",
}
build = {
   type = "builtin",
   modules = {
      ["i3ipc"] = "i3ipc/init.lua",
   },
}
