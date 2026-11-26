-- Stub tests for the login screens (no client): lua5.1 client/tests/glue_test.lua (from the module folder)
-- 1. the logic tables of TemucraftCharCreate.lua / TemucraftCharSelect.lua with the generated data,
-- 2. a stub load: both files built on stub frames and the client functions they call, then clicked through.
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
local glue = dir.."/Interface/GlueXML/";
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

dofile(glue.."TemucraftGlueData.lua");
dofile(glue.."TemucraftRacialsData.lua");
dofile(glue.."TemucraftRacePortraits.lua");
dofile(glue.."TemucraftCharCreate.lua");
dofile(glue.."TemucraftCharSelect.lua");
local C, S = assert(TemucraftCreateLogic), assert(TemucraftSelectLogic);

-- data
local n = 0;
for _ in pairs(TEMUCRAFT_CUSTOMIZE_COUNTS) do n = n + 1; end
check("counts for 30 races x 2 sexes", n >= 60 and TEMUCRAFT_CUSTOMIZE_COUNTS.HUMAN_MALE and TEMUCRAFT_CUSTOMIZE_COUNTS.HORDEHARANIR_FEMALE);
check("dalaran has brackets", TEMUCRAFT_ZONE_BRACKET_NAMES.Dalaran and TEMUCRAFT_ZONE_BRACKET[TEMUCRAFT_ZONE_BRACKET_NAMES.Dalaran[1]] == "Wrath of the Lich King");
local shortLabels = true;
for id, label in pairs(TEMUCRAFT_ZONE_BRACKET) do
	if ( string.find(label, "Classic") or string.find(label, "^Midnight %d") or string.find(label, ", ") ) then shortLabels = false; print("  long label", id, label); end
end
check("labels short: no Classic, no numbering, no lists", shortLabels);
local zonesOk = true;
for name, ids in pairs(TEMUCRAFT_ZONE_BRACKET_NAMES) do
	for _, id in ipairs(ids) do if ( not TEMUCRAFT_ZONE_BRACKET[id] ) then zonesOk = false; end end
end
check("every character select row has a label", zonesOk);

-- layout: every race placed, sides by faction, no two in one cell
local files = {
	"HUMAN", "ORC", "DWARF", "NIGHTELF", "SCOURGE", "TAUREN", "GNOME", "TROLL", "GOBLIN", "BLOODELF", "DRAENEI", "WORGEN",
	"ALLIANCEPANDAREN", "HORDEPANDAREN", "NIGHTBORNE", "HIGHMOUNTAINTAUREN", "VOIDELF", "LIGHTFORGEDDRAENEI",
	"ZANDALARITROLL", "KULTIRAN", "VULPERA", "DARKIRONDWARF", "MAGHAR", "MECHAGNOME", "ALLIANCEDRACTHYR", "HORDEDRACTHYR",
	"ALLIANCEEARTHEN", "HORDEEARTHEN", "ALLIANCEHARANIR", "HORDEHARANIR",
};
local horde = { ORC = 1, SCOURGE = 1, TAUREN = 1, TROLL = 1, GOBLIN = 1, BLOODELF = 1, HORDEPANDAREN = 1, NIGHTBORNE = 1,
	HIGHMOUNTAINTAUREN = 1, ZANDALARITROLL = 1, VULPERA = 1, MAGHAR = 1, HORDEDRACTHYR = 1, HORDEEARTHEN = 1, HORDEHARANIR = 1 };
local races = {};
for i, f in ipairs(files) do table.insert(races, { index = i, name = f, file = f, enabled = true, faction = horde[f] and "Horde" or "Alliance" }); end
table.insert(races, { index = 31, name = "Murloc", file = "MURLOC", enabled = true, faction = "Horde" });
local placed = C.Layout(races);
local cells, allOk, sides = {}, true, true;
for _, r in ipairs(races) do
	local p = placed[r.index];
	if ( not p ) then allOk = false; else
		local key = p.side..p.column..":"..p.row;
		if ( cells[key] ) then allOk = false; end
		cells[key] = true;
		if ( p.side ~= r.faction ) then sides = false; end
	end
end
check("31 races placed, one per cell", allOk);
check("each on its faction's side", sides);
check("human top of the outer column", placed[1].side == "Alliance" and placed[1].column == 1 and placed[1].row == 1);
check("void elf in the allied column", placed[17].column == 2);
check("unknown race on its side", placed[31].side == "Horde");

-- counters
check("wraps forward", C.Step(9, 9, 1) == 1);
check("wraps back", C.Step(1, 9, -1) == 9);
check("several clicks", C.Step(3, 9, 8) == 2);
local t = C.Totals("HUMAN", true, false);
check("human male totals", t[1] == 10 and t[2] == 12 and t[5] == 9);
local dk = C.Totals("HUMAN", true, true);
check("death knights get more skins", dk[1] > t[1]);
local clicks = C.RandomClicks({ 10, 1, 240, nil, 5 }, function(a, b) return b; end);
check("random: the shorter way round", clicks[1] == -1 and clicks[2] == nil and clicks[3] == -1 and clicks[5] == -1);
local pos, total, ok = 1, 240, true;
for k = 0, 239 do
	local c = C.RandomClicks({ total }, function() return k; end)[1];
	if ( C.Step(1, total, c) ~= k + 1 ) then ok = false; end
end
check("random clicks land where they say", ok);

-- names
check("name ok", C.NameStatus("Thrall") == "ok");
check("name empty", C.NameStatus("") == "empty");
check("name short", C.NameStatus("A") == "short");
check("name letters", C.NameStatus("Thr4ll") == "letters" and C.NameStatus("Two Words") == "letters");
check("name accents", C.NameStatus("Jaína") == "ok");
check("name long", C.NameStatus(string.rep("a", 48)) == "long");
-- the server's rules (CheckPlayerName, MinPlayerName 2, StrictPlayerNames 0, 12 letters)
local function st(n, r) return (C.CheckName(n, r)); end
check("name: 12 letters ok, 13 too long", st("Abcdefghijkl") == "ok" and st("Abcdefghijklm") == "long" and select(2, C.CheckName("Abcdefghijklm")) == "Too long (max 12)");
check("name: utf-8 counts letters, not bytes", st("Jaínajaínaja") == "ok" and st("Жанна") == "ok");
check("name: too short", st("A") == "short" and select(2, C.CheckName("A")) == "Too short (min 2)" and st("A", { min = 3, max = 12, strict = 0 }) == "short" and st("Ab", { min = 3 }) == "short");
check("name: no spaces, digits, symbols, apostrophes", st("Two Words") == "letters" and st("Thr4ll") == "letters" and st("Mal'Ganis") == "letters" and st("Thrall-") == "letters");
check("name: one alphabet", st("Thrаll") == "mixed" and st("ЖаннаJ") == "mixed" and st("Élodie") == "ok" and st("Łukasz") == "letters");
check("name: no letter three times in a row (any case)", st("Aaab") == "three" and st("AaAb") == "three" and st("Aabb") == "ok" and st("Жжжа") == "three");
check("name: strict 1 = a-z only", st("Élodie", { strict = 1 }) == "latin" and st("Elodie", { strict = 1 }) == "ok");
check("name: as the server saves it", select(3, C.CheckName("tHRALL")) == "Thrall" and select(3, C.CheckName("éLODIE")) == "Élodie" and select(3, C.CheckName("жАННА")) == "Жанна");
check("name: case never fails", st("tHRALL") == "ok" and st("thrall") == "ok");
check("name: bad utf-8", st("Ab\255c") == "letters");
local errEnv = { CHAR_CREATE_NAME_IN_USE = "That name is unavailable", CHAR_NAME_PROFANE = "That name contains mature language" };
check("name: server answers about the name", C.NameServerError("That name is unavailable", errEnv) and C.NameServerError("That name contains mature language", errEnv)
	and not C.NameServerError("Character created", errEnv) and not C.NameServerError(nil, errEnv));
-- tooltip lines: title gold, the rest white whatever colour codes the text has
local tlines = C.TooltipLines("Dracthyr", "|cffffd100 Created by Neltharion the Earth-Warden in an experiment that combined the cleverness of the mortals with the power of the dragons.", "|cffff0000Unavailable|r");
local tok = tlines[1].text == "Dracthyr" and tlines[1].color == "gold" and #tlines >= 4 and tlines[#tlines].color == "red" and tlines[#tlines].text == "Unavailable";
for i = 2, #tlines - 1 do if ( tlines[i].color ~= "white" or string.find(tlines[i].text, "|c", 1, true) ) then tok = false; end end
check("tooltip lines: gold title, white body (codes stripped), red error", tok);
-- even light: every race the same brightness
local hm = { { 1, 0, -0.48073, 0.71827, -0.50297, 1.0, 0, 0, 0, 2.0, 0.65, 0.397645, 0.2727 }, { 1, 0, -0.49767, -0.78677, 0.36513, 1.0, 0, 0, 0, 1.0, 0.6, 0.47059, 0.32471 } };
local ne = { { 1, 0, 0, 0, -1, 1.0, 0.0902, 0.0902, 0.1702, 1.0, 0, 0, 0 } };
local be = { { 1, 0, -0.82249, -0.54912, -0.14822, 1.0, 0, 0, 0, 2.0, 0.581175, 0.50588, 0.42588 }, { 1, 0, 0, 0, -1, 1.0, 0.60392, 0.6149, 0.7, 1.0, 0, 0, 0 }, { 1, 0, 0.02575, 0.86518, -0.50081, 1.0, 0, 0, 0, 1.0, 0.59137, 0.51745, 0.63471 } };
local function near(a, b) return math.abs(a - b) < 0.03; end
local lightsOk = true;
for _, set in ipairs({ hm, ne, be, {} }) do
	local even = C.EvenLights(set);
	local a, d = C.LightTotals(even);
	if ( not near(a, C.LIGHT_AMBIENT) or not near(d, C.LIGHT_DIRECT) or #even > 4 ) then lightsOk = false; print("  lights", a, d, #even); end
end
check("even light: same ambient and direct for every scene, at most 4 lights", lightsOk);
local hmEven = C.EvenLights(hm);
check("even light: keeps the scene's warm tint and directions", hmEven[1][7] > hmEven[1][9] and hmEven[2][3] == -0.48073 and #C.EvenLights(ne) == 3);

-- select: search
local chars = {
	{ name = "Thrall", level = 80, class = "Shaman", classFile = "SHAMAN", race = "Orc", faction = "Horde", zone = "Orgrimmar (Kalimdor, Classic)" },
	{ name = "Jaina", level = 70, class = "Mage", classFile = "MAGE", race = "Human", faction = "Alliance", zone = S.ZoneText("Dalaran") },
	{ name = "Bolvar", level = 12, class = "Paladin", classFile = "PALADIN", race = "Human", faction = "Alliance", zone = "Elwynn Forest" },
};
check("zone bracket", chars[2].zone == "Dalaran (Wrath of the Lich King)");
check("one map, no bracket", S.ZoneText("Orgrimmar") == "Orgrimmar" and S.ZoneText("Elwynn Forest") == "Elwynn Forest"
	and S.ZoneText("Valley of Trials") == "Valley of Trials" and S.ZoneText("City of Dalaran") == "City of Dalaran"
	and S.ZoneText("Stormwind City") == "Stormwind City");
check("zone without bracket", S.ZoneText("Nowhere Special") == "Nowhere Special" and S.ZoneText(nil) == "");
check("search name", #S.Filter(chars, "thra") == 1);
check("search level", #S.Filter(chars, "70") == 1 and #S.Filter(chars, "60-80") == 2 and #S.Filter(chars, "13+") == 2);
check("search class and race", #S.Filter(chars, "human mage") == 1);
check("search faction", #S.Filter(chars, "alliance") == 2);
check("search zone bracket", #S.Filter(chars, "wrath") == 1);
check("search roles", #S.Filter(chars, "heal") == 2 and #S.Filter(chars, "tank") == 1 and #S.Filter(chars, "dps") == 3);
check("empty search keeps all", #S.Filter(chars, "") == 3);
check("class from colour", S.ClassFile("Chaman", "|c000070deChaman|r") == "SHAMAN" and S.ClassFile("Death Knight") == "DEATHKNIGHT");
check("faction from race name", S.Faction("Human") == "Alliance" and S.Faction("Pandaren") == nil and S.Faction("Orc", "DEATHKNIGHT") == "Horde");

-- select: order
local function names(l) local t = {}; for i, c in ipairs(l) do t[i] = c.name; end return table.concat(t, ","); end
local roster3 = { { id = 1, name = "A" }, { id = 2, name = "B" }, { id = 3, name = "C" }, { id = 4, name = "New" } };
check("order: saved first, new at the end, gone skipped", names(S.ApplyOrder(roster3, { "C", "Gone", "A", "B" })) == "C,A,B,New");
check("order: none saved keeps the client's", names(S.ApplyOrder(roster3, nil)) == "A,B,C,New");
local moved = S.ApplyOrder(roster3, {});
check("move down", S.Move(moved, 1, 3) and names(moved) == "B,C,A,New");
check("move up", S.Move(moved, 4, 1) and names(moved) == "New,B,C,A");
check("move nowhere", not S.Move(moved, 2, 2) and not S.Move(moved, 2, 9));
check("index of", S.IndexOf(moved, 3) == 3);
local utf = "Jaína\tX\nÖrk";
check("encode round trip", S.Decode(S.Encode(utf)) == utf and not string.find(S.Encode(utf), "[%x~|!]"));
-- AccountLogin.lua's own format (copied): "tc1:" and hex, read with gmatch("%x%x") over all the rest
local function tcKey(i) return (i * 7 + 13) % 256; end
local function tcHide(text) local out = {}; for i = 1, string.len(text) do out[i] = string.format("%02x", (string.byte(text, i) + tcKey(i)) % 256); end return table.concat(out); end
local function tcShow(hex) local out, i = {}, 1; for pair in string.gmatch(hex, "%x%x") do out[i] = string.char((tonumber(pair, 16) - tcKey(i)) % 256); i = i + 1; end return table.concat(out); end
local accounts = "tc1:"..tcHide("ryan\tsecret\nalt\t");
local blob = S.SetOrder(accounts, "ryan", "Temucraft", { "Jaina", "Thrall" });
check("order kept after the accounts", string.sub(blob, 1, #accounts) == accounts and S.AccountsPart(blob) == accounts);
check("AccountLogin still reads its accounts", tcShow(string.sub(blob, 5)) == "ryan\tsecret\nalt\t");
check("order read back (account in any case)", table.concat(S.GetOrder(blob, "RYAN", "Temucraft"), ",") == "Jaina,Thrall");
blob = S.SetOrder(blob, "alt", "Temucraft", { "Bolvar" });
blob = S.SetOrder(blob, "ryan", "Temucraft PTR", { "Thrall", "Jaina" });
check("per account and realm", table.concat(S.GetOrder(blob, "ryan", "Temucraft"), ",") == "Jaina,Thrall"
	and table.concat(S.GetOrder(blob, "alt", "Temucraft"), ",") == "Bolvar"
	and table.concat(S.GetOrder(blob, "ryan", "Temucraft PTR"), ",") == "Thrall,Jaina" and S.GetOrder(blob, "alt", "Temucraft PTR") == nil);
blob = S.SetOrder(blob, "ryan", "Temucraft", { "Thrall", "Jaina", "Bad\tName" });
check("order replaced, not added", table.concat(S.GetOrder(blob, "ryan", "Temucraft"), ",") == "Thrall,Jaina");
local noAccounts = S.SetOrder("", "ryan", "Temucraft", { "Jaina" });
check("no saved accounts: tagged so nothing reads it as names", string.sub(noAccounts, 1, 5) == "tc1:~" and S.AccountsPart(noAccounts) == "");
check("stock name list kept", S.AccountsPart(S.SetOrder("one|!two|", "a", "r", { "X" })) == "one|!two|");
check("join without orders", S.JoinSaved("", "") == "" and S.JoinSaved("tc1:", "") == "" and S.JoinSaved(accounts, "") == accounts);
local big = "";
for k = 1, 30 do
	local many = {};
	for i = 1, 60 do many[i] = "Character"..k.."x"..i; end
	big = S.SetOrder(big, "acc"..k, "realm", many);
end
local _, code = S.SplitSaved(big);
check("order segment capped", string.len(code) <= S.MAX_SAVED and S.GetOrder(big, "acc30", "realm") and not S.GetOrder(big, "acc1", "realm"));
check("utf8 cut", S.Utf8Sub("Jaína", 3) == "Jaí" and S.Utf8Len("Jaína") == 5);


-- select: groups (saved in the same "~" segment; the old names-only orders read as one "Characters" group)
local oldBlob = S.SetOrder(accounts, "ryan", "Temucraft", { "Jaina", "Thrall" });
local g0 = S.GetGroups(oldBlob, "ryan", "Temucraft");
check("groups: an old order is the default group", #g0 == 1 and g0[1].default and S.GroupName(g0[1]) == "Characters" and table.concat(g0[1].names, ",") == "Jaina,Thrall");
check("groups: one plain group saves as the old format", S.SetGroups(accounts, "ryan", "Temucraft", g0) == oldBlob);
check("groups: none saved", S.GetGroups(oldBlob, "alt", "Temucraft") == nil);
local gi, gerr = S.AddGroup(g0, "  Favorites  ");
check("groups: add before the default", gi == 1 and g0[1].name == "Favorites" and g0[2].default);
check("groups: no twins, no empty names", select(2, S.AddGroup(g0, "favorites")) == "exists" and select(2, S.AddGroup(g0, "   ")) == "empty"
	and select(2, S.AddGroup(g0, "characters")) == "exists");
check("groups: move into a group", S.MoveName(g0, "Thrall", 1, nil) and table.concat(g0[1].names, ",") == "Thrall" and table.concat(g0[2].names, ",") == "Jaina");
check("groups: move before a card of another group", S.MoveName(g0, "Jaina", 1, "Thrall") and table.concat(g0[1].names, ",") == "Jaina,Thrall" and #g0[2].names == 0);
check("groups: within a group like Move", S.MoveName(g0, "Jaina", 1, "Thrall") and table.concat(g0[1].names, ",") == "Thrall,Jaina");
check("groups: nowhere", not S.MoveName(g0, "Gone", 1, nil) and not S.MoveName(g0, "Thrall", 9, nil) and not S.MoveName(g0, "Jaina", 1, nil));
S.AddGroup(g0, "Alternative");
g0[1].collapsed = true;
local blob2 = S.SetGroups(accounts, "ryan", "Temucraft", g0);
local g1 = S.GetGroups(blob2, "ryan", "Temucraft");
check("groups: saved and read back", #g1 == 3 and g1[1].name == "Favorites" and g1[1].collapsed and g1[2].name == "Alternative" and not g1[2].collapsed
	and g1[3].default and table.concat(g1[1].names, ",") == "Thrall,Jaina" and #g1[2].names == 0);
check("groups: accounts untouched", S.AccountsPart(blob2) == accounts and tcShow(string.sub(blob2, 5, #accounts)) == "ryan\tsecret\nalt\t");
check("groups: GetOrder gives every name in order", table.concat(S.GetOrder(blob2, "ryan", "Temucraft"), ",") == "Thrall,Jaina");
check("groups: rename", S.RenameGroup(g1, 2, "Alts") and S.GroupName(g1[2]) == "Alts" and select(2, S.RenameGroup(g1, 2, "favorites")) == "exists"
	and select(2, S.RenameGroup(g1, 2, "")) == "empty");
check("groups: rename the default", S.RenameGroup(g1, 3, "Mains") and S.GroupName(g1[3]) == "Mains" and S.RenameGroup(g1, 3, "") and S.GroupName(g1[3]) == "Characters");
S.RenameGroup(g1, 3, "Mains");
local g2 = S.GetGroups(S.SetGroups("", "a", "r", g1), "a", "r");
check("groups: renamed default kept", g2[3].default and g2[3].name == "Mains");
check("groups: delete sends the cards to the default", S.DeleteGroup(g1, 1) and #g1 == 2 and table.concat(g1[2].names, ",") == "Thrall,Jaina" and not S.DeleteGroup(g1, 2));
-- arrange and rows
local roster5 = { { id = 1, name = "A", level = 10 }, { id = 2, name = "B", level = 20 }, { id = 3, name = "C", level = 30 }, { id = 4, name = "New", level = 1 } };
local ga = S.GroupsFromEntries({ "#=+Fav", "C", "Gone", "#*+", "B", "A" });
local ar = S.Arrange(roster5, ga);
check("arrange: groups, gone dropped, new into the default", table.concat(ar[1].names, ",") == "C" and table.concat(ar[2].names, ",") == "B,A,New"
	and roster5[3].group == 1 and roster5[4].group == 2 and roster5[3].place == 1 and roster5[4].place == 4);
check("arrange: flatten", names(S.Flatten(ar)) == "C,B,A,New");
local r1, s1 = S.Rows(ar, "");
check("rows: headers and cards", #r1 == 6 and r1[1].kind == "header" and r1[1].count == 1 and r1[3].kind == "header" and r1[4].c.name == "B" and #s1 == 4);
ar[2].collapsed = true;
local r2, s2 = S.Rows(ar, "");
check("rows: a closed group shows its header only", #r2 == 3 and #s2 == 1);
local r3, s3 = S.Rows(ar, "20");
check("rows: search opens the groups with a match and hides the others", #r3 == 2 and r3[1].group == 2 and r3[2].c.name == "B" and #s3 == 1);
check("groups: names first, then a header (default first)", (function() local g = S.GroupsFromEntries({ "A", "#=-X", "B" }); return #g == 2 and g[1].default and g[2].collapsed and g[2].names[1] == "B"; end)());
check("groups: junk entries", (function() local g = S.GroupsFromEntries({ "#?", "#=+", "A", "A" }); return #g == 1 and #g[1].names == 2 and g[1].names[1] == "#?"; end)());

-- select: delete confirmation (any case, the client's word, always DELETE, Latin letters)
check("upper: latin, cyrillic, german", S.Upper("delete") == "DELETE" and S.Upper("удалить") == "УДАЛИТЬ" and S.Upper("ёжик") == "ЁЖИК" and S.Upper("löschen") == "LÖSCHEN");
check("delete enUS", S.DeleteOk("delete", "enUS", "DELETE") and S.DeleteOk("  DeLeTe ", "enUS", nil) and not S.DeleteOk("delet", "enUS", "DELETE") and not S.DeleteOk("", "enUS", "DELETE"));
check("delete ruRU", S.DeleteOk("удалить", "ruRU", "УДАЛИТЬ") and S.DeleteOk("УдАлИтЬ", "ruRU", nil) and S.DeleteOk("udalit", "ruRU", "УДАЛИТЬ")
	and S.DeleteOk("delete", "ruRU", "УДАЛИТЬ") and not S.DeleteOk("удалит", "ruRU", "УДАЛИТЬ"));
check("delete deDE", S.DeleteOk("löschen", "deDE", nil) and S.DeleteOk("LOESCHEN", "deDE", nil) and S.DeleteOk("loschen", "deDE", nil) and S.DeleteOk("Delete", "deDE", nil));
check("delete other locales", S.DeleteOk("supprimer", "frFR") and S.DeleteOk("borrar", "esMX") and S.DeleteOk("삭제", "koKR") and S.DeleteOk("删除", "zhCN") and S.DeleteOk("刪除", "zhTW"));
check("delete instructions", S.DeleteInstructions("enUS", "DELETE", "Type \"DELETE\" into the field to confirm.") == "Type \"DELETE\" into the field to confirm."
	and string.find(S.DeleteInstructions("ruRU", "УДАЛИТЬ", "Введите \"УДАЛИТЬ\""), "(or DELETE)", 1, true)
	and string.find(S.DeleteInstructions("deDE", nil, nil), "\"LÖSCHEN\"", 1, true) and string.find(S.DeleteInstructions("deDE", nil, nil), "(or DELETE)", 1, true));

-- select: card style, money, tooltip
local on, off, hov = S.CardStyle(true), S.CardStyle(false), S.CardStyle(false, true);
check("card style: selected = gold border and glow on the same dark card", on.glow and on.border[1] == 1 and on.border[2] > 0.7 and on.bg[1] == off.bg[1] and on.bg[1] < 0.2 and on.bg[4] == off.bg[4]);
check("card style: same name colour in every state", on.name[1] == off.name[1] and on.name[2] == off.name[2] and on.name[3] == off.name[3]);
check("card style: one frame, 2 px gold when selected, 1 px grey otherwise; number a dimmer gold", on.borderSize == 2 and off.borderSize == 1 and on.glowAlpha > 0 and on.glowAlpha <= 0.3
	and on.num[1] < on.name[1] and on.num[2] < on.name[2]);
check("card style: crest in colour everywhere, dimmed only when not selected", not on.crestDesaturated and not off.crestDesaturated and on.crestAlpha == 1 and off.crestAlpha < 1 and off.crestAlpha >= 0.5 and hov.crestAlpha == 1 and not off.glow);
check("money", S.Money(162575561) == "16,257 g 55 s 61 c" and S.Money(61) == "61 c" and S.Money(5501) == "55 s 1 c" and S.Money(1234567890000) == "123,456,789 g 0 s 0 c");
check("money icons", string.find(S.Money(10000, true), "UI-GoldIcon", 1, true) ~= nil);
local druid = { name = "Malfurion", class = "Druid", classFile = "DRUID", level = 85, zone = "Moonglade" };
local tl = S.TooltipLines(druid, "Temucraft", { spec = "Restoration", professions = { "Mining", "Herbalism" }, money = 162575561 }, nil, false);
check("tooltip with the summary", tl[1] == "|cffffd100Malfurion|r" and tl[2] == "|cff9d9d9dTemucraft|r" and tl[3] == "|cffff7d0aRestoration Druid|r"
	and tl[4] == "|cffffffffLevel 85|r" and tl[5] == "|cff9d9d9dMoonglade|r" and tl[6] == "|cffffffffMining, Herbalism|r" and tl[7] == "|cffffffff16,257 g 55 s 61 c|r");
local tl2 = S.TooltipLines(druid, "Temucraft", nil, "hint");
check("tooltip without it", #tl2 == 6 and tl2[3] == "|cffff7d0aDruid|r" and string.find(tl2[6], "hint"));
check("summary lookup and mail", S.Summary({ R = { A = { mail = { "Thrall", "Jaina" } } } }, "R", "A") and S.Summary({}, "R", "A") == nil and S.Summary(nil, "R", "A") == nil
	and S.MailText({ mail = { "Thrall", "Jaina" } }) == "Unread mail from:\nThrall, Jaina" and S.MailText({ mail = true }) == "Unread mail" and S.MailText({ mail = {} }) == nil);

---------------------------------------------------------------------------------------------------------------------
-- 2. stub load
---------------------------------------------------------------------------------------------------------------------
local frames = {};
local W = {};
W.__index = function(self, k)
	local v = rawget(W, k);
	if ( v ) then return v; end
	if ( string.match(k, "^%u") ) then
		return function() end;   -- any other widget method: a no-op
	end
end
local function new(kind, name, parent)
	local f = setmetatable({ kind = kind, scripts = {}, shown = true, enabled = true, text = "", children = {}, regions = {} }, W);
	if ( parent ) then f:SetParent(parent); end
	if ( name ) then _G[name] = f; end
	table.insert(frames, f);
	return f;
end
function W:SetParent(p)
	if ( self.parent ) then
		for i, c in ipairs(self.parent.children) do if ( c == self ) then table.remove(self.parent.children, i); break; end end
	end
	self.parent = p;
	if ( p ) then table.insert(p.children, self); end
end
function W:GetParent() return self.parent; end
function W:GetChildren() return unpack(self.children); end
function W:GetRegions() return unpack(self.regions); end
function W:SetScript(k, f) self.scripts[k] = f; end
function W:GetScript(k) return self.scripts[k]; end
function W:HookScript(k, f) local o = self.scripts[k]; self.scripts[k] = function(...) if ( o ) then o(...); end f(...); end end
function W:Show() local was = self.shown; self.shown = true; if ( not was and self.scripts.OnShow ) then self.scripts.OnShow(self); end end
function W:Hide() self.shown = false; end
function W:IsShown() return self.shown; end
function W:IsVisible() local f = self; while ( f ) do if ( not f.shown ) then return false; end f = f.parent; end return true; end
function W:Enable() self.enabled = true; end
function W:Disable() self.enabled = false; end
function W:IsEnabled() return self.enabled and 1 or nil; end
function W:SetText(t) self.text = t; if ( self.scripts.OnTextChanged ) then self.scripts.OnTextChanged(self); end end
function W:GetText() return self.text; end
function W:GetFrameLevel() return 1; end
function W:GetButtonState() return "NORMAL"; end
function W:GetName() return self.name or "stub"; end
function W:GetTop() return self.top; end
function W:GetBottom() return self.bottom; end
function W:GetEffectiveScale() return 1; end
function W:SetAlpha(a) self.alpha = a; end
function W:GetStringWidth() return string.len(self.text or "") * 6; end   -- 6 px a byte
function W:SetTexCoord(...) self.texCoord = { ... }; end
function W:SetDesaturated(d) self.desaturated = d and true or false; end
function W:SetTextColor(r, g, b) self.color = { r, g, b }; end
function W:ClearAllPoints() self.points = {}; end
function W:SetPoint(...) self.points = self.points or {}; table.insert(self.points, { ... }); end
function W:SetWidth(w) self.width = w; end
function W:SetHeight(h) self.height = h; end
function W:SetFocus() self.focus = true; end
function W:CreateTexture() local r = new("Texture"); table.insert(self.regions, r); return r; end
function W:CreateFontString() local r = new("FontString"); table.insert(self.regions, r); return r; end
function W:GetNormalTexture() return new("Texture"); end
function W:GetPushedTexture() return new("Texture"); end
function W:Click() if ( self.scripts.OnClick ) then self.scripts.OnClick(self, "LeftButton"); end end
function CreateFrame(kind, name, parent) local f = new(kind, name, parent); f.name = name; return f; end

-- the client's state and functions
local state = { race = 1, sex = 2, class = 1, cycles = {}, screen = "charselect", created = nil, facing = 0, selected = 1 };
SEX_MALE, SEX_FEMALE = 2, 3;
NUM_CHAR_CUSTOMIZATIONS, MAX_RACES, MIN_CHAR_NAME_LENGTH = 5, 30, 2;
CHAR_CUSTOMIZATION1_DESC, CHAR_CUSTOMIZATION2_DESC = "Skin Color", "Face";
HAIR_NORMAL_STYLE, HAIR_NORMAL_COLOR, FACIAL_HAIR_NORMAL = "Hair Style", "Hair Color", "Facial Hair";
CHARACTER_SELECT_INFO = "Level %d %s";
CLASS_ICON_TCOORDS = { WARRIOR = { 0, 0.25, 0, 0.25 } };
function PlaySound() end
function format(...) return string.format(...); end
function GetAvailableRaces()
	local out = {};
	for i, f in ipairs(files) do table.insert(out, f); table.insert(out, f); table.insert(out, (i == 30) and 0 or 1); end
	return unpack(out);
end
function GetFactionForRace(i) local f = files[i]; return f, horde[f] and "Horde" or "Alliance"; end
function GetSelectedRace() return state.race; end
function GetNameForRace() return files[state.race], files[state.race]; end
function GetSelectedSex() return state.sex; end
local classes = { "Warrior", "WARRIOR", 1, "Paladin", "PALADIN", 1, "Hunter", "HUNTER", 1, "Rogue", "ROGUE", 1, "Priest", "PRIEST", 1,
	"Death Knight", "DEATHKNIGHT", 1, "Shaman", "SHAMAN", 1, "Mage", "MAGE", 1, "Warlock", "WARLOCK", 1, nil, nil, nil, "Druid", "DRUID", 1 };
function GetAvailableClasses() return unpack(classes, 1, 33); end
function GetSelectedClass() return classes[state.class * 3 - 2], classes[state.class * 3 - 1], state.class; end
function IsRaceClassValid(r, c) return c ~= 3 or r ~= 1; end
function CycleCharCustomization(id, d) state.cycles[id] = (state.cycles[id] or 0) + d; end
function GetRandomName() return "Randomname"; end
function GetHairCustomization() return "NORMAL"; end
function GetFacialHairCustomization() return "NORMAL"; end
function SetCharacterCreateFacing(f) state.facing = f; end
function GetCharacterCreateFacing() return state.facing; end
function GetFlavorText() return "Some lore."; end
function GetSafeRaceIconCoords() return { 0, 1, 0, 1 }; end
function CharacterRace_OnClick(self, id) if ( self:IsEnabled() ) then state.race = id; SetCharacterRace(id); end end
function CharacterClass_OnClick(self, id) if ( self:IsEnabled() ) then state.class = id; end end
function SetCharacterRace(id) SetBackgroundModel(CharacterCreate, files[id]); end
function SetCharacterGender(sex) state.sex = sex; end
local backgrounds = {};
function SetBackgroundModel(model, name) table.insert(backgrounds, (TEMUCRAFT_CHARACTER_SCENES or "?")..":"..name); end
function CharacterCreate_Forward() if ( CharacterCreateFrame.state == "CLASSRACE" ) then CharacterCreateFrame.state = "CUSTOMIZATION"; else state.created = CharacterCreateNameEdit:GetText(); end end
function CharacterCreate_Back() if ( CharacterCreateFrame.state == "CUSTOMIZATION" ) then CharacterCreateFrame.state = "CLASSRACE"; else state.screen = "charselect"; end end
function SetGlueScreen(name) state.screen = name; end
function IsConnectedToServer() return true; end
function GetServerName() return "Temucraft"; end
local roster = {
	{ "Thrall", "Orc", "Shaman", 80, "Orgrimmar" }, { "Jaina", "Human", "Mage", 80, "Dalaran" }, { "Lorewalker", "Pandaren", "Monk", 10, "The Jade Forest of the Very Long Name, Pandaria" },
};
-- the client's saved account list (Config.wtf accountList): one saved account and an order (Jaina, Thrall) for it
local savedList = S.SetOrder("tc1:"..tcHide("ryan\t"), "ryan", "Temucraft", { "Jaina", "Thrall" });
function GetSavedAccountList() return savedList; end
function SetSavedAccountList(text) savedList = text; end
function GetSavedAccountName() return ""; end
local cursorY = 0;
function GetCursorPosition() return 0, cursorY; end
function CharacterSelect_OnKeyDown(self, key) state.stockKey = key; end
function GetNumCharacters() return #roster; end
function GetCharacterInfo(i) local c = roster[i]; if ( c ) then return c[1], c[2], c[3], c[4], c[5], 2, false, false, false, false; end end
function GetSelectBackgroundModel(i) return ({ "Orc", "Human", "HordePandaren" })[i]; end
function TemucraftRaceFaction(f) f = string.upper(f); return (f == "HORDEPANDAREN" or f == "ORC") and "Horde" or (f == "HUMAN" and "Alliance") or nil; end
function CharacterSelect_SelectCharacter(id) state.selected = id; CharacterSelect.selectedIndex = id; if ( id == CharacterSelect.createIndex ) then state.screen = "charcreate"; end end
function CharacterSelect_EnterWorld() state.entered = true; end
function CharacterSelect_Delete() state.deleted = CharacterSelect.selectedIndex; end
function CharacterSelect_ChangeRealm() state.realms = true; end
function CharacterSelect_Exit() state.screen = "login"; end
function QuitGame() state.quit = true; end
function UpdateCharacterList() end
function UpdateCharacterSelection() end

-- the client's frames
CharacterCreate = CreateFrame("ModelFFX", "CharacterCreate");
CharacterCreate.shown = false;
CharacterCreateFrame = CreateFrame("Frame", "CharacterCreateFrame", CharacterCreate);
CharacterCreateFrame.state = "CLASSRACE";
CharacterCreateNameEdit = CreateFrame("EditBox", "CharacterCreateNameEdit", CharacterCreateFrame);
CharCreateRaceFrame = CreateFrame("Frame", "CharCreateRaceFrame", CharacterCreateFrame);
CharCreateOkayButton = CreateFrame("Button", "CharCreateOkayButton", CharacterCreateFrame);
CharacterCreateTooltip = CreateFrame("Frame", "CharacterCreateTooltip");
CharacterSelect = CreateFrame("ModelFFX", "CharacterSelect");
CharacterSelect.shown = false;
CharacterSelect.selectedIndex, CharacterSelect.createIndex = 1, 4;
CharacterSelectUI = CreateFrame("Frame", "CharacterSelectUI", CharacterSelect);
CharacterSelectCharacterFrame = CreateFrame("Frame", "CharacterSelectCharacterFrame", CharacterSelectUI);
CharSelectEnterWorldButton = CreateFrame("Button", "CharSelectEnterWorldButton", CharacterSelectUI);
CharacterSelectBackButton = CreateFrame("Button", "CharacterSelectBackButton", CharacterSelectUI);
AccountLoginAccountEdit = CreateFrame("EditBox", "AccountLoginAccountEdit");
AccountLoginAccountEdit.text = "Ryan";

function CharacterCreate_OnKeyDown(key) state.createKey = key; if ( key == "ESCAPE" ) then CharacterCreate_Back(); end end
CHAR_CREATE_NAME_IN_USE = "That name is unavailable";
function GlueDialog_Show(which, text) state.dialog = text; end
LIGHT_LIVE = 0;
backgroundLights = 0;
function TemucraftApplyLights(model)
	model:AddCharacterLight(0, 1, 0, -0.48073, 0.71827, -0.50297, 1.0, 0, 0, 0, 2.0, 0.65, 0.397645, 0.2727);
	model:AddCharacterLight(0, 1, 0, -0.49767, -0.78677, 0.36513, 1.0, 0, 0, 0, 1.0, 0.6, 0.47059, 0.32471);
	model:AddLight(0, 1, 0, 0, 0, -1, 1.0, 0.2, 0.2, 0.2, 0, 0, 0, 0);
	backgroundLights = backgroundLights + 1;
end

-- load both files on the stub client
local ok1, err1 = pcall(dofile, glue.."TemucraftCharCreate.lua");
check("create loads on the stub client", ok1 or print(err1));
local ok2, err2 = pcall(dofile, glue.."TemucraftCharSelect.lua");
check("select loads on the stub client", ok2 or print(err2));

-- character create
local ok3, err3 = pcall(function() CharacterCreate:Show(); end);
check("create shows", ok3 or print(err3));
check("stock frames hidden, ours shown", not CharCreateRaceFrame:IsVisible() and TemucraftCharCreateFrame:IsVisible() and CharacterCreateNameEdit:GetParent() == TemucraftCharCreateFrame.nameBar);
check("30 race buttons", TemucraftCreateRace30 and TemucraftCreateRace30:IsShown() and not TemucraftCreateRace31);
check("disabled race greyed", TemucraftCreateRace30.enabled == false);
check("faction scene on create", (function() SetCharacterRace(2); return backgrounds[#backgrounds] == "faction:ORC"; end)());
TEMUCRAFT_SCENE_PICKS = { ORC = "Orc" };
TEMUCRAFT_CREATE_SCENES = "race";
SetCharacterRace(2);
check("TEMUCRAFT_CREATE_SCENES race keeps the race scene", backgrounds[#backgrounds] == "?:ORC");
TEMUCRAFT_CREATE_SCENES = nil;
TemucraftCreateRace2:Click();
check("race click selects", state.race == 2);
TemucraftCreateClass3:Click();
check("class click", state.class == 3);
state.race = 1; TemucraftCharCreate_Refresh();
check("invalid class greyed", TemucraftCreateClass3.enabled == false);
TemucraftCreatefemale:Click();
check("gender", state.sex == SEX_FEMALE);
TemucraftCreateNext:Click();
check("to customize", CharacterCreateFrame.state == "CUSTOMIZATION" and TemucraftCreateOption1:IsShown());
state.class = 1; TemucraftCharCreate_Refresh();
check("counter text: name left, count right", TemucraftCreateOption2.label.text == "Face" and TemucraftCreateOption2.count.text == "1 / 15");
TemucraftCreateOption2Left:Click();
check("counter wraps back", TemucraftCreateOption2.count.text == "15 / 15" and state.cycles[2] == -1);
CHAR_CUSTOMIZATION1_DESC = "Couleur de peau tres longue a lire";
TemucraftCharCreate_Refresh();
check("long option name cut before the count", string.sub(TemucraftCreateOption1.label.text, -3) == "..." and string.len(TemucraftCreateOption1.label.text) * 6 + 6 + string.len(TemucraftCreateOption1.count.text) * 6 <= 170 - 16
	and TemucraftCreateOption1.count.text ~= "");
CHAR_CUSTOMIZATION1_DESC = "Skin Color";
TemucraftCharCreate_Refresh();
state.cycles = {};
TemucraftCreateRandomize:Click();
local tot = C.Totals("HUMAN", false, false);
local good = true;
for id = 1, 5 do
	local shownPos = tonumber(string.match(_G["TemucraftCreateOption"..id].count.text, "(%d+) / "));
	local start = (id == 2) and 15 or 1;   -- face was clicked back to 15 above
	if ( shownPos ~= C.Step(start, tot[id], state.cycles[id] or 0) ) then good = false; end
end
check("randomize keeps the counters right", good);
TemucraftCreateNameDice:Click();
check("random name", CharacterCreateNameEdit:GetText() == "Randomname");
check("name check: green with the saved name", TemucraftCreateNameCheck:IsShown() and TemucraftCreateNameCheck.ok and TemucraftCreateNameCheck.title == "Randomname");
CharacterCreateNameEdit:SetText("Aaa");
check("name check: red with the reason", TemucraftCreateNameCheck:IsShown() and not TemucraftCreateNameCheck.ok and TemucraftCreateNameCheck.text == "No letter three times in a row");
CharacterCreateNameEdit:SetText("");
check("name check: empty box, no mark", not TemucraftCreateNameCheck:IsShown());
CharacterCreateNameEdit:SetText("Thrall");
GlueDialog_Show("OKAY", CHAR_CREATE_NAME_IN_USE);
check("name check: the server's answer turns it red", not TemucraftCreateNameCheck.ok and TemucraftCreateNameCheck.text == CHAR_CREATE_NAME_IN_USE and state.dialog == CHAR_CREATE_NAME_IN_USE);
CharacterCreateNameEdit:SetText("Thrallo");
check("name check: a new name clears it", TemucraftCreateNameCheck.ok);
check("name box centred, dice left, check right", TemucraftCreateNameBar.points[1][1] == "BOTTOM" and TemucraftCreateNameBar.points[1][4] == 0
	and TemucraftCreateNameDice.points[1][1] == "RIGHT" and TemucraftCreateNameDice.points[1][3] == "LEFT" and TemucraftCreateNameCheck.points[1][1] == "LEFT" and TemucraftCreateNameCheck.points[1][3] == "RIGHT");
-- tooltips one after the other: each laid out from scratch, one anchor
local function tipOk(owner, title)
	local t = TemucraftCharCreate_Tooltip();
	return t and t.shown and #t.points == 1 and t.points[1][2] == owner and t.lines[1].text == title and t.lines[1].color[1] == 1 and t.lines[1].color[3] == 0;
end
TemucraftCreateBack:Click();
TemucraftCreateRace2.scripts.OnEnter(TemucraftCreateRace2);
local raceTip = tipOk(TemucraftCreateRace2, "ORC");
TemucraftCreateClass1.scripts.OnEnter(TemucraftCreateClass1);
local classTip = tipOk(TemucraftCreateClass1, "Warrior");
TemucraftCreatemale.scripts.OnEnter(TemucraftCreatemale);
local maleTip = tipOk(TemucraftCreatemale, "Male") and TemucraftCharCreate_Tooltip().height < 40 and TemucraftCharCreate_Tooltip().width < 120;
TemucraftCreateNameDice.scripts.OnEnter(TemucraftCreateNameDice);
local diceTip = tipOk(TemucraftCreateNameDice, "Random name");
TemucraftCreateNameCheck.scripts.OnEnter(TemucraftCreateNameCheck);
local checkTip = tipOk(TemucraftCreateNameCheck, "Thrallo");
TemucraftCreateNameCheck.scripts.OnLeave(TemucraftCreateNameCheck);
check("tooltips: race, class, gender, dice, name check each fresh", raceTip and classTip and maleTip and diceTip and checkTip and not TemucraftCharCreate_Tooltip().shown);
-- every race: title gold, the faction, its racials (icon, name + category tag, a short white line each) and the grey
-- Shift hint; with Shift held the detailed view ("Racial - ..." lines, the descriptions), the lore in white (its own
-- colour codes don't leak) and "Release Shift ..."; both fit on a 768 high screen (columns when needed)
local oldFlavor = GetFlavorText;
GetFlavorText = function(key) return "|cffffd100 Lore of "..key.." that is long enough to need a second line in the tooltip box.|r"; end
TemucraftCharCreate_Refresh();
local racesOk, loreOk, fitOk, tagsOk, faceOk = true, true, true, true, true;
local function shownLines(t) local out = {}; for i = 1, #t.lines do if ( t.lines[i].shown ) then table.insert(out, t.lines[i]); end end return out; end
local function find(l, text) for i = 1, #l do if ( string.find(l[i].text, text, 1, true) ) then return i; end end end
local maxH = TemucraftCharCreate_TipMaxHeight();
for n = 1, 30 do
	local b = _G["TemucraftCreateRace"..n];
	IsShiftKeyDown = function() return nil; end
	b.scripts.OnEnter(b);
	local t = TemucraftCharCreate_Tooltip();
	local l = shownLines(t);
	local icons, tags = 0, 0;
	for _, ic in ipairs(t.icons or {}) do if ( ic.shown ) then icons = icons + 1; end end
	for _, tg in ipairs(t.tags or {}) do if ( tg.shown ) then tags = tags + 1; end end
	if ( l[1].color[3] ~= 0 or l[#l].text ~= C.DETAIL_HINT or icons < 2 or find(l, "Lore of") ) then racesOk = false; print("  race", n, l[1].text, l[#l].text, icons); end
	if ( tags ~= icons ) then tagsOk = false; print("  tags", n, tags, icons); end
	for i = 2, #l do if ( string.find(l[i].text, "|c", 1, true) or string.find(l[i].text, "...", 1, true) ) then racesOk = false; print("  text", n, l[i].text); end end
	if ( t.height > maxH ) then fitOk = false; print("  short too tall", n, t.height); end
	IsShiftKeyDown = function() return 1; end
	b.scripts.OnUpdate(b);
	t = TemucraftCharCreate_Tooltip();
	l = shownLines(t);
	local lore = find(l, "Lore of RACE_INFO_");
	if ( l[#l].text ~= C.SHORT_HINT or not lore or l[lore].color[3] ~= 1 or not find(l, "Racial - ") ) then loreOk = false; print("  detail", n, l[#l].text, lore); end
	if ( t.height > maxH + 14 ) then fitOk = false; print("  detail too tall", n, t.height, t.columns); end
	b.scripts.OnLeave(b);
	-- portraits look toward the middle: Alliance column right, Horde column left
	local facing = C.PortraitFacing(files[n], b.gender or "MALE");
	local final = b.mirrored and ((facing == "left") and "right" or "left") or facing;
	if ( final ~= (horde[files[n]] and "left" or "right") ) then faceOk = false; print("  facing", n, files[n], facing, b.mirrored); end
end
IsShiftKeyDown = function() return nil; end
GetFlavorText = oldFlavor;
check("race tooltips: gold name, faction, racials with icons, Shift hint, no ... (all races)", racesOk);
check("race tooltips: every racial has its category tag", tagsOk);
check("race tooltips: Shift shows the detailed view, then the lore and the short-view hint", loreOk);
check("race tooltips: both views fit a 768 high screen", fitOk);
check("race portraits: Alliance face right, Horde face left", faceOk);
TemucraftCreateNext:Click();
TemucraftCreateNext:Click();
check("finish creates", state.created == "Thrallo");
-- arrow keys turn, Alt-Z hides
state.facing = 0;
CharacterCreate_OnKeyDown("LEFT");
TemucraftCharCreateFrame.keysFrame = nil;
for _, f in ipairs(frames) do if ( f.parent == CharacterCreate and f.scripts.OnUpdate and not f.name ) then f.scripts.OnUpdate(f, 0.02); end end
local turned = state.facing < 0;
CharacterCreate.scripts.OnKeyUp(CharacterCreate, "LEFT");
local f0 = state.facing;
for _, f in ipairs(frames) do if ( f.parent == CharacterCreate and f.scripts.OnUpdate and not f.name ) then f.scripts.OnUpdate(f, 0.02); end end
check("arrow keys turn the character while held", turned and state.facing == f0);
function IsAltKeyDown() return true; end
CharacterCreate_OnKeyDown("Z");
check("Alt-Z hides the create screen", TemucraftCharCreate_IsHidden() and not TemucraftCharCreateFrame:IsShown() and TemucraftCreateEye:IsShown() and TemucraftCreateShowUI:IsShown());
function IsAltKeyDown() return false; end
local screenBefore = state.screen;
CharacterCreate_OnKeyDown("ESCAPE");
check("Escape brings it back (not Back)", not TemucraftCharCreate_IsHidden() and TemucraftCharCreateFrame:IsShown() and state.screen == screenBefore);
IsAltKeyDown = nil;   -- as in the real glue screens
CharacterCreate_OnKeyDown("LALT");
CharacterCreate_OnKeyDown("Z");
local altZ = TemucraftCharCreate_IsHidden();
CharacterCreate.scripts.OnKeyUp(CharacterCreate, "LALT");
CharacterCreate_OnKeyDown("ESCAPE");
CharacterCreate_OnKeyDown("Z");
check("Alt-Z without IsAltKeyDown: Alt tracked from its own key", altZ and not TemucraftCharCreate_IsHidden());
TemucraftCreateEye:Click();
TemucraftCreateShowUI:Click();
check("eye hides, a click shows", not TemucraftCharCreate_IsHidden() and TemucraftCharCreateFrame:IsShown());
-- even light through GlueParent's TemucraftApplyLights
local added = {};
local lmt = { __index = { AddCharacterLight = function(self, set, ...) table.insert(added, { set, ... }); end, AddLight = function() end } };
local model = setmetatable({}, lmt);
TemucraftApplyLights(model);
local la, ld = 0, 0;
local caughtLights = {};
for _, a in ipairs(added) do table.insert(caughtLights, { select(2, unpack(a)) }); end
la, ld = C.LightTotals(caughtLights);
check("even light applied to the character set", #added >= 2 and near(la, C.LIGHT_AMBIENT) and near(ld, C.LIGHT_DIRECT) and rawget(model, "AddCharacterLight") == nil and backgroundLights == 1);

-- character select
local ok4, err4 = pcall(function() CharacterSelect:Show(); end);
check("select shows", ok4 or print(err4));
check("stock list hidden", not CharacterSelectCharacterFrame:IsVisible() and TemucraftCharSelectFrame:IsVisible());
check("cards", TemucraftSelectCard1:IsShown() and TemucraftSelectCard3:IsShown() and not TemucraftSelectCard4:IsShown());
-- card names (the "1." place is its own small text in front)
local function cardName(n) return _G["TemucraftSelectCard"..n].name.text or ""; end
local function cardNames() local t = {}; for n = 1, 3 do t[n] = cardName(n); end return table.concat(t, ","); end
check("cards show their place first", TemucraftSelectCard1.num.text == "1." and TemucraftSelectCard3.num.text == "3." and TemucraftSelectCard1.name.text == "Jaina");
check("cards in the saved order, new ones after", cardNames() == "Jaina,Thrall,Lorewalker");
check("cards keep the client's index", TemucraftSelectCard1.id == 2 and TemucraftSelectCard2.id == 1 and TemucraftSelectCard3.id == 3);
check("card zone bracket", TemucraftSelectCard1.zone.text == "Dalaran (Wrath of the Lich King)" and TemucraftSelectCard2.zone.text == "Orgrimmar");
local z = TemucraftSelectCard3.zone.text;
check("long zone cut to one line", string.sub(z, -3) == "..." and string.len(z) * 6 <= 212 and string.find(z, "^The Jade Forest"));
check("card crest", TemucraftSelectCard3.crest.shown);
check("AccountLogin sees only its accounts", GetSavedAccountList() == "tc1:"..tcHide("ryan\t"));
TemucraftSelectSearch:SetText("horde");
check("search filters cards", TemucraftSelectCard2:IsShown() and not TemucraftSelectCard3:IsShown() and cardName(1) == "Thrall");
TemucraftSelectSearch:SetText("");
TemucraftSelectCard1:Click();
check("card selects by the client's index", state.selected == 2);
check("no order arrows (drag instead)", not TemucraftSelectCard1Up:IsShown() and not TemucraftSelectCard2Up:IsShown());
TemucraftSelectCard1.scripts.OnDoubleClick(TemucraftSelectCard1);
check("double click enters", state.entered and state.selected == 2);
state.entered = nil;
TemucraftSelectCard3:Click();
TemucraftSelectCard3Up:Click();
check("arrow up moves the selected card", cardNames() == "Jaina,Lorewalker,Thrall" and state.selected == 3 and CharacterSelect.selectedIndex == 3);
check("order saved for the account and realm", table.concat(S.GetOrder(savedList, "ryan", "Temucraft"), ",") == "Jaina,Lorewalker,Thrall");
TemucraftSelectCard2Down:Click();
check("arrow down", cardNames() == "Jaina,Thrall,Lorewalker");
-- AccountLogin.lua saving its accounts (tcSave) keeps the order
SetSavedAccountList("tc1:"..tcHide("ryan\tpw"));
check("saving accounts keeps the order", GetSavedAccountList() == "tc1:"..tcHide("ryan\tpw") and table.concat(S.GetOrder(savedList, "ryan", "Temucraft"), ",") == "Jaina,Thrall,Lorewalker");
SetSavedAccountList("");
check("forgetting every account keeps the order", GetSavedAccountList() == "" and S.GetOrder(savedList, "ryan", "Temucraft"));
-- drag Lorewalker (card 3) onto Jaina (card 1)
for n = 1, 8 do local b = _G["TemucraftSelectCard"..n]; b.top = 700 - (n - 1) * 68; b.bottom = b.top - 64; end
state.selected = 1; CharacterSelect.selectedIndex = 1;
TemucraftSelectCard3.scripts.OnMouseDown(TemucraftSelectCard3);
TemucraftSelectCard3.scripts.OnDragStart(TemucraftSelectCard3);
check("dragged card fades, arrows hide", TemucraftSelectCard3.alpha < 1 and not TemucraftSelectCard2Up:IsShown());
cursorY = 680;
TemucraftSelectCard3.scripts.OnDragStop(TemucraftSelectCard3);
TemucraftSelectCard1:Click();   -- the mouse-up that ends the drag
check("drag moves the card", cardNames() == "Lorewalker,Jaina,Thrall");
check("ending a drag does not select or enter", state.selected == 1 and not state.entered and TemucraftSelectCard1.alpha == 1);
TemucraftSelectCard3.scripts.OnMouseDown(TemucraftSelectCard3);
TemucraftSelectCard3:Click();
check("a click after a drag selects again", state.selected == 1 and TemucraftSelectCard3.id == 1);
cursorY = 700 - 58 - 20;   -- drop on Jaina (card 2) from card 3 (Thrall)
TemucraftSelectCard3.scripts.OnDragStart(TemucraftSelectCard3);
TemucraftSelectCard3.scripts.OnDragStop(TemucraftSelectCard3);
check("drag up one", cardNames() == "Lorewalker,Thrall,Jaina");
cursorY = 10;   -- below every card: the last place
TemucraftSelectCard1.scripts.OnDragStart(TemucraftSelectCard1);
TemucraftSelectCard1.scripts.OnDragStop(TemucraftSelectCard1);
check("drag below the cards: last", cardNames() == "Thrall,Jaina,Lorewalker");
-- arrow keys follow the cards
CharacterSelect.selectedIndex = 2; state.selected = 2;   -- Jaina, card 2
CharacterSelect_OnKeyDown(CharacterSelect, "DOWN");
check("key down: next card", state.selected == 3);
CharacterSelect_OnKeyDown(CharacterSelect, "DOWN");
check("key down wraps", state.selected == 1);
CharacterSelect_OnKeyDown(CharacterSelect, "ENTER");
check("other keys: the client's", state.stockKey == "ENTER");
-- a deleted character drops out, a new one goes last
table.remove(roster, 2); table.insert(roster, { "Newbie", "Orc", "Warrior", 1, "Durotar" });
GetSelectBackgroundModel = function(i) return ({ "Orc", "HordePandaren", "Orc" })[i]; end
UpdateCharacterList();
check("deleted drop out, new at the end", cardNames() == "Thrall,Lorewalker,Newbie" and TemucraftSelectCard3.id == 3 and TemucraftSelectCard2.id == 2);
TemucraftSelectEye:Click();
check("eye hides the interface", not TemucraftCharSelectFrame:IsVisible() and not CharSelectEnterWorldButton:IsVisible() and TemucraftSelectEye:IsShown());
TemucraftSelectEye:Click();
check("eye shows it again", TemucraftCharSelectFrame:IsVisible() and CharSelectEnterWorldButton:IsVisible());
TemucraftSelectMenu3:Click();
check("credits from select", state.screen == "credits");
SetGlueScreen("login");
check("credits come back to select", state.screen == "charselect");
TemucraftSelectRealms:Click();
check("realms", state.realms);
check("Back in the top bar, the stock one put away", TemucraftSelectBackButton:IsVisible() and TemucraftSelectBackButton.parent == TemucraftCharSelectFrame.top
	and TemucraftSelectBackButton.points[1][1] == "LEFT" and not CharacterSelectBackButton:IsVisible());
check("Menu at the top bar's right", TemucraftSelectMenuButton.points[1][1] == "RIGHT");
TemucraftSelectBackButton:Click();
check("Back goes back to the login screen", state.screen == "login");
state.screen = "charselect";
function IsAltKeyDown() return true; end
CharacterSelect_OnKeyDown(CharacterSelect, "Z");
local eyeHidden = not TemucraftCharSelectFrame:IsVisible();
function IsAltKeyDown() return false; end
CharacterSelect_OnKeyDown(CharacterSelect, "ESCAPE");
check("Alt-Z hides select, Escape shows it (no exit)", eyeHidden and TemucraftCharSelectFrame:IsVisible() and state.screen == "charselect");
IsAltKeyDown = nil;
CharacterSelect_OnKeyDown(CharacterSelect, "LALT");
CharacterSelect_OnKeyDown(CharacterSelect, "Z");
local selAltZ = not TemucraftCharSelectFrame:IsVisible();
CharacterSelect.scripts.OnKeyUp(CharacterSelect, "LALT");
CharacterSelect_OnKeyDown(CharacterSelect, "ESCAPE");
CharacterSelect_OnKeyDown(CharacterSelect, "Z");
check("select Alt-Z without IsAltKeyDown", selAltZ and TemucraftCharSelectFrame:IsVisible() and state.screen == "charselect");
TemucraftSelectCreate:Click();
check("create", state.screen == "charcreate");

-- the new pieces: highlight, delete dialog, groups, summary
CharacterSelect.selectedIndex, state.selected = 1, 1;   -- Thrall
TemucraftSelectSearch:SetText("");
TemucraftCharSelect_Refresh();
local function cardByName(name) for n = 1, 8 do local b = _G["TemucraftSelectCard"..n]; if ( b:IsShown() and b.char and b.char.name == name ) then return b; end end end
local thrallCard, loreCard = cardByName("Thrall"), cardByName("Lorewalker");
check("selected card: gold border and glow; others: crest in colour, dimmed", thrallCard.isSelected and thrallCard.glow[1].shown and thrallCard.frame[1].height == 2
	and thrallCard.crest.desaturated == false and not loreCard.isSelected and not loreCard.glow[1].shown and loreCard.frame[1].height == 1
	and loreCard.crest.desaturated == false and loreCard.crest.alpha < 1);
loreCard.scripts.OnEnter(loreCard);
local hoverCrest = loreCard.crest.alpha;
loreCard.scripts.OnLeave(loreCard);
check("hover: crest at full strength", hoverCrest == 1 and loreCard.crest.alpha < 1);
check("default group header", TemucraftSelectHeader1:IsShown() and TemucraftSelectHeader1.text.text == "Characters" and TemucraftSelectHeader1.count.text == "(3)");
check("plus, delete and restore buttons", TemucraftSelectPlus and TemucraftSelectDelete.enabled and TemucraftSelectRestore and TemucraftSelectRestore:IsShown());
-- delete
local deleted;
function DeleteCharacter(id) deleted = id; end
state.deleted = nil;
TemucraftSelectDelete:Click();
check("delete opens our dialog", TemucraftDeleteDialog:IsShown() and not state.deleted and not TemucraftDeleteOkay.enabled);
check("delete dialog names the character", string.find(TemucraftDeleteDialog.text.text, "Thrall Level 80 |cff0070deShaman|r", 1, true) ~= nil
	and TemucraftDeleteDialog.hint.text == "Type \"DELETE\" into the field to confirm.");
TemucraftDeleteEdit:SetText("delet");
check("okay off until the word is typed", not TemucraftDeleteOkay.enabled);
TemucraftDeleteEdit:SetText("Delete");
check("okay on for DELETE in any case", TemucraftDeleteOkay.enabled);
CharacterSelect_OnKeyDown(CharacterSelect, "ESCAPE");
check("escape closes the dialog, nothing else", not TemucraftDeleteDialog:IsShown() and state.stockKey ~= "ESCAPE" and deleted == nil);
TemucraftSelectDelete:Click();
check("dialog opens empty", TemucraftDeleteEdit:GetText() == "" and not TemucraftDeleteOkay.enabled);
TemucraftDeleteEdit:SetText("DELETE");
TemucraftDeleteOkay:Click();
check("okay deletes the selected character", deleted == 1 and not TemucraftDeleteDialog:IsShown());
deleted = nil;
GetLocale = function() return "ruRU"; end
DELETE_CONFIRM_STRING = "УДАЛИТЬ";
CONFIRM_CHAR_DELETE_INSTRUCTIONS = "Введите \"УДАЛИТЬ\" в поле для подтверждения.";
TemucraftSelectDelete:Click();
check("ruRU: the word and (or DELETE)", string.find(TemucraftDeleteDialog.hint.text, "(or DELETE)", 1, true) and string.find(TemucraftDeleteDialog.hint.text, "УДАЛИТЬ", 1, true));
TemucraftDeleteEdit:SetText("удалить");
local ru1 = TemucraftDeleteOkay.enabled;
TemucraftDeleteEdit:SetText("udalit");
local ru2 = TemucraftDeleteOkay.enabled;
TemucraftDeleteEdit:SetText("delete");
check("ruRU: Cyrillic in any case, Latin, English", ru1 and ru2 and TemucraftDeleteOkay.enabled);
TemucraftDeleteCancel:Click();
check("cancel keeps the character", deleted == nil and not TemucraftDeleteDialog:IsShown());
GetLocale, DELETE_CONFIRM_STRING, CONFIRM_CHAR_DELETE_INSTRUCTIONS = nil, nil, nil;
-- groups: right-click Lorewalker > Move to group > New group... "Favorites"
loreCard.scripts.OnMouseDown(loreCard, "RightButton");
loreCard.scripts.OnClick(loreCard, "RightButton");
check("right-click opens the card menu", TemucraftSelectPopup1Item1:IsShown() and TemucraftSelectPopup1Item1.text.text == "Move to group");
TemucraftSelectPopup1Item1:Click();
check("move to group: the groups and New group", TemucraftSelectPopup2Item1:IsShown() and string.find(TemucraftSelectPopup2Item1.text.text, "New group", 1, true));
TemucraftSelectPopup2Item1:Click();
check("new group dialog", TemucraftGroupDialog:IsShown() and not TemucraftSelectPopupBlocker:IsShown());
TemucraftGroupEdit:SetText("characters");
TemucraftGroupOkay:Click();
check("taken name refused", TemucraftGroupDialog:IsShown() and string.find(TemucraftGroupDialog.error.text, "already", 1, true));
TemucraftGroupEdit:SetText("Favorites");
TemucraftGroupOkay:Click();
local saved = S.GetGroups(savedList, "ryan", "Temucraft");
check("group made, card moved, saved", not TemucraftGroupDialog:IsShown() and saved[1].name == "Favorites" and table.concat(saved[1].names, ",") == "Lorewalker"
	and table.concat(saved[2].names, ",") == "Thrall,Newbie");
check("headers on screen", TemucraftSelectHeader1.text.text == "Favorites" and TemucraftSelectHeader2.text.text == "Characters" and cardNames() == "Lorewalker,Thrall,Newbie"
	and TemucraftSelectCard1.num.text == "1.");
TemucraftSelectHeader1:Click();
saved = S.GetGroups(savedList, "ryan", "Temucraft");
check("header click closes the group (saved)", saved[1].collapsed and cardName(1) == "Thrall" and not TemucraftSelectCard3:IsShown());
TemucraftSelectHeader1:Click();
check("and opens it", cardNames() == "Lorewalker,Thrall,Newbie");
-- drag Newbie (card 3) onto the Favorites header: Header1, Card1, Header2, Card2, Card3
local y0 = 700;
for _, f in ipairs({ TemucraftSelectHeader1, TemucraftSelectCard1, TemucraftSelectHeader2, TemucraftSelectCard2, TemucraftSelectCard3 }) do
	local h = (f == TemucraftSelectHeader1 or f == TemucraftSelectHeader2) and 24 or 64;
	f.top, f.bottom = y0, y0 - h; y0 = y0 - h - 4;
end
cursorY = 690;
TemucraftSelectCard3.scripts.OnDragStart(TemucraftSelectCard3);
TemucraftSelectCard3.scripts.OnDragStop(TemucraftSelectCard3);
saved = S.GetGroups(savedList, "ryan", "Temucraft");
check("drag onto a header: into that group, last", table.concat(saved[1].names, ",") == "Lorewalker,Newbie" and table.concat(saved[2].names, ",") == "Thrall");
-- rename and delete from the header's menu
TemucraftSelectHeader1.scripts.OnClick(TemucraftSelectHeader1, "RightButton");
check("header menu", TemucraftSelectPopup1Item1.text.text == "Rename" and TemucraftSelectPopup1Item2.text.text == "Delete");
TemucraftSelectPopup1Item1:Click();
check("rename dialog has the name", TemucraftGroupDialog:IsShown() and TemucraftGroupEdit:GetText() == "Favorites");
TemucraftGroupEdit:SetText("Mains");
TemucraftGroupOkay:Click();
check("renamed", TemucraftSelectHeader1.text.text == "Mains" and S.GetGroups(savedList, "ryan", "Temucraft")[1].name == "Mains");
TemucraftSelectHeader2.scripts.OnClick(TemucraftSelectHeader2, "RightButton");
check("the default group can't be deleted", TemucraftSelectPopup1Item1.text.text == "Rename" and not string.find(TemucraftSelectPopup1Item2.text.text or "", "Delete"));
CharacterSelect_OnKeyDown(CharacterSelect, "ESCAPE");
check("escape closes the popup", not TemucraftSelectPopupBlocker:IsShown() and state.stockKey ~= "ESCAPE");
TemucraftSelectHeader1.scripts.OnClick(TemucraftSelectHeader1, "RightButton");
TemucraftSelectPopup1Item2:Click();
saved = S.GetGroups(savedList, "ryan", "Temucraft");
check("deleted group: its cards back to Characters", #saved == 1 and table.concat(saved[1].names, ",") == "Thrall,Lorewalker,Newbie"
	and TemucraftSelectHeader1.text.text == "Characters" and not TemucraftSelectHeader2:IsShown());
check("one plain group saved in the old format again", not string.find(S.Decode(select(2, S.SplitSaved(savedList))), "#", 1, true));
-- the launcher's summary: mail badge and tooltip
TEMUCRAFT_CHAR_SUMMARY = { Temucraft = { Thrall = { spec = "Enhancement", professions = { "Mining" }, money = 1234567, mail = { "Jaina" } } } };
TemucraftCharSelect_Refresh(true);
thrallCard, loreCard = cardByName("Thrall"), cardByName("Lorewalker");
check("mail badge", thrallCard.mail:IsShown() and thrallCard.mailText == "Unread mail from:\nJaina" and not loreCard.mail:IsShown());
thrallCard.scripts.OnEnter(thrallCard);
local found = false;
for _, f in ipairs(frames) do if ( f.kind == "FontString" and f.shown and f.text == "|cff0070deEnhancement Shaman|r" ) then found = true; end end
check("card tooltip with spec and class", found);
TEMUCRAFT_CHAR_SUMMARY = nil;

-- 2026-11-25 evening: long AreaTable brackets cut, title colours, tooltip wrapping
check("zone: AreaTable bracket dropped", S.ZoneText("Valley of Trials (Durotar, Classic)") == "Valley of Trials");
check("zone: short label kept for real duplicates", S.ZoneText("Dalaran (Northrend, Wrath)") == "Dalaran (Wrath of the Lich King)");
check("title: faction and class colours", C.Title("Highmountain Tauren", "Horde", "Paladin", "PALADIN") == "|cffe8352aHighmountain Tauren|r  -  |cfff58cbaPaladin|r");
local wrapped = C.Wrap(string.rep("word ", 40), 30);
local longest = 0;
for line in string.gmatch(wrapped.."\n", "(.-)\n") do longest = math.max(longest, string.len(line)); end
check("tooltip text wrapped", longest <= 30 and string.find(wrapped, "\n"));

check("wrong realm: PTR client on Live", S.WrongRealm(30, "1 - Lorewalker Cho") and not S.WrongRealm(30, "[PTR] Falric") and not S.WrongRealm(20, "1 - Lorewalker Cho") and not S.WrongRealm(30, ""));
-- 2026-11-26 PTR test of e254cc7 -----------------------------------------------------------------------------------
-- reserved / profane names (synthetic lists: the real ones come from the client's DBCs)
local fake = { reserved = "zorblax\nquuxel", profane = "blarg", patterns = { { "profane", "^snorf" }, { "reserved", "wib.*le$" }, { "profane", "glim[ao]" } } };
check("filter: whole names", C.NameFilter("Zorblax", fake) == "reserved" and C.NameFilter("QUUXEL", fake) == "reserved" and C.NameFilter("Blarg", fake) == "profane");
check("filter: start, wildcard, set", C.NameFilter("Snorfy", fake) == "profane" and C.NameFilter("Wibbadle", fake) == "reserved" and C.NameFilter("Oglimo", fake) == "profane");
check("filter: others pass", C.NameFilter("Thrallo", fake) == nil and C.NameFilter("Asnorf", fake) == nil and C.NameFilter("Wibblex", fake) == nil);
check("filter: names ending in GM are reserved (server rule)", C.NameFilter("Bobgm", fake) == "reserved" and C.NameFilter("Bobgm") == "reserved");
check("filter: lower-cases Cyrillic and accents", C.NameFilter("ЖЖук", { reserved = "жжук", profane = "" }) == "reserved" and C.NameFilter("Élan", { reserved = "élan" }) == "reserved");
local oldFilters = TEMUCRAFT_NAME_FILTERS;
TEMUCRAFT_NAME_FILTERS = fake;
local fs, freason, fsaved = C.CheckName("zorblax");
check("name check: reserved, the word not echoed", fs == "reserved" and freason == "This name is reserved" and not string.find(freason, "orblax") and fsaved == "Zorblax");
check("name check: profane", select(2, C.CheckName("Snorfo")) == "This name isn't allowed" and C.CheckName("Thrallo") == "ok");
TEMUCRAFT_NAME_FILTERS = oldFilters;
-- the generated filter file loads and reads (no word printed)
dofile(glue.."TemucraftNameFilters.lua");
local nPat, badPat = 0, 0;
for _, p in ipairs(TEMUCRAFT_NAME_FILTERS.patterns) do nPat = nPat + 1; if ( not pcall(string.find, "abc", p[2]) ) then badPat = badPat + 1; end end
check("name filters: lists and valid patterns", string.len(TEMUCRAFT_NAME_FILTERS.reserved) > 1000 and string.len(TEMUCRAFT_NAME_FILTERS.profane) > 1000 and nPat > 100 and badPat == 0);
check("name filters: ordinary names pass", C.NameFilter("Kestrel") == nil and C.NameFilter("Marten") == nil and C.NameFilter("Elodie") == nil and C.NameFilter("Brynn") == nil);
TEMUCRAFT_NAME_FILTERS = nil;
-- racials: every playable race has at least two, each with an icon, a name and resolved text
local racialsOk = true;
for _, f in ipairs(files) do
	local r = TEMUCRAFT_RACIALS[f];
	if ( not r or #r < 2 ) then racialsOk = false; print("  racials", f, r and #r); end
	for _, e in ipairs(r or {}) do
		if ( not e.icon or e.icon == "" or not e.name or e.name == "" or not e.text or e.text == "" or string.find(e.text, "$", 1, true) ) then racialsOk = false; print("  racial", f, e.name, e.text); end
	end
end
check("racials: every race has 2 or more, no unresolved $ tokens", racialsOk);
local hardiness = { name = "Hardiness", icon = "Interface\\Icons\\X", cat = "Combat (Defense)", text = "Stuns 20% shorter.",
	detail = "Duration of Stun effects reduced by 20%.", meta = "Passive" };
local lines = C.RaceTooltipLines("Orc", "Horde", { hardiness }, "Lore.", false);
check("race tooltip lines: name, faction, racial with its category, short line, hint", lines[1].text == "Orc" and lines[1].color == "gold" and lines[2].color == "faction" and lines[2].faction == "Horde"
	and lines[3].text == "Hardiness" and lines[3].icon and lines[3].tag == "Combat (Defense)" and lines[4].text == "Stuns 20% shorter." and lines[4].indent
	and lines[5].text == C.DETAIL_HINT and lines[5].color == "grey" and #lines == 5);
lines = C.RaceTooltipLines("Orc", "Horde", { hardiness }, "Lore.", true);
check("race tooltip lines detailed: category, meta, description, lore, hint", lines[3].text == "Hardiness" and not lines[3].tag
	and lines[4].text == "Racial - Combat (Defense)" and lines[5].text == "Passive" and lines[6].text == "Duration of Stun effects reduced by 20%."
	and lines[7].text == "Lore." and lines[7].color == "white" and lines[7].gap and lines[8].text == C.SHORT_HINT);
check("portraits: mirrored only when looking away from the middle", not C.PortraitMirrored("Alliance", "right") and C.PortraitMirrored("Horde", "right")
	and C.PortraitMirrored("Alliance", "left") and not C.PortraitMirrored("Horde", "left") and C.PortraitMirrored("Horde", nil));
local mc = C.MirrorCoords({ 0.1, 0.2, 0.3, 0.4 }, true);
check("portraits: mirroring swaps the u coords", mc[1] == 0.2 and mc[2] == 0.1 and mc[3] == 0.3 and mc[4] == 0.4 and C.MirrorCoords({ 0, 1, 0, 1 }, false)[1] == 0);
check("portraits: atlas icons count as facing right", C.PortraitFacing("ORC", "MALE", true) == "right");
-- portraits
check("portraits: ours by default", C.Portrait("HUMAN", "FEMALE", false, { 0, 0.1, 0, 0.1 }, true) == "Interface\\Glues\\CharacterCreate\\TemucraftRace_HUMAN_FEMALE");
check("portraits: classic = the old atlas where there is one", C.Portrait("HUMAN", "MALE", true, { 0, 0.1, 0, 0.1 }, true) == "Interface\\Glues\\CharacterCreate\\RyansRacesRound"
	and C.Portrait("HORDEHARANIR", "MALE", true, nil, true) == "Interface\\Glues\\CharacterCreate\\TemucraftRace_HORDEHARANIR_MALE");
local nPortraits = 0;
for _ in pairs(TEMUCRAFT_RACE_PORTRAIT_FILES) do nPortraits = nPortraits + 1; end
check("portraits for all 30 races", nPortraits == 30 and TEMUCRAFT_RACE_PORTRAIT_FILES.HORDEDRACTHYR and TEMUCRAFT_RACE_PORTRAIT_FILES.ALLIANCEPANDAREN);
-- the Classic switch is kept in the saved account list, next to the accounts and the orders
local raw = S.JoinSaved("tc1:abcd", "");
raw = S.SetSetting(raw, "racePortraits", "classic");
check("setting saved and read", S.GetSetting(raw, "racePortraits") == "classic" and S.AccountsPart(raw) == "tc1:abcd");
raw = S.SetOrder(raw, "ACC", "Realm", { "Thrall" });
check("setting kept when orders change", S.GetSetting(raw, "racePortraits") == "classic" and S.GetOrder(raw, "ACC", "Realm")[1] == "Thrall");
raw = S.SetSetting(raw, "racePortraits", nil);
check("setting cleared", S.GetSetting(raw, "racePortraits") == nil and S.GetOrder(raw, "ACC", "Realm")[1] == "Thrall");
-- the card number on every card, the name box's own text kept
check("card number always", S.CardNumber({ place = 1 }) == "1." and S.CardNumber({ id = 3 }) == "3." and S.CardNumber(nil) == "");
local lbl = { GetObjectType = function() return "FontString"; end, GetText = function() return "NAME"; end };
local txt = { GetObjectType = function() return "FontString"; end, GetText = function() return "Ryan"; end };
check("name box: only the NAME label is hidden", C.IsNameLabel(lbl, "NAME") and not C.IsNameLabel(txt, "NAME"));

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
