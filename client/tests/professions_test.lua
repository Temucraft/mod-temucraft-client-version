-- Stub tests for the Professions window logic (no client): lua5.1 client/tests/professions_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftProfessions.lua");
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftDragonUI.lua");
local L, D = TemucraftProfessionsLogic, TemucraftDragonUILogic;
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

-- professions
check("skill id by English name", L.SkillId("Alchemy") == 171 and L.SkillId("Mining") == 186 and L.SkillId("First Aid") == 129);
check("skill id by the client's name", L.SkillId("Alchimie", { Alchimie = 171 }) == 171 and L.SkillId("Smelting", { Smelting = 186 }) == 186);
check("unknown skill", L.SkillId("Lockpicking") == nil and L.SkillId(nil) == nil);
check("gathering", L.IsGathering(182) and L.IsGathering(186) and L.IsGathering(356) and not L.IsGathering(171) and not L.IsGathering(1));
check("herbalism, skinning, fishing open no window; mining opens smelting",
	L.PROFESSIONS[182][2] == nil and L.PROFESSIONS[393][2] == nil and L.PROFESSIONS[356][2] == nil and L.PROFESSIONS[186][2] == 2656);
local inOrder = {};
for _, id in ipairs(L.ORDER) do inOrder[id] = true; end
local all = true;
for id in pairs(L.PROFESSIONS) do if ( not inOrder[id] ) then all = false; end end
check("every profession has a place", all and #L.ORDER == 14);

-- the server's stats (TPG "SS")
local st = L.ParseStats("186:5:3:10:0:0;171:0:0:0:12:-1;");
check("stats parsed", st[186][1] == 5 and st[186][3] == 10 and st[171][4] == 12 and st[171][5] == -1);
check("stats: nothing", next(L.ParseStats("")) == nil and next(L.ParseStats(nil)) == nil);
local g = L.Stats(186, st[186]);
check("gathering shows finesse, perception, deftness", #g == 3 and g[1][1] == "Finesse" and g[1][2] == 5 and g[3][1] == "Deftness" and g[3][2] == 10);
local c = L.Stats(171, st[171]);
check("crafting shows multicraft, resourcefulness", #c == 2 and c[1][1] == "Multicraft" and c[1][2] == 12 and c[2][1] == "Resourcefulness");
check("no stats from the server", #L.Stats(171, nil) == 0);

-- favourites
local favs = L.ParseFavs("2337,3170, 7183");
check("favourites parsed", favs[2337] and favs[3170] and favs[7183] and not favs[1]);
favs[3170] = nil; favs[100] = true;
check("favourites saved sorted", L.FavText(favs) == "100,2337,7183");
check("favourites empty", L.FavText({}) == "" and next(L.ParseFavs(nil)) == nil);
check("spell from recipe link", L.SpellFromLink("|cffffd000|Henchant:2337|h[Lesser Healing Potion]|h|r") == 2337 and L.SpellFromLink(nil) == nil);

-- the list
local entries = {
	{ index = 1, name = "Potion", kind = "header" },
	{ index = 2, name = "Minor Healing Potion", kind = "trivial", available = 4, spell = 2330 },
	{ index = 3, name = "Lesser Healing Potion", kind = "optimal", available = 0, spell = 2337, reagents = "briarthorn\nminor healing potion" },
	{ index = 4, name = "Elixir", kind = "header" },
	{ index = 5, name = "Elixir of Minor Defense", kind = "easy", available = 2, spell = 7183 },
	{ index = 6, name = "Flask", kind = "header" },
};
local function names(lines)
	local out = {};
	for _, l in ipairs(lines) do table.insert(out, (l.kind == "header" and "#" or "")..(l.kind == "header" and l.name or l.entry.name)); end
	return table.concat(out, ",");
end
check("everything, empty categories left out", names(L.Lines(entries, {})) == "#Potion,Minor Healing Potion,Lesser Healing Potion,#Elixir,Elixir of Minor Defense");
check("have materials", names(L.Lines(entries, { haveMats = true })) == "#Potion,Minor Healing Potion,#Elixir,Elixir of Minor Defense");
check("skill up: no grey", names(L.Lines(entries, { skillUp = true })) == "#Potion,Lesser Healing Potion,#Elixir,Elixir of Minor Defense");
check("search by name, any case", names(L.Lines(entries, { search = "ELIXIR" })) == "#Elixir,Elixir of Minor Defense");
check("search by reagent", names(L.Lines(entries, { search = "briar" })) == "#Potion,Lesser Healing Potion");
check("search finds nothing", #L.Lines(entries, { search = "zzz" }) == 0);
local col = L.Lines(entries, { collapsed = { Potion = true } });
check("collapsed category: header only, with its count", names(col) == "#Potion,#Elixir,Elixir of Minor Defense" and col[1].collapsed and col[1].count == 2);
local fav = L.Lines(entries, { favs = { [7183] = true } });
check("favorites first, and still in their category", names(fav) == "#Favorites,Elixir of Minor Defense,#Potion,Minor Healing Potion,Lesser Healing Potion,#Elixir,Elixir of Minor Defense"
	and fav[1].favorites and fav[2].fav and not fav[4].fav);
check("favorites follow the filters", names(L.Lines(entries, { favs = { [2337] = true }, haveMats = true })) == "#Potion,Minor Healing Potion,#Elixir,Elixir of Minor Defense");
check("favorites collapse", names(L.Lines(entries, { favs = { [7183] = true }, collapsed = { ["*favorites"] = true } })) == "#Favorites,#Potion,Minor Healing Potion,Lesser Healing Potion,#Elixir,Elixir of Minor Defense");
check("recipes before any header", names(L.Lines({ { index = 1, name = "Smelt Copper", kind = "easy", available = 1 } }, {})) == "Smelt Copper");
local lines = L.Lines(entries, { haveMats = true });
check("first recipe", L.FirstRecipe(lines).index == 2 and L.FirstRecipe({}) == nil);
check("selection on the list", L.HasIndex(lines, 5) and not L.HasIndex(lines, 3) and not L.HasIndex(lines, 1) and not L.HasIndex(lines, nil));

-- the recipe
local missing = L.Missing("Blacksmith Hammer", 1, "Anvil", nil, "Forge", false);
check("only what you lack is shown", #missing == 2 and missing[1] == "Anvil" and missing[2] == "Forge");
check("nothing lacking", #L.Missing() == 0 and #L.Missing("Blacksmith Hammer", 1) == 0);
check("made", L.Made(1, 1) == "" and L.Made(2, 2) == "2" and L.Made(2, 4) == "2-4" and L.Made(nil, nil) == "");
check("quantity steps and limits", L.Quantity(1, -1) == 1 and L.Quantity(1, 1) == 2 and L.Quantity("5", 0) == 5 and L.Quantity(999, 1) == 999
	and L.Quantity(nil, 0) == 1 and L.Quantity(3, 5, 4) == 4 and L.Quantity(0, 0) == 1);
check("skill text", L.SkillText(175, 225) == "175 / 225" and L.SkillText(300, 300, 15) == "300 / 300 (+15)");

-- DragonUI's Professions module wins
check("DragonUI's professions module takes ours", D.Resolve(true, function(m) return m == "professions"; end).tradeskill == true);
check("its note", D.Note("tradeskill", { tradeskill = true }) == "DragonUI's Professions");
check("without it ours stays", D.Resolve(true, function(m) return m == "spellbook"; end).tradeskill == nil);

print(failed == 0 and "all passed" or (failed.." failed"));
os.exit(failed == 0 and 0 or 1);
