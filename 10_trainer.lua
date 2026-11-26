config = config or (function()
  local values = {}
  return {
    temporary = true,
    get = function(key, default)
      local v = values[key]
      if v == nil then return default end
      return v
    end,
    set = function(key, value) values[key] = value end,
  }
end)()

world = world or setmetatable({}, { __index = function() return function() end end })
native = native or {}
natives = natives or { list = {} }

trainer = {
  menu = menu.new("Native Trainer VI"),
  sections = {},
  find = {},
  lines = {},
  frames = 0,
  rate = 0,
  writes = false,
}

function trainer.section(name, desc)
  local m = trainer.menu:submenu(name, desc)
  trainer.sections[#trainer.sections + 1] = { name = name, menu = m }
  return m
end

trainer.caps = {
  game = {
    why = "needs a game",
    test = function()
      local mode = game.mode()
      return (mode == "internal" or mode == "external") and mem.found()
    end,
  },
  build = {
    after = "game",
    why = "needs a known build",
    test = function()
      local build = game.build()
      return build ~= nil and build ~= "unknown"
    end,
  },
  offsets = {
    after = "build",
    why = "needs offsets for this build",
    test = function() return scripthookvi.offsets[game.build()] ~= nil end,
  },
  internal = { after = "game", why = "needs the injected engine", test = function() return game.mode() == "internal" end },
  natives = { after = "internal", why = "not written yet", test = function() return false end },
  calls = { after = "offsets", why = "needs Tick on the game thread", test = function() return trainer.game_seen ~= nil and now() - trainer.game_seen < 2000 end },
  player = { after = "offsets", why = "needs a player in the world", test = function() return world.player() ~= nil end },
  vitals = { after = "player", why = "needs Tick on the game thread", test = function() return trainer.missing("calls") == nil end },
  moves = { after = "player", why = "needs Tick on the game thread", test = function() return trainer.missing("calls") == nil end },
  writes = { why = "needs Allow writes", test = function() return trainer.writes end },
  types = { after = "game", why = "type registry not found", test = function() return par ~= nil and par.ready() end },
  scripts = { why = "needs the script folder", test = function() return scripthookvi.reload ~= nil or trainer.scripts_dir ~= nil end },
  rescan = { why = "needs an engine update", test = function() return scripthookvi.rescan ~= nil end },
  log_switch = { why = "needs an engine update", test = function() return scripthookvi.log_to_file ~= nil end },
  registry = { why = "needs an engine update", test = function() return scripthookvi.scripts ~= nil end },
}

local cache, cached_at = {}, -1

local function missing(name)
  if cached_at ~= trainer.frames then cache, cached_at = {}, trainer.frames end
  local known = cache[name]
  if known ~= nil then return known or nil end
  local cap = trainer.caps[name]
  local why
  if not cap then
    why = "needs " .. name
  else
    why = cap.after and missing(cap.after)
    if not why then
      local ok, yes = pcall(cap.test)
      if not (ok and yes) then why = cap.why end
    end
  end
  cache[name] = why or false
  return why
end

on_frame(function()
  if hook.ticking() then trainer.game_seen = now() end
end)

function trainer.missing(...)
  for _, name in ipairs({ ... }) do
    local why = missing(name)
    if why then return why end
  end
  return nil
end

function trainer.capability(name)
  return missing(name) == nil
end

function trainer.refresh()
  cached_at = -1
end

function trainer.needs(item, ...)
  local names = { ... }
  item.unavailable = function() return trainer.missing(table.unpack(names)) end
  return item
end

function trainer.find.player()
  local e = world.player()
  if not e then return nil end
  local x, y, z = world.position(e)
  if not x or not y or not z then return nil end
  return { entity = e, x = x, y = y, z = z, heading = world.heading(e), health = world.health(e), model = world.model(e) }
end

function trainer.todo(name)
  return function() log(name .. ": not written yet") end
end

function trainer.info(m, name, fn, desc, ...)
  local item = m:label(function() return name, fn() end, desc)
  item.label = name
  if select("#", ...) > 0 then trainer.needs(item, ...) end
  return item
end

function trainer.empty(m, text, desc)
  local item = m:label(function() return text end, desc)
  item.placeholder = true
  return item
end

function trainer.fill(m, item)
  for i = #m.items, 1, -1 do
    if m.items[i].placeholder then table.remove(m.items, i) end
  end
  return item
end

function trainer.hex(v)
  if not v then return "none" end
  return string.format("0x%x", v)
end

function trainer.setting(key, default)
  return config.get(key, default)
end

function trainer.store(key, value)
  config.set(key, value)
end

trainer.open_keys = {
  { "F3", 0x72 }, { "F4", 0x73 }, { "F5", 0x74 }, { "F6", 0x75 }, { "F7", 0x76 },
  { "F8", 0x77 }, { "F9", 0x78 }, { "F10", 0x79 }, { "F11", 0x7A }, { "Insert", 0x2D },
}

function trainer.key_name(vk)
  for _, k in ipairs(trainer.open_keys) do
    if k[2] == vk then return k[1] end
  end
  return string.format("key %x", vk)
end

local raw_log = log

function log(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
  local lines = trainer.lines
  lines[#lines + 1] = { at = now(), text = table.concat(parts, " ") }
  if #lines > 200 then table.remove(lines, 1) end
  raw_log(...)
end

print = log

local function readable(path)
  local f = io.open(path, "rb")
  if not f then return false end
  f:close()
  return true
end

trainer.scripts_dir = scripthookvi.scripts_dir
if scripthookvi.log_path and readable(scripthookvi.log_path) then trainer.log_file = scripthookvi.log_path end

function trainer.reload()
  return scripthookvi.reload()
end

local second, counted = 0, 0

on_frame(function(ms)
  trainer.frames = trainer.frames + 1
  if ms - second >= 1000 then
    trainer.rate = math.floor((trainer.frames - counted) * 1000 / math.max(1, ms - second) + 0.5)
    second, counted = ms, trainer.frames
  end
end)
