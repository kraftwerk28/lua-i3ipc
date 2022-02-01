#!/usr/bin/env luajit
local i3 = require("i3ipc")

local function dump(...) print(require("inspect")(...)) end

local ipc = i3.Connection:new { cmd = true }

ipc:main(function()
  ipc.cmd:on("tab", function(_, arg)
    local tabbed_node = ipc:get_tree():walk_focus(function(n)
      return n.layout == "tabbed"
    end)
    if not tabbed_node then return end
    local focused_index
    for index, node in ipairs(tabbed_node.nodes) do
      if node.id == tabbed_node.focus[1] then
        focused_index = index
      end
    end
    if arg == "prev" then
      focused_index =
        (focused_index - 2 + #tabbed_node.nodes) % #tabbed_node.nodes + 1
    elseif arg == "next" then
      focused_index = focused_index % #tabbed_node.nodes + 1
    end
    local to_be_focused =
      i3.wrap_node(tabbed_node.nodes[focused_index]):walk_focus()
    ipc:command(("[con_id=%d] focus"):format(to_be_focused.id))
  end)

  local prev_focused
  local cur_focused
  local focused_node = ipc:get_tree():find_focused()
  if focused_node then
    cur_focused = focused_node.id
  end
  ipc.cmd:on("focus", function(_, args)
    ipc:command(("[con_id=%d] focus"):format(prev_focused))
  end)

  ipc:on("window::focus", function(_, event)
    prev_focused = cur_focused
    cur_focused = event.container.id
  end)
end)
