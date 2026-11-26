-- Stub tests for the starting zone window's logic (no client): lua5.1 client/tests/startingzone_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
strsplit = strsplit or function(sep, s)
	local out, i = {}, 1;
	while true do
		local j = string.find(s, sep, i, true);
		if ( not j ) then table.insert(out, string.sub(s, i)); break; end
		table.insert(out, string.sub(s, i, j - 1)); i = j + 1;
	end
	return unpack(out);
end
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftStartingZone.lua");
local L = TemucraftStartingZoneLogic;
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

check("zone before BEGIN ignored", L.OnMessage("Z~0~1~1~14~363~-618.5~-4251.7~Valley of Trials") == nil and L.zones == nil);
check("begin", L.OnMessage("BEGIN~4") == nil);
L.OnMessage("Z~0~1~1~14~363~-618.5~-4251.7~Valley of Trials");
L.OnMessage("Z~2~0~0~85~154~1676.7~1678.3~Deathknell");
L.OnMessage("Z~4~0~1~215~222~-2917.6~-257.9~Camp Narache");
L.OnMessage("Z~6~0~530~3430~3431~10349.6~-6357.3~Sunstrider Isle");
check("end shows", L.OnMessage("END") == "show" and #L.zones == 4);
check("here first, Stay in", L.CardTitle(L.zones[1]) == "Stay in Valley of Trials");
check("others plain name", L.CardTitle(L.zones[2]) == "Deathknell" and L.zones[3].index == 4);
check("done hides", L.OnMessage("DONE") == "hide");
check("2 x 2 for four", L.Columns(4) == 2 and L.Columns(5) == 3);
check("pages", L.Pages(6) == 1 and L.Pages(7) == 2 and L.Pages(0) == 1);
check("map data", L.MAPS[14] and L.MAPS[14][1] == "Durotar" and L.MAPS[3524] and L.MAPS[141]);
local art = L.Art(L.zones[1]);
check("durotar art", art.file == "Durotar" and art.x0 >= 0 and art.y0 >= 0 and art.x0 + art.w <= L.MAP_W and art.y0 + art.h <= L.MAP_H);
-- Valley of Trials is south of the middle of Durotar
check("crop around the spot", art.x0 < 0.433 * L.MAP_W and art.x0 + art.w > 0.433 * L.MAP_W and art.y0 < 0.688 * L.MAP_H and art.y0 + art.h > 0.688 * L.MAP_H);
local tiles = L.Tiles(art);
local area = 0;
for _, t in ipairs(tiles) do
	area = area + (t.right - t.left) * (t.bottom - t.top);
	if ( t.u0 < 0 or t.u1 > 1 or t.v0 < 0 or t.v1 > 1 or t.tile < 1 or t.tile > 12 ) then area = -99; end
end
check("tiles cover the picture", math.abs(area - 1) < 1e-6 and #tiles <= 6);
check("unknown zone: loading screen", L.Art({ zone = 99999, map = 1 }).loading == L.LOADING[1]);
check("all stock starts have maps", L.MAPS[12] and L.MAPS[1] and L.MAPS[85] and L.MAPS[215] and L.MAPS[3430]);
check("not a string", L.OnMessage(nil) == nil);

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
