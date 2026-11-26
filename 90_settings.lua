local need = trainer.needs
local m = trainer.section("Settings", "How the menu looks and answers keys, and options of the engine.")

trainer.accents = {
  { "Magenta", 0xC2185B }, { "Crimson", 0xB71C1C }, { "Orange", 0xBF360C }, { "Green", 0x2E7D32 },
  { "Teal", 0x00796B }, { "Blue", 0x1565C0 }, { "Purple", 0x6A1B9A }, { "Graphite", 0x37474F },
}
local sides = { { "Left", "left" }, { "Right", "right" } }
local opacities = { { "50%", 50 }, { "60%", 60 }, { "70%", 70 }, { "82%", 82 }, { "90%", 90 }, { "100%", 100 } }
local schemes = { { "Numpad and arrows", "both" }, { "Numpad", "numpad" }, { "Arrows", "arrows" } }

local defaults = {
  ["menu.accent"] = "Magenta", ["menu.side"] = "left", ["menu.width"] = 432, ["menu.rows"] = 12,
  ["menu.scale"] = 100, ["menu.opacity"] = 82, ["menu.key"] = 0x73, ["menu.keys"] = "both",
  ["menu.block"] = true, ["menu.pad"] = true, ["menu.sound"] = false, ["status.show"] = true, ["status.content"] = 1,
}

local function get(key) return trainer.setting(key, defaults[key]) end

local function find(list, value, column)
  for i, entry in ipairs(list) do
    if entry[column] == value then return i end
  end
  return 1
end

local function names(list)
  local out = {}
  for i, entry in ipairs(list) do out[i] = entry[1] end
  return out
end

trainer.play_sound = function() end

local function apply()
  menu.accent = trainer.accents[find(trainer.accents, get("menu.accent"), 1)][2]
  menu.side = get("menu.side")
  menu.width = get("menu.width")
  menu.rows = get("menu.rows")
  menu.scale = get("menu.scale") / 100
  menu.opacity = get("menu.opacity")
  menu.key = get("menu.key")
  menu.keys = get("menu.keys")
  menu.block = get("menu.block")
  menu.pad = get("menu.pad")
end

menu.sound = function(name)
  if get("menu.sound") and trainer.capability("natives") then trainer.play_sound(name) end
end

apply()

local syncs = {}

local function setting(item, key, read)
  syncs[#syncs + 1] = function() item.value = read(get(key)) end
  syncs[#syncs]()
  return item
end

local function store(key, value)
  trainer.store(key, value)
  apply()
end

local function pick(list, key, column)
  return function(i) store(key, list[i][column]) end
end

setting(m:choice("Accent colour", names(trainer.accents), 1, pick(trainer.accents, "menu.accent", 1), "The colour of the header and the rules of the menu."),
  "menu.accent", function(v) return find(trainer.accents, v, 1) end)
setting(m:choice("Menu position", names(sides), 1, pick(sides, "menu.side", 2), "Which side of the screen the menu sits on."),
  "menu.side", function(v) return find(sides, v, 2) end)
local width = setting(m:number("Menu width", 432, 24, function(v) store("menu.width", v) end, "How wide the menu is."),
  "menu.width", function(v) return v end)
width.min, width.max = 360, 624
local rows = setting(m:number("Rows shown", 12, 1, function(v) store("menu.rows", v) end, "How many rows fit before the list scrolls."),
  "menu.rows", function(v) return v end)
rows.min, rows.max = 6, 20
local scale = setting(m:number("Text size", 100, 5, function(v) store("menu.scale", v) end, "Makes the text and the rows of the menu larger or smaller."),
  "menu.scale", function(v) return v end)
scale.min, scale.max, scale.format = 80, 130, function(v) return string.format("%d%%", v) end
setting(m:choice("Row opacity", names(opacities), 4, pick(opacities, "menu.opacity", 2), "How much of the game shows through the rows."),
  "menu.opacity", function(v) return find(opacities, v, 2) end)
setting(m:toggle("Status line", true, function(v) store("status.show", v) end, "Shows the engine state in the top left corner while you play."),
  "status.show", function(v) return v end)
local contents = {}
for i, s in ipairs(trainer.status_texts or {}) do contents[i] = s[1] end
setting(m:choice("Status line shows", contents, 1, function(i) store("status.content", i) end, "What the status line says."),
  "status.content", function(v) return v end)
setting(m:choice("Open key", names(trainer.open_keys), 2, pick(trainer.open_keys, "menu.key", 2), "The key that opens and closes the menu."),
  "menu.key", function(v) return find(trainer.open_keys, v, 2) end)
setting(m:choice("Navigation keys", names(schemes), 1, pick(schemes, "menu.keys", 2), "Which keys move, select and go back: Num8 Num2 Num5 Num0, or the arrows, Enter and Backspace."),
  "menu.keys", function(v) return find(schemes, v, 2) end)
setting(m:toggle("Controller", true, function(v) store("menu.pad", v) end, "The first gamepad works the menu: RB + A opens and closes it, the D-pad moves and changes values, A selects, B goes back. The game still sees these buttons."),
  "menu.pad", function(v) return v end)
setting(m:toggle("Hide menu keys from the game", true, function(v) store("menu.block", v) end, "Hides the menu's keys from GetAsyncKeyState and GetKeyState while the menu is open, in the injected engine. A game that reads the keyboard another way still sees them."),
  "menu.block", function(v) return v end)
setting(need(m:toggle("Menu sounds", false, function(v) store("menu.sound", v) end, "Plays the game's menu sounds as you move and select."), "natives"),
  "menu.sound", function(v) return v end)

local engine = m:submenu("Engine", "Where scripts come from, logging and the title search.")
trainer.info(engine, "Script folder", function() return trainer.scripts_dir or "not reported" end, "The folder the scripts load from. Set SCRIPTHOOKVI_SCRIPTS or --scripts to change it.")
trainer.info(engine, "Settings are", function() return config.temporary and "kept until reload" or "saved" end, "Whether these settings survive a reload and the next start of the game.")
setting(need(engine:toggle("Log to file", true, function(v)
  store("engine.log_file", v)
  scripthookvi.log_to_file(v)
end, "Writes every log line to ScriptHookVI.log beside the engine."), "log_switch"), "engine.log_file", function(v) return v ~= false end)
local function on_game_thread(v)
  if not trainer.capability("internal") or not trainer.capability("offsets") then return end
  if v then hook.tick(game.at("frame_update")) else hook.untick() end
end
setting(need(engine:toggle("Tick on the game thread", true, function(v)
  store("engine.game_thread", v)
  on_game_thread(v)
end, "Runs scripts inside the game's own per-frame update instead of on a timer. Calls into game functions need this."), "internal", "offsets"), "engine.game_thread", function(v) return v ~= false end)
need(engine:action("Look for the title again", function() scripthookvi.rescan() end, "Searches the game process for the title image again, for after a restart of the game."), "rescan")

m:action("Reset all settings", function()
  for key, value in pairs(defaults) do trainer.store(key, value) end
  for _, sync in ipairs(syncs) do sync() end
  apply()
end, "Puts every setting on this page back to its default.")
