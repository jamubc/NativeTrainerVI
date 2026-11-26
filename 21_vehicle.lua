local need, todo = trainer.needs, trainer.todo
local m = trainer.section("Vehicle", "Repairs, protection, paint and handling of the vehicle you are in.")

need(m:action("Repair", todo("Vehicle > Repair"), "Fixes the body, engine and tyres of the vehicle you are in."), "natives")
need(m:action("Clean", todo("Vehicle > Clean"), "Washes off dirt and removes decals."), "natives")
need(m:action("Flip upright", todo("Vehicle > Flip upright"), "Puts the vehicle back on its wheels."), "natives")
need(m:toggle("Can't be damaged", false, todo("Vehicle > Can't be damaged"), "Your vehicle takes no damage from crashes, bullets or fire."), "natives")
need(m:toggle("Tyres can't burst", false, todo("Vehicle > Tyres can't burst"), "Bullets and spikes leave your tyres whole."), "natives")
need(m:toggle("Seat belt", false, todo("Vehicle > Seat belt"), "You stay in your seat in a crash."), "natives")
need(m:toggle("Speed boost", false, todo("Vehicle > Speed boost"), "Hold Num9 to accelerate hard and Num3 to stop dead."), "natives")
need(m:toggle("Keep engine running", false, todo("Vehicle > Keep engine running"), "The engine stays on when you get out."), "natives")

local doors = m:submenu("Doors", "Open, close and lock the doors of your vehicle.")
need(doors:action("Open all doors", todo("Vehicle > Open all doors"), "Opens every door, the bonnet and the boot."), "natives")
need(doors:action("Close all doors", todo("Vehicle > Close all doors"), "Shuts every door, the bonnet and the boot."), "natives")
need(doors:toggle("Lock doors", false, todo("Vehicle > Lock doors"), "Nobody can get into your vehicle."), "natives")

local paint = m:submenu("Paint and upgrades", "Colours, tint, neon and every upgrade slot.")
local colours = { "Black", "White", "Silver", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Gold" }
need(paint:action("Max upgrades", todo("Vehicle > Max upgrades"), "Fits the best part in every upgrade slot."), "natives")
need(paint:action("Remove upgrades", todo("Vehicle > Remove upgrades"), "Puts the stock part back in every upgrade slot."), "natives")
need(paint:action("Random paint", todo("Vehicle > Random paint"), "Gives the vehicle random primary and secondary colours."), "natives")
need(paint:choice("Primary colour", colours, 1, todo("Vehicle > Primary colour"), "Changes the main body colour."), "natives")
need(paint:choice("Secondary colour", colours, 1, todo("Vehicle > Secondary colour"), "Changes the trim and detail colour."), "natives")
need(paint:choice("Window tint", { "None", "Light smoke", "Dark smoke", "Limo" }, 1, todo("Vehicle > Window tint"), "Darkens the windows."), "natives")
need(paint:toggle("Neon lights", false, todo("Vehicle > Neon lights"), "Lights up the ground under the vehicle."), "natives")

local perf = m:submenu("Performance", "Engine power and torque multipliers.")
local function times(v) return string.format("×%g", v) end
local power = need(perf:number("Engine power", 1, 0.5, todo("Vehicle > Engine power"), "Multiplies the power of the engine."), "natives")
power.min, power.max, power.format = 1, 10, times
local torque = need(perf:number("Torque", 1, 0.5, todo("Vehicle > Torque"), "Multiplies how hard the wheels pull from a standstill."), "natives")
torque.min, torque.max, torque.format = 1, 10, times
