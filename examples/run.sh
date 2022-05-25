#!/usr/bin/env bash
export LUA_PATH="$PWD/?.lua;$PWD/?/init.lua;/usr/share/lua/5.1/?.lua;$LUA_PATH"
exec "$@"
