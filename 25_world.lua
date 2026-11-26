local need, todo = trainer.needs, trainer.todo
local m = trainer.section("World", "Time, weather, traffic and population, and how the world behaves.")

local clock = m:submenu("Time", "The hour, and whether the clock runs.")
local hour = need(clock:number("Hour", 12, 1, function(v) world.set_hour(v) end, "Sets the clock to this hour."), "offsets")
hour.min, hour.max, hour.wrap, hour.format = 0, 23, true, function(v) return string.format("%02d:00", v) end
local hold = need(clock:toggle("Pause the clock", false, function(v) world.hold_clock(v) end, "The time of day stops moving. A mission can start it again."), "offsets")
clock.on_open = function()
  if not trainer.capability("offsets") then return end
  local h, held = world.clock()
  hour.value, hold.value = h or hour.value, held or false
end
need(clock:toggle("Follow the system clock", false, todo("World > Follow the system clock"), "Keeps the game clock in step with your computer's clock."), "natives")

local sky = m:submenu("Weather", "Set and hold the weather.")
local weathers = { "Sunny", "Cloudy", "Foggy", "Rain", "Storm" }
need(sky:choice("Weather", weathers, 2, todo("World > Weather"), "Changes the weather straight away."), "natives")
need(sky:toggle("Hold the weather", false, todo("World > Hold the weather"), "Keeps the weather from changing on its own."), "natives")
need(sky:toggle("Strong wind", false, todo("World > Strong wind"), "Trees, water and loose objects move in a strong wind."), "natives")

local crowd = m:submenu("Traffic and population", "How many vehicles and people fill the streets.")
local function percent(v) return string.format("%d%%", v) end
for _, d in ipairs({
  { "Traffic", "How many vehicles drive around you." },
  { "People on foot", "How many people walk around you." },
  { "Parked cars", "How many cars stand parked at the roadside." },
}) do
  local item = need(crowd:number(d[1], 100, 10, todo("World > " .. d[1]), d[2]), "natives")
  item.min, item.max, item.format = 0, 100, percent
end
need(crowd:toggle("Police patrols", true, todo("World > Police patrols"), "Police cars and officers appear on the streets."), "natives")
need(crowd:toggle("Trains", true, todo("World > Trains"), "Trains run on the tracks."), "natives")
need(crowd:toggle("Boats", true, todo("World > Boats"), "Boats sail the coast and the waterways."), "natives")
need(crowd:action("Clear the area", todo("World > Clear the area"), "Removes vehicles and people within 100 metres of you."), "natives")

local speeds = { 1, 0.75, 0.5, 0.25 }
need(m:choice("Game speed", { "100%", "75%", "50%", "25%" }, 1, function(i) world.set_speed(speeds[i]) end, "Slows the whole game down."), "offsets")
need(m:toggle("Moon gravity", false, todo("World > Moon gravity"), "Everything falls slowly, you included."), "natives")
need(m:toggle("Blackout", false, todo("World > Blackout"), "Turns off every artificial light in the state."), "natives")

local near = m:submenu("Nearby", "What the game has loaded around you, read from its entity pools.")
local counts, listed, read_at = {}, {}, -1e9

local function refresh()
  if now() - read_at < 1000 then return end
  read_at = now()
  for _, name in ipairs({ "peds", "vehicles", "objects" }) do counts[name] = { world.count(name) } end
  listed = {}
  local p = trainer.find.player()
  if not p then return end
  for _, name in ipairs({ "vehicles", "peds" }) do
    for _, e in ipairs(world.list(name)) do
      local x, y, z = world.position(e)
      if e ~= p.entity and x and y and z then
        listed[#listed + 1] = { kind = name == "peds" and "Ped" or "Vehicle", model = world.model(e), far = math.sqrt((x - p.x) ^ 2 + (y - p.y) ^ 2 + (z - p.z) ^ 2) }
      end
    end
  end
  table.sort(listed, function(a, b) return a.far < b.far end)
end

for _, d in ipairs({ { "Peds", "peds" }, { "Vehicles", "vehicles" }, { "Objects", "objects" } }) do
  trainer.info(near, d[1], function()
    refresh()
    local c = counts[d[2]]
    return c and c[1] and string.format("%d of %d", c[1], c[2])
  end, "How many are alive, out of the slots the game reserves.", "offsets")
end
trainer.info(near, "Your model", function()
  local p = trainer.find.player()
  return p and p.model and world.model_name(p.model)
end, "The model of the character you play.", "player")

function world.model_name(hash)
  return scripthookvi.models and scripthookvi.models[hash] or string.format("0x%08X", hash)
end

near.side = {
  width = 560,
  title = "Nearest",
  info = function() return trainer.capability("player") and string.format("%d in range", #listed) or "" end,
  draw = function(x, y, w, st)
    refresh()
    local size, rh, pad, shown = st.tx(15), st.tx(25), st.pad, 14
    ui.rect(x, y, w, shown * rh + st.px(12), st.row_bg)
    if #listed == 0 then
      ui.text(x + pad, y + st.px(6) + math.floor((rh - ui.line_height(size)) / 2 + 0.5), trainer.missing("player") or "Nothing else is loaded.", 0xFFA8A8A8, size)
    end
    for i = 1, math.min(shown, #listed) do
      local e = listed[i]
      local ty = y + st.px(6) + (i - 1) * rh + math.floor((rh - ui.line_height(size)) / 2 + 0.5)
      ui.text(x + pad, ty, e.kind, 0xFFA8A8A8, size)
      ui.text(x + pad + st.px(90), ty, e.model and world.model_name(e.model) or "no model", 0xFFFFFFFF, size)
      ui.text(x + w - pad, ty, string.format("%.1f m", e.far), 0xFFFFFFFF, size, nil, { align = "right", tabular = true })
    end
  end,
}
