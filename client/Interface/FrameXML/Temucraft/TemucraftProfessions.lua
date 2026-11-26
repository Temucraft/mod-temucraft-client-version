-- Temucraft Professions window (retail-style, like Dragonflight's Professions frame, for 3.3.5): it takes the place of
-- the stock TradeSkillFrame. Same look as our other windows (TemucraftStyle.lua).
--   Top     the profession's icon, name and skill bar ("175 / 225"), a link button (shift-click into chat), a small
--           Stats box (Finesse / Perception / Deftness for gathering, Multicraft / Resourcefulness for crafting: the
--           server's mod-temucraft-professions, addon prefix TPG, its "SS" answer to "GET"), and on the right a
--           button per profession you know (a click opens it; secure buttons, hidden in combat). Tabs: Recipes and
--           Overview (every profession with its bar and stats).
--   Left    the recipe list: search (recipe and reagent names), "Have materials", "Skill up" (orange / yellow / green),
--           collapsible categories, Favorites first (the star on a row; per character in TemucraftStore "prof.fav"),
--           the stock difficulty colours, how many you can make.
--   Right   the selected recipe: icon, name in its item quality colour, how many it makes, cooldown, what is still
--           missing (tools, anvil, forge: only what the client says you lack), the crafted item's tooltip, the
--           reagents (have / need; shift-click links, ctrl-click dresses up), and the bottom bar: Recipe link, Craft
--           from bag (with the TemucraftProfGear addon: its reagent bag), - quantity + and Max, Create All, Create.
-- Gathering professions (Herbalism, Skinning, Fishing) have no recipes: their page is the skill bar and stats. Mining
-- opens Smelting (a tradeskill) as its recipe list. Someone else's profession (a link in chat, IsTradeSkillLinked)
-- shows read-only. The stock tradeskill API does the work (GetTradeSkillInfo, SelectTradeSkill, DoTradeSkill ...);
-- in 3.3.5 enchanting is a tradeskill too (CraftFrame is gone), and Blizzard's frame still loads: UIParent calls
-- TradeSkillFrame_Show / _Hide, which open this window instead. "Classic professions window" (/tui) keeps the stock
-- one, and DragonUI's Professions module wins while it is on (TemucraftDragonUI.lua, "tradeskill").
--   /professions (/tprof)   opens or closes it (the Overview when no profession is open)

----------------------------------------------------------------------------------------------------------------------
-- The logic (no frames: tests/professions_test.lua runs it with stubs)
----------------------------------------------------------------------------------------------------------------------
TemucraftProfessionsLogic = {};
local L = TemucraftProfessionsLogic;

-- skill line id -> { English name, spell that opens its window (nil: gathering without one), icon, gathering }
L.PROFESSIONS = {
	[171] = { "Alchemy", 2259, "Trade_Alchemy" },
	[164] = { "Blacksmithing", 2018, "Trade_BlackSmithing" },
	[333] = { "Enchanting", 7411, "Trade_Engraving" },
	[202] = { "Engineering", 4036, "Trade_Engineering" },
	[773] = { "Inscription", 45357, "INV_Inscription_Tradeskill01" },
	[755] = { "Jewelcrafting", 25229, "INV_Misc_Gem_01" },
	[165] = { "Leatherworking", 2108, "Trade_LeatherWorking" },
	[197] = { "Tailoring", 3908, "Trade_Tailoring" },
	[185] = { "Cooking", 2550, "INV_Misc_Food_15" },
	[129] = { "First Aid", 3273, "Spell_Holy_SealOfSacrifice" },
	[186] = { "Mining", 2656, "Trade_Mining", true },      -- Smelting
	[182] = { "Herbalism", nil, "Spell_Nature_NatureTouchGrow", true },
	[393] = { "Skinning", nil, "INV_Misc_Pelt_Wolf_01", true },
	[356] = { "Fishing", nil, "Trade_Fishing", true },
};
-- the order of the buttons and the Overview: main professions, then the secondary ones
L.ORDER = { 171, 164, 333, 202, 773, 755, 165, 197, 186, 182, 393, 185, 129, 356 };
-- the stock difficulty colours (TradeSkillTypeColor)
L.COLORS = {
	optimal = { 1, 0.5, 0.25 }, medium = { 1, 1, 0 }, easy = { 0.25, 0.75, 0.25 }, trivial = { 0.5, 0.5, 0.5 },
	header = { 1, 0.82, 0 },
};
L.STAT_HELP = {
	{ "Finesse", "Chance for each gathered stack to come with half again as much." },
	{ "Perception", "Chance to also find a rare reagent: gems from ore, rare herbs, rare hides." },
	{ "Deftness", "Faster mining, herb gathering and skinning." },
	{ "Multicraft", "Chance for a craft of stackable goods (potions, food, bandages, gems...) to make extra." },
	{ "Resourcefulness", "Chance, for each kind of reagent, to get 30% of it back." },
};

-- a skill line's name (English, or another name the client gives it: aliases[name] = id) -> its id
function L.SkillId(name, aliases)
	if ( not name ) then return nil; end
	for id, p in pairs(L.PROFESSIONS) do
		if ( p[1] == name ) then return id; end
	end
	return aliases and aliases[name] or nil;
end

function L.IsGathering(id) return L.PROFESSIONS[id] ~= nil and L.PROFESSIONS[id][4] == true; end

-- "SS" from the server: "skill:fin:per:deft:multi:res;..." -> stats[skill] = { five numbers }
function L.ParseStats(data)
	local out = {};
	for skill, a, b, c, d, e in string.gmatch(data or "", "(%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+);") do
		out[tonumber(skill)] = { tonumber(a), tonumber(b), tonumber(c), tonumber(d), tonumber(e) };
	end
	return out;
end

-- the stats that matter for a profession: { { name, value, help } }
function L.Stats(skill, st)
	if ( not st ) then return {}; end
	local out = {};
	local first, last = 4, 5;
	if ( L.IsGathering(skill) ) then first, last = 1, 3; end
	for i = first, last do table.insert(out, { L.STAT_HELP[i][1], st[i] or 0, L.STAT_HELP[i][2] }); end
	return out;
end

-- favourites: "spell,spell,..." <-> set
function L.ParseFavs(text)
	local set = {};
	for id in string.gmatch(text or "", "%d+") do set[tonumber(id)] = true; end
	return set;
end
function L.FavText(set)
	local ids = {};
	for id, on in pairs(set or {}) do if ( on ) then table.insert(ids, id); end end
	table.sort(ids);
	return table.concat(ids, ",");
end

-- the recipe's spell id from GetTradeSkillRecipeLink
function L.SpellFromLink(link)
	return link and tonumber(string.match(link, "enchant:(%d+)")) or nil;
end

local function lower(s) return string.lower(s or ""); end

-- e = { index, name, kind, available, spell, reagents (names, lower case, or nil) }; opts: search, haveMats, skillUp
function L.Matches(e, opts)
	if ( opts.haveMats and (e.available or 0) <= 0 ) then return false; end
	if ( opts.skillUp and e.kind == "trivial" ) then return false; end
	local s = lower(opts.search);
	if ( s ~= "" ) then
		if ( not string.find(lower(e.name), s, 1, true) and not (e.reagents and string.find(e.reagents, s, 1, true)) ) then
			return false;
		end
	end
	return true;
end

-- entries: the whole list (expanded) in stock order, headers too (kind "header"); opts: collapsed (by header name;
-- "*favorites" for the Favorites group), favs (spell set), search, haveMats, skillUp.
-- Returns the lines: { kind = "header", name, key, collapsed, count } or { kind = "recipe", entry, fav }
function L.Lines(entries, opts)
	opts = opts or {};
	local collapsed, favs = opts.collapsed or {}, opts.favs or {};
	local groups, order, current = {}, {}, nil;
	local favList = {};
	for _, e in ipairs(entries) do
		if ( e.kind == "header" ) then
			current = { name = e.name, recipes = {} };
			table.insert(order, current);
		else
			if ( not current ) then
				current = { name = "", recipes = {} };
				table.insert(order, current);
			end
			if ( L.Matches(e, opts) ) then
				table.insert(current.recipes, e);
				if ( e.spell and favs[e.spell] ) then table.insert(favList, e); end
			end
		end
	end
	local lines = {};
	local function Group(name, key, recipes, isFav)
		if ( #recipes == 0 ) then return; end
		local shut = collapsed[key] and true or false;
		if ( name ~= "" ) then
			table.insert(lines, { kind = "header", name = name, key = key, collapsed = shut, count = #recipes, favorites = isFav });
		end
		if ( shut and name ~= "" ) then return; end
		for _, e in ipairs(recipes) do
			table.insert(lines, { kind = "recipe", entry = e, fav = e.spell ~= nil and favs[e.spell] == true });
		end
	end
	Group("Favorites", "*favorites", favList, true);
	for _, g in ipairs(order) do Group(g.name, g.name, g.recipes); end
	return lines;
end

-- the first recipe line (to select when nothing is)
function L.FirstRecipe(lines)
	for _, line in ipairs(lines) do if ( line.kind == "recipe" ) then return line.entry; end end
	return nil;
end

-- is this stock index still on a line
function L.HasIndex(lines, index)
	if ( not index ) then return false; end
	for _, line in ipairs(lines) do if ( line.kind == "recipe" and line.entry.index == index ) then return true; end end
	return false;
end

-- GetTradeSkillTools(i): name, has, name, has, ... -> the names still missing (what is met is left out)
function L.Missing(...)
	local out = {};
	for i = 1, select("#", ...), 2 do
		local name, has = select(i, ...);
		if ( name and not has ) then table.insert(out, name); end
	end
	return out;
end

-- how many a craft makes: "" (one), "2", "2-4"
function L.Made(minMade, maxMade)
	minMade, maxMade = minMade or 1, maxMade or minMade or 1;
	if ( maxMade <= 1 and minMade <= 1 ) then return ""; end
	if ( maxMade > minMade ) then return minMade.."-"..maxMade; end
	return tostring(minMade);
end

-- the quantity box: a number from 1 to 999 (max = what can be made, when known)
function L.Quantity(n, delta, max)
	n = (tonumber(n) or 1) + (delta or 0);
	if ( max and max > 0 and n > max ) then n = max; end
	if ( n > 999 ) then n = 999; end
	if ( n < 1 ) then n = 1; end
	return math.floor(n);
end

-- the skill bar's text
function L.SkillText(rank, maxRank, modifier)
	local t = (rank or 0).." / "..(maxRank or 0);
	if ( modifier and modifier > 0 ) then t = t.." (+"..modifier..")"; end
	return t;
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

----------------------------------------------------------------------------------------------------------------------
-- State
----------------------------------------------------------------------------------------------------------------------
local I = "Interface\\Icons\\";
local WIDTH, HEIGHT, LIST_W = 820, 560, 300;
local ROW_H, NUM_ROWS = 18, 0;
local MAX_REAGENTS = 8;

local session = false;          -- a tradeskill is open (ours or someone's link)
local lineName = nil;           -- GetTradeSkillLine() of the open one
local lineKey = nil;            -- and whose it is (a linked one)
local page = "recipes";         -- "recipes", "gather" (one profession without recipes), "overview"
local gatherSkill = nil;
local stats = {};               -- from the server (TPG "SS")
local entries, lines = {}, {};
local collapsed = {};
local favs = nil;               -- read from the store once it is in
local opts = { search = "", haveMats = false, skillUp = false };
local selected = nil;
local aliases = {};             -- the client's (localized) names -> skill id, for L.SkillId
local Update, UpdateList, UpdateDetail, UpdateHeader, UpdatePages, RefreshSwitcher, SyncSwitcher, ReadEntries;

-- the profession spells' names (the same as their skill lines), Smelting and Mining for Mining
for id, p in pairs(L.PROFESSIONS) do
	local name = p[2] and GetSpellInfo and GetSpellInfo(p[2]);
	if ( name ) then aliases[name] = id; end
end
for spell, id in pairs({ [2575] = 186, [8613] = 393, [7620] = 356 }) do
	local name = GetSpellInfo and GetSpellInfo(spell);
	if ( name ) then aliases[name] = id; end
end

local function Favs()
	if ( not favs ) then
		favs = L.ParseFavs(TemucraftStore_Get and TemucraftStore_Get("C", "prof.fav"));
	end
	return favs;
end
if ( TemucraftStore_OnReady ) then TemucraftStore_OnReady(function() favs = nil; if ( Update and TemucraftProfessionsFrame:IsShown() ) then Update(); end end); end

local function Linked()
	if ( not IsTradeSkillLinked ) then return false, nil; end
	local linked, who = IsTradeSkillLinked();
	return linked and true or false, who;
end

local askedAt = 0;
local function AskStats()
	if ( not SendAddonMessage or GetTime() - askedAt < 3 ) then return; end
	askedAt = GetTime();
	SendAddonMessage("TPG", "GET", "WHISPER", UnitName("player"));
end

-- the professions you know: { { id, name, rank, max, modifier } } in L.ORDER
local function Known()
	local found = {};
	if ( GetNumSkillLines ) then
		-- a collapsed header hides its lines: open them (once; the stock Skills pane keeps what it likes)
		for pass = 1, 3 do
			local any = false;
			for i = GetNumSkillLines(), 1, -1 do
				local name, header, expanded = GetSkillLineInfo(i);
				if ( header and not expanded and ExpandSkillHeader ) then ExpandSkillHeader(i); any = true; end
			end
			if ( not any ) then break; end
		end
		for i = 1, GetNumSkillLines() do
			local name, header, _, rank, _, modifier, maxRank = GetSkillLineInfo(i);
			local id = not header and L.SkillId(name, aliases);
			if ( id and L.PROFESSIONS[id] ) then
				found[id] = { id = id, name = name, rank = rank or 0, max = maxRank or 0, modifier = modifier or 0 };
			end
		end
	end
	local out = {};
	for _, id in ipairs(L.ORDER) do if ( found[id] ) then table.insert(out, found[id]); end end
	return out;
end

local function KnownOne(id)
	for _, p in ipairs(Known()) do if ( p.id == id ) then return p; end end
	return nil;
end

----------------------------------------------------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------------------------------------------------
local frame = CreateFrame("Frame", "TemucraftProfessionsFrame", UIParent);
frame:SetWidth(WIDTH); frame:SetHeight(HEIGHT);
frame:EnableMouse(true);
frame:SetMovable(true);
frame:SetClampedToScreen(true);
frame:Hide();
UIPanelWindows["TemucraftProfessionsFrame"] = { area = "left", pushable = 3, whileDead = 1 };
local titleText = TemucraftStyle_Window(frame, TRADE_SKILLS or "Professions");
local close = CreateFrame("Button", "TemucraftProfessionsFrameCloseButton", frame, "UIPanelCloseButton");
close:SetPoint("TOPRIGHT", -6, -6);
local drag = CreateFrame("Frame", nil, frame);
drag:SetPoint("TOPLEFT", 12, -8); drag:SetPoint("TOPRIGHT", -40, -8); drag:SetHeight(26);
drag:EnableMouse(true);
drag:RegisterForDrag("LeftButton");
drag:SetScript("OnDragStart", function() frame:StartMoving(); end);
drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); end);

local function Inset(parent)
	local f = CreateFrame("Frame", nil, parent);
	TemucraftStyle_Inset(f);
	return f;
end

local function Tip(owner, title, text)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT");
	GameTooltip:SetText(title);
	if ( text ) then GameTooltip:AddLine(text, 1, 1, 1, true); end
	GameTooltip:Show();
end

-- [[ top: icon, name, skill bar, link button, stats ]] --
local top = Inset(frame);
top:SetPoint("TOPLEFT", 16, -36); top:SetPoint("TOPRIGHT", -16, -36); top:SetHeight(62);
local profIcon = top:CreateTexture(nil, "ARTWORK");
profIcon:SetWidth(44); profIcon:SetHeight(44);
profIcon:SetPoint("LEFT", 10, 0);
local profName = top:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
profName:SetPoint("TOPLEFT", profIcon, "TOPRIGHT", 10, -2);
profName:SetJustifyH("LEFT");
local skillBar = CreateFrame("StatusBar", nil, top);
skillBar:SetWidth(210); skillBar:SetHeight(14);
skillBar:SetPoint("BOTTOMLEFT", profIcon, "BOTTOMRIGHT", 10, 2);
skillBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
skillBar:SetStatusBarColor(0.0, 0.6, 0.1);
local barBg = skillBar:CreateTexture(nil, "BACKGROUND");
barBg:SetAllPoints(); barBg:SetTexture(0, 0, 0, 0.6);
local barBorder = CreateFrame("Frame", nil, skillBar);
barBorder:SetPoint("TOPLEFT", -3, 3); barBorder:SetPoint("BOTTOMRIGHT", 3, -3);
barBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 });
barBorder:SetBackdropBorderColor(0.78, 0.62, 0.3, 1);
local skillText = skillBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
skillText:SetPoint("CENTER", 0, 1);
-- the profession link (shift-click into chat, like the stock button)
local linkButton = CreateFrame("Button", nil, top);
linkButton:SetWidth(32); linkButton:SetHeight(16);
linkButton:SetPoint("LEFT", profName, "RIGHT", 6, 0);
linkButton:SetNormalTexture("Interface\\Buttons\\UI-LinkProfession-Up");
linkButton:SetPushedTexture("Interface\\Buttons\\UI-LinkProfession-Down");
linkButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");
linkButton:SetScript("OnEnter", function(self) Tip(self, LINK_TRADESKILL_TOOLTIP or "Link this profession", "Click to put a link to your recipes in chat."); end);
linkButton:SetScript("OnLeave", GameTooltip_Hide);
local function InsertLink(link)
	if ( not link ) then return; end
	if ( not ChatEdit_InsertLink(link) and ChatFrame_OpenChat ) then ChatFrame_OpenChat(link); end
end
linkButton:SetScript("OnClick", function() if ( GetTradeSkillListLink ) then InsertLink(GetTradeSkillListLink()); end end);
local viewing = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
viewing:SetPoint("LEFT", skillBar, "RIGHT", 10, 0);

-- stats (the server's TPG "SS")
local statsBox = CreateFrame("Frame", nil, top);
statsBox:SetPoint("TOPLEFT", 320, -6); statsBox:SetPoint("BOTTOMLEFT", 320, 6); statsBox:SetWidth(170);
statsBox:EnableMouse(true);
local statsTitle = statsBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
statsTitle:SetPoint("TOPLEFT", 0, -2);
statsTitle:SetText("Stats");
local statLines = {};
for i = 1, 3 do
	local t = statsBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	t:SetPoint("TOPLEFT", 0, -2 - i * 12);
	t:SetPoint("RIGHT", 0, 0);
	t:SetJustifyH("LEFT");
	statLines[i] = t;
end
local statsSeparator = TemucraftStyle_Line(top);
statsSeparator:SetWidth(1); statsSeparator:SetHeight(46);
statsSeparator:SetPoint("RIGHT", statsBox, "LEFT", -10, 0);
local function StatsTooltip(owner, skill)
	local list = L.Stats(skill, stats[skill]);
	GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM");
	GameTooltip:SetText("Profession stats");
	if ( #list == 0 ) then
		GameTooltip:AddLine("This server sends no profession stats.", 0.8, 0.8, 0.8, true);
	end
	for _, s in ipairs(list) do
		GameTooltip:AddDoubleLine(s[1], s[2].."%", 1, 1, 1, 0.4, 0.8, 1);
		GameTooltip:AddLine(s[3], 0.8, 0.8, 0.8, true);
	end
	if ( #list > 0 and not L.IsGathering(skill) ) then
		GameTooltip:AddLine("Mastery adds up to 10% more of both as your skill rises past a recipe's yellow rank.", 0.6, 0.6, 0.6, true);
	end
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("Stats come from tools in your bags, profession equipment (Character > Professions) and specializations.", 0.6, 0.6, 0.6, true);
	GameTooltip:Show();
end
statsBox:SetScript("OnEnter", function(self) StatsTooltip(self, self.skill); end);
statsBox:SetScript("OnLeave", GameTooltip_Hide);

local function FillStats(box, lineTexts, skill)
	box.skill = skill;
	local list = L.Stats(skill, stats[skill]);
	for i = 1, #lineTexts do
		local s = list[i];
		if ( s ) then lineTexts[i]:SetText(format("%s  |cff66ccff%d%%|r", s[1], s[2])); else lineTexts[i]:SetText(""); end
	end
	if ( #list == 0 ) then lineTexts[1]:SetText("|cff888888(none)|r"); end
end

-- [[ the profession buttons (secure: a click casts the profession; hidden in combat) ]] --
local switcher = CreateFrame("Frame", "TemucraftProfessionsSwitcher", UIParent);
switcher:SetWidth(10); switcher:SetHeight(34);
switcher:Hide();
local combatNote = top:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
combatNote:SetPoint("RIGHT", -14, 0);
combatNote:SetText("Switch professions after combat");
combatNote:Hide();
local switchButtons = {};
local function SwitchButton(i)
	if ( switchButtons[i] ) then return switchButtons[i]; end
	local b = CreateFrame("Button", "TemucraftProfessionsSwitch"..i, switcher, "SecureActionButtonTemplate");
	b:SetWidth(30); b:SetHeight(30);
	b:RegisterForClicks("LeftButtonUp");
	b.icon = b:CreateTexture(nil, "ARTWORK");
	b.icon:SetAllPoints();
	b.border = b:CreateTexture(nil, "OVERLAY");
	b.border:SetTexture("Interface\\Buttons\\UI-Quickslot2");
	b.border:SetWidth(52); b.border:SetHeight(52);
	b.border:SetPoint("CENTER");
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
	b.glow = b:CreateTexture(nil, "OVERLAY");
	b.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight");
	b.glow:SetBlendMode("ADD");
	b.glow:SetAllPoints();
	b:SetScript("OnEnter", function(self)
		if ( not self.prof ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM");
		GameTooltip:SetText(self.prof.name);
		GameTooltip:AddLine(L.SkillText(self.prof.rank, self.prof.max, self.prof.modifier), 1, 1, 1);
		if ( L.IsGathering(self.prof.id) and self.prof.id ~= 186 ) then
			GameTooltip:AddLine("Its skill and stats (no recipes).", 0.8, 0.8, 0.8, true);
		elseif ( self.prof.id == 186 ) then
			GameTooltip:AddLine("Smelting: its recipes. Its skill and stats are on top.", 0.8, 0.8, 0.8, true);
		end
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	-- after the secure click: the gathering ones show their page here, the open one its recipes
	b:SetScript("PostClick", function(self)
		if ( not self.prof or self:GetAttribute("type") ) then return; end
		if ( not L.PROFESSIONS[self.prof.id][2] ) then page = "gather"; gatherSkill = self.prof.id;
		elseif ( session ) then page = "recipes"; end
		Update();
	end);
	switchButtons[i] = b;
	return b;
end

local currentSkill, sessionSkill;   -- forward: the skill id the header shows, the open tradeskill's (yours)
-- what each button does (out of combat only); more than 8 professions: two rows of smaller buttons
function RefreshSwitcher()
	if ( InCombatLockdown() ) then return; end
	local known = Known();
	local open, shown = sessionSkill(), currentSkill();
	local two = #known > 8;
	local size = two and 24 or 30;
	local perRow = two and math.ceil(#known / 2) or #known;
	local n = 0;
	for _, p in ipairs(known) do
		n = n + 1;
		local b = SwitchButton(n);
		local def = L.PROFESSIONS[p.id];
		b.prof = p;
		b.icon:SetTexture(I..def[3]);
		local spell = def[2] and GetSpellInfo(def[2]);
		-- the open one does nothing secure (casting it again would close it): it shows its recipes
		if ( spell and open ~= p.id ) then
			b:SetAttribute("type", "spell"); b:SetAttribute("spell", spell);
		else
			b:SetAttribute("type", nil); b:SetAttribute("spell", nil);
		end
		if ( shown == p.id ) then b.glow:Show(); else b.glow:Hide(); end
		b:SetWidth(size); b:SetHeight(size);
		b.border:SetWidth(size * 1.75); b.border:SetHeight(size * 1.75);
		local col, row = (n - 1) % perRow, math.floor((n - 1) / perRow);
		b:ClearAllPoints();
		if ( two ) then
			b:SetPoint("TOPRIGHT", switcher, "TOPRIGHT", -col * (size + 4), -row * (size + 4));
		else
			b:SetPoint("RIGHT", switcher, "RIGHT", -col * (size + 6), 0);
		end
		b:Show();
	end
	for i = n + 1, #switchButtons do switchButtons[i]:Hide(); switchButtons[i].prof = nil; end
	switcher:SetWidth(math.max(10, perRow * (size + 6)));
	switcher:SetHeight(two and (size * 2 + 4) or 34);
end

function SyncSwitcher()
	if ( InCombatLockdown() ) then
		if ( frame:IsShown() and not switcher:IsShown() ) then combatNote:Show(); end
		return;
	end
	combatNote:Hide();
	if ( frame:IsShown() ) then
		switcher:ClearAllPoints();
		switcher:SetPoint("RIGHT", top, "RIGHT", -12, 0);
		switcher:SetFrameStrata(frame:GetFrameStrata());
		switcher:SetFrameLevel(top:GetFrameLevel() + 10);
		RefreshSwitcher();
		switcher:Show();
	else
		switcher:Hide();
	end
end

-- [[ tabs ]] --
local tabs = {};
local function Tab(i, label, key)
	local b = CreateFrame("Button", nil, frame);
	b:SetWidth(110); b:SetHeight(22);
	b:SetPoint("TOPLEFT", 18 + (i - 1) * 116, -102);
	TemucraftStyle_Bar(b);
	TemucraftStyle_Highlight(b);
	b.glow = TemucraftStyle_Glow(b);
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	b.text:SetPoint("CENTER");
	b.text:SetText(label);
	b.key = key;
	b:SetScript("OnClick", function(self)
		PlaySound("igCharacterInfoTab");
		if ( self.key == "recipes" and not session ) then return; end
		page = self.key;
		Update();
	end);
	tabs[i] = b;
	return b;
end
Tab(1, "Recipes", "recipes");
Tab(2, "Overview", "overview");

-- [[ body pages ]] --
local recipesPage = CreateFrame("Frame", nil, frame);
recipesPage:SetPoint("TOPLEFT", 16, -128); recipesPage:SetPoint("BOTTOMRIGHT", -16, 16);
local gatherPage = CreateFrame("Frame", nil, frame);
gatherPage:SetAllPoints(recipesPage);
local overviewPage = CreateFrame("Frame", nil, frame);
overviewPage:SetAllPoints(recipesPage);

-- left: search, filters, the list
local listBox = Inset(recipesPage);
listBox:SetPoint("TOPLEFT", 0, 0); listBox:SetPoint("BOTTOMLEFT", 0, 0); listBox:SetWidth(LIST_W);
local search = CreateFrame("EditBox", "TemucraftProfessionsSearch", listBox, "InputBoxTemplate");
search:SetHeight(20);
search:SetPoint("TOPLEFT", 14, -8); search:SetPoint("TOPRIGHT", -10, -8);
search:SetAutoFocus(false);
local searchHint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
searchHint:SetPoint("LEFT", 2, 0);
searchHint:SetText(SEARCH or "Search");
search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
search:SetScript("OnTextChanged", function(self)
	local text = self:GetText() or "";
	if ( text == "" ) then searchHint:Show(); else searchHint:Hide(); end
	if ( text ~= opts.search ) then
		opts.search = text;
		if ( frame:IsShown() and page == "recipes" ) then ReadEntries(); UpdateList(); end
	end
end);
search:SetScript("OnEditFocusGained", function() searchHint:Hide(); end);
search:SetScript("OnEditFocusLost", function(self) if ( (self:GetText() or "") == "" ) then searchHint:Show(); end end);

local function Check(name, label, x, key, help)
	local c = CreateFrame("CheckButton", name, listBox, "UICheckButtonTemplate");
	c:SetWidth(22); c:SetHeight(22);
	c:SetPoint("TOPLEFT", x, -30);
	_G[name.."Text"]:SetText(label);
	_G[name.."Text"]:SetFontObject(GameFontHighlightSmall);
	c:SetScript("OnClick", function(self) opts[key] = self:GetChecked() and true or false; UpdateList(); end);
	c:SetScript("OnEnter", function(self) Tip(self, label, help); end);
	c:SetScript("OnLeave", GameTooltip_Hide);
	return c;
end
Check("TemucraftProfessionsHaveMats", "Have materials", 8, "haveMats", "Only recipes you have the reagents for.");
Check("TemucraftProfessionsSkillUp", "Skill up", 140, "skillUp", "Only recipes that can still raise your skill (orange, yellow and green).");

local scroll = CreateFrame("ScrollFrame", "TemucraftProfessionsScroll", listBox, "FauxScrollFrameTemplate");
scroll:SetPoint("TOPLEFT", 6, -56);
scroll:SetPoint("BOTTOMRIGHT", -28, 8);
local emptyText = listBox:CreateFontString(nil, "OVERLAY", "GameFontDisable");
emptyText:SetPoint("TOP", 0, -90);
emptyText:SetWidth(LIST_W - 30);
emptyText:SetText("No recipes match.");

NUM_ROWS = math.floor((HEIGHT - 128 - 16 - 56 - 8) / ROW_H);
local rows = {};

local function ToggleFav(spell)
	if ( not spell ) then return; end
	local set = Favs();
	set[spell] = (not set[spell]) or nil;
	if ( TemucraftStore_Set ) then TemucraftStore_Set("C", "prof.fav", L.FavText(set)); end
	UpdateList();
end

local function Select(index)
	if ( not index ) then return; end
	selected = index;
	if ( SelectTradeSkill ) then SelectTradeSkill(index); end
	UpdateList();
end

for i = 1, NUM_ROWS do
	local b = CreateFrame("Button", nil, listBox);
	b:SetHeight(ROW_H);
	b:SetPoint("TOPLEFT", 8, -56 - (i - 1) * ROW_H);
	b:SetPoint("RIGHT", scroll, "RIGHT", 0, 0);
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	b.bar = TemucraftStyle_Bar(b);
	b.glow = TemucraftStyle_Glow(b);
	TemucraftStyle_Highlight(b);
	b.expand = b:CreateTexture(nil, "ARTWORK");
	b.expand:SetWidth(14); b.expand:SetHeight(14);
	b.expand:SetPoint("LEFT", 2, 0);
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	b.name:SetPoint("LEFT", 18, 0);
	b.name:SetPoint("RIGHT", -40, 0);
	b.name:SetJustifyH("LEFT");
	b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.count:SetPoint("RIGHT", -22, 0);
	b.star = CreateFrame("Button", nil, b);
	b.star:SetWidth(16); b.star:SetHeight(16);
	b.star:SetPoint("RIGHT", -2, 0);
	b.star.tex = b.star:CreateTexture(nil, "ARTWORK");
	b.star.tex:SetAllPoints();
	b.star.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1");   -- the yellow star
	b.star:SetScript("OnClick", function(self) ToggleFav(self:GetParent().spell); end);
	b.star:SetScript("OnEnter", function(self)
		self:GetParent():LockHighlight();
		Tip(self, self:GetParent().fav and "Remove from Favorites" or "Add to Favorites");
	end);
	b.star:SetScript("OnLeave", function(self) self:GetParent():UnlockHighlight(); GameTooltip:Hide(); end);
	b:SetScript("OnClick", function(self, button)
		local line = self.line;
		if ( not line ) then return; end
		if ( line.kind == "header" ) then
			collapsed[line.key] = not collapsed[line.key] or nil;
			UpdateList();
			return;
		end
		local e = line.entry;
		if ( button == "RightButton" ) then ToggleFav(e.spell); return; end
		if ( IsModifiedClick("CHATLINK") and GetTradeSkillRecipeLink ) then InsertLink(GetTradeSkillRecipeLink(e.index)); return; end
		Select(e.index);
	end);
	b:SetScript("OnEnter", function(self)
		local line = self.line;
		if ( not line or line.kind ~= "recipe" ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetTradeSkillItem(line.entry.index);
		GameTooltip:AddLine("Right-click: favourite. Shift-click: link the recipe.", 0.6, 0.6, 0.6, true);
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	rows[i] = b;
end
scroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function() UpdateList(true); end); end);
listBox:EnableMouseWheel(true);
listBox:SetScript("OnMouseWheel", function(_, delta)
	local bar = _G["TemucraftProfessionsScrollScrollBar"];
	if ( bar ) then bar:SetValue(bar:GetValue() - delta * ROW_H * 3); end
end);

-- right: the selected recipe
local detail = Inset(recipesPage);
detail:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 8, 0); detail:SetPoint("BOTTOMRIGHT", 0, 0);
local recipeIcon = CreateFrame("Button", nil, detail);
recipeIcon:SetWidth(40); recipeIcon:SetHeight(40);
recipeIcon:SetPoint("TOPLEFT", 12, -12);
recipeIcon.border = recipeIcon:CreateTexture(nil, "OVERLAY");
recipeIcon.border:SetTexture("Interface\\Buttons\\UI-Quickslot2");
recipeIcon.border:SetWidth(68); recipeIcon.border:SetHeight(68);
recipeIcon.border:SetPoint("CENTER");
recipeIcon.made = recipeIcon:CreateFontString(nil, "OVERLAY", "NumberFontNormal");
recipeIcon.made:SetPoint("BOTTOMRIGHT", -2, 2);
recipeIcon:SetScript("OnEnter", function(self)
	if ( not selected ) then return; end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetTradeSkillItem(selected);
	GameTooltip:Show();
end);
recipeIcon:SetScript("OnLeave", GameTooltip_Hide);
recipeIcon:SetScript("OnClick", function()
	if ( selected and GetTradeSkillItemLink ) then HandleModifiedItemClick(GetTradeSkillItemLink(selected)); end
end);
local recipeName = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
recipeName:SetPoint("TOPLEFT", recipeIcon, "TOPRIGHT", 10, -2);
recipeName:SetPoint("RIGHT", -12, 0);
recipeName:SetJustifyH("LEFT");
local recipeSub = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
recipeSub:SetPoint("TOPLEFT", recipeName, "BOTTOMLEFT", 0, -4);
recipeSub:SetPoint("RIGHT", -12, 0);
recipeSub:SetJustifyH("LEFT");
local recipeNeeds = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
recipeNeeds:SetPoint("TOPLEFT", recipeIcon, "BOTTOMLEFT", 0, -8);
recipeNeeds:SetPoint("RIGHT", -12, 0);
recipeNeeds:SetJustifyH("LEFT");
local noRecipe = detail:CreateFontString(nil, "OVERLAY", "GameFontDisable");
noRecipe:SetPoint("CENTER");
noRecipe:SetText("Pick a recipe.");

-- the crafted item: its tooltip inside the panel
local preview = CreateFrame("GameTooltip", "TemucraftProfessionsPreview", detail, "GameTooltipTemplate");
preview:Hide();

-- reagents (two columns), from the bottom up over the bottom bar
local BAR_H, REAGENT_H = 34, 40;
local reagentTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal");
reagentTitle:SetText(SPELL_REAGENTS and (string.gsub(SPELL_REAGENTS, "%s*:%s*$", "")) or "Reagents");
local reagentBar = TemucraftStyle_Header(reagentTitle);
local reagents = {};
for i = 1, MAX_REAGENTS do
	local b = CreateFrame("Button", nil, detail);
	b:SetHeight(REAGENT_H - 4);
	b.icon = b:CreateTexture(nil, "ARTWORK");
	b.icon:SetWidth(32); b.icon:SetHeight(32);
	b.icon:SetPoint("LEFT", 2, 0);
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 6, -2);
	b.name:SetPoint("RIGHT", -2, 0);
	b.name:SetJustifyH("LEFT");
	b.have = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.have:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 6, 2);
	b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD");
	b:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.35);
	b:SetScript("OnEnter", function(self)
		if ( not selected ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetTradeSkillItem(selected, self.reagent);
		GameTooltip:AddLine("Shift-click: link it. Ctrl-click: try it on.", 0.6, 0.6, 0.6, true);
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	b:SetScript("OnClick", function(self)
		if ( selected and GetTradeSkillReagentItemLink ) then HandleModifiedItemClick(GetTradeSkillReagentItemLink(selected, self.reagent)); end
	end);
	b.reagent = i;
	reagents[i] = b;
end

-- the bottom bar
local bottom = CreateFrame("Frame", nil, detail);
bottom:SetPoint("BOTTOMLEFT", 8, 6); bottom:SetPoint("BOTTOMRIGHT", -8, 6); bottom:SetHeight(BAR_H - 6);
local barLine = TemucraftStyle_Line(detail);
barLine:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT", 0, 2); barLine:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 2);
local function Button(parent, label, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
	b:SetWidth(width); b:SetHeight(22);
	b:SetText(label);
	return b;
end
local createButton = Button(bottom, CREATE or "Create", 80);
createButton:SetPoint("RIGHT", 0, 0);
local createAllButton = Button(bottom, CREATE_ALL or "Create All", 96);
createAllButton:SetPoint("RIGHT", createButton, "LEFT", -4, 0);
local maxButton = Button(bottom, "Max", 40);
maxButton:SetPoint("RIGHT", createAllButton, "LEFT", -6, 0);
local plusButton = CreateFrame("Button", nil, bottom);
plusButton:SetWidth(23); plusButton:SetHeight(22);
plusButton:SetPoint("RIGHT", maxButton, "LEFT", -4, 0);
plusButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up");
plusButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down");
plusButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled");
plusButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");
local qty = CreateFrame("EditBox", "TemucraftProfessionsQuantity", bottom, "InputBoxTemplate");
qty:SetWidth(32); qty:SetHeight(20);
qty:SetPoint("RIGHT", plusButton, "LEFT", -2, 0);
qty:SetNumeric(true); qty:SetMaxLetters(3); qty:SetAutoFocus(false);
qty:SetJustifyH("CENTER");
qty:SetNumber(1);
local minusButton = CreateFrame("Button", nil, bottom);
minusButton:SetWidth(23); minusButton:SetHeight(22);
minusButton:SetPoint("RIGHT", qty, "LEFT", -6, 0);
minusButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up");
minusButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down");
minusButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled");
minusButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");
local recipeLinkButton = Button(bottom, "Recipe", 60);
recipeLinkButton:SetPoint("LEFT", 0, 0);
recipeLinkButton:SetScript("OnClick", function() if ( selected and GetTradeSkillRecipeLink ) then InsertLink(GetTradeSkillRecipeLink(selected)); end end);
recipeLinkButton:SetScript("OnEnter", function(self) Tip(self, "Link the recipe", "Puts a link to this recipe in chat."); end);
recipeLinkButton:SetScript("OnLeave", GameTooltip_Hide);
local bagButton = Button(bottom, "From bag", 70);
bagButton:SetPoint("LEFT", recipeLinkButton, "RIGHT", 4, 0);
bagButton:SetScript("OnEnter", function(self) Tip(self, "Craft from the reagent bag", "Crafts the number in the box, taking what is missing from your reagent bag."); end);
bagButton:SetScript("OnLeave", GameTooltip_Hide);
local busyText = bottom:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
busyText:SetPoint("LEFT", recipeLinkButton, "RIGHT", 8, 0);

local function Available()
	if ( not selected ) then return 0; end
	local _, _, available = GetTradeSkillInfo(selected);
	return available or 0;
end
local function SetQty(n) qty:SetNumber(n); end
minusButton:SetScript("OnClick", function() SetQty(L.Quantity(qty:GetNumber(), -1)); end);
plusButton:SetScript("OnClick", function() SetQty(L.Quantity(qty:GetNumber(), 1)); end);
maxButton:SetScript("OnClick", function() SetQty(L.Quantity(Available(), 0)); end);
qty:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
qty:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
createButton:SetScript("OnClick", function()
	if ( not selected ) then return; end
	qty:ClearFocus();
	DoTradeSkill(selected, L.Quantity(qty:GetNumber(), 0));
end);
createAllButton:SetScript("OnClick", function()
	if ( not selected ) then return; end
	local n = Available();
	if ( n <= 0 ) then return; end
	qty:ClearFocus();
	SetQty(n);
	DoTradeSkill(selected, n);
end);

-- Craft from the reagent bag (TemucraftProfGear's protocol: "RP <spell> <count>" takes the reagents out of the bag,
-- then Create once they are in the bags; the client only crafts with what is in the bags)
local pending;
local bagWatch = CreateFrame("Frame");
bagWatch:Hide();
bagWatch:SetScript("OnUpdate", function(self, elapsed)
	local p = pending;
	if ( not p ) then self:Hide(); return; end
	p.wait = p.wait - elapsed;
	local _, _, available = GetTradeSkillInfo(p.index);
	if ( available and available >= p.count ) then
		pending = nil; self:Hide();
		if ( GetTradeSkillSelectionIndex() == p.index ) then DoTradeSkill(p.index, p.count); end
	elseif ( p.wait <= 0 ) then
		pending = nil; self:Hide();
		UIErrorsFrame:AddMessage("Not enough reagents in your bags and reagent bag.", 1, 0.1, 0.1);
	end
end);
bagButton:SetScript("OnClick", function()
	if ( not selected ) then return; end
	local spell = L.SpellFromLink(GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(selected));
	if ( not spell ) then return; end
	local count = L.Quantity(qty:GetNumber(), 0);
	if ( Available() >= count ) then DoTradeSkill(selected, count); return; end
	SendAddonMessage("TPG", "RP "..spell.." "..count, "WHISPER", UnitName("player"));
	pending = { index = selected, count = count, wait = 3 };
	bagWatch:Show();
end);

-- [[ the gathering page (one profession without recipes) ]] --
local gatherBox = Inset(gatherPage);
gatherBox:SetAllPoints();
local gatherIcon = gatherBox:CreateTexture(nil, "ARTWORK");
gatherIcon:SetWidth(64); gatherIcon:SetHeight(64);
gatherIcon:SetPoint("TOP", 0, -30);
local gatherTitle = gatherBox:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
gatherTitle:SetPoint("TOP", gatherIcon, "BOTTOM", 0, -10);
local gatherNote = gatherBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
gatherNote:SetPoint("TOP", gatherTitle, "BOTTOM", 0, -8);
gatherNote:SetWidth(520);
local gatherStats = {};
for i = 1, 3 do
	local row = CreateFrame("Frame", nil, gatherBox);
	row:SetWidth(460); row:SetHeight(44);
	row:SetPoint("TOP", gatherNote, "BOTTOM", 0, -24 - (i - 1) * 50);
	row.bar = TemucraftStyle_Bar(row);
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	row.name:SetPoint("TOPLEFT", 12, -6);
	row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge");
	row.value:SetPoint("RIGHT", -12, 0);
	row.value:SetTextColor(0.4, 0.8, 1);
	row.help = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	row.help:SetPoint("BOTTOMLEFT", 12, 6);
	row.help:SetPoint("RIGHT", -70, 0);
	row.help:SetJustifyH("LEFT");
	gatherStats[i] = row;
end
local gatherNone = gatherBox:CreateFontString(nil, "OVERLAY", "GameFontDisable");
gatherNone:SetPoint("TOP", gatherNote, "BOTTOM", 0, -30);
gatherNone:SetText("No profession stats from this server.");

-- [[ the overview: every profession you know ]] --
local overviewBox = Inset(overviewPage);
overviewBox:SetAllPoints();
local overviewNote = overviewBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
overviewNote:SetPoint("BOTTOM", 0, 10);
overviewNote:SetText("Open a profession with its button at the top right. Herbalism, Skinning and Fishing show their skill and stats.");
local overviewEmpty = overviewBox:CreateFontString(nil, "OVERLAY", "GameFontDisable");
overviewEmpty:SetPoint("CENTER");
overviewEmpty:SetText("You have no professions yet. A trainer in any city teaches them.");
local overviewRows = {};
for i = 1, 14 do
	local row = CreateFrame("Button", nil, overviewBox);
	row:SetHeight(44);
	local col, r = (i - 1) % 2, math.floor((i - 1) / 2);
	row:SetWidth(370);
	row:SetPoint("TOPLEFT", 14 + col * 384, -12 - r * 50);
	row.bar = TemucraftStyle_Bar(row);
	TemucraftStyle_Highlight(row);
	row.icon = row:CreateTexture(nil, "ARTWORK");
	row.icon:SetWidth(34); row.icon:SetHeight(34);
	row.icon:SetPoint("LEFT", 6, 0);
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1);
	row.skill = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	row.skill:SetPoint("TOPRIGHT", -10, -6);
	row.stats = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	row.stats:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1);
	row.stats:SetPoint("RIGHT", -10, 0);
	row.stats:SetJustifyH("LEFT");
	row.stats:SetTextColor(0.4, 0.8, 1);
	row:SetScript("OnEnter", function(self) if ( self.prof ) then StatsTooltip(self, self.prof.id); end end);
	row:SetScript("OnLeave", GameTooltip_Hide);
	row:SetScript("OnClick", function(self)
		if ( self.prof and L.IsGathering(self.prof.id) and self.prof.id ~= 186 ) then
			page = "gather"; gatherSkill = self.prof.id; Update();
		end
	end);
	overviewRows[i] = row;
end

----------------------------------------------------------------------------------------------------------------------
-- Reading and drawing
----------------------------------------------------------------------------------------------------------------------
-- the open tradeskill's whole list (every category open: our own collapsed state is kept instead)
local function Shut()
	for i = GetNumTradeSkills(), 1, -1 do
		local _, kind, _, expanded = GetTradeSkillInfo(i);
		if ( kind == "header" and not expanded ) then return i; end
	end
	return nil;
end
function ReadEntries()
	entries = {};
	if ( not session or not GetNumTradeSkills ) then return; end
	if ( Shut() and ExpandTradeSkillSubClass ) then
		ExpandTradeSkillSubClass(0);   -- every category (0 = all, as the stock collapse-all button)
		for _ = 1, 50 do
			local i = Shut();
			if ( not i ) then break; end
			ExpandTradeSkillSubClass(i);
		end
	end
	local n = GetNumTradeSkills();
	local needReagents = (opts.search or "") ~= "";
	for i = 1, n do
		local name, kind, available = GetTradeSkillInfo(i);
		if ( name ) then
			local e = { index = i, name = name, kind = kind, available = available or 0 };
			if ( kind ~= "header" ) then
				e.spell = L.SpellFromLink(GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i));
				if ( needReagents ) then
					local names = {};
					for r = 1, (GetTradeSkillNumReagents(i) or 0) do
						local rn = GetTradeSkillReagentInfo(i, r);
						if ( rn ) then table.insert(names, string.lower(rn)); end
					end
					e.reagents = table.concat(names, "\n");
				end
			end
			table.insert(entries, e);
		end
	end
end

function currentSkill()
	if ( page == "gather" ) then return gatherSkill; end
	if ( session and page == "recipes" ) then return L.SkillId(lineName, aliases); end
	return nil;
end
function sessionSkill()
	if ( not session or Linked() ) then return nil; end
	return L.SkillId(lineName, aliases);
end

function UpdateHeader()
	local skill = currentSkill();
	local def = skill and L.PROFESSIONS[skill];
	local linked, who = Linked();
	local name, rank, maxRank, modifier;
	if ( page ~= "gather" and session and GetTradeSkillLine ) then
		name, rank, maxRank, modifier = GetTradeSkillLine();
	elseif ( skill ) then
		local p = KnownOne(skill);
		if ( p ) then name, rank, maxRank, modifier = p.name, p.rank, p.max, p.modifier; end
	end
	if ( page == "overview" or not name ) then
		profIcon:SetTexture(I.."INV_Misc_Book_11");
		profName:SetText(TRADE_SKILLS or "Professions");
		skillBar:Hide(); linkButton:Hide(); viewing:SetText("");
		statsBox:Hide(); statsSeparator:Hide();
		titleText:SetText(TRADE_SKILLS or "Professions");
		return;
	end
	local texture = (page ~= "gather" and session and GetTradeSkillTexture and GetTradeSkillTexture()) or (def and I..def[3]) or (I.."INV_Misc_QuestionMark");
	profIcon:SetTexture(texture);
	profName:SetText(name);
	titleText:SetText(linked and who and format("%s's %s", who, name) or name);
	skillBar:Show();
	skillBar:SetMinMaxValues(0, math.max(1, maxRank or 1));
	skillBar:SetValue(rank or 0);
	skillText:SetText(L.SkillText(rank, maxRank, modifier));
	if ( session and page ~= "gather" and not linked and GetTradeSkillListLink and GetTradeSkillListLink() ) then linkButton:Show(); else linkButton:Hide(); end
	viewing:SetText(linked and who and ("|cff888888"..format("Viewing %s's recipes", who).."|r") or "");
	-- someone else's profession: our stats would mean nothing there
	if ( skill and not linked ) then
		statsBox:Show(); statsSeparator:Show();
		FillStats(statsBox, statLines, skill);
	else
		statsBox:Hide(); statsSeparator:Hide();
	end
end

function UpdateList(scrolled)
	if ( not recipesPage:IsShown() ) then return; end
	if ( not scrolled ) then
		opts.collapsed, opts.favs = collapsed, Favs();
		lines = L.Lines(entries, opts);
		if ( not L.HasIndex(lines, selected) ) then
			local first = L.FirstRecipe(lines);
			-- keep the stock selection when it is on the list; else the first recipe
			local stock = GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex();
			if ( L.HasIndex(lines, stock) ) then selected = stock;
			elseif ( first ) then selected = first.index; if ( SelectTradeSkill ) then SelectTradeSkill(selected); end
			elseif ( not L.HasIndex(lines, selected) ) then selected = nil; end
		end
	end
	FauxScrollFrame_Update(scroll, #lines, NUM_ROWS, ROW_H);
	local offset = FauxScrollFrame_GetOffset(scroll);
	for i = 1, NUM_ROWS do
		local b, line = rows[i], lines[offset + i];
		b.line = line;
		if ( not line ) then
			b:Hide();
		else
			b:Show();
			if ( line.kind == "header" ) then
				b.bar:Show(); b.glow:Hide(); b.star:Hide();
				b.expand:Show();
				b.expand:SetTexture(line.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up");
				b.name:SetFontObject(GameFontNormal);
				b.name:SetText(line.favorites and ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12|t "..line.name) or line.name);
				b.name:SetTextColor(unpack(L.COLORS.header));
				b.count:SetText(line.collapsed and ("|cff888888"..line.count.."|r") or "");
				b.spell, b.fav = nil, nil;
			else
				local e = line.entry;
				b.bar:Hide(); b.expand:Hide();
				b.name:SetFontObject(GameFontNormalSmall);
				b.name:SetText(e.name);
				b.name:SetTextColor(unpack(L.COLORS[e.kind] or L.COLORS.trivial));
				b.count:SetText((e.available or 0) > 0 and ("["..e.available.."]") or "");
				b.spell, b.fav = e.spell, line.fav;
				if ( e.spell ) then
					b.star:Show();
					b.star.tex:SetVertexColor(1, 1, 1, line.fav and 1 or 0.18);
					b.star.tex:SetDesaturated(not line.fav);
				else
					b.star:Hide();
				end
				if ( e.index == selected ) then b.glow:Show(); else b.glow:Hide(); end
			end
		end
	end
	if ( #lines == 0 ) then emptyText:Show(); else emptyText:Hide(); end
	if ( not scrolled ) then UpdateDetail(); end
end

local function ReagentLayout(n)
	local rowsNeeded = math.ceil(n / 2);
	local width = (detail:GetWidth() or 480) - 24;
	for i = 1, MAX_REAGENTS do
		local b = reagents[i];
		b:ClearAllPoints();
		local col, r = (i - 1) % 2, math.floor((i - 1) / 2);
		b:SetWidth(width / 2 - 4);
		b:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 12 + col * (width / 2), BAR_H + 6 + (rowsNeeded - 1 - r) * REAGENT_H);
	end
	reagentTitle:ClearAllPoints();
	reagentTitle:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 14, BAR_H + 10 + rowsNeeded * REAGENT_H);
	return BAR_H + 30 + rowsNeeded * REAGENT_H;   -- the space they take from the bottom
end

function UpdateDetail()
	local index = selected;
	local linked = Linked();
	local name, kind, available, _, altVerb;
	if ( index ) then name, kind, available, _, altVerb = GetTradeSkillInfo(index); end
	if ( not name or kind == "header" ) then
		recipeIcon:Hide(); recipeName:SetText(""); recipeSub:SetText(""); recipeNeeds:SetText("");
		preview:Hide(); reagentTitle:Hide(); reagentBar:Hide();
		for i = 1, MAX_REAGENTS do reagents[i]:Hide(); end
		bottom:Hide(); barLine:Hide();
		noRecipe:Show();
		return;
	end
	noRecipe:Hide();
	recipeIcon:Show(); bottom:Show(); barLine:Show();
	recipeIcon:SetNormalTexture(GetTradeSkillIcon(index));
	local minMade, maxMade = GetTradeSkillNumMade(index);
	recipeIcon.made:SetText(L.Made(minMade, maxMade));
	-- the name in the crafted item's quality colour (enchants and the like: white)
	local itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(index);
	local quality = itemLink and select(3, GetItemInfo(itemLink));
	local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality];
	recipeName:SetText(name);
	if ( qc ) then recipeName:SetTextColor(qc.r, qc.g, qc.b); else recipeName:SetTextColor(1, 1, 1); end
	local sub = {};
	local c = L.COLORS[kind] or L.COLORS.trivial;
	local diff = ({ optimal = "Orange: always a skill point", medium = "Yellow: likely a skill point", easy = "Green: sometimes a skill point", trivial = "Grey: no more skill points" })[kind];
	if ( diff and not linked ) then table.insert(sub, format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, diff)); end
	local made = L.Made(minMade, maxMade);
	if ( made ~= "" ) then table.insert(sub, "Makes "..made); end
	recipeSub:SetText(table.concat(sub, "    "));
	-- what is still missing (tools, anvil, forge, totems) and the cooldown; what the client says you have is left out
	local needs = {};
	local missing = GetTradeSkillTools and L.Missing(GetTradeSkillTools(index)) or {};
	if ( #missing > 0 ) then table.insert(needs, "|cffff2020"..(REQUIRES_LABEL or "Requires:").." "..table.concat(missing, ", ").."|r"); end
	local cooldown = GetTradeSkillCooldown and GetTradeSkillCooldown(index);
	if ( cooldown and cooldown > 0 ) then table.insert(needs, "|cffff2020"..(COOLDOWN_REMAINING or "Cooldown remaining:").." "..SecondsToTime(cooldown).."|r"); end
	recipeNeeds:SetText(table.concat(needs, "\n"));
	-- reagents
	local n = GetTradeSkillNumReagents(index) or 0;
	local used = ReagentLayout(n);
	if ( n > 0 ) then reagentTitle:Show(); reagentBar:Show(); else reagentTitle:Hide(); reagentBar:Hide(); end
	for i = 1, MAX_REAGENTS do
		local b = reagents[i];
		if ( i <= n ) then
			local rName, rTexture, need, have = GetTradeSkillReagentInfo(index, i);
			b.icon:SetTexture(rTexture);
			b.name:SetText(rName or "...");
			have, need = have or 0, need or 0;
			if ( have >= need ) then
				b.have:SetText(format("|cffffffff%d / %d|r", have, need));
				b.icon:SetVertexColor(1, 1, 1); b.name:SetTextColor(1, 1, 1);
			else
				b.have:SetText(format("|cffff2020%d / %d|r", have, need));
				b.icon:SetVertexColor(0.5, 0.5, 0.5); b.name:SetTextColor(0.6, 0.6, 0.6);
			end
			b:Show();
		else
			b:Hide();
		end
	end
	-- the crafted item's tooltip between the header lines and the reagents (scaled down when it is too big)
	local topY = 64 + ((recipeNeeds:GetText() or "") ~= "" and (recipeNeeds:GetHeight() + 8) or 0);
	local room = (detail:GetHeight() or 400) - topY - used - 4;
	local roomW = (detail:GetWidth() or 480) - 20;
	preview:SetOwner(detail, "ANCHOR_NONE");
	preview:SetScale(1);
	preview:ClearAllPoints();
	preview:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -topY);
	preview:SetTradeSkillItem(index);
	preview:Show();
	preview:SetBackdropColor(0, 0, 0, 0);
	preview:SetBackdropBorderColor(0, 0, 0, 0);
	preview:SetFrameStrata(detail:GetFrameStrata());
	preview:SetFrameLevel(detail:GetFrameLevel() + 3);
	local h, w = preview:GetHeight() or 1, preview:GetWidth() or 1;
	local scale = math.min(1, room / math.max(h, 1), roomW / math.max(w, 1));
	if ( room < 30 ) then preview:Hide();
	elseif ( scale < 1 ) then
		preview:SetScale(scale);
		preview:ClearAllPoints();
		preview:SetPoint("TOPLEFT", detail, "TOPLEFT", 8 / scale, -topY / scale);
	end
	-- the bottom bar: someone else's recipes can't be made here
	local canMake = not linked and (available or 0) > 0 and not (cooldown and cooldown > 0);
	local bagOn = IsAddOnLoaded and IsAddOnLoaded("TemucraftProfGear") and not linked and not altVerb;
	for _, f in ipairs({ createButton, createAllButton, maxButton, plusButton, minusButton, qty }) do
		if ( linked ) then f:Hide(); else f:Show(); end
	end
	if ( altVerb and not linked ) then
		-- enchanting (Enchant) and the like: one at a time, as in the stock window
		createAllButton:Hide(); maxButton:Hide(); plusButton:Hide(); minusButton:Hide(); qty:Hide();
	end
	createButton:SetText(altVerb or CREATE or "Create");
	createAllButton:SetText(format("%s%s", CREATE_ALL or "Create All", (available or 0) > 0 and (" ("..available..")") or ""));
	if ( canMake ) then createButton:Enable(); createAllButton:Enable(); maxButton:Enable(); else createButton:Disable(); createAllButton:Disable(); maxButton:Disable(); end
	if ( bagOn and not (cooldown and cooldown > 0) ) then bagButton:Show(); else bagButton:Hide(); end
	busyText:SetText(linked and "Someone else's recipes: you can link them." or "");
end

local function UpdateGather()
	local skill = gatherSkill;
	local def = skill and L.PROFESSIONS[skill];
	if ( not def ) then return; end
	local p = KnownOne(skill);
	gatherIcon:SetTexture(I..def[3]);
	gatherTitle:SetText(p and p.name or def[1]);
	if ( skill == 356 ) then
		gatherNote:SetText("Fishing has no recipes: cast Fishing from your spellbook near water. Its skill rises as you fish.");
	else
		gatherNote:SetText(format("%s has no recipes: its skill rises as you gather. Your stats:", p and p.name or def[1]));
	end
	local list = L.Stats(skill, stats[skill]);
	for i = 1, 3 do
		local row, s = gatherStats[i], list[i];
		if ( s ) then
			row.name:SetText(s[1]); row.value:SetText(s[2].."%"); row.help:SetText(s[3]); row:Show();
		else
			row:Hide();
		end
	end
	if ( #list == 0 ) then gatherNone:Show(); else gatherNone:Hide(); end
end

local function UpdateOverview()
	local known = Known();
	for i, row in ipairs(overviewRows) do
		local p = known[i];
		row.prof = p;
		if ( p ) then
			local def = L.PROFESSIONS[p.id];
			row.icon:SetTexture(I..def[3]);
			row.name:SetText(p.name);
			row.skill:SetText(L.SkillText(p.rank, p.max, p.modifier));
			local parts = {};
			for _, s in ipairs(L.Stats(p.id, stats[p.id])) do table.insert(parts, format("%s %d%%", s[1], s[2])); end
			row.stats:SetText(table.concat(parts, "   "));
			row:Show();
		else
			row:Hide();
		end
	end
	if ( #known == 0 ) then overviewEmpty:Show(); else overviewEmpty:Hide(); end
end

function UpdatePages()
	if ( page == "recipes" and not session ) then page = "overview"; end
	if ( page == "recipes" ) then recipesPage:Show(); else recipesPage:Hide(); end
	if ( page == "gather" ) then gatherPage:Show(); else gatherPage:Hide(); end
	if ( page == "overview" ) then overviewPage:Show(); else overviewPage:Hide(); end
	for _, t in ipairs(tabs) do
		if ( t.key == page ) then t.glow:Show(); else t.glow:Hide(); end
		if ( t.key == "recipes" and not session ) then t.text:SetTextColor(0.5, 0.5, 0.5); else t.text:SetTextColor(1, 0.82, 0); end
	end
end

function Update()
	if ( not frame:IsShown() ) then return; end
	UpdatePages();
	UpdateHeader();
	if ( page == "recipes" ) then ReadEntries(); UpdateList();
	elseif ( page == "gather" ) then UpdateGather();
	else UpdateOverview(); end
	RefreshSwitcher();
end

-- many events come at once (after a craft: bags, skill, list): one redraw on the next frame
local dirty = CreateFrame("Frame");
dirty:Hide();
dirty:SetScript("OnUpdate", function(self) self:Hide(); Update(); end);
local function Later() if ( frame:IsShown() ) then dirty:Show(); end end

frame:SetScript("OnShow", function()
	PlaySound("igCharacterInfoOpen");
	SyncSwitcher();
	AskStats();
	Update();
end);
frame:SetScript("OnHide", function()
	PlaySound("igCharacterInfoClose");
	SyncSwitcher();
	pending = nil;
	if ( session ) then
		session = false;
		if ( CloseTradeSkill ) then CloseTradeSkill(); end
	end
	page = "recipes";
end);

----------------------------------------------------------------------------------------------------------------------
-- Taking the stock window's place
----------------------------------------------------------------------------------------------------------------------
local REPLACEMENTS = { "Skillet", "AdvancedTradeSkillWindow", "ATSW" };
function TemucraftProfessions_IsActive()
	if ( TemucraftUI_IsClassic and TemucraftUI_IsClassic("tradeskill") ) then return false; end
	for _, name in ipairs(REPLACEMENTS) do
		if ( IsAddOnLoaded(name) ) then return false; end
	end
	return true;
end

-- a tradeskill opened (UIParent's TRADE_SKILL_SHOW -> TradeSkillFrame_Show)
local closing = 0;
local function Opened()
	closing = 0;
	local name = GetTradeSkillLine and GetTradeSkillLine();
	local _, who = Linked();
	local key = (name or "").."|"..(who or "");
	local isNew = not session or key ~= lineKey;
	session, lineName, lineKey = true, name, key;
	if ( isNew ) then
		selected = nil; collapsed = {};
		opts.search = ""; search:SetText("");
		-- stock filters left on by the classic window would hide recipes here
		if ( SetTradeSkillSubClassFilter ) then SetTradeSkillSubClassFilter(0, 1, 1); end
		if ( SetTradeSkillInvSlotFilter ) then SetTradeSkillInvSlotFilter(0, 1, 1); end
		if ( SetTradeSkillItemNameFilter ) then SetTradeSkillItemNameFilter(""); end
		if ( SetTradeSkillItemLevelFilter ) then SetTradeSkillItemLevelFilter(0, 0); end
		if ( TradeSkillOnlyShowMakeable ) then TradeSkillOnlyShowMakeable(false); end
		SetQty(1);
	end
	page = "recipes";
	if ( frame:IsShown() ) then Update(); else ShowUIPanel(frame); end
	if ( not frame:IsShown() ) then frame:Show(); end   -- (a UI panel that did not fit)
end

-- the tradeskill closed (TRADE_SKILL_CLOSE): switching professions closes one and opens the next, so the window waits
-- a moment before it goes
local closer = CreateFrame("Frame");
closer:Hide();
closer:SetScript("OnUpdate", function(self, elapsed)
	closing = closing - elapsed;
	if ( closing > 0 ) then return; end
	self:Hide();
	if ( session ) then return; end
	if ( frame:IsShown() and page == "recipes" ) then HideUIPanel(frame); else Later(); end
end);
local function Closed()
	if ( not session ) then return; end
	session = false;
	closing = 0.3;
	closer:Show();
end

local hooked = false;
local function Hook()
	if ( hooked or not TradeSkillFrame_Show ) then return; end
	hooked = true;
	local stockShow, stockHide = TradeSkillFrame_Show, TradeSkillFrame_Hide;
	TradeSkillFrame_Show = function(...)
		if ( TemucraftProfessions_IsActive() ) then
			if ( TradeSkillFrame and TradeSkillFrame:IsShown() ) then HideUIPanel(TradeSkillFrame); end
			Opened();
			return;
		end
		if ( frame:IsShown() ) then session = false; HideUIPanel(frame); end
		return stockShow(...);
	end
	TradeSkillFrame_Hide = function(...)
		Closed();
		if ( stockHide ) then return stockHide(...); end
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Events, the option, /professions
----------------------------------------------------------------------------------------------------------------------
local events = CreateFrame("Frame");
events:RegisterEvent("ADDON_LOADED");
events:RegisterEvent("PLAYER_LOGIN");
events:RegisterEvent("TRADE_SKILL_UPDATE");
events:RegisterEvent("TRADE_SKILL_FILTER_UPDATE");
events:RegisterEvent("UPDATE_TRADESKILL_RECAST");
events:RegisterEvent("BAG_UPDATE");
events:RegisterEvent("SKILL_LINES_CHANGED");
events:RegisterEvent("CHAT_MSG_ADDON");
events:RegisterEvent("PLAYER_REGEN_DISABLED");
events:RegisterEvent("PLAYER_REGEN_ENABLED");
events:SetScript("OnEvent", function(self, event, a1, a2, a3, a4)
	if ( event == "ADDON_LOADED" ) then
		if ( a1 == "Blizzard_TradeSkillUI" ) then Hook(); end
	elseif ( event == "PLAYER_LOGIN" ) then
		if ( IsAddOnLoaded("Blizzard_TradeSkillUI") ) then Hook(); end
	elseif ( event == "CHAT_MSG_ADDON" ) then
		if ( a1 ~= "TPG" or a4 ~= UnitName("player") ) then return; end
		local kind, data = string.match(a2 or "", "^(%u%u) ?(.*)$");
		if ( kind == "SS" ) then stats = L.ParseStats(data); Later();
		elseif ( kind == "ER" ) then pending = nil; end
	elseif ( event == "UPDATE_TRADESKILL_RECAST" ) then
		if ( GetTradeskillRepeatCount and frame:IsShown() ) then SetQty(math.max(1, GetTradeskillRepeatCount())); end
	elseif ( event == "PLAYER_REGEN_DISABLED" ) then
		-- the last moment the secure buttons can be hidden (and let go of the window, which may move in combat)
		switcher:Hide();
		switcher:ClearAllPoints();
		if ( frame:IsShown() ) then combatNote:Show(); end
	elseif ( event == "PLAYER_REGEN_ENABLED" ) then
		SyncSwitcher();
	elseif ( event == "SKILL_LINES_CHANGED" ) then
		if ( frame:IsShown() ) then AskStats(); Later(); end
	else
		Later();
	end
end);

-- back to the stock window while ours is open: it closes (the next profession opens the stock one)
if ( TemucraftUI_OnChange ) then
	TemucraftUI_OnChange("classictradeskill", function(on) if ( on and frame:IsShown() ) then HideUIPanel(frame); end end);
end

SLASH_TEMUCRAFTPROFESSIONS1 = "/professions";
SLASH_TEMUCRAFTPROFESSIONS2 = "/tprof";
SlashCmdList["TEMUCRAFTPROFESSIONS"] = function()
	if ( frame:IsShown() ) then HideUIPanel(frame); return; end
	if ( not TemucraftProfessions_IsActive() ) then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Temucraft:|r the classic professions window is in use (/tui).");
		return;
	end
	page = session and "recipes" or "overview";
	ShowUIPanel(frame);
end;
function TemucraftProfessions_Toggle() SlashCmdList["TEMUCRAFTPROFESSIONS"](); end

-- the character window's Professions page: this window on one profession, the page of one without recipes (its
-- skill and stats: Herbalism, Skinning, Fishing; also any profession while in combat, when casting can't open it)
function TemucraftProfessions_ShowSkill(id)
	if ( not TemucraftProfessions_IsActive() or not L.PROFESSIONS[id] or not KnownOne(id) ) then return false; end
	page = "gather"; gatherSkill = id;
	if ( frame:IsShown() ) then Update(); else ShowUIPanel(frame); end
	return true;
end
