local M = {}

M.MAGIC = "i3-ipc"
M.HEADER_SIZE = #M.MAGIC + 8

-- luacheck: push no max line length
M.COMMAND = {
  RUN_COMMAND = 0, -- Run the payload as an i3 command (like the commands you can bind to keys).
  GET_WORKSPACES = 1, -- Get the list of current workspaces.
  SUBSCRIBE = 2, -- Subscribe this IPC connection to the event types specified in the message payload. See [events].
  GET_OUTPUTS = 3, -- Get the list of current outputs.
  GET_TREE = 4, -- Get the i3 layout tree.
  GET_MARKS = 5, -- Gets the names of all currently set marks.
  GET_BAR_CONFIG = 6, -- Gets the specified bar configuration or the names of all bar configurations if payload is empty.
  GET_VERSION = 7, -- Gets the i3 version.
  GET_BINDING_MODES = 8, -- Gets the names of all currently configured binding modes.
  GET_CONFIG = 9, -- Returns the last loaded i3 config.
  SEND_TICK = 10, -- Sends a tick event with the specified payload.
  SYNC = 11, -- Sends an i3 sync event with the specified random value to the specified window.
  GET_BINDING_STATE = 12, -- Request the current binding state, i.e. the currently active binding mode name.

  -- Sway-only
  GET_INPUTS = 100,
  GET_SEATS = 101,
}

M.EVENT = {
  WORKSPACE = { 0, "workspace" }, -- Sent when the user switches to a different workspace, when a new workspace is initialized or when a workspace is removed (because the last client vanished).
  OUTPUT = { 1, "output" }, -- Sent when RandR issues a change notification (of either screens, outputs, CRTCs or output properties).
  MODE = { 2, "mode" }, -- Sent whenever i3 changes its binding mode.
  WINDOW = { 3, "window" }, -- Sent when a client’s window is successfully reparented (that is when i3 has finished fitting it into a container), when a window received input focus or when certain properties of the window have changed.
  BARCONFIG_UPDATE = { 4, "barconfig_update" }, -- Sent when the hidden_state or mode field in the barconfig of any bar instance was updated and when the config is reloaded.
  BINDING = { 5, "binding" }, -- Sent when a configured command binding is triggered with the keyboard or mouse
  SHUTDOWN = { 6, "shutdown" }, -- Sent when the ipc shuts down because of a restart or exit by user command
  TICK = { 7, "tick" },
  BAR_STATE_UPDATE = { 20, "bar_state_update" },
  INPUT = { 21, "input" },
}
-- luacheck: pop

return M
