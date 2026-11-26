local need, hex = trainer.needs, trainer.hex
local m = trainer.section("Debug", "Engine status and tools for reading game memory. Nothing is written unless you allow it.")

local engine = m:submenu("Engine", "How the engine is connected and what it found.")
trainer.info(engine, "Connection", function() return game.mode() end, "internal: inside the game. external: from another process. detached: no game. preview: a rendered picture.")
trainer.info(engine, "Status", function() return game.status() end, "The same text the status line shows.")
trainer.info(engine, "Process", function() return game.pid() end, "The id of the process the engine reads.")
trainer.info(engine, "Title image", function() return mem.found() and "found" or "searching every 2 s" end, "Whether the game image is located; until then the engine reads its host.")
trainer.info(engine, "Build", function() return game.build() or "none" end, "The build name a script gave this image, or unknown for a title no script has an entry for.")
trainer.info(engine, "Image base", function() return hex(mem.base()) end, "Where the game image starts in memory.").font = "mono"
trainer.info(engine, "Image size", function() return string.format("%s  %.1f MB", hex(mem.size()), mem.size() / 1048576) end, "How many bytes the game image spans.").font = "mono"
trainer.info(engine, "Link stamp", function()
  local stamp = game.stamp()
  return stamp and string.format("%08x", stamp) or "none"
end, "The time stamp the image was linked with; it tells builds apart.").font = "mono"
trainer.info(engine, "Natives", function()
  local count = native.count and select(2, native.count()) or 0
  local named = native.spaces and native.spaces() or {}
  for _, n in ipairs(natives.list) do
    if not (named[n.space] and named[n.space][n.name]) then count = count + 1 end
  end
  return string.format("%d by name", count)
end, "How many natives scripts can call by name: the ones read from data plus the game's own handlers with a public name. Debug > Natives has the detail.")
trainer.info(engine, "Uptime", function() return string.format("%.0f s", now() / 1000) end, "Time since the engine started.")

local viewer = { addr = nil, writes = {} }
trainer.viewer = viewer
local view = m:submenu("Memory viewer", "A hex and text dump of memory, drawn beside this menu.")
local steps = { 0x1, 0x10, 0x100, 0x1000, 0x10000, 0x100000, 0x1000000, 0x10000000 }
local step_names = {}
for i, s in ipairs(steps) do step_names[i] = string.format("0x%x", s) end

local address = view:number("Address", 0, 0x100, function(v) viewer.go(v) end, "Left and right move the address by the step below.")
address.min, address.font, address.format = 0, "mono", function(v) return string.format("%x", v) end
local typed = view:text("Type address", "", function(text)
  local addr = tonumber((text:gsub("^0[xX]", "")), 16)
  if not addr then log("not a hex address: " .. text) end
  viewer.go(addr or viewer.addr)
end, "Select, type a hex address and press Enter to show it.")
view:choice("Step", step_names, 3, function(i) address.step = steps[i] end, "How far one press moves the address, one hex digit at a time.")

function viewer.go(addr)
  viewer.addr = addr
  address.value = addr
  typed.value = string.format("%x", addr)
end

view.on_open = function()
  if not viewer.addr then viewer.go(mem.base()) end
end

local go = view:submenu("Go to", "Jump to the image base, a section or a result from the other tools.")
go.on_open = function()
  go.items = {}
  go:action("Image base", function() viewer.go(mem.base()) end, "The first byte of the game image, its MZ header.")
  for _, s in ipairs(mem.sections()) do
    go:action(s.name ~= "" and s.name or "?", function() viewer.go(s.addr) end, string.format("The %s section, %s bytes at image +%x.", s.name, hex(s.size), s.addr - mem.base()))
  end
  go:action("Scratch buffer", function()
    trainer.scratch = trainer.scratch or mem.alloc(256)
    viewer.go(trainer.scratch)
  end, "256 bytes the engine owns, a safe place to try writes.")
  local hit = go:action("Last scan hit", function() viewer.go(trainer.scan.hit) end, "The first address the last pattern scan found.")
  hit.unavailable = function() return not trainer.scan.hit and "needs a scan hit" end
  local chain = go:action("Pointer chain result", function() viewer.go(trainer.chain.result()) end, "Where the pointer chain currently ends.")
  chain.unavailable = function() return not trainer.chain.result() and "needs a chain result" end
end

local byte = need(view:number("Byte at address", 0, 1, function(v)
  local old = mem.read(viewer.addr, "u8")
  if old and mem.write(viewer.addr, "u8", v) then
    viewer.writes[#viewer.writes + 1] = { addr = viewer.addr, old = old }
    log(string.format("wrote %02x at %x, was %02x", v, viewer.addr, old))
  end
end, "Left and right write a new value into the byte at the address."), "writes")
byte.min, byte.max, byte.wrap, byte.font = 0, 255, true, "mono"
byte.format = function(v) return string.format("%02x", v) end

local typed = { t = -1e9 }

local function type_here()
  if typed.addr ~= viewer.addr or now() - typed.t > 500 then
    typed = { addr = viewer.addr, t = now() }
    if par and trainer.capability("game") then typed.d, typed.kind, typed.label = par.class_of(viewer.addr) end
  end
  return typed
end

local here = view:action(function() return "Type at address: " .. (type_here().label or "none") end, function()
  trainer.open_members(type_here().d, viewer.addr)
end, "What par.class_of names at this address; select it to see the structure's members with their live values.")
here.unavailable = function()
  local t = type_here()
  return trainer.missing("game") or (not t.kind and "no vtable here") or (t.kind == "rtti" and "RTTI only")
    or (t.kind == "vtable" and "no parser type") or (not (t.d and t.d.ptr) and "not registered")
end

local undo = view:action("Undo last write", function()
  local w = table.remove(viewer.writes)
  mem.write(w.addr, "u8", w.old)
  log(string.format("restored %02x at %x", w.old, w.addr))
end, "Puts back the byte the last write changed.")
undo.unavailable = function() return trainer.missing("writes") or (#viewer.writes == 0 and "nothing written") end

view:action("Log this page", function()
  local start = viewer.addr - viewer.addr % 16
  for r = 0, 15 do
    local row = mem.bytes(start + r * 16, 16)
    log(string.format("%012x  %s", start + r * 16, row and row:gsub(".", function(c) return string.format("%02x ", c:byte()) end) or "unreadable"))
  end
end, "Writes the 256 bytes on screen to the log as hex.")

view.side = {
  width = 800,
  title = "Memory",
  info = function() return hex(viewer.addr) end,
  draw = function(x, y, w, st)
    local addr = viewer.addr or mem.base()
    byte.value = mem.read(addr, "u8") or 0
    local size, rh, pad = st.tx(15), st.tx(25), st.pad
    local lh = ui.line_height(size, "mono")
    local start = addr - addr % 16
    local cell = ui.text_width("00", size, "mono") + st.px(8)
    local char = ui.text_width("0", size, "mono")
    local ax = x + pad
    local hx = ax + ui.text_width("000000000000", size, "mono") + st.px(20)
    local cx = hx + 16 * cell + st.px(8) + st.px(14)
    local body = 16 * rh + st.px(12)
    ui.rect(x, y, w, body, st.row_bg)
    for r = 0, 15 do
      local at = start + r * 16
      local ry = y + st.px(6) + r * rh
      local ty = ry + math.floor((rh - lh) / 2 + 0.5)
      local row = mem.bytes(at, 16)
      ui.text(ax, ty, string.format("%012x", at), 0xFFA8A8A8, size, "mono")
      for i = 0, 15 do
        local bx = hx + i * cell + (i >= 8 and st.px(8) or 0)
        local b = row and row:byte(i + 1)
        if at + i == addr then ui.rect(bx - st.px(4), ry + st.px(1), cell - st.px(1), rh - st.px(2), st.accent) end
        local ink = not b and 0xFF767676 or (at + i == addr and 0xFFFFFFFF) or (b == 0 and 0xFF8A8A8A or 0xFFFFFFFF)
        ui.text(bx, ty, b and string.format("%02x", b) or "??", ink, size, "mono")
        local c = b and b >= 0x20 and b < 0x7F and string.char(b) or "."
        ui.text(cx + i * char, ty, c, b and b >= 0x20 and b < 0x7F and 0xFFFFFFFF or 0xFF767676, size, "mono")
      end
    end
    y = y + body
    local u32, u64, f32 = mem.read(addr, "u32"), mem.read(addr, "u64"), mem.read(addr, "f32")
    local text = mem.string(addr, 48):gsub("[^\32-\126]", ".")
    local lines = {
      { "u32", u32 and string.format("%08x   %d", u32, u32) or "unreadable" },
      { "u64", u64 and string.format("%016x", u64) or "unreadable" },
      { "f32", f32 and string.format("%.6g", f32) or "unreadable" },
      { "text", text ~= "" and menu.fit('"' .. text .. '"', w - 2 * pad - st.px(64), size, "mono") or "empty" },
    }
    local inset = st.px(10)
    ui.rect(x, y, w, #lines * lh + 2 * inset, st.label_bg)
    for i, l in ipairs(lines) do
      local ly = y + inset + (i - 1) * lh
      ui.text(x + pad, ly, l[1], 0xFFA8A8A8, size)
      ui.text(x + pad + st.px(64), ly, l[2], 0xFFFFFFFF, size, "mono")
    end
  end,
}

local scan = { hits = {} }
trainer.scan = scan
local patterns = {
  { "MZ header", "4D 5A 90 00", "The DOS header every image starts with." },
  { "PE header", "50 45 00 00 64 86", "The PE signature followed by the x64 machine id." },
  { "Function start", "48 89 5C 24 ?? 48 89 74 24 ?? 57 48 83 EC 20", "A common compiler prologue; finds the first 16 functions that use it." },
  { "int3 padding", "CC CC CC CC CC CC CC CC CC CC CC CC CC CC CC CC", "Sixteen bytes of int3 filler between functions, room for a hook." },
  { "Custom", "", "The pattern typed in the row below." },
}
for _, p in ipairs(rawget(world, "patterns") or {}) do table.insert(patterns, #patterns, p) end
local pattern_names = {}
for i, p in ipairs(patterns) do pattern_names[i] = p[1] end

local scanner = m:submenu("Pattern scan", "Search the image for a byte pattern and open what it finds.")
local which
which = scanner:choice("Pattern", pattern_names, 1, nil, function() return patterns[which.value][3] .. " " .. patterns[which.value][2] end)
scanner:text("Custom pattern", "", function(text)
  patterns[#patterns][2] = text
  which.value = #patterns
end, "Select and type hex bytes, ?? for any byte, for example 48 8B ?? 05. Enter makes it the pattern to scan.")
local ranges = { { name = "Whole image" } }
local range = scanner:choice("Range", { "Whole image" }, 1, nil, "Where to search: the whole image or one of its sections.")
scanner.on_open = function()
  ranges = { { name = "Whole image" } }
  for _, s in ipairs(mem.sections()) do ranges[#ranges + 1] = s end
  range.options = {}
  for i, r in ipairs(ranges) do range.options[i] = r.name end
  if range.value > #ranges then range.value = 1 end
end
local fixed

scanner:action("Scan", function()
  local p, r = patterns[which.value], ranges[range.value]
  local t0 = now()
  local ok, hits = pcall(mem.scan, p[2], r.addr, r.size, 16)
  scan.hits = ok and hits or {}
  scan.hit = scan.hits[1]
  scan.ms = now() - t0
  while #scanner.items > fixed do table.remove(scanner.items) end
  local summary = #scan.hits == 0 and "No hits" or string.format("%d hit%s%s", #scan.hits, #scan.hits == 1 and "" or "s", #scan.hits == 16 and " or more" or "")
  scanner:label(function() return summary, string.format("%.0f ms", scan.ms) end, ok and "Select a hit to open it in the memory viewer." or tostring(hits))
  for _, a in ipairs(scan.hits) do
    scanner:action(string.format("%x  image +%x", a, a - mem.base()), function()
      viewer.go(a)
      menu.enter(view)
    end, "Opens this address in the memory viewer.").font = "mono"
  end
  log(string.format("scan %s: %d hits in %.0f ms", p[1], #scan.hits, scan.ms))
end, "Searches the range for the pattern; the whole image takes about half a second.")
fixed = #scanner.items

local signatures = m:submenu("Signatures", "Named game addresses that scripts find by byte pattern, kept per build so the next start does not search again.")
signatures.on_open = function()
  signatures.items = {}
  need(signatures:action("Scan again", function()
    sig.rescan()
    for _, s in ipairs(sig.all()) do sig.get(s.name) end
  end, "Forgets what is kept for this build and searches the image for every pattern again."), "game")
  if #sig.all() == 0 then
    signatures:label(function() return "No signatures defined" end, "Scripts add them with sig.define.")
  end
  for _, s in ipairs(sig.all()) do
    signatures:label(function()
      local addr, why = sig.get(s.name)
      if not addr then return s.name, why end
      local rva = addr - mem.base()
      return s.name, rva >= 0 and rva < mem.size() and string.format("image +%x", rva) or hex(addr)
    end, function()
      for _, e in ipairs(sig.all()) do
        if e.name == s.name then
          local from = e.from == "cache" and "Kept from an earlier start" or e.from == "scan" and "Found by a scan" or "Not resolved"
          return string.format("%s, %d scan%s since load. Pattern %s", from, e.scans, e.scans == 1 and "" or "s", e.pattern)
        end
      end
    end)
  end
end

local chain = { offsets = { 0, 0, 0, 0 }, levels = 2, start = 1, base = 0 }
trainer.chain = chain
local starts = { "Image base", "Viewer address", "Last scan hit" }

function chain.origin()
  if chain.start == 2 then return viewer.addr end
  if chain.start == 3 then return scan.hit end
  return mem.base()
end

function chain.result()
  local origin = chain.origin()
  if not origin then return nil end
  return mem.deref(origin + chain.base, table.unpack(chain.offsets, 1, chain.levels))
end

local function signed(v) return v < 0 and string.format("-0x%x", -v) or string.format("+0x%x", v) end
local pointers = m:submenu("Pointer chain", "Follow pointers from a start address through a list of offsets.")
pointers:choice("Start", starts, 1, function(i) chain.start = i end, "Where the chain begins: the image base, the viewer's address or the last scan hit.")
local offset_items = {}
local base = pointers:number("Start offset", 0, 0x8, function(v) chain.base = v end, "Added to the start before the first pointer is read.")
base.format, base.font = signed, "mono"
offset_items[1] = base
local levels = pointers:number("Levels", 2, 1, function(v) chain.levels = v end, "How many pointers to follow.")
levels.min, levels.max = 1, 4
for i = 1, 4 do
  local item = pointers:number("Offset " .. i, 0, 0x8, function(v) chain.offsets[i] = v end, "Added after pointer " .. i .. " is read.")
  item.format, item.font = signed, "mono"
  item.unavailable = function() return i > chain.levels and "beyond Levels" end
  offset_items[#offset_items + 1] = item
end
pointers:choice("Offset step", { "0x8", "0x100", "0x1000", "0x10000", "0x100000" }, 1, function(_, name)
  for _, item in ipairs(offset_items) do item.step = tonumber(name) end
end, "How far one press of left or right moves an offset.")
trainer.info(pointers, "Result", function()
  if not chain.origin() then return "no start address" end
  return chain.result() and hex(chain.result()) or "unreadable"
end, "Where the chain ends, or unreadable when a pointer on the way is not mapped.").font = "mono"
trainer.info(pointers, "Value there", function()
  local r = chain.result()
  if not r then return "none" end
  local v = mem.read(r, "u64")
  return v and string.format("%016x", v) or "unreadable"
end, "The eight bytes at the end of the chain.").font = "mono"
local open = pointers:action("Open in memory viewer", function()
  viewer.go(chain.result())
  menu.enter(view)
end, "Shows the end of the chain in the memory viewer.")
open.unavailable = function() return not chain.result() and "needs a chain result" end
pointers:action("Log the chain", function()
  local parts = { string.format("%x %s", chain.origin() or 0, signed(chain.base)) }
  for i = 1, chain.levels do parts[#parts + 1] = signed(chain.offsets[i]) end
  log("chain " .. table.concat(parts, " ") .. " = " .. hex(chain.result()))
end, "Writes the start, the offsets and the result to the log.")

local function no_registry(x, y, w, st, rows)
  local size, rh = st.tx(15), st.tx(25)
  ui.rect(x, y, w, rows * rh + st.px(12), st.row_bg)
  local why = game.mode() == "preview" and "No game: this is a preview. The type registry is read from a running game."
    or trainer.missing("types") and ("No type registry: " .. trainer.missing("types") .. ".")
  ui.text(x + st.pad, y + st.px(6) + math.floor((rh - ui.line_height(size)) / 2 + 0.5), menu.fit(why or "", w - 2 * st.pad, size), 0xFFA8A8A8, size)
end

local function rows_of(x, y, w, st, n, first, current, cols, main, cell)
  local size, rh, pad = st.tx(15), st.tx(25), st.pad
  ui.rect(x, y, w, n * rh + st.px(12), st.row_bg)
  for r = 0, n - 1 do
    local i = first + r
    local ry = y + st.px(6) + r * rh
    local ty = ry + math.floor((rh - ui.line_height(size)) / 2 + 0.5)
    if i == current then ui.rect(x, ry, w, rh, st.accent) end
    local cx = x + pad
    for c, width in ipairs(cols) do
      local text = cell(i, c)
      if text then
        local cw = math.floor(width * (w - 2 * pad))
        local ink = (i == current or c == main) and 0xFFFFFFFF or 0xFFA8A8A8
        ui.text(cx, ty, menu.fit(text, cw - st.px(10), size), ink, size)
        cx = cx + cw
      end
    end
  end
end

local function hash_label(h) return h and (par.name(h) or string.format("0x%08x", h)) or "?" end

local fields = menu.new("Members")
local shown = { members = {} }
local pick = fields:number("Member", 1, 1, nil, "Left and right move through the members; the side panel follows.")
pick.min, pick.wrap = 1, true
pick.format = function(v)
  local mb = shown.members[v]
  return mb and (mb.name or string.format("0x%08x", mb.hash)) or "none"
end

function trainer.open_members(d, addr)
  shown = { d = d, addr = addr, members = par.members(d) }
  shown.view = addr and par.view(addr, d)
  pick.value, pick.max = 1, math.max(1, #shown.members)
  menu.enter(fields)
end

local up = fields:action("Base structure", function() trainer.open_members(par.struct(shown.d.base), shown.addr) end, "Shows the structure this one is built on, at the same address.")
up.unavailable = function() return not (shown.d and shown.d.base) and "no base structure" end
fields:action("Log members", function()
  log(string.format("%s, 0x%x bytes%s", hash_label(shown.d.hash), shown.d.size, shown.addr and string.format(", at %x", shown.addr) or ""))
  for _, mb in ipairs(shown.members) do
    local value = shown.view and "  = " .. par.format(shown.view[mb.hash]) or ""
    log(string.format("  +0x%04x  %-32s %s%s", mb.offset, mb.name or string.format("0x%08x", mb.hash), par.type_name(mb), value))
  end
end, "Writes every member with its offset and type, and its value when there is an address, to the log.")
fields.side = {
  width = 860,
  title = function() return shown.d and hash_label(shown.d.hash) or "Members" end,
  info = function()
    if not shown.d then return "" end
    return string.format("0x%x bytes, %d members%s", shown.d.size, #shown.members, shown.addr and string.format(", at %x", shown.addr) or "")
  end,
  draw = function(x, y, w, st)
    local n = 18
    local first = math.max(1, math.min(pick.value - 8, #shown.members - n + 1))
    local cols = shown.addr and { 0.12, 0.3, 0.3, 0.28 } or { 0.14, 0.43, 0.43 }
    rows_of(x, y, w, st, n, first, pick.value, cols, 2, function(i, c)
      local mb = shown.members[i]
      if not mb then return c == 2 and i == 1 and "No members." or nil end
      if c == 1 then return string.format("+%04x", mb.offset) end
      if c == 2 then return mb.name or string.format("0x%08x", mb.hash) end
      if c == 3 then return par.type_name(mb) end
      if now() - (shown.read_at or -1e9) > 250 then shown.values, shown.read_at = {}, now() end
      shown.values[i] = shown.values[i] or par.format(shown.view[mb.hash])
      return shown.values[i]
    end)
  end,
}

local types = m:submenu("Types", "The game's own type registry: every structure the game can load from data, with its size and members.")
trainer.types = types
local catalog = { all = nil }
local entry
local letters = { "all" }
for c = string.byte("A"), string.byte("Z") do letters[#letters + 1] = string.char(c) end
letters[#letters + 1] = "unnamed"

local function sorted()
  if catalog.all or not trainer.capability("types") then return catalog.all or {} end
  local all = {}
  for d in par.structs() do all[#all + 1] = d end
  table.sort(all, function(a, b)
    if (a.name ~= nil) ~= (b.name ~= nil) then return a.name ~= nil end
    if a.name and a.name:lower() ~= b.name:lower() then return a.name:lower() < b.name:lower() end
    return a.hash < b.hash
  end)
  catalog.all, catalog.count = all, par.counts()
  entry.max = math.max(1, #all)
  return all
end

trainer.info(types, "Registry", function()
  if game.mode() == "preview" then return "no game in a preview" end
  local miss = trainer.missing("types")
  if miss then return miss end
  local s, e = par.counts()
  return string.format("%d structures, %d enums", s, e)
end, "How many structures and enums the game has registered; read from its memory, not from a file.")
entry = trainer.needs(types:number("Structure", 1, 1, nil, "Left and right step through the structures in name order; Step and Starts with move faster."), "types")
entry.min, entry.wrap = 1, true
entry.format = function(v)
  local d = sorted()[v]
  return d and hash_label(d.hash) or "none"
end
trainer.needs(types:choice("Step", { "1", "10", "100", "1000" }, 1, function(_, name) entry.step = tonumber(name) end, "How many structures one press of left or right moves."), "types")
trainer.needs(types:choice("Starts with", letters, 1, function(_, letter)
  local all = sorted()
  for i, d in ipairs(all) do
    local first = d.name and d.name:sub(1, 1):upper()
    if letter == "all" or (letter == "unnamed" and not d.name) or (first and letter ~= "unnamed" and first >= letter) then
      entry.value = i
      return
    end
  end
end, "Jumps to the first structure whose name starts with this letter, or to the unnamed ones."), "types")
trainer.needs(types:action("Open members", function() trainer.open_members(sorted()[entry.value]) end, "Lists the selected structure's members with their offsets and types."), "types")
types.on_open = function()
  if not trainer.capability("types") then return end
  if catalog.count ~= par.counts() then catalog.all = nil end
  entry.max = math.max(1, #sorted())
end
types.side = {
  width = 760,
  title = "Structures",
  info = function() return catalog.all and string.format("%d / %d", entry.value, #catalog.all) or "" end,
  draw = function(x, y, w, st)
    if not trainer.capability("types") then return no_registry(x, y, w, st, 18) end
    local all = sorted()
    local first = math.max(1, math.min(entry.value - 8, #all - 17))
    rows_of(x, y, w, st, 18, first, entry.value, { 0.64, 0.18, 0.18 }, 1, function(i, c)
      local d = all[i]
      if not d then return nil end
      if c == 1 then return hash_label(d.hash) end
      if c == 2 then return string.format("0x%x", d.size) end
      return string.format("%d members", d.count)
    end)
  end,
}

local logs = m:submenu("Log", "The latest log lines, drawn beside this menu.")
local tail, tail_at = {}, -1e9

local function file_lines()
  if now() - tail_at < 500 then return tail end
  tail_at = now()
  local f = io.open(trainer.log_file, "rb")
  if not f then return tail end
  local size = f:seek("end")
  f:seek("set", math.max(0, size - 6000))
  local text = f:read("a") or ""
  f:close()
  tail = {}
  for line in text:gmatch("[^\r\n]+") do tail[#tail + 1] = { text = line } end
  if size > 6000 then table.remove(tail, 1) end
  return tail
end

local function lines() return trainer.log_file and file_lines() or trainer.lines end
logs:action("Write a test line", function() log("test line from the Debug menu") end, "Adds a line to the log so you can see it arrive.")
logs:action("Clear the list", function()
  trainer.lines = {}
  tail = {}
end, "Empties this view; the log file keeps every line.")
logs.side = {
  width = 720,
  title = function() return trainer.log_file and "ScriptHookVI.log" or "Script log" end,
  info = function() return string.format("%d lines", #lines()) end,
  draw = function(x, y, w, st)
    local size, rh, pad = st.tx(15), st.tx(25), st.pad
    local list, shown = lines(), 18
    local body = shown * rh + st.px(12)
    ui.rect(x, y, w, body, st.row_bg)
    local first = math.max(1, #list - shown + 1)
    if #list == 0 then
      ui.text(x + pad, y + st.px(6) + math.floor((rh - ui.line_height(size)) / 2 + 0.5), "No lines yet. Scripts write here with log().", 0xFFA8A8A8, size)
    end
    local tw = ui.text_width("0000.0", size) + st.px(14)
    for i = first, #list do
      local l = list[i]
      local ty = y + st.px(6) + (i - first) * rh + math.floor((rh - ui.line_height(size)) / 2 + 0.5)
      local tx = x + pad
      if l.at then
        local stamp = string.format("%.1f", l.at / 1000)
        ui.text(tx + tw - st.px(14) - ui.text_width(stamp, size), ty, stamp, 0xFFA8A8A8, size)
        tx = tx + tw
      end
      ui.text(tx, ty, menu.fit(l.text, x + w - pad - tx, size), 0xFFFFFFFF, size)
    end
  end,
}

local calls = m:submenu("Natives", "The script natives in the natives table, by name, with live values.")
trainer.info(calls, "Provided by ScriptHookVI", function() return tostring(#natives.list) end, "Natives in the natives table, listed by namespace below. ScriptHookVI as published provides none.")
if native.count then
  trainer.info(calls, "Handlers in this build", function() return tostring((native.count())) end, "Native functions found in the game image, each carrying its own hash. native.call(hash, ...) runs one.")
  trainer.info(calls, "With a public name", function() return tostring(select(2, native.count())) end, "Handlers whose hash has a known name, callable by that name.")
  trainer.info(calls, "Callable now", function() return trainer.missing("calls") == nil and "yes" or "no" end, "Handlers run on the game's own thread: Settings > Engine > Tick on the game thread.")
end
local spaces, seen = {}, {}
for _, n in ipairs(natives.list) do
  if not seen[n.space] then
    seen[n.space] = { space = n.space, count = 0 }
    spaces[#spaces + 1] = seen[n.space]
  end
  seen[n.space].count = seen[n.space].count + 1
end
for _, s in ipairs(spaces) do
  trainer.info(calls, s.space, function() return tostring(s.count) end, "Natives in " .. s.space .. " that ScriptHookVI provides itself; the panel lists them, with live values where one can be shown.").space = s.space
end
calls.side = {
  width = 640,
  title = "Natives",
  info = function()
    local item = calls.items[calls.sel]
    return item and item.space or spaces[1] and spaces[1].space or ""
  end,
  draw = function(x, y, w, st)
    local item = calls.items[calls.sel]
    local space = item and item.space or spaces[1] and spaces[1].space
    local size, rh, pad, row = st.tx(15), st.tx(25), st.pad, 0
    ui.rect(x, y, w, (seen[space] and seen[space].count or 0) * rh + st.px(12), st.row_bg)
    for _, n in ipairs(natives.list) do
      if n.space == space then
        local ty = y + st.px(6) + row * rh + math.floor((rh - ui.line_height(size)) / 2 + 0.5)
        ui.text(x + pad, ty, n.name, 0xFFFFFFFF, size)
        local ok, v = pcall(function() return n.sample and n.sample(n.fn()) end)
        ui.text(x + w - pad, ty, ok and v or n.how, ok and v and 0xFFFFFFFF or 0xFFA8A8A8, size, nil, { align = "right", tabular = true })
        row = row + 1
      end
    end
  end,
}

local files = m:submenu("Scripts", "Every script file the engine loaded, with its state; turn files off or on and reload.")
local listed, listed_at = {}, -1

local function find(name)
  if listed_at ~= trainer.frames then listed, listed_at = scripthookvi.scripts(), trainer.frames end
  for _, s in ipairs(listed) do
    if s.name == name then return s end
  end
end

local function own(name)
  return name:match("10_trainer%.lua$") ~= nil
end

local function state(name)
  local s = find(name)
  if not s then return "gone" end
  if s.state == "failed" and s.line then return "failed, line " .. s.line end
  return s.state
end

local function about(name)
  local s = find(name)
  if not s then return "Not in the engine's list any more." end
  local text = s.error
  if s.state == "disabled" then
    text = "Turned off in the settings."
  elseif not text then
    local adds = {}
    for _, item in ipairs(trainer.menu.items) do
      if item.file == name then adds[#adds + 1] = item.label end
    end
    text = string.format("Loaded in %.1f ms; %d on_frame, %d script, %d menu items.", s.load_ms, s.frames, s.threads, s.items)
    if #adds > 0 then text = text .. " Adds " .. table.concat(adds, ", ") .. " to the menu." end
  end
  if s.core then return "Part of ScriptHookVI, always loaded. " .. text end
  if own(name) then return "The trainer itself, always loaded. " .. text end
  if s.enabled ~= (s.state ~= "disabled") then text = text .. (s.enabled and " Runs" or " Stays off") .. " from the next reload." end
  return text
end

files.on_open = function()
  files.items = {}
  need(files:action("Reload all scripts", function() trainer.reload() end, "Loads every script file again; settings that are not saved go back to their defaults."), "scripts")
  if not scripthookvi.scripts then
    trainer.info(files, "Script list", function() return "" end, "The engine keeps a list of script files and their state.", "registry")
    return
  end
  for _, s in ipairs(scripthookvi.scripts()) do
    local name = s.name
    local item = files:toggle(name, s.enabled, function(v) config.set("scripts." .. name .. ".enabled", v) end, function() return about(name) end)
    item.note = function() return state(name) end
    if s.core or own(name) then item.unavailable = function() return "always on, " .. state(name) end end
  end
end

trainer.info(m, "Frames", function() return string.format("%d at %d per second", trainer.frames, trainer.rate) end, "How many times the scripts have ticked, and how often they tick now.")
m:toggle("Allow writes", false, function(v)
  trainer.writes = v
  natives.writes = v
  trainer.refresh()
end, "Lets the memory tools change game memory. Off every time the scripts load.")
