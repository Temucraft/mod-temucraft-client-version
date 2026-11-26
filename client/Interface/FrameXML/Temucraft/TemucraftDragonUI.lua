-- Temucraft and DragonUI (https://github.com/NeticSoul/DragonUI; ours is the Temucraft/DragonUI-Temucraft fork).
-- DragonUI is the base of the interface. Where one of its modules covers one of our windows, ours steps aside: that
-- piece acts as if its "Classic" option were on (the stock frame opens and DragonUI dresses or replaces it), and the
-- player's own saved Classic choice is left as it is. Our unique windows (reputation and Renown, guild, guild bank,
-- collections, flight map, Issue Reporter, the Esc menu, ...) stay. Turn the DragonUI module (or DragonUI) off and
-- /reload: ours come back. Read once at login: DragonUI's own modules load once and need a /reload to change too.
--   TemucraftDragonUI_IsLoaded()        DragonUI is running
--   TemucraftDragonUI_Owns(which)       DragonUI has this piece: "char", "currency", "micro", "book", "talents",
--                                       "gossip", "addons" (keys of TemucraftDragonUILogic.TAKEOVER)
--   TemucraftDragonUI_Note(which)       "DragonUI's Character Panel" for the options page, or nil
--   TemucraftDragonUI_OnChange(func)    func() once DragonUI's choices are known (at login; at once if they are)
TemucraftDragonUILogic = {};
local D = TemucraftDragonUILogic;

-- our piece -> the DragonUI module that has it (DragonUIDB.profiles[<profile>].modules.<module>.enabled)
D.TAKEOVER = {
	char = "characterpanel",      -- its retail character window (Pet, Skills, Currency and Honor panes of its own)
	currency = "characterpanel",  -- its Currency pane
	micro = "micromenu",          -- its micro menu and bag bar
	book = "spellbook",           -- its spellbook window (P)
	talents = "talents",          -- its talent and glyph window (N)
	gossip = "questdialog",       -- its quest and gossip dialogs
	addons = "addonmanager",      -- its AddOns list (our Esc menu's AddOns row and /addons open it)
};
D.NAMES = {
	characterpanel = "Character Panel", micromenu = "Micro Menu", spellbook = "Spellbook", talents = "Talents",
	questdialog = "Quest Dialog", addonmanager = "Addon Manager",
};

-- which of ours DragonUI has: loaded = DragonUI is running, enabled(module) = its module is on
function D.Resolve(loaded, enabled)
	local owned = {};
	if ( not loaded or type(enabled) ~= "function" ) then return owned; end
	for which, module in pairs(D.TAKEOVER) do
		local ok, on = pcall(enabled, module);
		if ( ok and on ) then owned[which] = true; end
	end
	return owned;
end

-- the options page's note for a piece DragonUI has
function D.Note(which, owned)
	local module = D.TAKEOVER[which];
	if ( not module or not (owned and owned[which]) ) then return nil; end
	return "DragonUI's "..(D.NAMES[module] or module);
end

-- Leatrix Maps (with Questie's pins) is the standard Temucraft world map. DragonUI's World Map module replaces the same
-- frame: it is off in our defaults (patch 0004, which also makes it step aside while Leatrix Maps is loaded). A player
-- who turns it on anyway is told once: what to say, or nil (applied = DragonUI's map really took the frame)
function D.MapWarning(dragonLoaded, worldmapOn, leatrixLoaded, applied)
	if ( not (dragonLoaded and worldmapOn and leatrixLoaded) ) then return nil; end
	if ( applied ) then
		return "|cffffd100Temucraft:|r DragonUI's World Map and Leatrix Maps both change the world map. Leatrix Maps (with Questie) is the Temucraft map: turn DragonUI's World Map off (/dui) and /reload.";
	end
	return "|cffffd100Temucraft:|r DragonUI's World Map is on, but it steps aside for Leatrix Maps, the Temucraft map. Turn it off in /dui to stop this note.";
end

-- Two quest trackers: DragonUI's (its questtracker module, over the stock watch list) and Questie's own. DragonUI's is
-- kept; Questie can't feed it (its tracker is a separate list), but with its own tracker off Questie leaves the stock
-- watch list alone, so DragonUI's shows the watched quests and Questie keeps its map pins and tooltips. Turned off once
-- per Questie profile (a flag in that profile), so a player who turns Questie's tracker back on keeps it.
-- true = turn it off now
function D.QuestieTrackerOff(dragonLoaded, trackerOn, profile)
	return dragonLoaded and trackerOn and type(profile) == "table" and profile.temucraftTracker == nil or false;
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

local owned, loaded, known = {}, false, false;
local listeners = {};

-- DragonUI's addon table (core.lua: _G.DragonUI = addon), once its AceDB is in (OnInitialize, at its ADDON_LOADED)
local function Running()
	local dui = _G.DragonUI;
	if ( not (IsAddOnLoaded and IsAddOnLoaded("DragonUI")) or type(dui) ~= "table" ) then return nil; end
	if ( type(dui.IsModuleEnabled) ~= "function" or type(dui.db) ~= "table" or not dui.db.profile ) then return nil; end
	return dui;
end

local function Read()
	local dui = Running();
	loaded = dui ~= nil;
	owned = D.Resolve(loaded, function(module) return dui:IsModuleEnabled(module); end);
	known = true;
	for _, func in ipairs(listeners) do func(); end
end

-- asked before PLAYER_LOGIN reached us (another frame's PLAYER_LOGIN ran first): read now
local function Known()
	if ( not known and IsLoggedIn and IsLoggedIn() ) then Read(); end
	return known;
end

function TemucraftDragonUI_IsLoaded() Known(); return loaded; end
function TemucraftDragonUI_Owns(which) Known(); return owned[which] == true; end
function TemucraftDragonUI_Note(which) Known(); return D.Note(which, owned); end
function TemucraftDragonUI_OnChange(func)
	table.insert(listeners, func);
	if ( known ) then func(); end
end

-- DragonUI's spellbook: the Train button and the automatic-learning box of TemucraftAutoLearn.lua come along while
-- it is open. Its window is a secure frame, so they are not parented or anchored to it: they follow its corner.
local function CarryTrainButton()
	local root, train, check = _G.DragonUI_SpellbookFrame, _G.TemucraftTrainButton, _G.TemucraftAutoLearnCheck;
	if ( not root or not train or root.temucraftTrain ) then return; end
	root.temucraftTrain = true;
	local follow = CreateFrame("Frame");
	follow:Hide();
	local function Place()
		local left, bottom = root:GetLeft(), root:GetBottom();
		if ( not left or not bottom ) then return; end
		local scale = root:GetEffectiveScale() / UIParent:GetEffectiveScale();
		train:ClearAllPoints();
		train:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scale + 44, bottom * scale + 12);
	end
	follow:SetScript("OnUpdate", Place);
	local function Lend(on)
		for _, f in ipairs({ train, check }) do
			if ( f ) then
				f:SetParent(on and UIParent or SpellBookFrame);
				if ( on ) then f:SetFrameStrata("DIALOG"); end
			end
		end
		if ( on ) then
			Place(); follow:Show();
			if ( TemucraftAutoLearn_Ask ) then TemucraftAutoLearn_Ask(); end
		else
			follow:Hide();
			train:ClearAllPoints();
			train:SetPoint("TOPRIGHT", SpellBookFrame, "TOPRIGHT", -44, -40);
		end
	end
	root:HookScript("OnShow", function() Lend(true); end);
	root:HookScript("OnHide", function() Lend(false); end);
	if ( root:IsShown() ) then Lend(true); end
end

local events = CreateFrame("Frame");
events:RegisterEvent("PLAYER_LOGIN");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
-- Questie's own tracker off beside DragonUI's (see D.QuestieTrackerOff). Our PLAYER_LOGIN runs before Questie's (its
-- AceDB is in since its ADDON_LOADED), and Questie reads trackerEnabled at its PLAYER_LOGIN.
local function QuestieTracker()
	local dui = Running();
	local q = _G.Questie;
	local profile = type(q) == "table" and type(q.db) == "table" and q.db.profile;
	local ok, trackerOn = pcall(function() return dui and dui:IsModuleEnabled("questtracker"); end);
	if ( not D.QuestieTrackerOff(dui ~= nil, ok and trackerOn, profile) ) then return; end
	profile.temucraftTracker = true;
	if ( profile.trackerEnabled ~= false ) then
		profile.trackerEnabled = false;
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Temucraft:|r your quests are in DragonUI's quest tracker; Questie's own tracker is off (Questie's options, Tracker, turn it back on).");
	end
end

-- DragonUI's World Map with Leatrix Maps: told once, at login or when the map opens (it can be turned on in /dui)
local mapWarned = false;
local function MapCheck()
	if ( mapWarned ) then return; end
	local dui = Running();
	if ( not dui ) then return; end
	local ok, on = pcall(function() return dui:IsModuleEnabled("worldmap"); end);
	local wm = dui.WorldMap;
	local applied = type(wm) == "table" and type(wm.IsApplied) == "function" and wm.IsApplied();
	local text = D.MapWarning(true, ok and on, IsAddOnLoaded("Leatrix_Maps") and true or false, applied);
	if ( text ) then mapWarned = true; DEFAULT_CHAT_FRAME:AddMessage(text); end
end
if ( WorldMapFrame ) then WorldMapFrame:HookScript("OnShow", MapCheck); end

events:SetScript("OnEvent", function(self, event)
	if ( event == "PLAYER_LOGIN" ) then
		if ( not known ) then Read(); end
		pcall(QuestieTracker);
		return;
	end
	MapCheck();
	-- DragonUI builds its spellbook at its own PLAYER_LOGIN
	self:UnregisterEvent("PLAYER_ENTERING_WORLD");
	if ( TemucraftDragonUI_Owns("book") ) then CarryTrainButton(); end
end);
