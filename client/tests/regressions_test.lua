-- Regression tests for the client bugs fixed 2026-11-24 .. 26 (no client): lua5.1 client/tests/regressions_test.lua
-- (from the module folder). One check per bug, on the WoW API mock (wowmock.lua) with the whole patch-^ loaded.
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
local M = dofile(dir.."/tests/wowmock.lua");
M.dir = dir;
local failed = 0;
local function check(name, ok, detail)
	if ( not ok ) then failed = failed + 1; print("FAIL "..name); if ( detail ) then print("     "..tostring(detail)); end
	else print("ok   "..name); end
end
local function noErrors(env, from) return #env.__errors == from, table.concat(M.errors(env, from), "\n"); end
local function count(list, pattern)
	local n = 0;
	for _, l in ipairs(list) do if ( string.find(l, pattern) ) then n = n + 1; end end
	return n;
end

---------------------------------------------------------------------------------------------------------------------
-- FrameXML, as the client has it before our files run
---------------------------------------------------------------------------------------------------------------------
local env = M.new();
env.__player.level = 80;
local menu = env.CreateFrame("Frame", "GameMenuFrame", env.UIParent);
menu:Hide();
for _, name in ipairs({ "GameMenuButtonOptions", "GameMenuButtonSoundOptions", "GameMenuButtonUIOptions", "GameMenuButtonKeybindings",
	"GameMenuButtonMacros", "GameMenuButtonRatings", "GameMenuButtonLogout", "GameMenuButtonQuit", "GameMenuButtonContinue" }) do
	local b = env.CreateFrame("Button", name, menu, "GameMenuButtonTemplate");
	b:SetWidth(144);
end
-- the game's own tutorial tip button, shown by the client on a new login
local tip = env.CreateFrame("Button", "TutorialFrameAlertButton", env.UIParent);
for _, f in ipairs(M.tocFiles(dir.."/build_mpq.py", "FRAME_FILES")) do M.load(env, dir.."/Interface/FrameXML/"..f); end
check("patch-^ loads", noErrors(env, 0));
env.__loggedIn = true;
M.fire(env, "PLAYER_LOGIN");
M.fire(env, "PLAYER_ENTERING_WORLD");
M.tick(env, 20);

-- 1. Tooltips (98abd74): our lines once per build, in one fixed order, and only the client's cooldown line
do
	local e0 = #env.__errors;
	local tt = env.GameTooltip;
	local function build()
		tt:SetOwner(env.UIParent, "ANCHOR_NONE");
		tt:SetSpell(5, "spell");                       -- Charge, 15 s cooldown (wowmock_api.lua)
		M.tick(env, 2);
		return tt:Lines();
	end
	local first = build();
	local again = build();
	M.tick(env, 3);                                    -- the 0.2 s refreshes of DragonUI's book / the bars
	local later = tt:Lines();
	check("tooltip: built once (same lines every refresh, none added a frame later)",
		table.concat(first, "\n") == table.concat(again, "\n") and table.concat(again, "\n") == table.concat(later, "\n"),
		table.concat(first, " / ").." <> "..table.concat(later, " / "));
	check("tooltip: one SpellID line", count(later, "SpellID: 100") == 1, table.concat(later, " / "));
	check("tooltip: one cooldown line (the client's)", count(later, "[Cc]ooldown") == 1, table.concat(later, " / "));
	-- the order the providers say: each of our lines after the ones with a lower order
	local order = {};
	for _, p in ipairs(TemucraftTooltipsLogic and TemucraftTooltipsLogic.Sorted(env.TemucraftTooltipLines, "spell") or env.TemucraftTooltipsLogic.Sorted(env.TemucraftTooltipLines, "spell")) do table.insert(order, p.order); end
	local sorted = true;
	for i = 2, #order do if ( order[i] < order[i - 1] ) then sorted = false; end end
	check("tooltip: providers in a fixed order", #order >= 2 and sorted);
	check("tooltip: no errors", noErrors(env, e0));
end

-- 2. Esc menu (6ba9764): every row anchored to the menu's top; an addon's button anchored to a stock one is no loop
do
	local e0 = #env.__errors;
	local dui = env.CreateFrame("Button", "DragonUIGameMenuButton", menu, "GameMenuButtonTemplate");
	dui:SetWidth(144);
	dui:SetPoint("TOP", env.GameMenuButtonContinue, "BOTTOM", 0, -1);    -- what DragonUI does
	env.GameMenuButtonContinue:SetPoint("TOP", env.GameMenuButtonQuit, "BOTTOM", 0, -1);
	menu:Show();
	M.tick(env, 2);
	local ok, rows, bad = true, 0, {};
	for _, b in ipairs({ menu:GetChildren() }) do
		if ( b:IsShown() and b:GetObjectType() == "Button" and b:GetNumPoints() > 0 ) then
			rows = rows + 1;
			local _, rel = b:GetPoint(1);
			if ( b:GetNumPoints() ~= 1 or rel ~= menu ) then ok = false; table.insert(bad, b:GetName() or "?"); end
		end
	end
	check("Esc menu: every row on the menu's top ("..rows.." rows)", ok and rows >= 8, table.concat(bad, ", "));
	check("Esc menu: no circular anchor", count(M.errors(env, e0), "dependent") == 0, table.concat(M.errors(env, e0), "\n"));
	menu:Hide();
end

-- 3. ScrollingEdit boxes (4d2f637): Guild and Issue Reporter boxes start with a cursor offset
do
	local e0 = #env.__errors;
	env.TemucraftGuild_Toggle(); M.tick(env, 2);
	env.TemucraftIssues_Open(); M.tick(env, 2);
	local boxes, ok = 0, true;
	for _, f in ipairs(env.__frames) do
		if ( f.kind == "EditBox" and f.scripts.OnCursorChanged == env.ScrollingEdit_OnCursorChanged ) then
			boxes = boxes + 1;
			if ( type(f.cursorOffset) ~= "number" or type(f.cursorHeight) ~= "number" ) then ok = false; end
			f:SetText("text set before the box ever had a cursor");    -- ScrollingEdit_OnTextChanged -> OnUpdate
		end
	end
	M.tick(env, 2);
	check("ScrollingEdit boxes have cursorOffset ("..boxes.." boxes)", ok and boxes >= 2);
	check("ScrollingEdit: a SetText before any cursor is no error", noErrors(env, e0));
end

-- 4. Tutorial (f704d31): nothing on a character that doesn't get it (level 80)
do
	tip:Show();     -- the client shows its tip button again later
	M.tick(env, 5);
	local any = false;
	for _, f in ipairs(env.__frames) do
		if ( type(f.name) == "string" and string.find(f.name, "^TemucraftTutorial") and f.isFrame and f.parent == env.UIParent and f:IsShown() ) then any = f.name; end
	end
	check("tutorial: no tutorial frame on a level 80 character", not any, any);
	check("tutorial: the game's tip button stays hidden", not tip:IsShown());
end

-- 5. Options sliders (a8db045 / 08631c4): name left and value right on the line above the bar
do
	local e0 = #env.__errors;
	env.TemucraftOptions_Open(); M.tick(env, 2);
	-- every page once, so the sliders are made
	for _, page in ipairs(env.TemucraftOptionsLogic.PAGES or {}) do env.TemucraftOptions_Open(page.title); M.tick(env, 2); end
	local sliders, ok, bad = 0, true, nil;
	for i = 1, 200 do
		local s, value = rawget(env, "TemucraftOptionsSlider"..i), rawget(env, "TemucraftOptionsSlider"..i.."Value");
		if ( not s ) then break; end
		sliders = sliders + 1;
		local r = s:GetParent();
		local vp, vrel, vrp = value:GetPoint(1);
		local _, nextB = nil, vrel;
		local sp = { s:GetPoint(1) };
		local lp = { r.label and r.label:GetPoint(1) };
		-- value: its bottom right on the top right of the > button right of the bar; label: the row's top left
		if ( vp ~= "BOTTOMRIGHT" or vrp ~= "TOPRIGHT" or select(2, vrel:GetPoint(1)) ~= s or lp[1] ~= "TOPLEFT" ) then ok = false; bad = "slider "..i; end
	end
	check("Options sliders: label left, value right above the bar ("..sliders.." sliders)", ok and sliders > 0, bad);
	check("Options: no errors", noErrors(env, e0));
	env.TemucraftOptionsFrame:Hide();
end

-- 6. Reputation hosted in DragonUI's smaller window (2026-11-26): the rows fit the pane, the scroll bar shows
do
	local L = env.TemucraftReputationLogic;
	env.__factions = {};
	table.insert(env.__factions, { name = "Classic", header = true });
	for i = 1, 30 do table.insert(env.__factions, { name = "Faction "..i, id = 100 + i, child = true }); end
	table.insert(env.__factions, { name = "Horde", header = true });
	env.ToggleCharacter("ReputationFrame"); M.tick(env, 2);
	-- right after the move into DragonUI's pane: GetHeight still has our window's 17 rows, the drawn list is 300 px high
	L.listBox.rect = { left = 0, right = 400, top = 300, bottom = 0 };
	env.TemucraftReputation_SetLayout(true, env.UIParent);
	local shown = 0;
	for _, b in ipairs(L.rows) do if ( b:IsShown() ) then shown = shown + 1; end end
	check("reputation (hosted): rows fit the pane ("..shown.." of "..#L.rows..")", shown == L.RowsFor(300) and shown < #L.rows);
	check("reputation (hosted): the scroll bar shows", env.TemucraftReputationScroll.scrollBarShown == true);
	-- not laid out yet: a few rows, then the real count a frame later
	L.listBox.rect = nil;
	L.listBox.GetTop = function() return nil; end
	L.listBox.GetBottom = function() return nil; end
	env.TemucraftReputationFrame:Hide(); env.TemucraftReputationFrame:Show();
	shown = 0;
	for _, b in ipairs(L.rows) do if ( b:IsShown() ) then shown = shown + 1; end end
	check("reputation (hosted, not laid out): never the 17 rows of our own window", shown < #L.rows);
	env.TemucraftReputation_SetLayout(false);
	env.TemucraftReputationFrame:Hide();
end

-- 7. Professions page with no professions (2026-11-26): no lone sub-tab, the hint on short lines
do
	local L = env.TemucraftCharacterLogic;
	check("professions: no sub-tab row with one page", L.ProfSubTabs(false).show == false and L.ProfSubTabs(false).top == 0
		and L.ProfSubTabs(true).show == true);
	local longest = 0;
	for line in string.gmatch(L.PROF_HINT, "[^\n]+") do longest = math.max(longest, string.len(line)); end
	check("professions: hint lines short enough for DragonUI's pane", longest <= 48, L.PROF_HINT);
	env.TemucraftCharacter_Open("prof"); M.tick(env, 2);
	check("professions: the lone Professions sub-tab is hidden", not env.TemucraftCharacterProfSubTab1:IsShown());
end

-- 8. Starting zone window (f9ba6aa): "Stay in ..." first, whatever order the server sends
do
	local L = env.TemucraftStartingZoneLogic;
	L.OnMessage("BEGIN~3");
	L.OnMessage("Z~2~0~0~85~154~1676.7~1678.3~Deathknell");
	L.OnMessage("Z~4~0~1~215~222~-2917.6~-257.9~Camp Narache");
	L.OnMessage("Z~0~1~1~14~363~-618.5~-4251.7~Valley of Trials");
	L.OnMessage("END");
	check("starting zone: Stay in ... first", L.CardTitle(L.zones[1]) == "Stay in Valley of Trials" and L.zones[2].name == "Deathknell");
end

---------------------------------------------------------------------------------------------------------------------
-- GlueXML
---------------------------------------------------------------------------------------------------------------------
local glue = M.new();
-- the stock name box: its "NAME" label (faction font) and its own text, both FontString regions
local create = glue.CreateFrame("Frame", "CharacterCreate", glue.UIParent); create:Hide();
local edit = glue.CreateFrame("EditBox", "CharacterCreateNameEdit", create);
local label = edit:CreateFontString(nil, "OVERLAY", glue.FactionName_Shadow_Huge); label:SetText("NAME");
local typed = edit:CreateFontString(nil, "OVERLAY", glue.GlueEditBoxFont); typed:SetText("Ryan");
local select_ = glue.CreateFrame("Frame", "CharacterSelect", glue.UIParent); select_:Hide();
glue.GetNumCharacters = function() return 1; end
glue.GetCharacterInfo = function(i) if ( i == 1 ) then return "Thrall", "Orc", "Shaman", 80, "Orgrimmar", 2, false, false, false, false; end end
for _, f in ipairs(M.tocFiles(dir.."/build_mpq.py", "GLUE_FILES")) do M.load(glue, dir.."/Interface/GlueXML/"..f); end
for _, f in ipairs(M.tocFiles(dir.."/build_mpq.py", "ROOT_GLUE_FILES")) do M.load(glue, dir.."/Interface/"..f); end
check("glue files load", noErrors(glue, 0));

-- 9. Character create (1ba5a47): the typed name stays visible, only the stock NAME label goes
do
	local e0 = #glue.__errors;
	create:Show(); M.tick(glue, 2);
	check("name box: typed text visible, NAME label hidden", typed:IsShown() and not label:IsShown());
	check("character create: no errors", noErrors(glue, e0));
	create:Hide();
end

-- 10. Character select (1ba5a47): the card number on every card, also with one character
do
	local e0 = #glue.__errors;
	select_:Show();
	M.fire(glue, "CHARACTER_LIST_UPDATE");
	M.tick(glue, 3);
	local found, numbered = 0, 0;
	for _, f in ipairs(glue.__frames) do
		if ( f.num and f.char ) then
			found = found + 1;
			if ( f.num:IsShown() and f.num:GetText() == "1." ) then numbered = numbered + 1; end
		end
	end
	if ( found == 0 ) then
		-- the screen didn't build its cards on the mock: the rule itself
		check("character select: card number with one character", glue.TemucraftSelectLogic.CardNumber({ place = 1 }) == "1.");
	else
		check("character select: card number with one character", numbered == found and found == 1, found.." cards, "..numbered.." numbered");
	end
	check("character select: no errors", noErrors(glue, e0));
end

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
