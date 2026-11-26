local ticks = 0

trainer.status_texts = {
  { "Status and uptime", function() return string.format("ScriptHookVI  %s menu  up %ds  %s", trainer.key_name(menu.key), ticks, game.status()) end },
  { "Status only", function() return game.status() end },
  { "With frame rate", function() return string.format("ScriptHookVI  %s menu  up %ds  %d fps  %s", trainer.key_name(menu.key), ticks, trainer.rate, game.status()) end },
}

script(function()
  while true do
    ticks = ticks + 1
    wait(1000)
  end
end)

on_frame(function()
  if not trainer.setting("status.show", true) then return end
  local choice = trainer.status_texts[trainer.setting("status.content", 1)] or trainer.status_texts[1]
  local s = ui.height() / 1080
  local size = math.floor(14 * s + 0.5)
  local pad, h = math.floor(10 * s + 0.5), math.floor(26 * s + 0.5)
  local x, y = math.floor(menu.x * s + 0.5), math.floor(8 * s + 0.5)
  local text = choice[2]()
  ui.rect(x, y, ui.text_width(text, size) + 2 * pad, h, 0xD2000000)
  ui.text(x + pad, y + math.floor((h - ui.line_height(size)) / 2 + 0.5), text, 0xFFFFFFFF, size)
end)
