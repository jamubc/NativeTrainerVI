local need, todo = trainer.needs, trainer.todo
local m = trainer.section("Weapons", "Weapons, ammunition, special bullets and attachments.")

need(m:action("Give all weapons", todo("Weapons > Give all"), "Adds every weapon with full ammunition."), "natives")
need(m:action("Remove all weapons", todo("Weapons > Remove all"), "Takes every weapon away, fists excepted."), "natives")
need(m:action("Refill ammunition", todo("Weapons > Refill"), "Fills the ammunition of every weapon you carry."), "natives")
need(m:toggle("Unlimited ammunition", false, todo("Weapons > Unlimited ammunition"), "Your ammunition never runs out."), "natives")
need(m:toggle("No reload", false, todo("Weapons > No reload"), "Your magazine never empties, so you never reload."), "natives")
need(m:toggle("Explosive bullets", false, todo("Weapons > Explosive bullets"), "Bullets explode where they hit."), "natives")
need(m:toggle("Fire bullets", false, todo("Weapons > Fire bullets"), "Bullets set what they hit on fire."), "natives")
need(m:toggle("Explosive melee", false, todo("Weapons > Explosive melee"), "Punches and melee hits explode."), "natives")
local damage = need(m:number("Damage", 1, 1, todo("Weapons > Damage"), "Multiplies the damage of every weapon you use."), "natives")
damage.min, damage.max, damage.format = 1, 10, function(v) return string.format("×%d", v) end
need(m:toggle("Vehicle rockets", false, todo("Weapons > Vehicle rockets"), "Press Num+ in a vehicle to fire rockets straight ahead."), "natives")

local parts = m:submenu("Attachments", "Scopes, grips, suppressors and tints for the weapon in your hands.")
need(parts:action("Add all attachments", todo("Weapons > Add all attachments"), "Fits every attachment the weapon in your hands accepts."), "natives")
need(parts:action("Remove attachments", todo("Weapons > Remove attachments"), "Takes every attachment off the weapon in your hands."), "natives")
need(parts:choice("Tint", { "Normal", "Black", "Silver", "Gold", "Green", "Camouflage" }, 1, todo("Weapons > Tint"), "Changes the finish of the weapon in your hands."), "natives")
