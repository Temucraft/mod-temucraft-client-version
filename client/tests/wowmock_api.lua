-- The client functions and values of wowmock.lua (one place to add what a test needs).
-- env.__player, env.__cvars, env.__addons, env.__spells, env.__factions, env.__skills can be changed by a test.
return function(env, new, M)
	local realOs = os;

	-- the client's Lua: string / table / math aliases, bit, time
	local S, T = string, table;
	env.strsub, env.strlen, env.strupper, env.strlower, env.strfind, env.strmatch = S.sub, S.len, S.upper, S.lower, S.find, S.match;
	env.strrep, env.strbyte, env.strchar, env.strrev, env.format, env.gsub, env.gmatch = S.rep, S.byte, S.char, S.reverse, S.format, S.gsub, S.gmatch;
	env.tinsert, env.tremove, env.sort, env.getn, env.foreach, env.foreachi = T.insert, T.remove, T.sort, T.getn, T.foreach, T.foreachi;
	env.floor, env.ceil, env.abs, env.max, env.min, env.sqrt, env.random = math.floor, math.ceil, math.abs, math.max, math.min, math.sqrt, math.random;
	env.mod = math.fmod; env.fmod = math.fmod; env.exp = math.exp; env.log = math.log; env.log10 = math.log10;
	env.sin = function(d) return math.sin(math.rad(d)); end
	env.cos = function(d) return math.cos(math.rad(d)); end
	env.rad, env.deg, env.frexp, env.ldexp = math.rad, math.deg, math.frexp, math.ldexp;
	function env.strtrim(s, chars)
		chars = chars and ("["..chars.."]") or "%s";
		return (string.gsub(string.gsub(s, "^"..chars.."+", ""), chars.."+$", ""));
	end
	function env.strsplit(sep, s, limit)
		local out, at, n = {}, 1, 0;
		while ( true ) do
			n = n + 1;
			local a, b = string.find(s, "["..sep.."]", at);
			if ( not a or (limit and n >= limit) ) then table.insert(out, string.sub(s, at)); break; end
			table.insert(out, string.sub(s, at, a - 1));
			at = b + 1;
		end
		return unpack(out);
	end
	function env.strjoin(sep, ...) return table.concat({ ... }, sep); end
	function env.strconcat(...) return table.concat({ ... }); end
	function env.tostringall(...) local t = { ... }; for i = 1, select("#", ...) do t[i] = tostring(t[i]); end return unpack(t, 1, select("#", ...)); end
	function env.wipe(t) for k in pairs(t) do t[k] = nil; end return t; end
	env.table.wipe = env.wipe;
	function env.tContains(t, v) for _, x in pairs(t) do if ( x == v ) then return 1; end end return nil; end
	function env.time(t) return realOs.time(t); end
	function env.date(f, t) return realOs.date(f, t); end
	function env.debugstack() return debug.traceback(); end
	function env.debugprofilestop() return realOs.clock() * 1000; end
	function env.debugprofilestart() end
	function env.GetTime() return env.__now or 1000; end
	local bit = {};
	function bit.band(a, b) local r, p = 0, 1; for _ = 1, 32 do if ( a % 2 == 1 and b % 2 == 1 ) then r = r + p; end a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2; end return r; end
	function bit.bor(a, b) local r, p = 0, 1; for _ = 1, 32 do if ( a % 2 == 1 or b % 2 == 1 ) then r = r + p; end a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2; end return r; end
	function bit.bxor(a, b) local r, p = 0, 1; for _ = 1, 32 do if ( a % 2 ~= b % 2 ) then r = r + p; end a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2; end return r; end
	function bit.lshift(a, n) return (a * 2 ^ n) % 4294967296; end
	function bit.rshift(a, n) return math.floor(a / 2 ^ n); end
	function bit.bnot(a) return 4294967295 - a; end
	env.bit = bit;

	local function record(where, err) table.insert(env.__errors, { where, tostring(err) }); end
	local handler = function(err) record("geterrorhandler", debug.traceback(tostring(err), 2)); end
	function env.geterrorhandler() return handler; end
	function env.seterrorhandler(f) handler = f; end
	function env.securecall(f, ...) if ( type(f) == "string" ) then f = env[f]; end return f(...); end
	function env.issecure() return 1; end
	function env.issecurevariable() return 1, nil; end
	function env.forceinsecure() end
	function env.getglobal(k) return env[k]; end
	function env.setglobal(k, v) env[k] = v; end
	function env.hooksecurefunc(a, b, c)
		local tbl, name, hook = a, b, c;
		if ( type(a) == "string" ) then tbl, name, hook = env, a, b; end
		local orig = tbl[name];
		if ( orig == nil ) then record("hooksecurefunc", "hooksecurefunc(): "..tostring(name).." is not a function"); return; end
		rawset(tbl, name, function(...)
			local r = { orig(...) };
			hook(...);
			return unpack(r);
		end);
	end

	-- frames
	function env.CreateFrame(kind, name, parent, template)
		local f = new(kind, name, parent, template);
		if ( kind == "Slider" or (template and string.find(template, "Slider", 1, true)) ) then f.min, f.max, f.value = 0, 1, 0; end
		if ( kind == "EditBox" or (template and string.find(template, "InputBox", 1, true)) ) then f.kind = "EditBox"; end
		return f;
	end
	local function frame(kind, name, template) local f = new(kind, name, nil, template); return f; end
	frame("Frame", "UIParent"); frame("WorldFrame", "WorldFrame");
	env.UIParent.width, env.UIParent.height = 1920, 1080;
	for _, n in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3", "WorldMapTooltip" }) do
		local t = new("GameTooltip", n, env.UIParent);
		t.width = 250;
	end
	local chat = new("ScrollingMessageFrame", "DEFAULT_CHAT_FRAME", env.UIParent);
	env.ChatFrame1 = chat;
	for _, n in ipairs({ "UIErrorsFrame" }) do new("MessageFrame", n, env.UIParent); end
	env.GameTooltip_Hide = function() env.GameTooltip:Hide(); end
	env.ShowUIPanel = function(f) if ( f ) then f:Show(); end end
	env.HideUIPanel = function(f) if ( f ) then f:Hide(); end end
	env.ToggleFrame = function(f) if ( f:IsShown() ) then f:Hide(); else f:Show(); end end
	env.CloseAllWindows = function() return nil; end
	env.CloseMenus = function() return nil; end
	env.CloseDropDownMenus = function() end
	env.UISpecialFrames, env.UIPanelWindows, env.StaticPopupDialogs, env.SlashCmdList = {}, {}, {}, {};
	env.ChatTypeInfo = setmetatable({}, { __index = function(t, k) local v = { r = 1, g = 1, b = 1, sticky = 0 }; rawset(t, k, v); return v; end });
	env.StaticPopup_Show = function(which) env.__popup = which; end
	env.StaticPopup_Hide = function() end
	env.StaticPopup_Visible = function() return nil; end
	env.PlaySound, env.PlaySoundFile, env.PlayMusic, env.StopMusic = function() end, function() end, function() end, function() end
	env.SetPortraitTexture, env.SetPortraitToTexture = function() end, function() end
	env.CooldownFrame_SetTimer = function() end
	env.SetDesaturation = function(t, d) if ( t and t.SetDesaturated ) then t:SetDesaturated(d); end end
	env.SetItemButtonTexture = function() end
	env.SetItemButtonCount = function() end
	env.EasyMenu = function() end
	env.MouseIsOver = function() return nil; end
	env.GetMouseFocus = function() return nil; end
	env.GetCursorPosition = function() return 0, 0; end
	env.GetScreenWidth = function() return 1920; end
	env.GetScreenHeight = function() return 1080; end
	env.GetFramerate = function() return 60; end
	env.GetNetStats = function() return 0, 0, 50; end
	-- dropdowns, faux scroll frames, tabs: what the stock UI does
	env.UIDropDownMenu_CreateInfo = function() return {}; end
	env.UIDropDownMenu_Initialize = function(f, init, display, level)
		f.initialize = init;
		if ( init ) then
			local ok, err = xpcall(function() init(f, level or 1); end, debug.traceback);
			if ( not ok ) then record((f:GetName() or "?")..":dropdown init", err); end
		end
	end
	env.UIDropDownMenu_AddButton = function(info) if ( type(info) ~= "table" ) then record("UIDropDownMenu_AddButton", "info is not a table"); end end
	env.UIDropDownMenu_SetText = function(f, t) f.dropText = t; end
	env.UIDropDownMenu_GetText = function(f) return f.dropText; end
	env.UIDropDownMenu_SetWidth = function() end
	env.UIDropDownMenu_SetSelectedValue = function(f, v) f.selectedValue = v; end
	env.UIDropDownMenu_GetSelectedValue = function(f) return f.selectedValue; end
	env.UIDropDownMenu_SetSelectedID = function(f, v) f.selectedID = v; end
	env.UIDropDownMenu_GetSelectedID = function(f) return f.selectedID; end
	env.UIDropDownMenu_JustifyText = function() end
	env.UIDropDownMenu_EnableDropDown = function() end
	env.UIDropDownMenu_DisableDropDown = function() end
	env.ToggleDropDownMenu = function() end
	env.HideDropDownMenu = function() end
	env.UIDROPDOWNMENU_MENU_VALUE, env.UIDROPDOWNMENU_OPEN_MENU, env.UIDROPDOWNMENU_MENU_LEVEL = nil, nil, 1;
	env.FauxScrollFrame_Update = function(f, numItems, numToDisplay, height)
		f.fauxItems, f.fauxShown = numItems, numToDisplay;
		local bar = env[(f:GetName() or "").."ScrollBar"];
		f.scrollBarShown = numItems > numToDisplay;
		if ( f.scrollBarShown ) then f:Show(); end
		return f.scrollBarShown;
	end
	env.FauxScrollFrame_GetOffset = function(f) return f.offset or 0; end
	env.FauxScrollFrame_SetOffset = function(f, o) f.offset = o; end
	env.FauxScrollFrame_OnVerticalScroll = function(f, value, h, fn) f.offset = math.floor(value / h + 0.5); if ( fn ) then fn(f); end end
	env.PanelTemplates_SetNumTabs = function(f, n) f.numTabs = n; end
	env.PanelTemplates_SetTab = function(f, i) f.selectedTab = i; end
	env.PanelTemplates_GetSelectedTab = function(f) return f.selectedTab; end
	env.PanelTemplates_SelectTab = function(t) t.selectedTab = true; end
	env.PanelTemplates_DeselectTab = function(t) t.selectedTab = false; end
	env.PanelTemplates_DisableTab = function() end
	env.PanelTemplates_EnableTab = function() end
	env.PanelTemplates_TabResize = function() end
	env.PanelTemplates_UpdateTabs = function() end
	env.InterfaceOptions_AddCategory = function() end
	env.InterfaceOptionsFrame_OpenToCategory = function() end
	-- the stock ScrollingEdit functions (UIPanelTemplates.lua): OnUpdate does arithmetic on cursorOffset (nil before
	-- the box ever had a cursor -> the error of 4d2f637)
	env.ScrollingEdit_OnTextChanged = function(self, scrollFrame)
		self.handleCursorChange = true;
		env.ScrollingEdit_OnUpdate(self, 0, scrollFrame);
	end
	env.ScrollingEdit_OnCursorChanged = function(self, x, y, w, h)
		self.cursorOffset, self.cursorHeight, self.handleCursorChange = y, h, true;
	end
	env.ScrollingEdit_OnUpdate = function(self, elapsed, scrollFrame)
		if ( not self.handleCursorChange ) then return; end
		scrollFrame = scrollFrame or self:GetParent();
		local height, range, scroll = scrollFrame:GetHeight(), scrollFrame:GetVerticalScrollRange(), scrollFrame:GetVerticalScroll();
		local size = height + range;
		local cursorOffset = -self.cursorOffset;
		if ( math.floor(height) <= 0 or math.floor(range) <= 0 ) then self.handleCursorChange = false; return; end
		while ( cursorOffset < scroll ) do scroll = scroll - (height / 2); if ( scroll < 0 ) then scroll = 0; end scrollFrame:SetVerticalScroll(scroll); end
		while ( (cursorOffset + self.cursorHeight) > (scroll + height) and scroll < range ) do scroll = scroll + (height / 2); scrollFrame:SetVerticalScroll(scroll); end
		self.handleCursorChange = false;
	end

	-- colours and constants the code does arithmetic or indexing on
	local function color(r, g, b) return { r = r, g = g, b = b, a = 1 }; end
	env.NORMAL_FONT_COLOR, env.HIGHLIGHT_FONT_COLOR, env.GREEN_FONT_COLOR = color(1, 0.82, 0), color(1, 1, 1), color(0.1, 1, 0.1);
	env.RED_FONT_COLOR, env.GRAY_FONT_COLOR, env.YELLOW_FONT_COLOR = color(1, 0.1, 0.1), color(0.5, 0.5, 0.5), color(1, 1, 0);
	env.PASSIVE_SPELL_FONT_COLOR, env.ORANGE_FONT_COLOR, env.DISABLED_FONT_COLOR = color(0.77, 0.64, 0), color(1, 0.5, 0.25), color(0.5, 0.5, 0.5);
	env.NORMAL_FONT_COLOR_CODE, env.HIGHLIGHT_FONT_COLOR_CODE, env.FONT_COLOR_CODE_CLOSE = "|cffffd200", "|cffffffff", "|r";
	env.RED_FONT_COLOR_CODE, env.GREEN_FONT_COLOR_CODE, env.GRAY_FONT_COLOR_CODE = "|cffff2020", "|cff20ff20", "|cff808080";
	env.ITEM_QUALITY_COLORS = {};
	for q = -1, 7 do env.ITEM_QUALITY_COLORS[q] = { r = 1, g = 1, b = 1, hex = "|cffffffff" }; end
	env.RAID_CLASS_COLORS = {};
	env.CLASS_ICON_TCOORDS = {};
	env.LOCALIZED_CLASS_NAMES_MALE, env.LOCALIZED_CLASS_NAMES_FEMALE = {}, {};
	env.CLASS_SORT_ORDER = { "WARRIOR", "DEATHKNIGHT", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER" };
	for _, c in ipairs(env.CLASS_SORT_ORDER) do
		env.RAID_CLASS_COLORS[c] = color(0.8, 0.6, 0.4);
		env.CLASS_ICON_TCOORDS[c] = { 0, 0.25, 0, 0.25 };
		env.LOCALIZED_CLASS_NAMES_MALE[c] = c; env.LOCALIZED_CLASS_NAMES_FEMALE[c] = c;
	end
	env.MAX_BATTLEFIELD_QUEUES, env.MAX_ARENA_TEAMS, env.MAX_ARENA_TEAM_MEMBERS = 3, 3, 10;
	env.MAX_GUILDBANK_TABS, env.MAX_GUILDBANK_SLOTS_PER_TAB, env.MAX_WATCHED_TOKENS = 6, 98, 3;
	env.NUMGOSSIPBUTTONS, env.WATCHFRAME_MAXACHIEVEMENTS, env.LFR_BROWSE_AUTO_REFRESH_TIME = 32, 10, 20;
	env.TYPEID_HEROIC_DIFFICULTY, env.MAX_PARTY_MEMBERS, env.MAX_RAID_MEMBERS, env.NUM_BAG_SLOTS = 1, 4, 40, 4;
	env.NUM_CHAT_WINDOWS, env.MAX_SKILLLINE_TABS, env.SPELLS_PER_PAGE, env.MAX_SPELLS = 10, 8, 12, 1024;
	env.CR_HIT_MELEE, env.CR_HIT_RANGED, env.CR_HIT_SPELL, env.CR_CRIT_TAKEN_MELEE = 6, 7, 8, 15;
	env.CR_HASTE_MELEE, env.CR_HASTE_RANGED, env.CR_HASTE_SPELL, env.CR_ARMOR_PENETRATION = 18, 19, 20, 25;
	env.BOOKTYPE_SPELL, env.BOOKTYPE_PET = "spell", "pet";
	env.LFG_RETURN_VALUES, env.LFG_INSTANCE_INVALID_CODES = { name = 1, typeID = 2, minLevel = 3, maxLevel = 4 }, {};
	env.LFDDungeonList, env.LFRRaidList, env.LFGEnabledList, env.LFGCollapseList = {}, {}, {}, {};
	env.LFDHiddenByCollapseList, env.LFRHiddenByCollapseList, env.LFGLockList, env.LFGQueuedForList = {}, {}, {}, {};
	env.LFGDungeonInfo = {};
	env.SHORTDATE, env.LEVEL_ABBR = "%2$d/%1$02d/%3$02d", "Lvl";
	env.COOLDOWN_REMAINING = "Cooldown remaining:";
	env.SHOW_TALENT_LEVEL, env.SHOW_LFD_LEVEL, env.SHOW_PVP_LEVEL = 10, 15, 10;
	env.INTERFACEOPTIONS_ADDONCATEGORIES, env.TALENT_BRANCH_ARRAY = {}, {};
	env.LFD_LEVEL_FORMAT_RANGE, env.LFD_LEVEL_FORMAT_SINGLE = "(%d - %d)", "(%d)";

	-- the player
	env.__player = env.__player or { name = "Tester", level = 80, class = "Warrior", classFile = "WARRIOR", classId = 1,
		race = "Human", raceFile = "Human", faction = "Alliance", sex = 2, xp = 0, xpMax = 1000, guid = "0x0000000000000001" };
	local P = env.__player;
	local function me(u) return u == "player" or u == nil; end
	function env.UnitName(u) if ( me(u) ) then return P.name, nil; end end
	function env.UnitClass(u) if ( me(u) ) then return P.class, P.classFile, P.classId; end end
	function env.UnitRace(u) if ( me(u) ) then return P.race, P.raceFile; end end
	function env.UnitLevel(u) if ( me(u) ) then return P.level; end return 0; end
	function env.UnitFactionGroup(u) if ( me(u) ) then return P.faction, P.faction; end end
	function env.UnitSex(u) return P.sex; end
	function env.UnitGUID(u) if ( me(u) ) then return P.guid; end end
	function env.UnitExists(u) return me(u) and 1 or nil; end
	function env.UnitIsPlayer(u) return me(u) and 1 or nil; end
	function env.UnitIsUnit(a, b) return a == b and 1 or nil; end
	function env.UnitXP() return P.xp; end
	function env.UnitXPMax() return P.xpMax; end
	function env.UnitHealth() return 100; end
	function env.UnitHealthMax() return 100; end
	function env.UnitMana() return 100; end
	function env.UnitManaMax() return 100; end
	function env.UnitPower() return 100; end
	function env.UnitPowerMax() return 100; end
	function env.UnitPowerType() return 1, "RAGE"; end
	function env.UnitStat() return 50, 50, 0, 0; end
	function env.UnitArmor() return 1000, 1000, 1000, 0, 0; end
	function env.UnitAttackPower() return 500, 0, 0; end
	function env.UnitRangedAttackPower() return 100, 0, 0; end
	function env.UnitDamage() return 100, 150, 0, 0, 0, 0, 1; end
	function env.UnitRangedDamage() return 2, 50, 80, 0, 0, 1; end
	function env.UnitAttackSpeed() return 2.6, 0; end
	function env.UnitResistance() return 0, 0, 0, 0; end
	function env.UnitDefense() return 400, 0; end
	function env.UnitAffectingCombat() return env.__combat and 1 or nil; end
	function env.UnitPVPName(u) return env.UnitName(u); end
	function env.UnitClassification() return "normal"; end
	function env.UnitCreatureType() return "Humanoid"; end
	function env.GetUnitSpeed() return 7, 7, 4.5, 4.7; end
	function env.UnitAura() return nil; end
	function env.UnitBuff() return nil; end
	function env.UnitDebuff() return nil; end
	function env.GetMoney() return 1234567; end
	function env.GetRealmName() return "Temucraft"; end
	function env.GetLocale() return "enUS"; end
	function env.GetBuildInfo() return "3.3.5", "12340", "Jun 24 2010", 30300; end
	function env.GetExpansionLevel() return 2; end
	function env.InCombatLockdown() return env.__combat and 1 or nil; end
	function env.IsLoggedIn() return env.__loggedIn and 1 or nil; end
	function env.GetZoneText() return "Elwynn Forest"; end
	function env.GetRealZoneText() return "Elwynn Forest"; end
	function env.GetSubZoneText() return "Northshire Abbey"; end
	function env.GetMinimapZoneText() return "Northshire Abbey"; end
	function env.GetCurrentMapContinent() return 2; end
	function env.GetCurrentMapZone() return 0; end
	function env.GetCurrentMapAreaID() return 30; end
	function env.GetCurrentMapDungeonLevel() return 0; end
	function env.GetPlayerMapPosition() return 0.5, 0.5; end
	function env.GetCorpseMapPosition() return 0, 0; end
	function env.GetMapContinents() return "Kalimdor", "Eastern Kingdoms", "Outland", "Northrend"; end
	function env.GetInstanceInfo() return "Elwynn Forest", "none", 0, "", 5, 0, false; end
	function env.IsInInstance() return nil, "none"; end
	function env.GetGameTime() return 12, 0; end
	function env.CalendarGetDate() return 5, 26, 11, 2026; end
	function env.GetCoinTextureString(n) return tostring(n); end
	function env.GetCoinText(n) return tostring(n); end
	function env.SecondsToTime(s) return tostring(s).." sec"; end
	function env.GetQuestDifficultyColor() return color(1, 1, 0); end
	function env.GetText(token) return token; end
	function env.GetCurrencyListSize() return 0; end
	function env.GetAverageItemLevel() return 200, 200; end
	for _, n in ipairs({ "GetCritChance", "GetDodgeChance", "GetParryChance", "GetBlockChance", "GetRangedCritChance",
		"GetSpellCritChance", "GetSpellBonusDamage", "GetSpellBonusHealing", "GetArmorPenetration", "GetSpellPenetration",
		"GetCombatRating", "GetCombatRatingBonus", "GetHonorCurrency", "GetArenaCurrency", "GetPlayerFacing",
		"GetCurrentTitle", "GetCurrentArenaSeason", "GetPreviousArenaSeason", "GetTotalAchievementPoints",
		"GetComparisonAchievementPoints", "GetUnspentTalentPoints", "GetGroupPreviewTalentPointsSpent",
		"GetLFDLockPlayerCount", "GetCurrentGuildBankTab", "GetCurrentBindingSet", "GetTradeskillRepeatCount",
		"GetTradeSkillSelectionIndex", "GetQuestLogSelection", "GetGuildRosterShowOffline", "GetAddOnMemoryUsage",
		"GetAddOnCPUUsage", "GetPetSpellBonusDamage" }) do
		env[n] = function() return 0; end
	end
	function env.GetExpertise() return 0, 0; end
	function env.GetManaRegen() return 0, 0; end
	function env.GetPetExperience() return 0, 1; end
	function env.GetPVPLifetimeStats() return 0, 0, 0; end
	function env.GetPVPSessionStats() return 0, 0; end
	function env.GetPVPYesterdayStats() return 0, 0, 0; end
	function env.GetBattlefieldStatus() return "none", nil, 0; end
	function env.GetNumCompletedAchievements() return 0, 0; end
	function env.GetCategoryList() return {}; end
	function env.GetStatisticsCategoryList() return {}; end
	function env.GetActiveTalentGroup() return 1; end
	function env.GetNumTalentGroups() return 1; end
	function env.GetNumTalentTabs() return 3; end
	function env.GetTalentTabInfo(i) return ({ "Arms", "Fury", "Protection" })[i], "Interface\\Icons\\Ability_Rogue_Eviscerate", 0, "WarriorArms"; end
	function env.GetLFGRoles() return false, false, false, true; end
	function env.GetAvailableRoles() return true, true, true; end
	function env.GetTexCoordsForRole() return 0, 1, 0, 1; end
	function env.GetBackgroundTexCoordsForRole() return 0, 1, 0, 1; end
	function env.GetItemQualityColor() return 1, 1, 1, "|cffffffff"; end
	function env.GetItemInfo(id)
		if ( type(id) == "string" ) then id = tonumber(string.match(id, "item:(%d+)")) or 0; end
		if ( not id ) then return nil; end
		return "Item "..id, "|cffffffff|Hitem:"..id..":0:0:0:0:0:0:0|h[Item "..id.."]|h|r", 2, 10, 1, "Armor", "Cloth", 1, "INVTYPE_HEAD", "Interface\\Icons\\INV_Misc_QuestionMark", 100;
	end
	function env.GetItemIcon() return "Interface\\Icons\\INV_Misc_QuestionMark"; end
	function env.GetItemCount() return 0; end
	function env.GetItemCooldown() return 0, 0, 1; end
	function env.GetInventorySlotInfo(name) return 1, "Interface\\Icons\\INV_Misc_QuestionMark"; end
	function env.GetContainerNumSlots() return 16; end
	function env.GetCVar(k) return env.__cvars[k] or "0"; end
	function env.GetCVarBool(k) return env.__cvars[k] == "1" and 1 or nil; end
	function env.GetCVarDefault(k) return "0"; end
	function env.SetCVar(k, v) env.__cvars[k] = v ~= nil and tostring(v) or nil; end
	function env.RegisterCVar(k, v) if ( env.__cvars[k] == nil ) then env.__cvars[k] = v; end end
	env.__cvars = env.__cvars or {};
	env.__addons = env.__addons or {};
	function env.IsAddOnLoaded(n) return env.__addons[n] and 1 or nil; end
	function env.LoadAddOn(n) return env.__addons[n] and 1 or nil, "MISSING"; end
	function env.GetAddOnInfo() return nil; end
	function env.IsAddOnLoadOnDemand() return nil; end
	env.__sent = {};
	function env.SendAddonMessage(prefix, msg, chan, target) table.insert(env.__sent, { prefix, msg, chan, target }); end
	function env.SendChatMessage(msg, chan) table.insert(env.__sent, { "CHAT", msg, chan }); end
	function env.GetBindingKey() return nil; end
	function env.GetBindingAction() return ""; end
	function env.SetBinding() return 1; end
	function env.SaveBindings() end

	-- the spellbook: tab 1 General (with the racials), tab 2 the class
	env.__spells = env.__spells or {
		{ id = 6603, name = "Attack", rank = "", tab = 1 },
		{ id = 59752, name = "Every Man for Himself", rank = "Racial", tab = 1 },
		{ id = 20599, name = "Diplomacy", rank = "Racial Passive", tab = 1, passive = true },
		{ id = 78, name = "Heroic Strike", rank = "Rank 1", tab = 2 },
		{ id = 100, name = "Charge", rank = "Rank 1", tab = 2, cooldown = 15 },
	};
	local function spellById(id) for i, s in ipairs(env.__spells) do if ( s.id == id or s.name == id ) then return s, i; end end end
	function env.GetNumSpellTabs() return 2; end
	function env.GetSpellTabInfo(t)
		local first, count = nil, 0;
		for i, s in ipairs(env.__spells) do if ( s.tab == t ) then first = first or (i - 1); count = count + 1; end end
		if ( t > 2 ) then return nil; end
		return ({ "General", "Arms" })[t], "Interface\\Icons\\INV_Misc_Book_09", first or 0, count;
	end
	function env.GetSpellName(slot, book)
		if ( book == "pet" ) then return nil; end
		local s = env.__spells[slot];
		if ( s ) then return s.name, s.rank; end
	end
	function env.GetSpellLink(slot, book)
		local s = type(slot) == "number" and book and env.__spells[slot] or spellById(slot);
		if ( s ) then return "|cff71d5ff|Hspell:"..s.id.."|h["..s.name.."]|h|r", ""; end
	end
	function env.GetSpellTexture() return "Interface\\Icons\\Spell_Nature_Heal"; end
	function env.IsPassiveSpell(slot, book) local s = book and env.__spells[slot] or spellById(slot); return s and s.passive and 1 or nil; end
	function env.GetSpellInfo(id)
		local s = spellById(id);
		local name = s and s.name or (type(id) == "number" and ("Spell "..id)) or (type(id) == "string" and id) or nil;
		if ( not name ) then return nil; end
		return name, s and s.rank or "", "Interface\\Icons\\Spell_Nature_Heal", 0, false, 1, 0, 0, 0;
	end
	function env.GetSpellCooldown(id)
		local s = spellById(type(id) == "number" and (env.__spells[id] and id <= #env.__spells and env.__spells[id].id) or id) or spellById(id);
		if ( s and s.cooldown ) then return env.GetTime() - 1, s.cooldown, 1; end
		return 0, 0, 1;
	end
	function env.GetActionInfo(slot) local s = env.__actions and env.__actions[slot]; if ( s ) then return "spell", s, "spell", s; end end
	function env.GetMacroSpell() return nil; end

	-- skills (professions) and factions
	env.__skills = env.__skills or {};
	function env.GetNumSkillLines() return #env.__skills; end
	function env.GetSkillLineInfo(i) local s = env.__skills[i]; if ( s ) then return s.name, s.header, true, s.rank or 0, 0, 0, s.max or 0; end end
	env.ExpandSkillHeader = function() end
	env.__factions = env.__factions or {};
	function env.GetNumFactions() return #env.__factions; end
	function env.GetFactionInfo(i)
		local f = env.__factions[i];
		if ( f ) then return f.name, "", f.standing or 4, 0, 3000, f.value or 100, false, true, f.header, false, not f.header or f.hasRep, false, f.child, f.id; end
	end
	env.ExpandFactionHeader = function() end
	env.IsFactionInactive = function() return nil; end

	env.LibStub = nil;
end
