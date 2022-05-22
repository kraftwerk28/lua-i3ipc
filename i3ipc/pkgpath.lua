local base = "/usr/share/lua/5.1/i3ipc/_rocks"
package.path = base
  .. "/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;"
  .. package.path
package.cpath = base .. "/lib/lua/5.1/?.so;" .. package.cpath
