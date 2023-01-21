#!/usr/bin/env bash
export LUA_PATH="./?/init.lua;$HOME/.luarocks/share/lua/5.1/?.lua;$HOME/.luarocks/share/lua/5.1/?/init.lua;$(luajit -e 'print(package.path)')"
export LUA_CPATH="$HOME/.luarocks/lib/lua/5.1/?.so;$HOME/.luarocks/lib/lua/5.1/?/init.so;$(luajit -e 'print(package.cpath)')"
exec luajit "$@"
