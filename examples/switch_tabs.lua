#!/usr/bin/env luajit
-- Switch to prev/next tab in topmost tabbed layout
local i3 = require("i3ipc")
local ipc = i3.Connection:new()
ipc:main(function()
  ipc.cmd:on("tab", function(arg)
    local tabbed_node = ipc:get_tree():walk_focus(function(n)
      return n.layout == "tabbed"
    end)
    if not tabbed_node then
      return
    end
    local focused_index
    for index, node in ipairs(tabbed_node.nodes) do
      if node.id == tabbed_node.focus[1] then
        focused_index = index
      end
    end
    local nnodes = #tabbed_node.nodes
    if arg == "prev" then
      focused_index = (focused_index - 2 + nnodes) % nnodes + 1
    else
      focused_index = focused_index % nnodes + 1
    end
    local to_be_focused =
      i3.wrap_node(tabbed_node.nodes[focused_index]):walk_focus()
    ipc:command(("[con_id=%d] focus"):format(to_be_focused.id))
  end)
end)
