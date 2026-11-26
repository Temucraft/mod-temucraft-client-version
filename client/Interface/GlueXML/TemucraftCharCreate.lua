--[[
	Temucraft character creation, the retail way (Ryan's call: that and nothing more).

	Step 1 (race and class): Alliance races in two columns on the left, Horde on the right, the classes in a row along
	the bottom (the ones the race can't be greyed out), male / female at the top. Step 2 (Customize): the name at the
	top with a random name dice and a check mark, the appearance options with arrows and "Face 3 / 9" counters,
	Randomize Appearance, rotate left / right. Back / Next / Finish at the bottom corners.

	It sits on top of the client's own character create (CharacterCreate.lua / .xml from patch-A, patch-~ and the
	locale patch-<locale>-C): that code still runs and still does the work (SetCharacterRace, SetCharacterGender,
	CharacterCreate_Forward ...), its frames are only moved into a hidden holder. So it works with the 30-race
	CharacterCreate.lua (patch-~-races-30) and with the older 20-race one alike.

	3.3.5 can't tell Lua which appearance choice is shown, only cycle them (CycleCharCustomization). The counters count
	the clicks and wrap around at the totals in TemucraftGlueData.lua (generated from the DBCs). The client rolls a
	random look the first time a race and sex is shown: that look is "1". Randomize Appearance clicks a random number of
	times per option, so the counters stay right.

	Settings (Interface\TemucraftScenes.lua, written by the launcher; defaults below):
	  TEMUCRAFT_LOGIN_UI = "classic"        the character screens as they were before (this file does nothing)
	  TEMUCRAFT_CREATE_SCENES = "race"      character create shows each race's own scene instead of its faction's
	  TEMUCRAFT_SCENE_PICKS[race or class]  the player's own scene for that race (or class) wins, as on select
--]]

TemucraftCreateLogic = {};
local Logic = TemucraftCreateLogic;

-- Column of each race: 1 = the faction's original races (outer column), 2 = the allied races (inner column)
Logic.COLUMNS = {
	{ "HUMAN", "DWARF", "NIGHTELF", "GNOME", "DRAENEI", "WORGEN", "ALLIANCEPANDAREN", "ALLIANCEDRACTHYR" },
	{ "VOIDELF", "LIGHTFORGEDDRAENEI", "DARKIRONDWARF", "KULTIRAN", "MECHAGNOME", "ALLIANCEEARTHEN", "ALLIANCEHARANIR" },
	{ "ORC", "SCOURGE", "TAUREN", "TROLL", "BLOODELF", "GOBLIN", "HORDEPANDAREN", "HORDEDRACTHYR" },
	{ "NIGHTBORNE", "HIGHMOUNTAINTAUREN", "MAGHAR", "ZANDALARITROLL", "VULPERA", "HORDEEARTHEN", "HORDEHARANIR" },
};
Logic.MAX_ROWS = 8;

-- races: { { index, name, file, enabled, faction }, ... } -> { [index] = { side = "Alliance"|"Horde", column = 1|2, row } }
function Logic.Layout(races)
	local slot, placed, rows = {}, {}, { {}, {}, {}, {} };
	for col, list in ipairs(Logic.COLUMNS) do
		for row, file in ipairs(list) do
			slot[file] = { col, row };
		end
	end
	local function put(race, col, row)
		rows[col][row] = race.index;
		placed[race.index] = { side = (col <= 2) and "Alliance" or "Horde", column = (col - 1) % 2 + 1, row = row };
	end
	local rest = {};
	for _, race in ipairs(races) do
		local s = slot[string.upper(race.file or "")];
		local col = s and s[1];
		-- a race in the other faction's list (or unknown) goes to its own faction's allied column
		if ( col and race.faction and ((col <= 2) ~= (race.faction == "Alliance")) ) then
			col = nil;
		end
		if ( col and not rows[col][s[2]] ) then
			put(race, col, s[2]);
		else
			table.insert(rest, race);
		end
	end
	for _, race in ipairs(rest) do
		local cols = (race.faction == "Horde") and { 4, 3 } or { 2, 1, 4, 3 };
		local done = false;
		for _, col in ipairs(cols) do
			for row = 1, Logic.MAX_ROWS do
				if ( not done and not rows[col][row] ) then
					put(race, col, row);
					done = true;
				end
			end
		end
	end
	return placed;
end

-- How many choices each option cycles through: { skin, face, hair style, hair colour, facial } (nil = unknown)
function Logic.Totals(file, male, deathKnight, hd)
	local key = string.upper(file or "").."_"..(male and "MALE" or "FEMALE");
	local row = (hd and TEMUCRAFT_CUSTOMIZE_COUNTS_HD and TEMUCRAFT_CUSTOMIZE_COUNTS_HD[key])
		or (TEMUCRAFT_CUSTOMIZE_COUNTS and TEMUCRAFT_CUSTOMIZE_COUNTS[key]);
	if ( not row ) then
		return {};
	end
	if ( deathKnight ) then
		return { row[6] or row[1], row[7] or row[2], row[3], row[8] or row[4], row[5] };
	end
	return { row[1], row[2], row[3], row[4], row[5] };
end

-- One step of a counter that wraps around: Step(9, 9, 1) = 1
function Logic.Step(pos, total, delta)
	if ( not total or total < 1 ) then
		return pos;
	end
	return ((pos or 1) - 1 + delta) % total + 1;
end

-- Randomize as counted clicks: { [option] = clicks (negative = left) }, the shorter way round
function Logic.RandomClicks(totals, random)
	local clicks = {};
	for id = 1, 5 do
		local total = totals[id];
		if ( total and total > 1 ) then
			local k = random(0, total - 1);
			if ( k > total / 2 ) then
				k = k - total;
			end
			clicks[id] = k;
		end
	end
	return clicks;
end

-- The name check: the server's own rules (AzerothCore ObjectMgr::CheckPlayerName, worldserver.conf MinPlayerName = 2,
-- StrictPlayerNames = 0, MAX_PLAYER_NAME = 12), checked while typing. 3.3.5 has no "is this name free" request and the
-- glue screen no addon channel, so taken / reserved / profane names are only known after Finish (the server's answer
-- turns the mark red, see NameServerError). TEMUCRAFT_NAME_RULES = { min =, max =, strict = } overrides the defaults.
-- StrictPlayerNames 0: every letter Latin (with the Latin-1 and Latin Extended-A accents), or every letter Cyrillic, or
-- every letter East Asian; 1 (bit 1): basic Latin a-z only. The realm-language bit (2) is treated as 0.
Logic.NAME_RULES = { min = 2, max = 12, strict = 0 };
Logic.NAME_REASONS = {
	empty = "Enter a name", short = "Too short (min %d)", long = "Too long (max %d)",
	letters = "Only letters (no spaces, digits or symbols)", mixed = "Only one alphabet (don't mix Latin and Cyrillic)",
	three = "No letter three times in a row", latin = "Only the letters a-z",
};

-- UTF-8 -> code points, or nil when the text isn't valid UTF-8
function Logic.Utf8Codes(text)
	local out, i, n = {}, 1, string.len(text or "");
	while ( i <= n ) do
		local b = string.byte(text, i);
		local len, cp = 1, b;
		if ( b >= 240 and b <= 244 ) then len, cp = 4, b - 240;
		elseif ( b >= 224 ) then len, cp = 3, b - 224;
		elseif ( b >= 192 ) then len, cp = 2, b - 192;
		elseif ( b >= 128 ) then return nil; end
		if ( i + len - 1 > n ) then return nil; end
		for k = 1, len - 1 do
			local c = string.byte(text, i + k);
			if ( c < 128 or c > 191 ) then return nil; end
			cp = cp * 64 + (c - 128);
		end
		table.insert(out, cp);
		i = i + len;
	end
	return out;
end

local function BasicLatin(c) return (c >= 65 and c <= 90) or (c >= 97 and c <= 122); end
local function ExtendedLatin(c)
	return BasicLatin(c) or (c >= 0xC0 and c <= 0xD6) or (c >= 0xD8 and c <= 0xDE) or c == 0xDF or (c >= 0xE0 and c <= 0xF6)
		or (c >= 0xF8 and c <= 0xFE) or (c >= 0x100 and c <= 0x12F) or c == 0x1E9E;
end
local function Cyrillic(c) return (c >= 0x410 and c <= 0x44F) or c == 0x401 or c == 0x451; end
local function EastAsian(c)
	return (c >= 0x1100 and c <= 0x11F9) or (c >= 0x3041 and c <= 0x30FF) or (c >= 0x3131 and c <= 0x318E)
		or (c >= 0x31F0 and c <= 0x31FF) or (c >= 0x3400 and c <= 0x4DB5) or (c >= 0x4E00 and c <= 0x9FC3)
		or (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0xFF01 and c <= 0xFFEE);
end
local function AllOf(codes, test)
	for _, c in ipairs(codes) do if ( not test(c) ) then return false; end end
	return true;
end
local function Lower(c)
	if ( (c >= 65 and c <= 90) or (c >= 0xC0 and c <= 0xDE and c ~= 0xD7) or (c >= 0x410 and c <= 0x42F) ) then return c + 32; end
	if ( c == 0x401 ) then return 0x451; end
	if ( c >= 0x100 and c <= 0x12F and c % 2 == 0 ) then return c + 1; end
	return c;
end
local function Upper(c)
	if ( (c >= 97 and c <= 122) or (c >= 0xE0 and c <= 0xFE and c ~= 0xF7) or (c >= 0x430 and c <= 0x44F) ) then return c - 32; end
	if ( c == 0x451 ) then return 0x401; end
	if ( c >= 0x100 and c <= 0x12F and c % 2 == 1 ) then return c - 1; end
	return c;
end
local function Utf8Char(c)
	if ( c < 128 ) then return string.char(c); end
	if ( c < 2048 ) then return string.char(192 + math.floor(c / 64), 128 + c % 64); end
	if ( c < 65536 ) then return string.char(224 + math.floor(c / 4096), 128 + math.floor(c / 64) % 64, 128 + c % 64); end
	return string.char(240 + math.floor(c / 262144), 128 + math.floor(c / 4096) % 64, 128 + math.floor(c / 64) % 64, 128 + c % 64);
end

-- "tHRALL" -> "Thrall": the name as the server saves it (normalizePlayerName: first letter upper, the rest lower)
function Logic.SavedName(text)
	local codes = Logic.Utf8Codes(text);
	if ( not codes ) then return text; end
	local out = {};
	for i, c in ipairs(codes) do out[i] = Utf8Char((i == 1) and Upper(c) or Lower(c)); end
	return table.concat(out);
end

-- status ("ok", "empty", "short", "long", "letters", "mixed", "three", "latin", "reserved", "profane"), the reason to
-- show (nil when ok), the name as it will be saved
function Logic.CheckName(text, rules)
	rules = rules or TEMUCRAFT_NAME_RULES or Logic.NAME_RULES;
	local min, max, strict = rules.min or 2, rules.max or 12, rules.strict or 0;
	text = text or "";
	if ( text == "" ) then return "empty", nil, ""; end
	local codes = Logic.Utf8Codes(text);
	if ( not codes ) then return "letters", Logic.NAME_REASONS.letters, text; end
	local function fail(status, n) return status, string.format(Logic.NAME_REASONS[status], n or 0), Logic.SavedName(text); end
	if ( #codes > max ) then return fail("long", max); end
	if ( #codes < min ) then return fail("short", min); end
	local function letter(c) return ExtendedLatin(c) or Cyrillic(c) or EastAsian(c); end
	if ( not AllOf(codes, letter) ) then return fail("letters"); end
	if ( strict % 2 == 1 and strict < 2 ) then
		if ( not AllOf(codes, BasicLatin) ) then return fail("latin"); end
	elseif ( not (AllOf(codes, ExtendedLatin) or AllOf(codes, Cyrillic) or AllOf(codes, EastAsian)) ) then
		return fail("mixed");
	end
	for i = 3, #codes do
		local a, b, c = Lower(codes[i - 2]), Lower(codes[i - 1]), Lower(codes[i]);
		if ( a == b and b == c ) then return fail("three"); end
	end
	local filtered = Logic.NameFilter(text);
	if ( filtered ) then return filtered, Logic.FILTER_REASONS[filtered], Logic.SavedName(text); end
	return "ok", nil, Logic.SavedName(text);
end

-- Reserved and profane names: the client's own NamesReserved.dbc / NamesProfanity.dbc (every locale), made into
-- TEMUCRAFT_NAME_FILTERS (TemucraftNameFilters.lua) by gen_name_filters.py. Whole-name rows are what the server refuses
-- too (ObjectMgr::IsReservedName / IsProfanityName compare whole names, StrictNames.Reserved / .Profanity = 1), plus
-- every name ending in "gm"; the other rows (part of a name, wildcards) as Lua patterns on the lower-case name. The
-- server's reserved_name / profanity_name tables aren't known here: those still come back after Finish.
Logic.FILTER_REASONS = { reserved = "This name is reserved", profane = "This name isn't allowed" };
local filterSets, filterSource;
local function FilterSets(data)
	if ( filterSource ~= data ) then
		filterSource, filterSets = data, { reserved = {}, profane = {} };
		for _, kind in ipairs({ "reserved", "profane" }) do
			for word in string.gmatch(data[kind] or "", "[^\n]+") do filterSets[kind][word] = true; end
		end
	end
	return filterSets;
end
-- "reserved", "profane" or nil (the name itself is never shown)
function Logic.NameFilter(text, data)
	data = data or TEMUCRAFT_NAME_FILTERS;
	local codes = Logic.Utf8Codes(text or "");
	if ( not codes or #codes == 0 ) then return nil; end
	local low = {};
	for i, c in ipairs(codes) do low[i] = Utf8Char(Lower(c)); end
	local name = table.concat(low);
	if ( string.sub(name, -2) == "gm" ) then return "reserved"; end
	if ( type(data) ~= "table" ) then return nil; end
	local sets = FilterSets(data);
	if ( sets.reserved[name] ) then return "reserved"; end
	if ( sets.profane[name] ) then return "profane"; end
	for _, p in ipairs(data.patterns or {}) do
		local ok, hit = pcall(string.find, name, p[2]);
		if ( ok and hit ) then return p[1]; end
	end
	return nil;
end

-- The stock "NAME" label of the name box (to hide it), not the box's own text: a FontString in the faction font or
-- with the NAME text
function Logic.IsNameLabel(region, nameText, labelFont)
	if ( not region or not region.GetObjectType or region:GetObjectType() ~= "FontString" ) then return false; end
	if ( labelFont and region.GetFontObject and region:GetFontObject() == labelFont ) then return true; end
	local t = region.GetText and region:GetText();
	return t ~= nil and (t == (nameText or "NAME") or t == "NAME");
end

-- the old name of it ("ok", "empty", "short", "long", "letters" ...)
function Logic.NameStatus(text)
	return (Logic.CheckName(text));
end

-- The server's answers to Finish that are about the name (the client's own strings): the name mark turns red with it
Logic.NAME_ERROR_STRINGS = {
	"CHAR_CREATE_NAME_IN_USE", "CHAR_CREATE_INVALID_NAME", "CHAR_NAME_RESERVED", "CHAR_NAME_PROFANE", "CHAR_NAME_FAILURE",
	"CHAR_NAME_INVALID_CHARACTER", "CHAR_NAME_MIXED_LANGUAGES", "CHAR_NAME_THREE_CONSECUTIVE", "CHAR_NAME_TOO_LONG",
	"CHAR_NAME_TOO_SHORT", "CHAR_NAME_NO_NAME", "CHAR_NAME_INVALID_APOSTROPHE", "CHAR_NAME_MULTIPLE_APOSTROPHES",
	"CHAR_NAME_INVALID_SPACE", "CHAR_NAME_RUSSIAN_CONSECUTIVE_SILENT_CHARACTERS",
	"CHAR_NAME_RUSSIAN_SILENT_CHARACTER_AT_BEGINNING_OR_END", "CHAR_NAME_DECLENSION_DOESNT_MATCH_BASE_NAME",
};
function Logic.NameServerError(text, env)
	env = env or _G;
	if ( type(text) ~= "string" or text == "" ) then return nil; end
	for _, key in ipairs(Logic.NAME_ERROR_STRINGS) do
		local s = env[key];
		if ( type(s) == "string" and s ~= "" and s == text ) then return text; end
	end
	return nil;
end

-- Tooltip lines: the title in gold, every other line white (their own colour codes taken out, so no colour leaks from
-- the title or from the text), an error in red. { { text =, color = "gold"|"white"|"red" }, ... }
function Logic.StripColors(text)
	return (string.gsub(string.gsub(text or "", "|c%x%x%x%x%x%x%x%x", ""), "|r", ""));
end
function Logic.TooltipLines(title, body, err, width)
	local out = {};
	local function add(text, color)
		for line in string.gmatch(Logic.Wrap(Logic.StripColors(text), width or 52).."\n", "(.-)\n") do
			line = string.match(line, "^%s*(.-)%s*$");
			if ( line ~= "" ) then table.insert(out, { text = line, color = color }); end
		end
	end
	if ( title and title ~= "" ) then table.insert(out, { text = Logic.StripColors(title), color = "gold" }); end
	if ( body and body ~= "" ) then add(body, "white"); end
	if ( err and err ~= "" ) then add(err, "red"); end
	return out;
end

-- Even light for the character (create and select): the scenes' lights were made for their own race, so a race on
-- another race's (or the faction's) scene could stand almost unlit (Highmountain Tauren on the Horde scene: no ambient
-- at all). The character's light set keeps the scene's directions and colours (warm on the Horde scenes, cool on the
-- Alliance ones) but every race gets the same brightness: ambient and direct light scaled to the same totals, and a
-- key and fill light from the front-left / back-right when the scene has none. Only the character set changes; the
-- background keeps the scene's own lights. Light: { enabled, omni, dirX, dirY, dirZ, ambI, ambR, ambG, ambB, dirI, dirR, dirG, dirB }.
Logic.LIGHT_AMBIENT, Logic.LIGHT_DIRECT = 0.42, 1.35;
local function Lum(r, g, b) return 0.3 * (r or 0) + 0.59 * (g or 0) + 0.11 * (b or 0); end
local function Tint(r, g, b, target)
	local l = Lum(r, g, b);
	if ( l <= 0.001 ) then return target, target, target; end
	local k = target / l;
	return math.min(1, r * k), math.min(1, g * k), math.min(1, b * k);
end
function Logic.LightTotals(lights)
	local amb, dir = 0, 0;
	for _, l in ipairs(lights or {}) do
		if ( l[1] == 1 ) then
			amb = amb + (l[6] or 0) * Lum(l[7], l[8], l[9]);
			dir = dir + (l[10] or 0) * Lum(l[11], l[12], l[13]);
		end
	end
	return amb, dir;
end
function Logic.EvenLights(lights, ambientTarget, directTarget)
	ambientTarget, directTarget = ambientTarget or Logic.LIGHT_AMBIENT, directTarget or Logic.LIGHT_DIRECT;
	local amb, dir = Logic.LightTotals(lights);
	-- the scene's tint: its ambient colour, else its direct colour, else neutral
	local tr, tg, tb, tw, dr, dg, db, dw = 0, 0, 0, 0, 0, 0, 0, 0;
	local directs = {};
	for _, l in ipairs(lights or {}) do
		if ( l[1] == 1 ) then
			local a = (l[6] or 0) * Lum(l[7], l[8], l[9]);
			if ( a > 0 ) then tr, tg, tb, tw = tr + l[7] * a, tg + l[8] * a, tb + l[9] * a, tw + a; end
			local d = (l[10] or 0) * Lum(l[11], l[12], l[13]);
			if ( d > 0 ) then
				dr, dg, db, dw = dr + l[11] * d, dg + l[12] * d, db + l[13] * d, dw + d;
				table.insert(directs, { l = l, d = d });
			end
		end
	end
	local ar, ag, ab = 1, 1, 1;
	if ( tw > 0 ) then ar, ag, ab = tr / tw, tg / tw, tb / tw; elseif ( dw > 0 ) then ar, ag, ab = dr / dw, dg / dw, db / dw; end
	ar, ag, ab = Tint(ar, ag, ab, ambientTarget);
	local out = { { 1, 0, 0, 0, -1, 1.0, ar, ag, ab, 0.0, 0, 0, 0 } };
	table.sort(directs, function(x, y) return x.d > y.d; end);
	if ( #directs > 0 ) then
		local k = directTarget / dir;
		for i = 1, math.min(3, #directs) do
			local l = directs[i].l;
			-- the colour scaled first (up to white), the rest in the intensity
			local want = directs[i].d * k;
			local r, g, b = Tint(l[11], l[12], l[13], math.min(0.9, want));
			local intensity = want / math.max(0.001, Lum(r, g, b));
			table.insert(out, { 1, l[2] or 0, l[3], l[4], l[5], 1.0, 0, 0, 0, intensity, r, g, b });
		end
	else
		local cr, cg, cb = dr, dg, db;
		if ( dw > 0 ) then cr, cg, cb = dr / dw, dg / dw, db / dw; else cr, cg, cb = ar, ag, ab; end
		local kr, kg, kb = Tint(cr, cg, cb, 0.45);
		table.insert(out, { 1, 0, -0.64623469, 0.57582057, -0.50081086, 1.0, 0, 0, 0, directTarget * 0.7 / 0.45, kr, kg, kb });
		table.insert(out, { 1, 0, -0.45756075, -0.58900136, -0.66611975, 1.0, 0, 0, 0, directTarget * 0.3 / 0.45, kr, kg, kb });
	end
	return out;
end

-- Breaks long text into lines of about `width` characters (the glue tooltip doesn't wrap: one long line would run
-- across the whole screen). Keeps |n breaks and colour codes.
function Logic.Wrap(text, width)
	width = width or 52;
	local out = {};
	local src = string.gsub(text or "", "|n", "\n");
	for para in string.gmatch(src.."\n", "(.-)\n") do
		local line, len = "", 0;
		for word in string.gmatch(para, "%S+") do
			local visible = string.len((string.gsub(string.gsub(word, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")));
			if ( len > 0 and len + 1 + visible > width ) then
				table.insert(out, line);
				line, len = word, visible;
			else
				line = (len > 0) and (line.." "..word) or word;
				len = len + ((len > 0) and 1 or 0) + visible;
			end
		end
		table.insert(out, line);
	end
	return table.concat(out, "\n");
end

-- The race tooltip: the race's name (gold), its faction, then its racial abilities (icon, name, one line each, from
-- TEMUCRAFT_RACIALS, made by gen_racials.py from the PTR's Spell.dbc) and "Hold Alt to see the lore" in grey; with Alt
-- held the lore (the client's RACE_INFO_ text) and "Release Alt to see racials".
-- Lines: { text =, color = "gold"|"white"|"red"|"grey"|"faction"|"name", icon =, small = true, indent = true }
Logic.LORE_HINT, Logic.RACIALS_HINT = "Hold Alt to see the lore", "Release Alt to see racials";
function Logic.RaceTooltipLines(name, faction, racials, lore, alt, err, width)
	width = width or 52;
	local out = {};
	local function wrap(text, color, extra)
		for line in string.gmatch(Logic.Wrap(Logic.StripColors(text or ""), width).."\n", "(.-)\n") do
			line = string.match(line, "^%s*(.-)%s*$");
			if ( line ~= "" ) then
				local l = { text = line, color = color };
				for k, v in pairs(extra or {}) do l[k] = v; end
				table.insert(out, l);
			end
		end
	end
	table.insert(out, { text = Logic.StripColors(name or ""), color = "gold" });
	if ( faction and faction ~= "" ) then
		local label = (faction == "Alliance" and (FACTION_ALLIANCE or "Alliance")) or (faction == "Horde" and (FACTION_HORDE or "Horde")) or faction;
		table.insert(out, { text = label, color = "faction", faction = faction });
	end
	if ( err and err ~= "" ) then wrap(err, "red"); end
	if ( alt or not racials or #racials == 0 ) then
		if ( lore and lore ~= "" ) then wrap(lore, "white"); end
		if ( racials and #racials > 0 ) then table.insert(out, { text = Logic.RACIALS_HINT, color = "grey", small = true, gap = true }); end
	else
		for _, r in ipairs(racials) do
			table.insert(out, { text = r.name or "", color = "name", icon = r.icon, gap = true });
			wrap(r.text, "white", { small = true, indent = true });
		end
		if ( lore and lore ~= "" ) then table.insert(out, { text = Logic.LORE_HINT, color = "grey", small = true, gap = true }); end
	end
	return out;
end
function Logic.Racials(file)
	return TEMUCRAFT_RACIALS and TEMUCRAFT_RACIALS[string.upper(file or "")] or nil;
end

-- Race portraits: Ryan's 130 px retail portraits (gen_race_portraits.py: 128x128 BLPs, round) by default; "Classic
-- race portraits" (Options window, saved with TemucraftGlueSetting_Set) brings back the old icons
-- (RyansRacesRound, the client's race atlas) for the races that have one there.
Logic.PORTRAIT_PATH = "Interface\\Glues\\CharacterCreate\\TemucraftRace_%s_%s";
function Logic.PortraitClassic()
	if ( TEMUCRAFT_RACE_PORTRAITS == "classic" ) then return true; end
	return (TemucraftGlueSetting_Get and TemucraftGlueSetting_Get("racePortraits") == "classic") and true or false;
end
-- texture, { l, r, t, b } for a race file and "MALE" / "FEMALE"; classicCoords = the atlas coords (nil = none)
function Logic.Portrait(file, gender, classic, classicCoords, hasNew)
	file = string.upper(file or "");
	if ( classic and classicCoords ) then
		return "Interface\\Glues\\CharacterCreate\\RyansRacesRound", classicCoords, true;
	end
	if ( hasNew == false and classicCoords ) then
		return "Interface\\Glues\\CharacterCreate\\RyansRacesRound", classicCoords, true;
	end
	return string.format(Logic.PORTRAIT_PATH, file, gender), { 0, 1, 0, 1 }, false;
end

-- Faction and class colours for the "Race - Class" line (the glue screens have no RAID_CLASS_COLORS)
Logic.FACTION_COLORS = { Alliance = "ff4a9cff", Horde = "ffe8352a" };
Logic.CLASS_COLORS = {
	WARRIOR = "ffc79c6e", PALADIN = "fff58cba", HUNTER = "ffabd473", ROGUE = "fffff569", PRIEST = "ffffffff",
	DEATHKNIGHT = "ffc41f3b", SHAMAN = "ff0070de", MAGE = "ff69ccf0", WARLOCK = "ff9482c9", MONK = "ff00ff96",
	DRUID = "ffff7d0a", DEMONHUNTER = "ffa330c9", EVOKER = "ff33937f",
};
-- "|cff4a9cffHighmountain Tauren|r  -  |cfff58cbaPaladin|r"
function Logic.Title(race, faction, className, classFile)
	local parts = {};
	if ( race and race ~= "" ) then
		local c = Logic.FACTION_COLORS[faction or ""];
		table.insert(parts, c and ("|c"..c..race.."|r") or race);
	end
	if ( className and className ~= "" ) then
		local c = Logic.CLASS_COLORS[string.upper(classFile or "")];
		table.insert(parts, c and ("|c"..c..className.."|r") or className);
	end
	return table.concat(parts, "  -  ");
end

---------------------------------------------------------------------------------------------------------------------
-- The screen (only in the client)
---------------------------------------------------------------------------------------------------------------------
if ( not CharacterCreate or not CreateFrame ) then
	return;
end

local OPTION_LABELS = { "Skin Color", "Face", "Hair Style", "Hair Color", "Facial Hair" };
local OPTION_ROW_WIDTH, OPTION_ARROW = 230, 30;
local OPTION_BAR_WIDTH, OPTION_PAD = OPTION_ROW_WIDTH - 2 * OPTION_ARROW, 8;
local ICON_SIZE, ICON_STEP = 46, 54;
local NAME_WIDTH = 220;
local SIDE_MARGIN, TOP_MARGIN = 40, -96;

local root, holder, raceButtons, classButtons, optionRows = nil, nil, {}, {}, {};
local ToggleHidden;
local positions = {};      -- ["NIGHTELF_FEMALE"] = { 1, 1, 1, 1, 1 }: the counters of each race and sex
local lastDeathKnight;     -- the counters' skin / face reset when death knight is picked or dropped (other skins)
local throttle = 0;

local function Active()
	return TEMUCRAFT_LOGIN_UI ~= "classic";
end
TemucraftCharCreate_Active = Active;

-- Our own tooltip: the stock CharacterCreateTooltip / GlueTooltip keep their old anchors (GlueTooltip_SetOwner only adds
-- a point) and their old size, so one use could leave the next one a huge empty box (the gender buttons). This one is
-- laid out from scratch every time: lines left-aligned, the title gold, the text white, errors red, sized to its lines,
-- anchored only where asked. side: "right" / "left" / "top" / "bottom" of the owner.
local tip;
local TIP_COLORS = { gold = { 1, 0.82, 0 }, white = { 1, 1, 1 }, red = { 1, 0.25, 0.25 }, grey = { 0.6, 0.6, 0.6 },
	name = { 1, 0.9, 0.55 }, Alliance = { 0.29, 0.61, 1 }, Horde = { 0.91, 0.21, 0.16 } };
local function Tooltip(owner, title, side, body, err, prebuilt)
	if ( not owner or not (title or prebuilt) ) then return; end
	if ( not tip ) then
		tip = CreateFrame("Frame", "TemucraftCreateTooltip", CharacterCreate);
		tip:SetFrameStrata("TOOLTIP");
		tip:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } });
		tip:SetBackdropColor(0.03, 0.03, 0.05, 0.96);
		tip:SetBackdropBorderColor(0.8, 0.65, 0.3, 1);
		tip.lines, tip.icons = {}, {};
	end
	local lines = prebuilt or Logic.TooltipLines(title, body, err);
	local width, y, icons = 60, -10, 0;
	for i, line in ipairs(lines) do
		local fs = tip.lines[i];
		if ( not fs ) then
			fs = tip:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall");
			fs:SetJustifyH("LEFT");
			tip.lines[i] = fs;
		end
		if ( line.gap and i > 1 ) then y = y - 4; end
		local x = 11 + ((line.icon or line.indent) and 22 or 0);
		fs:SetFontObject((i == 1 and line.color == "gold") and GlueFontNormal
			or ((line.color == "name" or line.color == "faction") and GlueFontNormalSmall) or GlueFontHighlightSmall);
		fs:ClearAllPoints();
		fs:SetPoint("TOPLEFT", tip, "TOPLEFT", x, y);
		fs:SetText(line.text);
		local c = TIP_COLORS[line.color == "faction" and (line.faction or "") or line.color] or TIP_COLORS.white;
		fs:SetTextColor(c[1], c[2], c[3]);
		fs:Show();
		if ( line.icon ) then
			icons = icons + 1;
			local t = tip.icons[icons];
			if ( not t ) then
				t = tip:CreateTexture(nil, "ARTWORK");
				t:SetWidth(18); t:SetHeight(18);
				tip.icons[icons] = t;
			end
			t:SetTexture(line.icon);
			t:SetTexCoord(0.07, 0.93, 0.07, 0.93);
			t:ClearAllPoints();
			t:SetPoint("TOPLEFT", tip, "TOPLEFT", 11, y + 2);
			t:Show();
		end
		width = math.max(width, (fs:GetStringWidth() or 0) + x + 13);
		y = y - ((i == 1) and 18 or (line.icon and 16 or 14));
	end
	for i = #lines + 1, #tip.lines do tip.lines[i]:Hide(); end
	for i = icons + 1, #tip.icons do tip.icons[i]:Hide(); end
	tip:SetWidth(width);
	tip:SetHeight(-y + 8);
	tip:ClearAllPoints();
	if ( side == "top" ) then
		tip:SetPoint("BOTTOM", owner, "TOP", 0, 10);
	elseif ( side == "bottom" ) then
		tip:SetPoint("TOP", owner, "BOTTOM", 0, -8);
	elseif ( side == "left" ) then
		tip:SetPoint("TOPRIGHT", owner, "TOPLEFT", -10, 4);
	elseif ( side == "rightmiddle" ) then
		tip:SetPoint("LEFT", owner, "RIGHT", 10, 0);
	else
		tip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 10, 4);
	end
	tip:Show();
	tip.owner = owner;
end
local function HideTooltip()
	if ( tip ) then tip:Hide(); end
	if ( CharacterCreateTooltip ) then CharacterCreateTooltip:Hide(); end
end
TemucraftCharCreate_Tooltip = function() return tip; end

-- The stock functions only ask a button whether it's enabled and tell it to check itself
local proxy = { IsEnabled = function() return 1; end, SetChecked = function() end };

-- The faction crests (the PvP badges the character list uses too): the badge fills the top left of its 64x64 file
local FACTION_CREST_FILE = { Alliance = "Interface\\TargetingFrame\\UI-PVP-Alliance", Horde = "Interface\\TargetingFrame\\UI-PVP-Horde" };
local FACTION_CREST = { Alliance = { 0, 0.66, 0, 0.66 }, Horde = { 0, 0.66, 0, 0.66 } };

local function SelectedFaction()
	local index = GetSelectedRace();
	if ( not index ) then
		return nil;
	end
	local _, faction = GetFactionForRace(index);
	if ( faction == "Alliance" or faction == "Horde" ) then
		return faction;
	end
	local _, file = GetNameForRace();
	return TemucraftRaceFaction and TemucraftRaceFaction(file) or nil;
end

local function SelectedFile()
	local _, file = GetNameForRace();
	return string.upper(file or "");
end
local function IsMale()
	return GetSelectedSex() == SEX_MALE;
end
local function IsDeathKnight()
	local _, classFile = GetSelectedClass();
	return classFile == "DEATHKNIGHT";
end
local function IsHD()
	if ( type(TEMUCRAFT_HD_RACES) == "table" ) then
		return TEMUCRAFT_HD_RACES[SelectedFile()] and true or false;
	end
	return TEMUCRAFT_CHARACTER_SCENES == "new";
end
local function CounterKey()
	return SelectedFile().."_"..(IsMale() and "MALE" or "FEMALE");
end
local function Counters()
	local key = CounterKey();
	positions[key] = positions[key] or { 1, 1, 1, 1, 1 };
	return positions[key];
end

-- One look for the race (round) and class (square) buttons: the same gold, the same glow strength.
--   round:  a thin gold ring exactly around the portrait (the glue screen's own ring art, UI-CharacterCreatePatchwerk:
--           its ring sits 1.5 / 0.5 px off the middle of its 82x82 cell and has a radius of 0.384 of it), the
--           selected race the same ring bright with a soft glow, hover a lighter ring.
--   square: a thin gold square border (four 1 px lines), the selected class the stock gold square glow
--           (UI-GearManager-ItemButton-Highlight), hover the stock square highlight (ButtonHilight-Square).
local GOLD, RING_DIM = { 1, 0.82, 0.3 }, { 0.72, 0.58, 0.32 };
local GLOW_ALPHA = 0.55;
local RING_FILE, RING_COORDS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreatePatchwerk", { 0.79296875, 0.953125, 0.00097656, 0.08105469 };
local RING_RADIUS = 0.384;

local function Ring(b, layer, size, blend)
	local t = b:CreateTexture(nil, layer);
	t:SetTexture(RING_FILE);
	t:SetTexCoord(RING_COORDS[1], RING_COORDS[2], RING_COORDS[3], RING_COORDS[4]);
	t:SetBlendMode(blend or "BLEND");
	t:SetWidth(size); t:SetHeight(size);
	t:SetPoint("CENTER", b, "CENTER", size * 1.5 / 82, -size * 0.5 / 82);
	return t;
end

local function MakeIconButton(name, parent, size, shape)
	local b = CreateFrame("CheckButton", name, parent);
	b:SetWidth(size); b:SetHeight(size);
	b.shape = shape or "round";
	b.icon = b:CreateTexture(nil, "ARTWORK");
	b.icon:SetAllPoints(b);
	if ( b.shape == "round" ) then
		local ringSize = (size / 2 + 1) / RING_RADIUS;   -- the ring just outside the portrait's edge
		b.border = Ring(b, "OVERLAY", ringSize);
		b.border:SetVertexColor(RING_DIM[1], RING_DIM[2], RING_DIM[3]);
		b.ring = Ring(b, "OVERLAY", ringSize, "ADD");     -- selected: bright ring ...
		b.ring:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]);
		b.glow = Ring(b, "BORDER", ringSize * 1.18, "ADD");   -- ... and a soft wider glow
		b.glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]);
		b.glow:SetAlpha(GLOW_ALPHA);
		local hl = Ring(b, "HIGHLIGHT", ringSize, "ADD");
		hl:SetVertexColor(1, 0.95, 0.75);
		hl:SetAlpha(0.45);
	else
		b.edges = {};
		-- { point 1, x, y, point 2, x, y, vertical }: 1 px outside the icon
		for i, p in ipairs({ { "TOPLEFT", -1, 1, "TOPRIGHT", 1, 1 }, { "BOTTOMLEFT", -1, -1, "BOTTOMRIGHT", 1, -1 },
				{ "TOPLEFT", -1, 1, "BOTTOMLEFT", -1, -1, true }, { "TOPRIGHT", 1, 1, "BOTTOMRIGHT", 1, -1, true } }) do
			local e = b:CreateTexture(nil, "OVERLAY");
			e:SetTexture(1, 1, 1, 1);
			e:SetVertexColor(RING_DIM[1], RING_DIM[2], RING_DIM[3]);
			e:SetPoint(p[1], b, p[1], p[2], p[3]);
			e:SetPoint(p[4], b, p[4], p[5], p[6]);
			if ( p[7] ) then e:SetWidth(1); else e:SetHeight(1); end
			b.edges[i] = e;
		end
		b.ring = b:CreateTexture(nil, "OVERLAY");   -- selected: the gold square glow (its square fills 49 of 64 px)
		b.ring:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-ItemButton-Highlight");
		b.ring:SetTexCoord(0, 0.765625, 0, 0.765625);
		b.ring:SetBlendMode("ADD");
		b.ring:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]);
		b.ring:SetWidth(size * 49 / 36); b.ring:SetHeight(size * 49 / 36);
		b.ring:SetPoint("CENTER", b, "CENTER", 0, 0);
		local hl = b:CreateTexture(nil, "HIGHLIGHT");
		hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square");
		hl:SetBlendMode("ADD");
		hl:SetAllPoints(b);
	end
	b.ring:Hide();
	if ( b.glow ) then b.glow:Hide(); end
	b:SetScript("OnEnter", function(self)
		if ( self.tooltipLines ) then
			self.tipAlt = IsAltKeyDown and IsAltKeyDown() and true or false;
			Tooltip(self, nil, self.tooltipSide, nil, nil, self.tooltipLines(self.tipAlt));
		else
			Tooltip(self, self.tooltip, self.tooltipSide, self.tooltipBody, self.tooltipError);
		end
	end);
	b:SetScript("OnLeave", function(self) self.tipAlt = nil; HideTooltip(); end);
	-- the race tooltip swaps racials / lore while Alt is held
	b:SetScript("OnUpdate", function(self)
		if ( self.tipAlt ~= nil and self.tooltipLines and tip and tip:IsShown() and tip.owner == self ) then
			local alt = IsAltKeyDown and IsAltKeyDown() and true or false;
			if ( alt ~= self.tipAlt ) then
				self.tipAlt = alt;
				Tooltip(self, nil, self.tooltipSide, nil, nil, self.tooltipLines(alt));
			end
		end
	end);
	return b;
end

local function SetIconState(b, selected, enabled)
	if ( selected ) then b.ring:Show(); else b.ring:Hide(); end
	if ( b.glow ) then if ( selected ) then b.glow:Show(); else b.glow:Hide(); end end
	b.icon:SetDesaturated(not enabled);
	b.icon:SetAlpha(enabled and 1 or 0.45);
	if ( b.border ) then b.border:SetDesaturated(not enabled); b.border:SetAlpha(enabled and 1 or 0.5); end
	for _, e in ipairs(b.edges or {}) do e:SetAlpha(enabled and 1 or 0.4); end
	b.enabled = enabled;
end

-- One line: cut with "..." when it is wider than `width`
local function Utf8Sub(text, n)
	local out, k = {}, 0;
	for ch in string.gmatch(text or "", "[%z\1-\127\192-\253][\128-\191]*") do
		k = k + 1;
		if ( k > n ) then break; end
		out[k] = ch;
	end
	return table.concat(out);
end
local function SetOneLine(fs, text, width)
	fs:SetText(text);
	if ( not fs.GetStringWidth or (fs:GetStringWidth() or 0) <= width ) then return; end
	local _, len = string.gsub(text or "", "[%z\1-\127\192-\253]", "");
	local lo, hi = 0, len;
	while ( lo < hi ) do
		local mid = math.floor((lo + hi + 1) / 2);
		fs:SetText(Utf8Sub(text, mid).."...");
		if ( (fs:GetStringWidth() or 0) <= width ) then lo = mid; else hi = mid - 1; end
	end
	fs:SetText(Utf8Sub(text, lo).."...");
end

-- the retail panel (as on character select): dark, gold metal border (3.3.5's DialogFrame art)
local function Panel(parent)
	local f = CreateFrame("Frame", nil, parent);
	f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
		tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } });
	f:SetBackdropColor(1, 1, 1, 0.9);
	return f;
end

local function NavButton(name, parent, text, onClick)
	local b = CreateFrame("Button", name, parent, "GlueButtonTemplate");
	b:SetWidth(160); b:SetHeight(36);
	b:SetText(text);
	b:SetScript("OnClick", onClick);
	return b;
end

---------------------------------------------------------------------------------------------------------------------
-- Refresh: our widgets show what the stock code has selected (it is the one that knows)
---------------------------------------------------------------------------------------------------------------------
local Refresh;

local function StockRaceEnabled(index, enabled)
	-- the stock buttons know about paid race changes (CharacterChangeFixup) on top of GetAvailableRaces
	for i = 1, MAX_RACES or 30 do
		local b = _G["CharCreateRaceButton"..i];
		if ( b and b.raceIndex == index ) then
			return b:IsEnabled() and true or false, b.tooltip;
		end
	end
	return enabled, nil;
end

local function RefreshRaces()
	local list, data = {}, { GetAvailableRaces() };
	for i = 1, #data, 3 do
		local index = (i - 1) / 3 + 1;
		local _, faction = GetFactionForRace(index);
		faction = (faction == "Alliance" or faction == "Horde") and faction
			or (TemucraftRaceFaction and TemucraftRaceFaction(data[i + 1])) or "Alliance";
		table.insert(list, { index = index, name = data[i], file = data[i + 1], enabled = (data[i + 2] == 1), faction = faction });
	end
	local placed = Logic.Layout(list);
	local gender = IsMale() and "MALE" or "FEMALE";
	local classic = Logic.PortraitClassic();
	local selected = GetSelectedRace();
	for _, b in ipairs(raceButtons) do b:Hide(); end
	for n, race in ipairs(list) do
		local p = placed[race.index];
		local b = raceButtons[n];
		if ( not b ) then
			b = MakeIconButton("TemucraftCreateRace"..n, root.races, ICON_SIZE, "round");
			b:SetScript("OnClick", function(self)
				self:SetChecked(nil);
				if ( self.enabled and self.raceIndex ) then
					CharacterRace_OnClick(proxy, self.raceIndex);
					Refresh();
				end
			end);
			raceButtons[n] = b;
		end
		local enabled, stockTip = StockRaceEnabled(race.index, race.enabled);
		local atlas = (GetSafeRaceIconCoords and GetSafeRaceIconCoords(race.file, gender))
			or (RACE_ICON_TCOORDS and RACE_ICON_TCOORDS[string.upper(race.file).."_"..gender]) or nil;
		local hasNew = TEMUCRAFT_RACE_PORTRAIT_FILES and (TEMUCRAFT_RACE_PORTRAIT_FILES[string.upper(race.file)] and true or false);
		local texture, coords, isAtlas = Logic.Portrait(race.file, gender, classic, atlas, hasNew);
		b.icon:SetTexture(texture);
		if ( isAtlas ) then
			-- the atlas portrait's circle fills 58 of the 64 px of its cell: crop to it so it fills the button and the ring
			local iu, iv = (coords[2] - coords[1]) * 3 / 64, (coords[4] - coords[3]) * 3 / 64;
			b.icon:SetTexCoord(coords[1] + iu, coords[2] - iu, coords[3] + iv, coords[4] - iv);
		else
			b.icon:SetTexCoord(0, 1, 0, 1);   -- ours are round and fill their 128 px
		end
		b.raceIndex = race.index;
		local info = GetFlavorText and GetFlavorText("RACE_INFO_"..string.upper(race.file), GetSelectedSex());
		local err = (not enabled) and stockTip ~= race.name and stockTip or nil;
		local racials, name, faction = Logic.Racials(race.file), race.name, race.faction;
		b.tooltip = race.name;
		b.tooltipLines = function(alt) return Logic.RaceTooltipLines(name, faction, racials, info, alt, err); end;
		b.tooltipSide = (p.side == "Alliance") and "right" or "left";
		b:ClearAllPoints();
		local x = SIDE_MARGIN + (p.column - 1) * ICON_STEP + ICON_SIZE / 2;
		local y = TOP_MARGIN - (p.row - 1) * ICON_STEP - ICON_SIZE / 2;
		if ( p.side == "Alliance" ) then
			b:SetPoint("CENTER", root, "TOPLEFT", x, y);
		else
			b:SetPoint("CENTER", root, "TOPRIGHT", -x, y);
		end
		SetIconState(b, race.index == selected, enabled);
		b:Show();
	end
end

local function RefreshClasses()
	-- GetClassesForRace() isn't used: only the races-30 exe gives it the Lua stack room for its values
	local data = { GetAvailableClasses() };
	local _, _, selected = GetSelectedClass();
	local count = 0;
	for i = 1, #data, 3 do
		if ( data[i] ) then count = count + 1; end
	end
	for _, b in ipairs(classButtons) do b:Hide(); end
	local n = 0;
	for i = 1, #data, 3 do
		local index = (i - 1) / 3 + 1;
		local name, file, available = data[i], data[i + 1], data[i + 2];
		if ( name and file ) then
			n = n + 1;
			local b = classButtons[n];
			if ( not b ) then
				b = MakeIconButton("TemucraftCreateClass"..n, root.classes, 40, "square");
				b.tooltipSide = "top";
				b.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes");
				b:SetScript("OnClick", function(self)
					self:SetChecked(nil);
					if ( self.enabled and self.classIndex ) then
						CharacterClass_OnClick(proxy, self.classIndex);
						Refresh();
					end
				end);
				classButtons[n] = b;
			end
			local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[string.upper(file)];
			if ( coords ) then
				b.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes");
				b.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]);
			else
				b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
				b.icon:SetTexCoord(0, 1, 0, 1);
			end
			local stock = _G["CharCreateClassButton"..index];
			local enabled = (available == 1) and IsRaceClassValid(GetSelectedRace(), index) and true or false;
			if ( stock and stock:IsShown() and not stock:IsEnabled() ) then
				enabled = false;   -- paid services lock the class
			end
			b.classIndex = index;
			b.tooltip = name;
			b.tooltipError = (not enabled) and ((stock and stock.tooltip ~= name and stock.tooltip) or CLASS_DISABLED) or nil;
			b:ClearAllPoints();
			b:SetPoint("CENTER", root.classes, "CENTER", (n - (count + 1) / 2) * 50, 0);
			SetIconState(b, index == selected, enabled);
			b:Show();
		end
	end
	root.classes:SetWidth(math.max(count * 50 + 30, 200));
end

local function OptionLabel(id)
	local hair = GetHairCustomization and GetHairCustomization() or "NORMAL";
	local facial = GetFacialHairCustomization and GetFacialHairCustomization() or "NORMAL";
	local labels = {
		CHAR_CUSTOMIZATION1_DESC, CHAR_CUSTOMIZATION2_DESC,
		_G["HAIR_"..hair.."_STYLE"], _G["HAIR_"..hair.."_COLOR"], _G["FACIAL_HAIR_"..facial],
	};
	return labels[id], (id <= 2) and (labels[id] or OPTION_LABELS[id]) or labels[id];
end

local function RefreshOptions()
	local totals = Logic.Totals(SelectedFile(), IsMale(), IsDeathKnight(), IsHD());
	local counters = Counters();
	local dk = IsDeathKnight();
	if ( lastDeathKnight ~= nil and lastDeathKnight ~= dk ) then
		counters[1], counters[2] = 1, 1;
	end
	lastDeathKnight = dk;
	local y = -50;
	for id = 1, NUM_CHAR_CUSTOMIZATIONS or 5 do
		local row = optionRows[id];
		local _, label = OptionLabel(id);
		if ( label and label ~= "" ) then
			local total = totals[id];
			-- the name on the left of the bar, "3 / 9" on its right; a long (translated) name is cut before the count
			if ( total and total > 0 ) then
				if ( counters[id] > total ) then counters[id] = total; end
				row.count:SetText(counters[id].." / "..total);
			else
				row.count:SetText("");
			end
			local room = OPTION_BAR_WIDTH - 2 * OPTION_PAD - ((row.count:GetText() or "") ~= "" and ((row.count:GetStringWidth() or 0) + 6) or 0);
			SetOneLine(row.label, label, room);
			row.total = total;
			row:ClearAllPoints();
			row:SetPoint("TOP", root.options, "TOP", 0, y);
			y = y - 40;
			row:Show();
		else
			row:Hide();
		end
	end
	root.randomize:ClearAllPoints();
	root.randomize:SetPoint("TOP", root.options, "TOP", 0, y - 6);
	root.options:SetHeight(-y + 56);
end

-- The name check: the server's rules while typing; after Finish the server's own answer about the name (taken,
-- reserved, mature language ...) until the name changes
local serverNameError, serverErrorName;
local function RefreshName()
	local text = CharacterCreateNameEdit:GetText() or "";
	local status, reason, saved = Logic.CheckName(text);
	local check = root.nameCheck;
	if ( serverNameError and text ~= serverErrorName ) then serverNameError = nil; end
	if ( status == "empty" ) then
		check:Hide();
		root.nameHint:SetText("");
		return;
	end
	if ( status == "ok" and serverNameError ) then status, reason = "server", serverNameError; end
	check.ok = (status == "ok");
	check.status = status;
	if ( check.ok ) then
		root.nameMark:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready");
		check.title = saved;
		check.text = "Name looks good - the server checks if it's taken when you click "..(FINISH or "Finish")..".";
		root.nameHint:SetText("");
	else
		root.nameMark:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady");
		check.title = saved ~= "" and saved or text;
		check.text = reason;
		root.nameHint:SetText(reason or "");
	end
	check:Show();
end

-- The server's answer to Finish (the status dialog's text) when it is about the name
local function CheckServerAnswer(text)
	local err = Logic.NameServerError(text);
	if ( err and root and root:IsShown() ) then
		serverNameError, serverErrorName = err, CharacterCreateNameEdit:GetText() or "";
		RefreshName();
	end
end

function Refresh()
	if ( not root or not root:IsShown() ) then
		return;
	end
	local customize = (CharacterCreateFrame.state == "CUSTOMIZATION");
	local male = IsMale();
	root.male.ring[male and "Show" or "Hide"](root.male.ring);
	root.female.ring[male and "Hide" or "Show"](root.female.ring);
	if ( customize ) then
		root.races:Hide(); root.classes:Hide();
		root.options:Show(); root.nameBar:Show();
		root.next:SetText(FINISH or "Finish");
		RefreshOptions();
		RefreshName();
	else
		root.options:Hide(); root.nameBar:Hide();
		root.races:Show(); root.classes:Show();
		root.next:SetText(CUSTOMIZE or "Customize");
		RefreshRaces();
		RefreshClasses();
	end
	local race = GetNameForRace();
	local className, classFile = GetSelectedClass();
	local faction = SelectedFaction();
	root.title:SetText(Logic.Title(race, faction, className, classFile));
	-- step 2 shows the faction crest and the class icon either side of the line
	local crest = faction and FACTION_CREST[faction];
	if ( customize and crest ) then
		root.titleFaction:SetTexture(FACTION_CREST_FILE[faction]);
		root.titleFaction:SetTexCoord(crest[1], crest[2], crest[3], crest[4]);
		root.titleFaction:Show();
	else
		root.titleFaction:Hide();
	end
	local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[string.upper(classFile)];
	if ( customize and coords ) then
		root.titleClass:SetTexCoord(coords[1], coords[2], coords[3], coords[4]);
		root.titleClass:Show();
	else
		root.titleClass:Hide();
	end
	if ( CharCreateOkayButton and CharCreateOkayButton:IsEnabled() ) then
		root.next:Enable();
	else
		root.next:Disable();
	end
	-- the altered form (worgen / human) portraits stay ours to see
	if ( CharacterCreateAlteredFormSelector and CharacterCreateAlteredFormSelector:GetParent() ~= root ) then
		CharacterCreateAlteredFormSelector:SetParent(root);
		CharacterCreateAlteredFormSelector:ClearAllPoints();
		CharacterCreateAlteredFormSelector:SetPoint("LEFT", root, "LEFT", 150, -40);
	end
end
TemucraftCharCreate_Refresh = Refresh;
-- the Options window's "Classic race portraits"
TemucraftRacePortraits_IsClassic = function() return Logic.PortraitClassic(); end
TemucraftRacePortraits_SetClassic = function(on)
	if ( TemucraftGlueSetting_Set ) then TemucraftGlueSetting_Set("racePortraits", on and "classic" or nil); end
	Refresh();
end

---------------------------------------------------------------------------------------------------------------------
-- Appearance: counted clicks
---------------------------------------------------------------------------------------------------------------------
local function Cycle(id, delta)
	local counters = Counters();
	local total = Logic.Totals(SelectedFile(), IsMale(), IsDeathKnight(), IsHD())[id];
	local step = (delta > 0) and 1 or -1;
	for _ = 1, math.abs(delta) do
		CycleCharCustomization(id, step);
	end
	counters[id] = Logic.Step(counters[id], total, delta);
end

local function Randomize()
	PlaySound("gsCharacterCreationLook");
	local totals = Logic.Totals(SelectedFile(), IsMale(), IsDeathKnight(), IsHD());
	-- skin before face (faces depend on it), hair style before colour
	local clicks = Logic.RandomClicks(totals, math.random);
	for id = 1, 5 do
		if ( clicks[id] and clicks[id] ~= 0 ) then
			Cycle(id, clicks[id]);
		end
	end
	if ( CharCreate_ResetFeaturesDisplay ) then
		CharCreate_ResetFeaturesDisplay();
	end
	Refresh();
end

---------------------------------------------------------------------------------------------------------------------
-- Hide the interface, turn with the arrow keys
---------------------------------------------------------------------------------------------------------------------
local hidden, turning = false, nil;
function ToggleHidden(show)
	if ( not root ) then return; end
	if ( show == nil ) then show = hidden; end
	hidden = not show;
	HideTooltip();
	if ( hidden ) then
		root:Hide();
		root.catcher:Show();
		root.eye.icon:SetDesaturated(1);
	else
		root.catcher:Hide();
		root:Show();
		root.eye.icon:SetDesaturated(nil);
		Refresh();
	end
end
TemucraftCharCreate_ToggleHidden = function(show) ToggleHidden(show); end
TemucraftCharCreate_IsHidden = function() return hidden; end

---------------------------------------------------------------------------------------------------------------------
-- Building the screen
---------------------------------------------------------------------------------------------------------------------
local function Build()
	root = CreateFrame("Frame", "TemucraftCharCreateFrame", CharacterCreateFrame);
	root:SetAllPoints(CharacterCreate);
	root:SetFrameLevel(CharacterCreateFrame:GetFrameLevel() + 5);
	holder = CreateFrame("Frame", nil, CharacterCreate);
	holder:Hide();

	-- male / female
	for _, sex in ipairs({ "male", "female" }) do
		local b = MakeIconButton("TemucraftCreate"..sex, root, 40, "round");
		b.tooltipSide = (sex == "male") and "left" or "right";
		b.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Gender");
		if ( sex == "male" ) then
			b.icon:SetTexCoord(0, 0.5, 0, 1);
			b:SetPoint("TOP", root, "TOP", -28, -22);
			b.tooltip = MALE or "Male";
		else
			b.icon:SetTexCoord(0.5, 1, 0, 1);
			b:SetPoint("TOP", root, "TOP", 28, -22);
			b.tooltip = FEMALE or "Female";
		end
		b:SetScript("OnClick", function(self)
			self:SetChecked(nil);
			local want = (self == root.male) and SEX_MALE or SEX_FEMALE;
			if ( GetSelectedSex() ~= want ) then
				PlaySound("gsCharacterCreationClass");
				SetCharacterGender(want);
			end
			Refresh();
		end);
		root[sex] = b;
	end
	root.title = root:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
	root.title:SetPoint("BOTTOM", root, "BOTTOM", 0, 112);
	root.titleFaction = root:CreateTexture(nil, "OVERLAY");
	root.titleFaction:SetWidth(44); root.titleFaction:SetHeight(44);
	root.titleFaction:SetPoint("RIGHT", root.title, "LEFT", -8, 0);
	root.titleClass = root:CreateTexture(nil, "OVERLAY");
	root.titleClass:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes");
	root.titleClass:SetWidth(40); root.titleClass:SetHeight(40);
	root.titleClass:SetPoint("LEFT", root.title, "RIGHT", 8, 0);

	-- step 1: race columns and the class row
	root.races = CreateFrame("Frame", nil, root);
	root.races:SetAllPoints(root);
	for _, side in ipairs({ "Alliance", "Horde" }) do
		local label = root.races:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
		label:SetText(side == "Alliance" and (FACTION_ALLIANCE or "Alliance") or (FACTION_HORDE or "Horde"));
		local x = SIDE_MARGIN + ICON_STEP - (ICON_STEP - ICON_SIZE) / 2;
		if ( side == "Alliance" ) then
			label:SetPoint("BOTTOM", root, "TOPLEFT", x, TOP_MARGIN + 10);
		else
			label:SetPoint("BOTTOM", root, "TOPRIGHT", -x, TOP_MARGIN + 10);
		end
		local crest = root.races:CreateTexture(nil, "ARTWORK");
		crest:SetTexture(FACTION_CREST_FILE[side]);
		local c = FACTION_CREST[side];
		crest:SetTexCoord(c[1], c[2], c[3], c[4]);
		crest:SetWidth(56); crest:SetHeight(56);
		crest:SetPoint("BOTTOM", label, "TOP", 0, 2);
	end
	root.classes = Panel(root);
	root.classes:SetHeight(64);
	root.classes:SetPoint("BOTTOM", root, "BOTTOM", 0, 28);

	-- step 2: the name box exactly in the middle (under the "Race - Class" line), the random-name dice left of it and
	-- the name check right of it, both hung on the box's edges so they never move it
	root.nameBar = CreateFrame("Frame", "TemucraftCreateNameBar", root);
	root.nameBar:SetWidth(NAME_WIDTH); root.nameBar:SetHeight(40);
	root.nameBar:SetPoint("BOTTOM", root, "BOTTOM", 0, 34);
	root.nameLabel = root.nameBar:CreateFontString(nil, "OVERLAY", "GlueFontNormal");
	root.nameLabel:SetPoint("BOTTOM", root.nameBar, "TOP", 0, 1);
	root.nameLabel:SetText(NAME or "Name");
	root.dice = CreateFrame("Button", "TemucraftCreateNameDice", root.nameBar);
	root.dice:SetWidth(32); root.dice:SetHeight(32);
	root.dice:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up");
	root.dice:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Down");
	root.dice:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight", "ADD");
	root.dice:SetPoint("RIGHT", root.nameBar, "LEFT", -6, -1);
	root.dice.tooltip = RANDOMIZE or "Random name";
	root.dice:SetScript("OnEnter", function(self) Tooltip(self, self.tooltip, "top"); end);
	root.dice:SetScript("OnLeave", HideTooltip);
	root.dice:SetScript("OnClick", function()
		PlaySound("gsCharacterCreationLook");
		CharacterCreateNameEdit:SetText(GetRandomName());
		RefreshName();
	end);
	-- the check: green tick / red cross (the ready check's), hover for why
	root.nameCheck = CreateFrame("Button", "TemucraftCreateNameCheck", root.nameBar);
	root.nameCheck:SetWidth(26); root.nameCheck:SetHeight(26);
	root.nameCheck:SetPoint("LEFT", root.nameBar, "RIGHT", 6, -1);
	root.nameMark = root.nameCheck:CreateTexture(nil, "ARTWORK");
	root.nameMark:SetAllPoints(root.nameCheck);
	root.nameCheck:SetScript("OnEnter", function(self)
		-- right of the tick / cross, so it never covers "Name" or the "Race - Class" line above the box
		if ( self.ok ) then
			Tooltip(self, self.title, "rightmiddle", self.text);
		else
			Tooltip(self, self.title, "rightmiddle", nil, self.text);
		end
	end);
	root.nameCheck:SetScript("OnLeave", HideTooltip);
	root.nameCheck:Hide();
	root.nameHint = root.nameBar:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall");
	root.nameHint:SetTextColor(1, 0.25, 0.25);
	root.nameHint:SetPoint("TOP", root.nameBar, "BOTTOM", 0, 2);

	root.options = Panel(root);
	root.options:SetWidth(270);
	root.options:SetPoint("TOPLEFT", root, "TOPLEFT", 30, -130);
	local head = root.options:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
	head:SetPoint("TOP", root.options, "TOP", 0, -16);
	head:SetText(CUSTOMIZE_OPTIONS or "Appearance");
	for id = 1, NUM_CHAR_CUSTOMIZATIONS or 5 do
		local row = CreateFrame("Button", "TemucraftCreateOption"..id, root.options);
		row:SetWidth(OPTION_ROW_WIDTH); row:SetHeight(34);
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp");
		-- a dark bar, as the group headers on select: only the part of the art you see (its rows 5-22 of 32 are the
		-- bar, edge lines included; above and below is soft shadow), so the bar is exactly the row's middle
		local bg = row:CreateTexture(nil, "BACKGROUND");
		bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Background");
		bg:SetTexCoord(0, 0.6640625, 5 / 32, 23 / 32);
		bg:SetVertexColor(0.6, 0.6, 0.65);
		bg:SetPoint("TOPLEFT", row, "TOPLEFT", OPTION_ARROW, -6);
		bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -OPTION_ARROW, 6);
		row.bar = bg;
		-- the name left in the bar (gold), the count right (white): each spans the bar's full height and is centred in
		-- it (JustifyV), so the text sits on the bar's middle whatever the font's line height
		row.label = row:CreateFontString(nil, "OVERLAY", "GlueFontNormal");
		row.label:SetJustifyH("LEFT");
		row.label:SetJustifyV("MIDDLE");
		row.label:SetPoint("TOPLEFT", bg, "TOPLEFT", OPTION_PAD, 1);
		row.label:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", OPTION_PAD, 1);
		row.count = row:CreateFontString(nil, "OVERLAY", "GlueFontHighlight");
		row.count:SetJustifyH("RIGHT");
		row.count:SetJustifyV("MIDDLE");
		row.count:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -OPTION_PAD, 1);
		row.count:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -OPTION_PAD, 1);
		for _, dir in ipairs({ "Left", "Right" }) do
			local arrow = CreateFrame("Button", row:GetName()..dir, row);
			arrow:SetWidth(32); arrow:SetHeight(32);
			arrow:SetPoint(dir == "Left" and "LEFT" or "RIGHT", row, dir == "Left" and "LEFT" or "RIGHT", 0, 0);
			arrow:SetNormalTexture("Interface\\Glues\\Common\\Glue-"..dir.."Arrow-Button-Up");
			arrow:SetPushedTexture("Interface\\Glues\\Common\\Glue-"..dir.."Arrow-Button-Down");
			arrow:SetHighlightTexture("Interface\\Glues\\Common\\Glue-"..dir.."Arrow-Button-Highlight", "ADD");
			local delta = (dir == "Left") and -1 or 1;
			arrow:SetScript("OnClick", function()
				PlaySound("gsCharacterCreationLook");
				Cycle(id, delta);
				Refresh();
			end);
		end
		-- a click on the row itself: left = next, right = back (like the stock buttons)
		row:SetScript("OnClick", function(self, button)
			PlaySound("gsCharacterCreationLook");
			Cycle(id, (button == "RightButton") and -1 or 1);
			Refresh();
		end);
		optionRows[id] = row;
	end
	root.randomize = CreateFrame("Button", "TemucraftCreateRandomize", root.options, "GlueButtonSmallTemplate");
	root.randomize:SetWidth(200); root.randomize:SetHeight(28);
	root.randomize:SetText("Randomize Appearance");
	root.randomize:SetScript("OnClick", Randomize);

	-- rotate the character
	for _, dir in ipairs({ "Left", "Right" }) do
		local b = CreateFrame("Button", "TemucraftCreateRotate"..dir, root);
		b:SetWidth(40); b:SetHeight(40);
		b:SetPoint("BOTTOM", root, "BOTTOM", dir == "Left" and -150 or 150, 150);
		b:SetNormalTexture("Interface\\Glues\\CharacterCreate\\UI-RotationRight-Big-Up");
		b:SetPushedTexture("Interface\\Glues\\CharacterCreate\\UI-RotationRight-Big-Down");
		b:SetHighlightTexture("Interface\\Glues\\Common\\Glue-RightArrow-Button-Highlight", "ADD");
		if ( dir == "Left" ) then
			b:GetNormalTexture():SetTexCoord(1, 0, 0, 1);
			b:GetPushedTexture():SetTexCoord(1, 0, 0, 1);
		end
		local step = (dir == "Left") and -1 or 1;
		b:SetScript("OnUpdate", function(self)
			if ( self:GetButtonState() == "PUSHED" ) then
				SetCharacterCreateFacing(GetCharacterCreateFacing() + step * (CHARACTER_FACING_INCREMENT or 2));
			end
		end);
	end

	-- Hide the interface (the eye, as on character select, or Alt-Z): only the scene and the character stay; the eye,
	-- a click anywhere, Escape or Alt-Z bring it back. The arrow keys still turn the character.
	root.eye = CreateFrame("Button", "TemucraftCreateEye", CharacterCreate);
	root.eye:SetWidth(34); root.eye:SetHeight(34);
	root.eye:SetPoint("BOTTOMLEFT", CharacterCreate, "BOTTOMLEFT", 202, 31);
	root.eye:SetFrameLevel(root:GetFrameLevel() + 20);
	root.eye.icon = root.eye:CreateTexture(nil, "ARTWORK");
	root.eye.icon:SetTexture("Interface\\Icons\\Ability_EyeOfTheOwl");
	root.eye.icon:SetAllPoints(root.eye);
	root.eye:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
	root.eye:SetScript("OnClick", function() ToggleHidden(); end);
	root.eye:SetScript("OnEnter", function(self)
		Tooltip(self, hidden and "Show the interface" or "Hide the interface", "top", "Alt-Z. Left / Right arrow keys turn the character.");
	end);
	root.eye:SetScript("OnLeave", HideTooltip);
	root.catcher = CreateFrame("Button", "TemucraftCreateShowUI", CharacterCreate);
	root.catcher:SetAllPoints(CharacterCreate);
	root.catcher:SetFrameLevel(root:GetFrameLevel() + 15);
	root.catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	root.catcher:SetScript("OnClick", function() ToggleHidden(); end);
	root.catcher:Hide();
	-- arrow keys: held = keeps turning, as the rotate buttons
	root.keys = CreateFrame("Frame", nil, CharacterCreate);
	root.keys:SetScript("OnUpdate", function()
		if ( turning and CharacterCreate:IsShown() ) then
			SetCharacterCreateFacing(GetCharacterCreateFacing() + turning * (CHARACTER_FACING_INCREMENT or 2));
		end
	end);

	-- Back / Next (Customize) / Finish
	root.back = NavButton("TemucraftCreateBack", root, BACK or "Back", function()
		CharacterCreate_Back();
		Refresh();
	end);
	root.back:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 30, 30);
	root.next = NavButton("TemucraftCreateNext", root, CUSTOMIZE or "Customize", function()
		CharacterCreate_Forward();
		Refresh();
	end);
	root.next:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -30, 30);

	-- Only cheap checks every frame: the whole screen is redrawn on clicks and when something changes, not on a timer
	-- (redrawing 30 race buttons four times a second made every click lag).
	local lastState, lastRace, lastClass, lastSex, lastOkay;
	root:SetScript("OnUpdate", function(self, elapsed)
		throttle = throttle + (elapsed or 0);
		if ( throttle < 0.2 ) then
			return;
		end
		throttle = 0;
		local state, race, class, sex = CharacterCreateFrame.state, GetSelectedRace(), select(3, GetSelectedClass()), GetSelectedSex();
		local okay = CharCreateOkayButton and CharCreateOkayButton:IsEnabled() and true or false;
		if ( state ~= lastState or race ~= lastRace or class ~= lastClass or sex ~= lastSex or okay ~= lastOkay ) then
			lastState, lastRace, lastClass, lastSex, lastOkay = state, race, class, sex, okay;
			Refresh();
		end
	end);
end

-- Move the stock frames out of sight (they keep working); the name box comes to our name bar
local function HideStock()
	for _, child in ipairs({ CharacterCreateFrame:GetChildren() }) do
		if ( child ~= root and child ~= CharacterCreateNameEdit and child ~= CharacterCreateAlteredFormSelector ) then
			child:SetParent(holder);
		end
	end
	local edit = CharacterCreateNameEdit;
	edit:SetParent(root.nameBar);
	edit:ClearAllPoints();
	edit:SetAllPoints(root.nameBar);
	edit:Show();
	-- the typed name in the middle of the box, in the screen's edit box font (GlueEditBoxFont, white): the stock box
	-- starts its text 15 px in, for the old layout
	if ( edit.SetTextInsets ) then edit:SetTextInsets(6, 6, 0, 0); end
	if ( edit.SetJustifyH ) then edit:SetJustifyH("CENTER"); end
	if ( edit.SetFontObject and GlueEditBoxFont ) then edit:SetFontObject(GlueEditBoxFont); end
	if ( edit.SetTextColor ) then edit:SetTextColor(1, 1, 1); end
	-- the stock "NAME" over the box is in the big blackletter faction font (FactionName_Shadow_Huge): ours (nameLabel,
	-- the screen's own font) replaces it. Only that one: the box's own text is a FontString region too (hiding every
	-- FontString hid the typed name, only the caret was left).
	if ( edit.GetRegions ) then
		for _, r in ipairs({ edit:GetRegions() }) do
			if ( Logic.IsNameLabel(r, NAME, FactionName_Shadow_Huge) ) then r:Hide(); end
		end
	end
end

local function OnShow()
	if ( not Active() ) then
		if ( root ) then root:Hide(); root.eye:Hide(); root.catcher:Hide(); end
		return;
	end
	if ( not root ) then
		Build();
	end
	HideStock();
	-- The client rolled a new look for the race and sex it starts on (ResetCharCustomize); the other races and sexes
	-- keep the look they had (CCharacterCreation::m_charPreferences), and so their counters. A paid change starts from
	-- the character's own look: every counter starts again.
	if ( PAID_SERVICE_TYPE ) then
		positions = {};
	else
		positions[CounterKey()] = nil;
	end
	lastDeathKnight = nil;
	serverNameError, turning = nil, nil;
	hidden = false;
	root.catcher:Hide();
	root.eye.icon:SetDesaturated(nil);
	root.eye:Show();
	root:Show();
	Refresh();
end

if ( CharacterCreate.HookScript ) then
	CharacterCreate:HookScript("OnShow", OnShow);
else
	local old = CharacterCreate:GetScript("OnShow");
	CharacterCreate:SetScript("OnShow", function(...) if ( old ) then old(...); end OnShow(); end);
end

-- Character create shows the faction's scene by default (Alliance or Horde), not the race's; the player's own pick
-- (TEMUCRAFT_SCENE_PICKS) still wins, and TEMUCRAFT_CREATE_SCENES = "race" keeps each race's scene.
local oldBackground = SetBackgroundModel;
if ( oldBackground ) then
	SetBackgroundModel = function(model, name, race)
		if ( model == CharacterCreate and Active() and TEMUCRAFT_CREATE_SCENES ~= "race" ) then
			local saved = TEMUCRAFT_CHARACTER_SCENES;
			TEMUCRAFT_CHARACTER_SCENES = "faction";
			local ok, err = pcall(oldBackground, model, name, race);
			TEMUCRAFT_CHARACTER_SCENES = saved;
			if ( not ok ) then
				error(err, 0);
			end
			return;
		end
		return oldBackground(model, name, race);
	end
end

-- The edit box's own changes update the check mark
if ( CharacterCreateNameEdit and CharacterCreateNameEdit.HookScript ) then
	CharacterCreateNameEdit:HookScript("OnTextChanged", function()
		if ( root and root:IsShown() ) then
			RefreshName();
		end
	end);
end

-- Keys on the screen (the name box gets its own keys while it has the focus, so typing still moves its cursor):
-- Left / Right turn the character while held, Alt-Z hides / shows the interface; with it hidden Escape brings it back
-- and Enter does nothing (no Finish by accident). Everything else goes to the client's own handler (Escape = Back,
-- Enter = Next / Finish).
local oldCreateKeyDown = CharacterCreate_OnKeyDown;
if ( oldCreateKeyDown ) then
	CharacterCreate_OnKeyDown = function(key, ...)
		if ( Active() and root ) then
			if ( key == "LEFT" or key == "RIGHT" ) then
				turning = (key == "LEFT") and -1 or 1;
				return;
			end
			if ( key == "Z" and IsAltKeyDown and IsAltKeyDown() ) then
				ToggleHidden();
				return;
			end
			if ( hidden ) then
				if ( key == "ESCAPE" ) then ToggleHidden(true); end
				if ( key ~= "PRINTSCREEN" ) then return; end
			end
		end
		return oldCreateKeyDown(key, ...);
	end
end
local function CreateKeyUp(self, key)
	if ( key == "LEFT" or key == "RIGHT" ) then turning = nil; end
end
if ( CharacterCreate.HookScript and CharacterCreate:GetScript("OnKeyUp") ) then
	CharacterCreate:HookScript("OnKeyUp", CreateKeyUp);
else
	CharacterCreate:SetScript("OnKeyUp", CreateKeyUp);
end

-- The server's answer to Finish comes in the status dialog (OPEN_STATUS_DIALOG -> GlueDialog_Show, or
-- UPDATE_STATUS_DIALOG -> GlueDialogText:SetText): a name answer turns the name check red with it
local oldDialogShow = GlueDialog_Show;
if ( oldDialogShow ) then
	GlueDialog_Show = function(which, text, ...)
		local r = oldDialogShow(which, text, ...);
		CheckServerAnswer(text);
		return r;
	end
end
if ( GlueDialogText and GlueDialogText.SetText ) then
	local oldSetText = GlueDialogText.SetText;
	GlueDialogText.SetText = function(self, text, ...)
		oldSetText(self, text, ...);
		CheckServerAnswer(text);
	end
end

-- Even light on every race (see Logic.EvenLights): the character's light set from GlueParent.lua's TemucraftApplyLights
-- (patch-~) is caught and replaced by the even one; the background's own lights stay. TEMUCRAFT_EVEN_LIGHT = false
-- (Interface\TemucraftScenes.lua) keeps the scene's lights as they are.
local oldApplyLights = TemucraftApplyLights;
if ( oldApplyLights ) then
	TemucraftApplyLights = function(model, ...)
		if ( not Active() or TEMUCRAFT_EVEN_LIGHT == false or not model or not model.AddCharacterLight ) then
			return oldApplyLights(model, ...);
		end
		local caught = {};
		local add, raw = model.AddCharacterLight, rawget(model, "AddCharacterLight");
		model.AddCharacterLight = function(self, set, ...)
			if ( set == (LIGHT_LIVE or 0) ) then table.insert(caught, { ... }); else add(self, set, ...); end
		end
		local ok, err = pcall(oldApplyLights, model, ...);
		model.AddCharacterLight = raw;   -- back to the frame's own method
		if ( not ok ) then error(err, 0); end
		for _, light in ipairs(Logic.EvenLights(caught)) do
			add(model, LIGHT_LIVE or 0, unpack(light));
		end
	end
end
