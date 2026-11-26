local need, todo = trainer.needs, trainer.todo
local m = trainer.section("Misc", "HUD, radio and camera.")

need(m:toggle("Hide HUD", false, todo("Misc > Hide HUD"), "Hides the minimap, money and every other on-screen display."), "natives")
need(m:toggle("Hide minimap", false, todo("Misc > Hide minimap"), "Hides the minimap and keeps the rest of the HUD."), "natives")
need(m:action("Next radio station", todo("Misc > Next radio station"), "Tunes the radio to the next station."), "natives")
need(m:action("Skip radio track", todo("Misc > Skip radio track"), "Skips to the next song on the current station."), "natives")
need(m:toggle("Radio on foot", false, todo("Misc > Radio on foot"), "Keeps the radio playing when you are not in a vehicle."), "natives")
need(m:toggle("Free camera", false, todo("Misc > Free camera"), "Detaches the camera so you can fly it with the movement keys."), "natives")
local fov = need(m:number("Field of view", 50, 5, todo("Misc > Field of view"), "Widens or narrows the gameplay camera."), "natives")
fov.min, fov.max, fov.format = 30, 120, function(v) return string.format("%d°", v) end
