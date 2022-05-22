local wrap_node

local function find_bfs_dfs(node, predicate, opts, check_all)
  local queue = { node }
  local found = {}
  while #queue > 0 do
    local cur
    if opts.search_method == "bfs" then
      cur = table.remove(queue, 1)
    elseif opts.search_method == "dfs" then
      cur = table.remove(queue)
    else
      error("Unknown search method")
    end
    if predicate(cur) then
      if check_all then
        table.insert(found, wrap_node(cur))
      else
        return wrap_node(cur)
      end
    end
    if (opts.check_only or "tiling") == "tiling" then
      for _, con in ipairs(cur.nodes) do
        table.insert(queue, con)
      end
    end
    if (opts.check_only or "floating") == "floating" then
      for _, con in ipairs(cur.floating_nodes) do
        table.insert(queue, con)
      end
    end
  end
  if check_all then
    return found
  end
end

local node_mt = {}
node_mt.__index = node_mt

function node_mt:find_con(predicate, opts)
  opts = opts or {}
  opts.search_method = opts.search_method or "bfs"
  opts.check_only = opts.check_only or "tiling"
  return find_bfs_dfs(self, predicate, opts)
end

function node_mt:find_all(predicate, opts)
  opts = opts or {}
  opts.search_method = opts.search_method or "bfs"
  opts.check_only = opts.check_only or "tiling"
  return find_bfs_dfs(self, predicate, opts, true)
end

function node_mt:walk_focus(predicate)
  local cur = self
  while true do
    if predicate and predicate(cur) then
      return wrap_node(cur)
    end
    if #(cur.focus or {}) == 0 then
      if predicate then
        return nil
      else
        return cur
      end
    end
    local focus_id = cur.focus[1]
    for _, child in ipairs(cur.nodes) do
      if child.id == focus_id then
        cur = child
        goto cont
      end
    end
    for _, child in ipairs(cur.floating_nodes) do
      if child.id == focus_id then
        cur = child
        goto cont
      end
    end
    ::cont::
  end
end

function node_mt:find_focused()
  return self:walk_focus(function(n)
    return n.focused
  end)
end

wrap_node = function(node)
  if getmetatable(node) ~= nil then
    return node
  end
  return setmetatable(node, node_mt)
end

return wrap_node
