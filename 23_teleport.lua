local need, todo = trainer.needs, trainer.todo
local m = trainer.section("Teleport", "Move to the waypoint, a saved spot or a named place.")

need(m:action("To waypoint", todo("Teleport > To waypoint"), "Moves you to the waypoint set on the map."), "natives")
need(m:action("Into nearest vehicle", todo("Teleport > Into nearest vehicle"), "Puts you in the driver's seat of the closest vehicle."), "natives")
need(m:action("Forward 10 metres", function()
  local e = world.player()
  local x, y, z = world.position(e)
  local fx, fy = world.forward(e)
  if x and fx then world.move(x + 10 * fx, y + 10 * fy, z + 0.5) end
end, "Moves you ten metres in the direction you face."), "moves")
local function add(x, y, z)
  trainer.add_position(string.format("%.1f, %.1f, %.1f", x, y, z), function() world.move(x, y, z) end, "Moves you back to this spot.")
end
need(m:action("Save this position", function()
  local p = trainer.find.player()
  if not p then return end
  config.set("teleport.saved", config.get("teleport.saved", "") .. string.format("%.2f,%.2f,%.2f;", p.x, p.y, p.z))
  add(p.x, p.y, p.z)
end, "Adds the spot you stand on to Saved positions."), "player")

local saved = m:submenu("Saved positions", "Spots you saved, newest last.")
trainer.empty(saved, "Nothing saved yet", "Save this position adds the spot you stand on to this list.")
function trainer.add_position(label, fn, desc)
  return trainer.fill(saved, need(saved:action(label, fn, desc), "moves"))
end
for x, y, z in config.get("teleport.saved", ""):gmatch("([^,;]+),([^,;]+),([^,;]+);") do
  add(tonumber(x), tonumber(y), tonumber(z))
end

local places = m:submenu("Places", "Named places.")
trainer.empty(places, "No places listed yet", "A script adds a place with trainer.add_place.")
trainer.places = {}
function trainer.add_place(name, x, y, z)
  local place = { name = name, at = { x = x, y = y, z = z } }
  trainer.places[name] = place
  return trainer.fill(places, need(places:action(name, function() world.move(place.at.x, place.at.y, place.at.z) end, "Moves you to " .. name .. "."), "moves"))
end

local shown = false
need(m:toggle("Show coordinates", false, function(v) shown = v end, "Shows your position and heading at the bottom of the screen."), "player")

on_frame(function()
  local p = shown and trainer.find.player()
  if not p then return end
  local s = ui.height() / 1080
  local size = math.floor(16 * s + 0.5)
  local pad, h = math.floor(12 * s + 0.5), math.floor(30 * s + 0.5)
  local text = string.format("X %.1f   Y %.1f   Z %.1f   heading %.0f°", p.x, p.y, p.z, p.heading)
  local w = ui.text_width(text, size, nil, { tabular = true }) + 2 * pad
  local x, y = math.floor((ui.width() - w) / 2), ui.height() - h - math.floor(24 * s + 0.5)
  ui.rect(x, y, w, h, 0xD2000000)
  ui.text(x + pad, y + math.floor((h - ui.line_height(size)) / 2 + 0.5), text, 0xFFFFFFFF, size, nil, { tabular = true })
end)
