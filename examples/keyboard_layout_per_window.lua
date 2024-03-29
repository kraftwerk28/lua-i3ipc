local i3 = require("i3ipc")

local current_focused, previous_focused
-- { con_id => { input_identifier => layout_index } }
local windows = {}

local ipc = i3.Connection:new()

function ipc:get_keyboard_inputs()
  local inputs, r = self:get_inputs(), {}
  for _, input in ipairs(inputs) do
    if input.type == "keyboard" and input.xkb_active_layout_index ~= nil then
      table.insert(r, input)
    end
  end
  return r
end

ipc:main(function(ipc)
  ipc:on("window::focus", function(ipc, event)
    previous_focused = current_focused
    local con_id = event.container.id
    local inputs = ipc:get_keyboard_inputs()
    local input_layouting = {}
    for _, input in ipairs(inputs) do
      input_layouting[input.identifier] = input.xkb_active_layout_index
    end
    if previous_focused ~= nil and previous_focused ~= con_id then
      windows[previous_focused] = input_layouting
    end
    local cached_layouts = windows[con_id]
    local commands = {}
    if cached_layouts ~= nil then
      for input_id, layout_index in pairs(cached_layouts) do
        if layout_index ~= input_layouting[input_id] then
          table.insert(
            commands,
            ('input "%s" xkb_switch_layout %d'):format(input_id, layout_index)
          )
        end
      end
    else
      for _, input in ipairs(inputs) do
        if input.xkb_active_layout_index ~= 0 then
          table.insert(
            commands,
            ('input "%s" xkb_switch_layout %d'):format(input.identifier, 0)
          )
        end
      end
    end
    if #commands > 0 then
      ipc:command(table.concat(commands, ", "))
    end
    current_focused = con_id
  end)

  ipc:on("window::close", function(ipc, event)
    windows[event.container.id] = nil
  end)

  ipc:on("workspace::init", function()
    for _, input in ipairs(ipc:get_keyboard_inputs()) do
      ipc:command(
        ('input "%s" xkb_switch_layout %d'):format(input.identifier, 0)
      )
    end
  end)
end)
