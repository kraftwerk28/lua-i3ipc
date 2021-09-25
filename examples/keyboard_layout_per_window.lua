local version = _VERSION:match("%d+%.%d+")
package.path = package.path..";"..
  os.getenv("HOME").."/.luarocks/share/lua/"..version.."/?.lua;"
package.cpath = package.cpath..";"..
  os.getenv("HOME").."/.luarocks/lib/lua/"..version.."/?.so;"

local i3 = require"i3ipc"
local CMD = i3.COMMAND
local inspect = require"inspect"

local prev_focused
local windows = {}

local function get_inputs(conn)
  local r = {}
  for _, input in ipairs(conn:send(CMD.GET_INPUTS)) do
    if input.type == "keyboard" and input.xkb_active_layout_index then
      table.insert(r, input)
    end
  end
  return r
end

local function on_focus(conn, event)
  if event.change ~= "focus" then
    return
  end
  local con_id = event.container.id
  local inputs = get_inputs(conn)
  local input_layouting = {}
  for _, input in ipairs(inputs) do
    input_layouting[input.identifier] = input.xkb_active_layout_index
  end
  if prev_focused ~= nil and prev_focused ~= con_id then
    windows[prev_focused] = input_layouting
  end
  local cached_layouts = windows[con_id]
  if cached_layouts ~= nil then
    for input_id, layout_index in pairs(cached_layouts) do
      if layout_index ~= input_layouting[input_id] then
        local command =
          ([[input "%s" xkb_switch_layout %d]]):format(input_id, layout_index)
        conn:cmd(command)
      end
    end
  else
    for _, input in ipairs(inputs) do
      if input.xkb_active_layout_index ~= 0 then
        local command =
          ([[input "%s" xkb_switch_layout %d]]):format(input.identifier, 0)
        conn:cmd(command)
      end
    end
  end
  prev_focused = con_id
end

i3.main(function(conn)
  conn:subscribe(i3.EVENT.WINDOW, on_focus)
end)
