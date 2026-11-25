-- Stub tests for the login screens (no client): lua5.1 client/tests/glue_test.lua (from the module folder)
-- 1. the logic tables of TemucraftCharCreate.lua / TemucraftCharSelect.lua with the generated data,
-- 2. a stub load: both files built on stub frames and the client functions they call, then clicked through.
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
local glue = dir.."/Interface/GlueXML/";
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

dofile(glue.."TemucraftGlueData.lua");
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
AccountLoginAccountEdit = CreateFrame("EditBox", "AccountLoginAccountEdit");
AccountLoginAccountEdit.text = "Ryan";

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
check("counter text", string.find(TemucraftCreateOption2.text.text, "1 / 15", 1, true) ~= nil);
TemucraftCreateOption2Left:Click();
check("counter wraps back", string.find(TemucraftCreateOption2.text.text, "15 / 15", 1, true) ~= nil and state.cycles[2] == -1);
state.cycles = {};
TemucraftCreateRandomize:Click();
local tot = C.Totals("HUMAN", false, false);
local good = true;
for id = 1, 5 do
	local shownPos = tonumber(string.match(_G["TemucraftCreateOption"..id].text.text, "(%d+) / "));
	local start = (id == 2) and 15 or 1;   -- face was clicked back to 15 above
	if ( shownPos ~= C.Step(start, tot[id], state.cycles[id] or 0) ) then good = false; end
end
check("randomize keeps the counters right", good);
TemucraftCreateNameDice:Click();
check("random name", CharacterCreateNameEdit:GetText() == "Randomname");
TemucraftCreateNext:Click();
check("finish creates", state.created == "Randomname");

-- character select
local ok4, err4 = pcall(function() CharacterSelect:Show(); end);
check("select shows", ok4 or print(err4));
check("stock list hidden", not CharacterSelectCharacterFrame:IsVisible() and TemucraftCharSelectFrame:IsVisible());
check("cards", TemucraftSelectCard1:IsShown() and TemucraftSelectCard3:IsShown() and not TemucraftSelectCard4:IsShown());
local function cardNames() local t = {}; for n = 1, 3 do t[n] = _G["TemucraftSelectCard"..n].name.text; end return table.concat(t, ","); end
check("cards in the saved order, new ones after", cardNames() == "Jaina,Thrall,Lorewalker");
check("cards keep the client's index", TemucraftSelectCard1.id == 2 and TemucraftSelectCard2.id == 1 and TemucraftSelectCard3.id == 3);
check("card zone bracket", TemucraftSelectCard1.zone.text == "Dalaran (Wrath of the Lich King)" and TemucraftSelectCard2.zone.text == "Orgrimmar");
local z = TemucraftSelectCard3.zone.text;
check("long zone cut to one line", string.sub(z, -3) == "..." and string.len(z) * 6 <= 212 and string.find(z, "^The Jade Forest"));
check("card crest", TemucraftSelectCard3.crest.shown);
check("AccountLogin sees only its accounts", GetSavedAccountList() == "tc1:"..tcHide("ryan\t"));
TemucraftSelectSearch:SetText("horde");
check("search filters cards", TemucraftSelectCard2:IsShown() and not TemucraftSelectCard3:IsShown() and TemucraftSelectCard1.name.text == "Thrall");
TemucraftSelectSearch:SetText("");
TemucraftSelectCard1:Click();
check("card selects by the client's index", state.selected == 2);
check("arrows on the selected card only", TemucraftSelectCard1Up:IsShown() and not TemucraftSelectCard2Up:IsShown() and TemucraftSelectCard1Up.enabled == false and TemucraftSelectCard1Down.enabled);
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
for n = 1, 9 do local b = _G["TemucraftSelectCard"..n]; b.top = 700 - (n - 1) * 58; b.bottom = b.top - 54; end
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
TemucraftSelectCreate:Click();
check("create", state.screen == "charcreate");

-- 2026-11-25 evening: long AreaTable brackets cut, title colours, tooltip wrapping
check("zone: AreaTable bracket dropped", S.ZoneText("Valley of Trials (Durotar, Classic)") == "Valley of Trials");
check("zone: short label kept for real duplicates", S.ZoneText("Dalaran (Northrend, Wrath)") == "Dalaran (Wrath of the Lich King)");
check("title: faction and class colours", C.Title("Highmountain Tauren", "Horde", "Paladin", "PALADIN") == "|cffe8352aHighmountain Tauren|r  -  |cfff58cbaPaladin|r");
local wrapped = C.Wrap(string.rep("word ", 40), 30);
local longest = 0;
for line in string.gmatch(wrapped.."|n", "(.-)|n") do longest = math.max(longest, string.len(line)); end
check("tooltip text wrapped", longest <= 30 and string.find(wrapped, "|n"));

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
