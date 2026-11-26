-- Load test for patch-^ (no client): lua5.1 client/tests/load_test.lua (from the module folder)
-- Every file of the patch in the order of the generated FrameXML.toc / GlueXML.toc (build_mpq.py's lists) on the
-- WoW API mock (wowmock.lua), then the login events, then each of our windows opened (and closed). Any Lua error fails.
-- A second pass opens the windows again in combat: a protected (secure) frame changed then is an error too.
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
local M = dofile(dir.."/tests/wowmock.lua");
M.dir = dir;
local failed = 0;
local function check(name, ok, detail)
	if ( not ok ) then failed = failed + 1; print("FAIL "..name); if ( detail ) then print(detail); end else print("ok   "..name); end
end
local function errorsSince(env, n, label)
	local list = M.errors(env, n);
	check(label, #list == 0, table.concat(list, "\n"));
	return #env.__errors;
end

---------------------------------------------------------------------------------------------------------------------
-- FrameXML
---------------------------------------------------------------------------------------------------------------------
local frameFiles = M.tocFiles(dir.."/build_mpq.py", "FRAME_FILES");
check("FrameXML.toc lists our files", #frameFiles >= 40);
local env = M.new();
local n = 0;
for _, f in ipairs(frameFiles) do
	M.load(env, dir.."/Interface/FrameXML/"..f);
	n = errorsSince(env, n, "loads: "..f);
end
-- the game's startup: addons loaded, saved variables, login, the world
M.fire(env, "ADDON_LOADED", "Blizzard_TimeManager");
M.fire(env, "VARIABLES_LOADED");
env.__loggedIn = true;
M.fire(env, "PLAYER_LOGIN");
M.fire(env, "PLAYER_ENTERING_WORLD");
M.fire(env, "UPDATE_FACTION");
M.fire(env, "SKILL_LINES_CHANGED");
M.fire(env, "SPELLS_CHANGED");
M.tick(env, 30);
n = errorsSince(env, n, "PLAYER_LOGIN / PLAYER_ENTERING_WORLD and 3 s of OnUpdate");

-- our windows: open, a few frames, close
local function call(label, fn)
	local ok, err = xpcall(fn, debug.traceback);
	if ( not ok ) then table.insert(env.__errors, { label, err }); end
	M.tick(env, 3);
end
local function slash(cmd, msg)
	for key, handler in pairs(env.SlashCmdList) do
		for i = 1, 9 do
			local s = rawget(env, "SLASH_"..key..i);
			if ( s == cmd ) then return handler(msg or ""); end
		end
	end
	error("no slash command "..cmd);
end
local function shown(name) local f = rawget(env, name); return f and f:IsShown(); end

local WINDOWS = {
	{ "Options", function() env.TemucraftOptions_Open(); end, "TemucraftOptionsFrame" },
	{ "Esc menu", function() env.GameMenuFrame:Show(); end, nil },
	{ "Character: Character", function() env.ToggleCharacter("PaperDollFrame"); end, "TemucraftCharacterFrame" },
	{ "Character: Reputation", function() env.ToggleCharacter("ReputationFrame"); end, "TemucraftReputationFrame" },
	{ "Character: Skills", function() env.ToggleCharacter("SkillFrame"); end, nil },
	{ "Character: Currency", function() env.ToggleCharacter("TokenFrame"); end, nil },
	{ "Character: Professions", function() env.TemucraftCharacter_Open("prof"); end, nil },
	{ "Spellbook", function() env.ToggleSpellBook("spell"); end, "TemucraftPlayerSpellsFrame" },
	{ "Spellbook: every tab (Racials too)", function()
		env.ToggleSpellBook("spell");
		for i = 1, 8 do local tab = rawget(env, "TemucraftSpellBookTab"..i) or rawget(env, "SpellBookSkillLineTab"..i); if ( tab and tab.Click ) then tab:Click(); end end
	end, nil },
	{ "Talents", function() env.ToggleTalentFrame(); end, nil },
	{ "Professions", function() env.TemucraftProfessions_Toggle(); end, "TemucraftProfessionsFrame" },
	{ "Achievements", function() env.TemucraftAchievements_Toggle(); end, "TemucraftAchievementFrame" },
	{ "Adventure Guide", function() env.TemucraftAdventureGuide_Toggle(); end, "TemucraftAdventureGuideFrame" },
	{ "Group Finder", function() env.TemucraftGroupFinder_Open(); end, "TemucraftGroupFinderFrame" },
	{ "PvP", function() env.TogglePVPFrame(); end, nil },
	{ "Collections", function() env.TemucraftCollections_Toggle(); end, "TemucraftCollectionsFrame" },
	{ "Guild", function() env.TemucraftGuild_Toggle(); end, nil },
	{ "Issue Reporter", function() env.TemucraftIssues_Open(); end, nil },
	{ "AddOns", function() env.TemucraftAddOnList_Toggle(); end, nil },
	-- the starting zone window opens on the server's list (prefix TSZ, whispered to the player)
	{ "Starting zone", function()
		for _, m in ipairs({ "BEGIN~3", "Z~0~1~0~12~9~-8949.9~-132.5~Northshire", "Z~2~0~0~85~154~1676.7~1678.3~Deathknell",
			"Z~4~0~1~215~222~-2917.6~-257.9~Camp Narache", "END" }) do
			M.fire(env, "CHAT_MSG_ADDON", "TSZ", m, "WHISPER", "Tester");
		end
	end, "TemucraftStartingZoneFrame" },
	{ "Tutorial", function() slash("/ttutorial", ""); end, nil },
};

local function openAll(label)
	for _, w in ipairs(WINDOWS) do
		local before = #env.__errors;
		call(w[1], w[2]);
		-- (with DragonUI running, its own windows take some of these over: ours stay hidden then)
		if ( w[3] and label ~= "DragonUI" ) then check(label..": "..w[1].." shows", shown(w[3])); end
		call(w[1].." (Escape)", function() env.CloseAllWindows(); for _, name in ipairs(env.UISpecialFrames) do local f = rawget(env, name); if ( f and f.Hide ) then f:Hide(); end end end);
		n = errorsSince(env, before, label..": "..w[1]);
	end
end
openAll("open");
-- every slash command once (each one's own window or answer)
local before = #env.__errors;
for key, handler in pairs(env.SlashCmdList) do call("/"..key, function() handler(""); end); end
n = errorsSince(env, before, "every slash command runs");

-- in combat: no protected frame may change
env.__combat = true;
M.fire(env, "PLAYER_REGEN_DISABLED");
openAll("in combat");
env.__combat = false;
M.fire(env, "PLAYER_REGEN_ENABLED");
M.tick(env, 5);
n = errorsSince(env, n, "out of combat again");

---------------------------------------------------------------------------------------------------------------------
-- FrameXML with DragonUI running (its character window hosts our Reputation and Professions pages)
---------------------------------------------------------------------------------------------------------------------
env = M.new();
env.__addons.DragonUI = true;
env.DragonUI = { db = { profile = {} }, IsModuleEnabled = function() return true; end,
	CharacterPanel = { OWNED_TABS = {}, SUBFRAMES = {}, SUBFRAME_LEVEL = 10, TAB_GAP = 1 } };
local cf = env.CreateFrame("Frame", "CharacterFrame", env.UIParent);
cf:Hide();
cf.Inset = env.CreateFrame("Frame", nil, cf);
for i = 1, 6 do env.CreateFrame("Button", "CharacterFrameTab"..i, cf); end
env.CharacterFrame_ShowSubFrame = function(name) end;
n = 0;
for _, f in ipairs(frameFiles) do M.load(env, dir.."/Interface/FrameXML/"..f); end
n = errorsSince(env, n, "DragonUI: loads");
env.__loggedIn = true;
M.fire(env, "PLAYER_LOGIN");
M.fire(env, "PLAYER_ENTERING_WORLD");
M.tick(env, 30);
n = errorsSince(env, n, "DragonUI: login");
check("DragonUI: our Professions tab on its strip", rawget(env, "CharacterFrameTab7") ~= nil and rawget(env, "TemucraftCharacterProfPane") ~= nil);
for _, pane in ipairs({ "TemucraftCharacterRepPane", "TemucraftCharacterProfPane" }) do
	call(pane, function()
		cf:Show();
		env.CharacterFrame_ShowSubFrame(pane);
	end);
	check("DragonUI: "..pane.." shows", rawget(env, pane) and rawget(env, pane):IsShown());
	call(pane.." closed", function() cf:Hide(); end);
	n = errorsSince(env, n, "DragonUI: "..pane);
end
openAll("DragonUI");

---------------------------------------------------------------------------------------------------------------------
-- GlueXML
---------------------------------------------------------------------------------------------------------------------
local glue = M.new();
local glueFiles = M.tocFiles(dir.."/build_mpq.py", "GLUE_FILES");
local rootFiles = M.tocFiles(dir.."/build_mpq.py", "ROOT_GLUE_FILES");
check("GlueXML.toc lists our files", #glueFiles >= 8 and #rootFiles >= 2);
local g = 0;
for _, f in ipairs(glueFiles) do
	M.load(glue, dir.."/Interface/GlueXML/"..f);
	g = errorsSince(glue, g, "glue loads: "..f);
end
for _, f in ipairs(rootFiles) do
	M.load(glue, dir.."/Interface/"..f);
	g = errorsSince(glue, g, "glue loads: "..f);
end
-- the screens: login, character select, character create, the Options window
for _, name in ipairs({ "AccountLogin", "CharacterSelect", "CharacterCreate", "TemucraftGlueOptionsFrame" }) do
	local f = rawget(glue, name) or glue[name];
	if ( f and f.Show ) then
		f.shown = false;
		local ok, err = xpcall(function() f:Show(); end, debug.traceback);
		if ( not ok ) then table.insert(glue.__errors, { name, err }); end
		M.fire(glue, "UPDATE_CHARACTER_LIST");
		M.fire(glue, "CHARACTER_LIST_UPDATE");
		M.tick(glue, 3);
		f:Hide();
	end
	g = errorsSince(glue, g, "glue screen: "..name);
end

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
