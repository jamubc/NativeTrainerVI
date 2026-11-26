local need, todo = trainer.needs, trainer.todo
local m = trainer.section("Spawner", "Vehicles, people, bodyguards and objects.")

local cars = m:submenu("Vehicles", "Spawn a vehicle by kind.")
local kinds = {}
for _, kind in ipairs({ "Cars", "Motorcycles", "Off-road", "Vans and trucks", "Emergency and service", "Military", "Boats", "Helicopters", "Planes", "Bicycles" }) do
  local k = cars:submenu(kind, "Spawn one of the " .. kind:lower() .. ".")
  trainer.empty(k, "No models listed yet", "Model names are added here as they are found in the game files.")
  kinds[kind] = k
end

function trainer.add_vehicle(kind, label, fn, desc)
  local k = kinds[kind] or error("no vehicle kind " .. tostring(kind))
  return trainer.fill(k, need(k:action(label, fn, desc), "calls"))
end

local people = m:submenu("People", "Spawn a person next to you.")
need(people:action("Copy of yourself", todo("Spawner > Copy of yourself"), "Spawns a person who looks exactly like your character."), "natives")
trainer.empty(people, "No models listed yet", "Model names are added here as they are found in the game files.")

local guards = m:submenu("Bodyguards", "Armed people who follow and protect you.")
need(guards:action("Add a bodyguard", todo("Spawner > Add a bodyguard"), "Spawns an armed person who follows and protects you."), "natives")
need(guards:choice("Bodyguard weapon", { "Pistol", "SMG", "Carbine rifle", "Pump shotgun" }, 1, todo("Spawner > Bodyguard weapon"), "The weapon each new bodyguard carries."), "natives")
need(guards:action("Dismiss bodyguards", todo("Spawner > Dismiss bodyguards"), "Sends every bodyguard away."), "natives")

local objects = m:submenu("Objects", "Props placed in front of you.")
trainer.empty(objects, "No models listed yet", "Model names are added here as they are found in the game files.")
need(objects:action("Delete spawned objects", todo("Spawner > Delete objects"), "Removes every object this trainer placed."), "natives")

need(m:toggle("Spawn in the vehicle", trainer.setting("spawner.enter", true), function(v) trainer.store("spawner.enter", v) end, "Puts you in the driver's seat of each vehicle you spawn."), "natives")
need(m:toggle("Replace the last vehicle", trainer.setting("spawner.replace", false), function(v) trainer.store("spawner.replace", v) end, "Deletes the vehicle you spawned before when you spawn a new one."), "natives")
need(m:toggle("Spawn fully upgraded", trainer.setting("spawner.upgrade", false), function(v) trainer.store("spawner.upgrade", v) end, "Fits the best part in every upgrade slot of each vehicle you spawn."), "natives")
need(m:action("Delete everything spawned", todo("Spawner > Delete everything"), "Removes every vehicle, person and object this trainer spawned."), "natives")
