-- Temucraft Group Finder (retail-style, like the PVEFrame of later expansions, for 3.3.5): one window in the shared
-- look (TemucraftStyle.lua) with two tabs on top, Dungeons & Raids and Player vs. Player, and on the left of each the
-- big category buttons:
--   Dungeons & Raids   Dungeon Finder   roles (Tank / Healer / Damage, Leader in a group), the type (a random dungeon
--                                       of your level, a holiday, or Specific Dungeons with the stock list: headers,
--                                       checkboxes, locks), the rewards of a random one, the queue status (time in
--                                       queue, average wait, who was found), Find Group / Leave Queue, the backfill
--                                       offer, Teleport in and out of a Dungeon Finder group.
--                      Raid Finder      the 3.3.5 Raid Browser: List yourself (roles, raids, a comment; List Me /
--                                       Unlist) and Browse (pick a raid, the players and groups listed for it, their
--                                       roles and bosses killed; Whisper, Invite, Refresh, a filter and a search).
--   Player vs. Player  the pages of TemucraftGroupFinderPvP.lua (battlegrounds, arena, honor and conquest).
-- The stock frames still load and do the work behind it: LFDParentFrame's events show the role check, the "dungeon
-- ready" popup and the vote kick, LFGEventFrame keeps the lists (LFDDungeonList, LFGEnabledList, ...), the minimap eye
-- and its status tooltip stay stock. Only what opens the windows changes: ToggleLFDParentFrame (I, the micro buttons,
-- the eye), ToggleLFRParentFrame and TogglePVPFrame (H) open this window, and a ShowUIPanel of a stock frame (the
-- Dungeon Finder from a gossip, the battlemaster's "queue from anywhere") is swapped for ours a frame later.
-- "Classic group finder" / "Classic PvP window" (/tui, keys ui.classiclfg / ui.classicpvp) keep the stock windows.
-- Not here: Premade Groups. 3.3.5 has no group listing API (C_LFGList came with 5.x) and no module of ours adds one,
-- so there is nothing to build it on. Mythic+ and Rated Battlegrounds are later expansions too.
--   /groupfinder, /lfd, /lfg (dungeons), /lfr, /raidbrowser (raids), /pvp (the PvP tab; /pvp flag: the old PvP flag)

----------------------------------------------------------------------------------------------------------------------
-- The logic (no frames: tests/groupfinder_test.lua runs it with stubs)
----------------------------------------------------------------------------------------------------------------------
TemucraftGroupFinderLogic = {};
local L = TemucraftGroupFinderLogic;

-- key bindings (Bindings.xml calls the stock Toggle functions, which land here): binding -> tab, page
L.ROUTES = {
	TOGGLELFGPARENT = { "pve", "dungeons" },      -- I (and the Dungeon Finder micro button, the minimap eye)
	TOGGLELFRPARENT = { "pve", "raids" },         -- the Raid Browser key (no default key)
	TOGGLECHARACTER4 = { "pvp", "battlegrounds" },-- H (and the PvP micro button, /pvp)
};
-- each tab's Classic key (TemucraftUI_IsClassic)
L.CLASSIC = { pve = "lfg", pvp = "pvp" };

-- what a binding does: "ours" / "stock" / "none" (below the level), tab, page.
-- isClassic(which) -> bool; minLevels = { dungeons = SHOW_LFD_LEVEL, pvp = SHOW_PVP_LEVEL } (raids: none, as stock)
function L.Route(binding, isClassic, level, minLevels)
	local r = L.ROUTES[binding];
	if ( not r ) then return nil; end
	local tab, page = r[1], r[2];
	if ( isClassic and isClassic(L.CLASSIC[tab]) ) then return "stock", tab, page; end
	minLevels = minLevels or {};
	local min = (tab == "pvp" and minLevels.pvp) or (page == "dungeons" and minLevels.dungeons) or 0;
	if ( (level or 0) < min ) then return "none", tab, page; end
	return "ours", tab, page;
end

-- a toggle: "hide" (that page is open), "switch" (the window is open on another page) or "show"
function L.ToggleAction(shown, curTab, curPage, tab, page)
	if ( not shown ) then return "show"; end
	if ( curTab == tab and (page == nil or curPage == page) ) then return "hide"; end
	return "switch";
end

-- the roles that can be ticked: only those the class can do (GetAvailableRoles)
function L.Roles(canTank, canHeal, canDps, tank, heal, dps)
	return { tank = (canTank and tank) and true or false, healer = (canHeal and heal) and true or false,
		dps = (canDps and dps) and true or false };
end
function L.HasRole(r) return r ~= nil and (r.tank or r.healer or r.dps) and true or false; end

-- the roles can change only outside a queue
function L.RolesChangeable(mode)
	return not (mode == "queued" or mode == "listed" or mode == "rolecheck" or mode == "proposal");
end

-- the Find Group button (as LFDQueueFrameFindGroupButton_Update, plus: no role, or nothing ticked, can't join)
-- returns label ("leave", "party", "find") and enabled, and why not ("role", "choice", nil)
function L.FindButton(mode, inGroup, empowered, backfill, hasRole, hasChoice)
	local label;
	if ( mode == "queued" or mode == "rolecheck" or mode == "proposal" ) then label = "leave";
	elseif ( inGroup ) then label = "party";
	else label = "find"; end
	local enabled = empowered and mode ~= "proposal" and mode ~= "listed" and (label == "leave" or not backfill) and true or false;
	local why = nil;
	if ( enabled and label ~= "leave" ) then
		if ( not hasRole ) then enabled, why = false, "role";
		elseif ( not hasChoice ) then enabled, why = false, "choice"; end
	end
	return label, enabled, why;
end

-- the Raid Browser's List button (as LFRQueueFrameFindGroupButton_Update): label, enabled
function L.ListButton(mode, inGroup, empowered, hasRaids, hasRole)
	local label;
	if ( mode == "listed" ) then label = inGroup and "unlistgroup" or "unlistme";
	else label = inGroup and "listgroup" or "listme"; end
	local enabled = empowered and mode ~= "proposal" and mode ~= "queued" and mode ~= "rolecheck" and hasRaids and true or false;
	if ( enabled and mode ~= "listed" and not inGroup and not hasRole ) then enabled = false; end
	return label, enabled;
end

-- the random dungeons to offer (LFDQueueFrameTypeDropDown_Initialize's isRandomDungeonDisplayable):
-- list = { { id, name, minLevel, maxLevel, expansion, joinable } }
function L.RandomChoices(list, level, expansion)
	local out = {};
	for _, d in ipairs(list or {}) do
		if ( level >= (d.minLevel or 0) and level <= (d.maxLevel or 999) and (expansion or 0) >= (d.expansion or 0) ) then
			table.insert(out, d);
		end
	end
	return out;
end

local function lower(s) return string.lower(s or ""); end

-- the specific list (LFDDungeonList, headers have negative ids, each followed by its dungeons) with a search: a header
-- that matches keeps all its dungeons, a dungeon that matches keeps its header. nameOf(id), groupOf(id) -> header id
function L.FilterList(ids, nameOf, groupOf, search)
	local s = lower(search);
	local out = {};
	if ( s == "" ) then
		for i, id in ipairs(ids or {}) do out[i] = id; end
		return out;
	end
	local headerHit, keep = {}, {};
	for _, id in ipairs(ids or {}) do
		if ( id < 0 and string.find(lower(nameOf(id)), s, 1, true) ) then headerHit[id] = true; end
	end
	for _, id in ipairs(ids or {}) do
		if ( id > 0 ) then
			local g = groupOf(id);
			if ( headerHit[g] or string.find(lower(nameOf(id)), s, 1, true) ) then keep[id] = true; keep[g] = true; end
		elseif ( headerHit[id] ) then keep[id] = true; end
	end
	for _, id in ipairs(ids or {}) do if ( keep[id] ) then table.insert(out, id); end end
	return out;
end

-- does the list have something ticked that can be joined (enabled = LFGEnabledList, locks = LFGLockList)
function L.HasChoice(ids, enabled, locks)
	for _, id in ipairs(ids or {}) do
		if ( id > 0 and enabled and enabled[id] and not (locks and locks[id]) ) then return true; end
	end
	return false;
end

-- GetLFGQueueStats' needs -> found of each (1 tank, 1 healer, 3 damage)
L.TOTALS = { tank = 1, healer = 1, dps = 3 };
function L.Found(tankNeeds, healerNeeds, dpsNeeds)
	local function f(total, need) return math.max(0, total - math.min(total, need or total)); end
	return f(L.TOTALS.tank, tankNeeds), f(L.TOTALS.healer, healerNeeds), f(L.TOTALS.dps, dpsNeeds);
end

-- "4:05", "1:02:03"
function L.Clock(seconds)
	seconds = math.max(0, math.floor(seconds or 0));
	local h, m, s = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60;
	if ( h > 0 ) then return string.format("%d:%02d:%02d", h, m, s); end
	return string.format("%d:%02d", m, s);
end

-- the Raid Browser's results: { { name, level, className, comment, partyMembers, isTank, isHealer, isDamage } };
-- opts = { kind = "all" | "groups" | "players", role = nil | "tank" | "healer" | "dps", search = text } -> indices
function L.BrowseFilter(results, opts)
	opts = opts or {};
	local s = lower(opts.search);
	local out = {};
	for i, r in ipairs(results or {}) do
		local ok = true;
		local party = (r.partyMembers or 0) > 0;
		if ( opts.kind == "groups" and not party ) then ok = false; end
		if ( opts.kind == "players" and party ) then ok = false; end
		if ( ok and opts.role and not party ) then
			if ( (opts.role == "tank" and not r.isTank) or (opts.role == "healer" and not r.isHealer)
				or (opts.role == "dps" and not r.isDamage) ) then ok = false; end
		end
		if ( ok and s ~= "" and not string.find(lower(r.name), s, 1, true) and not string.find(lower(r.comment), s, 1, true)
			and not string.find(lower(r.className), s, 1, true) ) then ok = false; end
		if ( ok ) then table.insert(out, i); end
	end
	return out;
end

-- the Adventure Guide's instance for a Dungeon Finder name (TEMUCRAFT_ADVENTURE_GUIDE.instances: key or id = map, name;
-- TemucraftAdventureGuide_Open takes that key)
function L.AdventureGuideId(name, data)
	if ( not name or type(data) ~= "table" or type(data.instances) ~= "table" ) then return nil; end
	local n = lower(name);
	for _, inst in ipairs(data.instances) do
		if ( lower(inst.name) == n ) then return inst.key or inst.id; end
	end
	-- "Maraudon - Purple Crystals", "Blackrock Depths - Upper City": the instance before the wing
	local base = string.match(n, "^(.-)%s+%-%s+.+$");
	if ( base ) then
		for _, inst in ipairs(data.instances) do if ( lower(inst.name) == base ) then return inst.key or inst.id; end end
	end
	return nil;
end

-- copper -> "1g 20s 5c" (when GetCoinTextureString is missing)
function L.Money(copper)
	copper = math.floor(copper or 0);
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100;
	local parts = {};
	if ( g > 0 ) then table.insert(parts, g.."g"); end
	if ( s > 0 ) then table.insert(parts, s.."s"); end
	if ( c > 0 or #parts == 0 ) then table.insert(parts, c.."c"); end
	return table.concat(parts, " ");
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

----------------------------------------------------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------------------------------------------------
local WIDTH, HEIGHT, LEFT_W = 820, 560, 214;
local ROLE_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES";
local tabKey, pageKey = "pve", "dungeons";
local categories = { pve = {}, pvp = {} };
local lastPage = { pve = "dungeons", pvp = "battlegrounds" };
local Update, Later;

local frame = CreateFrame("Frame", "TemucraftGroupFinderFrame", UIParent);
frame:SetWidth(WIDTH); frame:SetHeight(HEIGHT);
frame:EnableMouse(true);
frame:SetMovable(true);
frame:SetClampedToScreen(true);
frame:SetToplevel(true);
frame:Hide();
UIPanelWindows["TemucraftGroupFinderFrame"] = { area = "left", pushable = 0, whileDead = 1 };
local titleText = TemucraftStyle_Window(frame, DUNGEONS_BUTTON or "Group Finder");
local close = CreateFrame("Button", "TemucraftGroupFinderFrameCloseButton", frame, "UIPanelCloseButton");
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
local function Tip(owner, title, text, anchor)
	GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT");
	GameTooltip:SetText(title);
	if ( text ) then GameTooltip:AddLine(text, 1, 1, 1, true); end
	GameTooltip:Show();
end
local function Button(parent, label, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
	b:SetWidth(width); b:SetHeight(22);
	b:SetText(label);
	return b;
end
local function BarButton(parent, label, width)
	local b = CreateFrame("Button", nil, parent);
	b:SetWidth(width); b:SetHeight(22);
	TemucraftStyle_Bar(b);
	TemucraftStyle_Highlight(b);
	b.glow = TemucraftStyle_Glow(b);
	b.glow:Hide();
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	b.text:SetPoint("CENTER");
	b.text:SetText(label);
	return b;
end
local function InGroup() return GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0; end
local function Mode() if ( GetLFGMode ) then return GetLFGMode(); end return nil; end

-- [[ the two tabs ]] --
local TABS = { { "pve", "Dungeons & Raids" }, { "pvp", PLAYER_V_PLAYER or "Player vs. Player" } };
local tabButtons = {};
for i, t in ipairs(TABS) do
	local b = BarButton(frame, t[2], 150);
	b:SetPoint("TOPLEFT", 18 + (i - 1) * 156, -36);
	b.key = t[1];
	b:SetScript("OnClick", function(self)
		PlaySound("igCharacterInfoTab");
		TemucraftGroupFinder_Open(self.key, nil);
	end);
	tabButtons[t[1]] = b;
end

-- [[ the category column and the page area ]] --
local left = Inset(frame);
left:SetPoint("TOPLEFT", 16, -64); left:SetPoint("BOTTOMLEFT", 16, 16); left:SetWidth(LEFT_W);
local content = CreateFrame("Frame", "TemucraftGroupFinderContent", frame);
content:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0); content:SetPoint("BOTTOMRIGHT", -16, 16);

local catButtons = {};
local function CategoryButton(i)
	if ( catButtons[i] ) then return catButtons[i]; end
	local b = CreateFrame("Button", nil, left);
	b:SetWidth(LEFT_W - 16); b:SetHeight(86);
	b:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 92);
	b:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	b:SetBackdropBorderColor(0.6, 0.5, 0.3, 1);
	b.art = b:CreateTexture(nil, "BACKGROUND");
	b.art:SetPoint("TOPLEFT", 3, -3); b.art:SetPoint("BOTTOMRIGHT", -3, 3);
	b.shade = b:CreateTexture(nil, "BORDER");
	b.shade:SetPoint("BOTTOMLEFT", 3, 3); b.shade:SetPoint("BOTTOMRIGHT", -3, 3); b.shade:SetHeight(40);
	b.shade:SetTexture(0, 0, 0, 0.6);
	b.icon = b:CreateTexture(nil, "ARTWORK");
	b.icon:SetWidth(30); b.icon:SetHeight(30);
	b.icon:SetPoint("BOTTOMLEFT", 8, 8);
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	b.name:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 6, 12);
	b.name:SetPoint("RIGHT", -6, 0); b.name:SetJustifyH("LEFT");
	b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -1);
	b.sub:SetPoint("RIGHT", -6, 0); b.sub:SetJustifyH("LEFT");
	b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD");
	b:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.25);
	b.glow = TemucraftStyle_Glow(b);
	b.glow:SetVertexColor(1, 0.82, 0, 0.6);
	b.glow:Hide();
	b:SetScript("OnClick", function(self)
		PlaySound("igCharacterInfoTab");
		TemucraftGroupFinder_Open(tabKey, self.key);
	end);
	b:SetScript("OnEnter", function(self) if ( self.def and self.def.tooltip ) then Tip(self, self.def.label, self.def.tooltip); end end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	catButtons[i] = b;
	return b;
end

-- other files add pages: def = { label, sub, art, coords = { l, r, t, b }, icon, page (frame), onShow, update,
-- title, tooltip }; the page is parented to the page area
function TemucraftGroupFinder_AddCategory(tab, key, def)
	def.key = key;
	def.page:SetParent(content);
	def.page:ClearAllPoints();
	def.page:SetAllPoints(content);
	def.page:Hide();
	table.insert(categories[tab], def);
end
function TemucraftGroupFinder_Content() return content; end
function TemucraftGroupFinder_Later() if ( Later ) then Later(); end end

local function FindDef(tab, key)
	for _, def in ipairs(categories[tab] or {}) do if ( def.key == key ) then return def; end end
	return nil;
end

local function Layout()
	for _, b in pairs(tabButtons) do if ( b.key == tabKey ) then b.glow:Show(); else b.glow:Hide(); end end
	local list = categories[tabKey] or {};
	for i, def in ipairs(list) do
		local b = CategoryButton(i);
		b.key, b.def = def.key, def;
		b.art:SetTexture(def.art);
		local c = def.coords or { 0, 1, 0, 1 };
		b.art:SetTexCoord(c[1], c[2], c[3], c[4]);
		b.icon:SetTexture(def.icon);
		b.name:SetText(def.label);
		b.sub:SetText(def.sub or "");
		if ( def.key == pageKey ) then b.glow:Show(); b:SetBackdropBorderColor(1, 0.82, 0, 1); b.art:SetVertexColor(1, 1, 1);
		else b.glow:Hide(); b:SetBackdropBorderColor(0.6, 0.5, 0.3, 1); b.art:SetVertexColor(0.65, 0.65, 0.65); end
		b:Show();
	end
	for i = #list + 1, #catButtons do catButtons[i]:Hide(); end
	for tab, defs in pairs(categories) do
		for _, def in ipairs(defs) do
			if ( tab == tabKey and def.key == pageKey ) then def.page:Show(); else def.page:Hide(); end
		end
	end
	local def = FindDef(tabKey, pageKey);
	titleText:SetText(def and def.title or (tabKey == "pvp" and (PLAYER_V_PLAYER or "Player vs. Player") or "Group Finder"));
end

function Update()
	if ( not frame:IsShown() ) then return; end
	Layout();
	local def = FindDef(tabKey, pageKey);
	if ( def and def.update ) then def.update(); end
end
local dirty = CreateFrame("Frame");
dirty:Hide();
dirty:SetScript("OnUpdate", function(self) self:Hide(); Update(); end);
function Later() if ( frame:IsShown() ) then dirty:Show(); end end

-- open the window on a tab (and page: nil = the tab's last page); toggle: close it when that is what's open
function TemucraftGroupFinder_Open(tab, page, toggle)
	tab = tab or "pve";
	page = page or lastPage[tab];
	if ( not FindDef(tab, page) ) then page = categories[tab][1] and categories[tab][1].key; end
	if ( toggle ) then
		local action = L.ToggleAction(frame:IsShown(), tabKey, pageKey, tab, page);
		if ( action == "hide" ) then HideUIPanel(frame); return; end
	end
	local changed = tabKey ~= tab or pageKey ~= page;
	tabKey, pageKey = tab, page;
	lastPage[tab] = page;
	if ( frame:IsShown() ) then
		Layout();
		local def = FindDef(tab, page);
		if ( changed and def and def.onShow ) then def.onShow(); end
		Update();
	else
		ShowUIPanel(frame);
		if ( not frame:IsShown() ) then frame:Show(); end
	end
end
function TemucraftGroupFinder_IsShown(tab) return frame:IsShown() and (tab == nil or tab == tabKey); end
function TemucraftGroupFinder_Page() return tabKey, pageKey; end

local hideHooks = {};
function TemucraftGroupFinder_OnHide(func) table.insert(hideHooks, func); end

frame:SetScript("OnShow", function()
	PlaySound("igCharacterInfoOpen");
	Layout();
	local def = FindDef(tabKey, pageKey);
	if ( def and def.onShow ) then def.onShow(); end
	Update();
	UpdateMicroButtons();
end);
frame:SetScript("OnHide", function()
	PlaySound("igCharacterInfoClose");
	for _, func in ipairs(hideHooks) do func(); end
	UpdateMicroButtons();
end);

----------------------------------------------------------------------------------------------------------------------
-- Roles (shared by the Dungeon Finder and the Raid Browser): the stock SetLFGRoles / GetLFGRoles, and the stock check
-- boxes are kept in step (LFG_UpdateRoleCheckboxes), so the role check popup shows the same
----------------------------------------------------------------------------------------------------------------------
local ROLES = { { "tank", "TANK", TANK or "Tank" }, { "healer", "HEALER", HEALER or "Healer" }, { "dps", "DAMAGER", DAMAGER or "Damage" } };
local function Available()
	if ( not GetAvailableRoles ) then return true, true, true; end
	return GetAvailableRoles();
end
local function SetRoles(leader, tank, healer, dps)
	SetLFGRoles(leader and true or false, tank and true or false, healer and true or false, dps and true or false);
	if ( LFG_UpdateRoleCheckboxes ) then LFG_UpdateRoleCheckboxes(); end
	Later();
end

local function RoleRow(parent, withLeader)
	local row = { buttons = {} };
	for i, r in ipairs(ROLES) do
		local b = CreateFrame("Button", nil, parent);
		b:SetWidth(46); b:SetHeight(46);
		b:SetPoint("TOPLEFT", 12 + (i - 1) * 112, -10);
		b.bg = b:CreateTexture(nil, "BACKGROUND");
		b.bg:SetTexture("Interface\\LFGFrame\\UI-LFG-ICONS-ROLEBACKGROUNDS");
		b.bg:SetTexCoord(GetBackgroundTexCoordsForRole(r[2]));
		b.bg:SetPoint("CENTER"); b.bg:SetWidth(70); b.bg:SetHeight(70);
		b.bg:SetAlpha(0.6);
		b.icon = b:CreateTexture(nil, "ARTWORK");
		b.icon:SetAllPoints();
		b.icon:SetTexture(ROLE_TEX);
		b.icon:SetTexCoord(GetTexCoordsForRole(r[2]));
		b.check = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate");
		b.check:SetWidth(24); b.check:SetHeight(24);
		b.check:SetPoint("BOTTOMLEFT", -6, -6);
		b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
		b.label:SetPoint("LEFT", b, "RIGHT", 6, 0);
		b.label:SetText(r[3]);
		b.role = r[1];
		local function Toggle()
			local leader, tank, healer, dps = GetLFGRoles();
			local v = { tank = tank, healer = healer, dps = dps };
			v[r[1]] = not v[r[1]];
			PlaySound(v[r[1]] and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
			SetRoles(leader, v.tank, v.healer, v.dps);
		end
		b.check:SetScript("OnClick", Toggle);
		b:SetScript("OnClick", function(self) if ( self.check:IsEnabled() == 1 ) then Toggle(); end end);
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP");
			GameTooltip:SetText(r[3]);
			if ( self.notAvailable ) then GameTooltip:AddLine("Your class can't do this role.", 1, 0.2, 0.2, true);
			elseif ( self.locked ) then GameTooltip:AddLine("Roles can't change while you are queued or listed.", 0.8, 0.8, 0.8, true); end
			GameTooltip:Show();
		end);
		b:SetScript("OnLeave", GameTooltip_Hide);
		row.buttons[i] = b;
	end
	if ( withLeader ) then
		local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate");
		c:SetWidth(24); c:SetHeight(24);
		c:SetPoint("TOPLEFT", 12 + 3 * 112 - 6, -18);
		c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		c.text:SetPoint("LEFT", c, "RIGHT", 0, 1);
		c.text:SetText(LEADER or "Leader");
		c:SetScript("OnClick", function(self)
			local _, tank, healer, dps = GetLFGRoles();
			SetRoles(self:GetChecked() and true or false, tank, healer, dps);
		end);
		c:SetScript("OnEnter", function(self) Tip(self, LEADER or "Leader", "You will lead the group the Dungeon Finder puts together."); end);
		c:SetScript("OnLeave", GameTooltip_Hide);
		row.leader = c;
	end
	function row.Update()
		local leader, tank, healer, dps = GetLFGRoles();
		local canTank, canHeal, canDps = Available();
		local can = { tank = canTank, healer = canHeal, dps = canDps };
		local chosen = L.Roles(canTank, canHeal, canDps, tank, healer, dps);
		local changeable = L.RolesChangeable(Mode());
		for _, b in ipairs(row.buttons) do
			b.notAvailable = not can[b.role];
			b.locked = not changeable;
			b.check:SetChecked(chosen[b.role]);
			if ( can[b.role] and changeable ) then b.check:Enable(); else b.check:Disable(); end
			SetDesaturation(b.icon, not can[b.role]);
			b.icon:SetAlpha(can[b.role] and 1 or 0.4);
			if ( can[b.role] ) then b.check:Show(); else b.check:Hide(); end
		end
		if ( row.leader ) then
			local canLead = (GetNumPartyMembers() == 0 or IsPartyLeader()) and (GetNumRaidMembers() == 0 or IsRaidLeader());
			row.leader:SetChecked(leader);
			if ( InGroup() ) then row.leader:Show(); else row.leader:Hide(); end
			if ( canLead and changeable ) then row.leader:Enable(); else row.leader:Disable(); end
		end
		return chosen;
	end
	return row;
end

local function LockTip(owner, dungeonID)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT");
	GameTooltip:AddLine(YOU_MAY_NOT_QUEUE_FOR_DUNGEON or "You can't queue for this.", 1, 1, 1);
	for i = 1, (GetLFDLockPlayerCount and GetLFDLockPlayerCount() or 0) do
		local playerName, reason = GetLFDLockInfo(dungeonID, i);
		if ( reason and reason ~= 0 ) then
			local who = (i == 1) and "SELF_" or "OTHER_";
			local text = _G["INSTANCE_UNAVAILABLE_"..who..(LFG_INSTANCE_INVALID_CODES[reason] or "OTHER")];
			if ( text ) then GameTooltip:AddLine(format(text, playerName), 1, 0.3, 0.3, true); end
		end
	end
	GameTooltip:Show();
end

-- the Adventure Guide (TemucraftAdventureGuide.lua; only used while it is there)
local function AdventureGuideFor(name)
	if ( type(TemucraftAdventureGuide_Open) ~= "function" ) then return nil; end
	local data = TemucraftAdventureGuideLogic and type(TemucraftAdventureGuideLogic.Data) == "function" and TemucraftAdventureGuideLogic.Data()
		or TEMUCRAFT_ADVENTURE_GUIDE;
	return L.AdventureGuideId(name, data);
end
local function OpenAdventureGuide(name)
	local id = AdventureGuideFor(name);
	if ( id and type(TemucraftAdventureGuide_Open) == "function" ) then TemucraftAdventureGuide_Open(id); end
end

----------------------------------------------------------------------------------------------------------------------
-- Dungeon Finder
----------------------------------------------------------------------------------------------------------------------
local dfPage = CreateFrame("Frame", nil, content);
local dfRolesBox = Inset(dfPage);
dfRolesBox:SetPoint("TOPLEFT", 0, 0); dfRolesBox:SetPoint("TOPRIGHT", 0, 0); dfRolesBox:SetHeight(66);
local dfRoles = RoleRow(dfRolesBox, true);

-- the type: a random dungeon (or a holiday) or the specific list
local typeLabel = dfRolesBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
typeLabel:SetPoint("TOPRIGHT", -170, -10);
typeLabel:SetText(TYPE or "Type");
local typeDrop = CreateFrame("Frame", "TemucraftGroupFinderTypeDropDown", dfRolesBox, "UIDropDownMenuTemplate");
typeDrop:SetPoint("TOPRIGHT", 10, -22);
UIDropDownMenu_SetWidth(typeDrop, 160);

local function TypeName(value)
	if ( value == "specific" or value == nil ) then return SPECIFIC_DUNGEONS or "Specific Dungeons"; end
	return (GetLFGDungeonInfo(value)) or "?";
end
local function SetType(value)
	if ( LFDQueueFrame_SetType ) then LFDQueueFrame_SetType(value); else LFDQueueFrame.type = value; end
	UIDropDownMenu_SetText(typeDrop, TypeName(value));
	Later();
end
local function RandomList()
	local list = {};
	for i = 1, (GetNumRandomDungeons and GetNumRandomDungeons() or 0) do
		local id, name = GetLFGRandomDungeonInfo(i);
		local _, _, minLevel, maxLevel, _, _, _, expansion = GetLFGDungeonInfo(id);
		table.insert(list, { id = id, name = name, minLevel = minLevel, maxLevel = maxLevel, expansion = expansion,
			joinable = IsLFGDungeonJoinable(id) });
	end
	return L.RandomChoices(list, UnitLevel("player"), GetExpansionLevel());
end
-- initialized on first use (UIDropDownMenu_Initialize runs the function at once: not at load, before the LFG data)
local function TypeMenu()
	local info = UIDropDownMenu_CreateInfo();
	info.text = SPECIFIC_DUNGEONS or "Specific Dungeons";
	info.value = "specific";
	info.func = function(self) SetType(self.value); end;
	info.checked = LFDQueueFrame.type == "specific";
	UIDropDownMenu_AddButton(info);
	for _, d in ipairs(RandomList()) do
		info = UIDropDownMenu_CreateInfo();
		info.text = d.name;
		info.value = d.id;
		if ( d.joinable ) then
			info.func = function(self) SetType(self.value); end;
			info.checked = LFDQueueFrame.type == d.id;
		else
			info.disabled = 1;
			info.tooltipWhileDisabled = 1; info.tooltipOnButton = 1;
			info.tooltipTitle = YOU_MAY_NOT_QUEUE_FOR_THIS;
			info.tooltipText = LFDConstructDeclinedMessage and LFDConstructDeclinedMessage(d.id);
		end
		UIDropDownMenu_AddButton(info);
	end
end

-- the body: the random dungeon (art, text, rewards) or the specific list
local BOTTOM_H = 64;
local dfBody = Inset(dfPage);
dfBody:SetPoint("TOPLEFT", dfRolesBox, "BOTTOMLEFT", 0, -6); dfBody:SetPoint("BOTTOMRIGHT", 0, BOTTOM_H);

local randomView = CreateFrame("Frame", nil, dfBody);
randomView:SetPoint("TOPLEFT", 6, -6); randomView:SetPoint("BOTTOMRIGHT", -6, 6);
local randomArt = randomView:CreateTexture(nil, "BACKGROUND");
randomArt:SetAllPoints();
randomArt:SetAlpha(0.35);
local rTitle = randomView:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
rTitle:SetPoint("TOPLEFT", 14, -12); rTitle:SetPoint("RIGHT", -14, 0); rTitle:SetJustifyH("LEFT");
local rDesc = randomView:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
rDesc:SetPoint("TOPLEFT", rTitle, "BOTTOMLEFT", 0, -8); rDesc:SetPoint("RIGHT", -14, 0); rDesc:SetJustifyH("LEFT");
local rRewardsTitle = randomView:CreateFontString(nil, "OVERLAY", "GameFontNormal");
rRewardsTitle:SetPoint("TOPLEFT", rDesc, "BOTTOMLEFT", 0, -22);
rRewardsTitle:SetText(REWARDS or "Rewards");
local rRewardsBar = TemucraftStyle_Header(rRewardsTitle);
local rRewardsText = randomView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
rRewardsText:SetPoint("TOPLEFT", rRewardsTitle, "BOTTOMLEFT", 0, -10); rRewardsText:SetPoint("RIGHT", -14, 0);
rRewardsText:SetJustifyH("LEFT");
local rewardButtons = {};
for i = 1, 6 do
	local b = CreateFrame("Button", "TemucraftGroupFinderReward"..i, randomView, "ItemButtonTemplate");
	b:SetPoint("TOPLEFT", rRewardsText, "BOTTOMLEFT", ((i - 1) % 2) * 230, -8 - math.floor((i - 1) / 2) * 44);
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.label:SetPoint("LEFT", b, "RIGHT", 6, 0); b.label:SetWidth(180); b.label:SetJustifyH("LEFT");
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetLFGDungeonReward(self.dungeonID, self.index);
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	b:SetScript("OnClick", function(self)
		if ( GetLFGDungeonRewardLink ) then HandleModifiedItemClick(GetLFGDungeonRewardLink(self.dungeonID, self.index)); end
	end);
	rewardButtons[i] = b;
end
local rMoney = randomView:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
rMoney:SetJustifyH("LEFT");
local rCooldown = randomView:CreateFontString(nil, "OVERLAY", "GameFontRed");
rCooldown:SetPoint("BOTTOMLEFT", 14, 10); rCooldown:SetPoint("RIGHT", -14, 0); rCooldown:SetJustifyH("LEFT");

-- the specific list
local specificView = CreateFrame("Frame", nil, dfBody);
specificView:SetPoint("TOPLEFT", 6, -6); specificView:SetPoint("BOTTOMRIGHT", -6, 6);
local specificArt = specificView:CreateTexture(nil, "BACKGROUND");
specificArt:SetAllPoints();
specificArt:SetTexture("Interface\\LFGFrame\\UI-LFG-BACKGROUND-DUNGEONWALL");
specificArt:SetAlpha(0.25);
local dfSearch = CreateFrame("EditBox", "TemucraftGroupFinderSearch", specificView, "InputBoxTemplate");
dfSearch:SetHeight(20); dfSearch:SetWidth(220);
dfSearch:SetPoint("TOPLEFT", 12, -6);
dfSearch:SetAutoFocus(false);
local dfSearchHint = dfSearch:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
dfSearchHint:SetPoint("LEFT", 2, 0);
dfSearchHint:SetText(SEARCH or "Search");
local dfSearchText = "";
dfSearch:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
dfSearch:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
dfSearch:SetScript("OnTextChanged", function(self)
	local t = self:GetText() or "";
	if ( t == "" ) then dfSearchHint:Show(); else dfSearchHint:Hide(); end
	if ( t ~= dfSearchText ) then dfSearchText = t; Later(); end
end);
dfSearch:SetScript("OnEditFocusGained", function() dfSearchHint:Hide(); end);
dfSearch:SetScript("OnEditFocusLost", function(self) if ( (self:GetText() or "") == "" ) then dfSearchHint:Show(); end end);
local dfScroll = CreateFrame("ScrollFrame", "TemucraftGroupFinderDungeonScroll", specificView, "FauxScrollFrameTemplate");
dfScroll:SetPoint("TOPLEFT", 0, -32); dfScroll:SetPoint("BOTTOMRIGHT", -24, 2);
local DROW_H = 20;
local dfRows = {};
local dfLines = {};
local DungeonRows;
for i = 1, 14 do
	local b = CreateFrame("Button", nil, specificView);
	b:SetHeight(DROW_H);
	b:SetPoint("TOPLEFT", 4, -32 - (i - 1) * DROW_H);
	b:SetPoint("RIGHT", dfScroll, "RIGHT", 0, 0);
	b.bar = TemucraftStyle_Bar(b);
	TemucraftStyle_Highlight(b);
	b.expand = CreateFrame("Button", nil, b);
	b.expand:SetWidth(14); b.expand:SetHeight(14);
	b.expand:SetPoint("LEFT", 4, 0);
	b.check = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate");
	b.check:SetWidth(20); b.check:SetHeight(20);
	b.check:SetPoint("LEFT", 20, 0);
	b.lock = b:CreateTexture(nil, "ARTWORK");
	b.lock:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-LOCK");
	b.lock:SetWidth(14); b.lock:SetHeight(16);
	b.lock:SetPoint("CENTER", b.check, "CENTER", 0, 0);
	b.heroic = b:CreateTexture(nil, "ARTWORK");
	b.heroic:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-HEROIC");
	b.heroic:SetTexCoord(0, 0.5, 0, 0.625);
	b.heroic:SetWidth(12); b.heroic:SetHeight(15);
	b.heroic:SetPoint("LEFT", b.check, "RIGHT", 2, 0);
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	b.name:SetPoint("LEFT", b.check, "RIGHT", 4, 0);
	b.name:SetPoint("RIGHT", -120, 0); b.name:SetJustifyH("LEFT");
	b.level = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.level:SetPoint("RIGHT", -34, 0);
	b.guide = CreateFrame("Button", nil, b);
	b.guide:SetWidth(16); b.guide:SetHeight(16);
	b.guide:SetPoint("RIGHT", -10, 0);
	b.guide:SetNormalTexture("Interface\\Icons\\INV_Misc_Book_09");
	b.guide:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
	b.guide:SetScript("OnClick", function(self) OpenAdventureGuide(self:GetParent().dungeonName); end);
	b.guide:SetScript("OnEnter", function(self) Tip(self, "Adventure Guide", "Open this dungeon in the Adventure Guide."); end);
	b.guide:SetScript("OnLeave", GameTooltip_Hide);
	local function Collapse(self)
		local row = self.id and self or self:GetParent();
		if ( row.id and row.id < 0 and LFDList_SetHeaderCollapsed ) then
			LFDList_SetHeaderCollapsed(row.id, not LFGCollapseList[row.id]);
			Later();
		end
	end
	b.expand:SetScript("OnClick", Collapse);
	b.check:SetScript("OnClick", function(self)
		local id = self:GetParent().id;
		local on = self:GetChecked() and true or false;
		PlaySound(on and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
		if ( id < 0 ) then LFDList_SetHeaderEnabled(id, on);
		else
			LFDList_SetDungeonEnabled(id, on);
			LFGListUpdateHeaderEnabledAndLockedStates(LFDDungeonList, LFGEnabledList, LFGLockList, LFDHiddenByCollapseList);
		end
		Later();
	end);
	b:SetScript("OnClick", function(self)
		if ( self.id and self.id < 0 ) then Collapse(self);
		elseif ( self.id and self.check:IsShown() and self.check:IsEnabled() == 1 ) then self.check:Click(); end
	end);
	b:SetScript("OnEnter", function(self)
		if ( self.id and self.id > 0 and LFGLockList and LFGLockList[self.id] ) then LockTip(self, self.id); end
	end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	dfRows[i] = b;
end
dfScroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, DROW_H, function() DungeonRows(); end); end);

-- the bottom: the queue status and Find Group
local dfBottom = Inset(dfPage);
dfBottom:SetPoint("BOTTOMLEFT", 0, 0); dfBottom:SetPoint("BOTTOMRIGHT", 0, 0); dfBottom:SetHeight(BOTTOM_H - 6);
local findButton = Button(dfBottom, FIND_A_GROUP or "Find Group", 150);
findButton:SetPoint("RIGHT", -10, 0); findButton:SetHeight(26);
local teleportButton = Button(dfBottom, "Teleport", 90);
teleportButton:SetPoint("RIGHT", findButton, "LEFT", -6, 0);
teleportButton:Hide();
local dfStatus = dfBottom:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
dfStatus:SetPoint("TOPLEFT", 12, -10); dfStatus:SetPoint("RIGHT", teleportButton, "LEFT", -8, 0); dfStatus:SetJustifyH("LEFT");
local dfStatus2 = dfBottom:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
dfStatus2:SetPoint("TOPLEFT", dfStatus, "BOTTOMLEFT", 0, -4); dfStatus2:SetPoint("RIGHT", teleportButton, "LEFT", -8, 0); dfStatus2:SetJustifyH("LEFT");
-- the backfill offer (your group is in a dungeon and lost a member)
local backfill = CreateFrame("Frame", nil, dfPage);
backfill:SetPoint("BOTTOMLEFT", dfBottom, "TOPLEFT", 0, 2); backfill:SetPoint("BOTTOMRIGHT", dfBottom, "TOPRIGHT", 0, 2);
backfill:SetHeight(40);
backfill:SetFrameLevel(dfBody:GetFrameLevel() + 10);
backfill:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
backfill:SetBackdropColor(0.1, 0.07, 0.02, 0.95); backfill:SetBackdropBorderColor(1, 0.82, 0, 1);
local backfillText = backfill:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
backfillText:SetPoint("LEFT", 12, 0); backfillText:SetPoint("RIGHT", -170, 0); backfillText:SetJustifyH("LEFT");
local backfillYes = Button(backfill, YES or "Yes", 70);
backfillYes:SetPoint("RIGHT", -86, 0);
backfillYes:SetScript("OnClick", function() PartyLFGStartBackfill(); Later(); end);
local backfillNo = Button(backfill, HIDE or "Hide", 70);
backfillNo:SetPoint("RIGHT", -10, 0);
local backfillHidden = false;
backfillNo:SetScript("OnClick", function() backfillHidden = true; Later(); end);
backfill:Hide();
-- listed in the Raid Browser: no Dungeon Finder
local dfLocked = CreateFrame("Frame", nil, dfPage);
dfLocked:SetAllPoints(dfBody);
dfLocked:SetFrameLevel(dfBody:GetFrameLevel() + 20);
dfLocked:EnableMouse(true);
dfLocked:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" });
dfLocked:SetBackdropColor(0, 0, 0, 0.8);
local dfLockedText = dfLocked:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge");
dfLockedText:SetPoint("CENTER", 0, 20); dfLockedText:SetWidth(420);
dfLockedText:SetText(NO_LFD_WHILE_LFR or "You can't use the Dungeon Finder while you are listed in the Raid Browser.");
local dfLockedButton = Button(dfLocked, UNLIST_ME or "Unlist Me", 140);
dfLockedButton:SetPoint("TOP", dfLockedText, "BOTTOM", 0, -16);
dfLockedButton:SetScript("OnClick", function() LeaveLFG(); end);
dfLocked:Hide();

local dfCanJoin = false;
findButton:SetScript("OnClick", function()
	local mode = Mode();
	if ( mode == "queued" or mode == "listed" or mode == "rolecheck" ) then LeaveLFG();
	elseif ( LFDQueueFrame_Join ) then
		if ( LFDQueueFrame_Update ) then LFDQueueFrame_Update(); end   -- the stock lists the join reads
		LFDQueueFrame_Join();
	end
	Later();
end);
findButton:SetScript("OnEnter", function(self)
	if ( self.why == "role" ) then Tip(self, FIND_A_GROUP or "Find Group", "Pick at least one role first.");
	elseif ( self.why == "choice" ) then Tip(self, FIND_A_GROUP or "Find Group", "Tick at least one dungeon you can enter."); end
end);
findButton:SetScript("OnLeave", GameTooltip_Hide);
teleportButton:SetScript("OnClick", function() LFGTeleport(IsInLFGDungeon() and true or false); end);
teleportButton:SetScript("OnEnter", function(self)
	Tip(self, IsInLFGDungeon() and (TELEPORT_OUT_OF_DUNGEON or "Teleport out of the dungeon") or (TELEPORT_TO_DUNGEON or "Teleport to the dungeon"));
end);
teleportButton:SetScript("OnLeave", GameTooltip_Hide);

local function DungeonName(id) local info = LFGGetDungeonInfoByID(id); return info and info[LFG_RETURN_VALUES.name] or ""; end
local function DungeonGroup(id) local info = LFGGetDungeonInfoByID(id); return info and info[LFG_RETURN_VALUES.groupID] or 0; end

function DungeonRows()
	local mode = Mode();
	local queued = mode == "queued" or mode == "listed";
	local editable = not (mode == "rolecheck" or queued or not LFD_IsEmpowered());
	FauxScrollFrame_Update(dfScroll, #dfLines, #dfRows, DROW_H);
	local offset = FauxScrollFrame_GetOffset(dfScroll);
	for i, b in ipairs(dfRows) do
		local id = dfLines[i + offset];
		b.id = id;
		if ( id ) then
			local info = LFGGetDungeonInfoByID(id);
			local name = info[LFG_RETURN_VALUES.name];
			b.dungeonName = name;
			local state = queued and LFGQueuedForList[id] or LFGEnabledList[id];
			if ( state == 1 ) then
				b.check:SetCheckedTexture("Interface\\Buttons\\UI-MultiCheck-Up");
				b.check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-MultiCheck-Disabled");
			else
				b.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check");
				b.check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled");
			end
			b.check:SetChecked(state and state ~= 0);
			if ( editable ) then b.check:Enable(); else b.check:Disable(); end
			local locked = LFGLockList and LFGLockList[id];
			if ( locked ) then b.check:Hide(); b.lock:Show(); else b.check:Show(); b.lock:Hide(); end
			if ( id < 0 ) then
				b.bar:Show();
				b.expand:Show();
				b.expand:SetNormalTexture(LFGCollapseList[id] and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up");
				b.name:SetFontObject(GameFontNormal);
				b.name:SetText(name);
				b.level:SetText("");
				if ( info[LFG_RETURN_VALUES.typeID] == TYPEID_HEROIC_DIFFICULTY ) then
					b.heroic:Show(); b.name:SetPoint("LEFT", b.heroic, "RIGHT", 2, 0);
				else
					b.heroic:Hide(); b.name:SetPoint("LEFT", b.check, "RIGHT", 4, 0);
				end
				b.guide:Hide();
			else
				b.bar:Hide();
				b.expand:Hide();
				b.heroic:Hide();
				b.name:SetPoint("LEFT", b.check, "RIGHT", 4, 0);
				local minLevel, maxLevel = info[LFG_RETURN_VALUES.minLevel], info[LFG_RETURN_VALUES.maxLevel];
				if ( minLevel == maxLevel ) then b.level:SetText(format(LFD_LEVEL_FORMAT_SINGLE or "(%d)", minLevel));
				else b.level:SetText(format(LFD_LEVEL_FORMAT_RANGE or "(%d - %d)", minLevel, maxLevel)); end
				local color = GetQuestDifficultyColor(info[LFG_RETURN_VALUES.recLevel]);
				b.level:SetFontObject(color.font);
				b.name:SetFontObject(editable and color.font or QuestDifficulty_Header);
				b.name:SetText(name);
				if ( AdventureGuideFor(name) ) then b.guide:Show(); else b.guide:Hide(); end
			end
			b:Show();
		else
			b:Hide();
		end
	end
end

local function UpdateRandom(id)
	local name, _, _, _, _, _, _, _, _, texture, difficulty, _, description, isHoliday = GetLFGDungeonInfo(id);
	local doneToday, moneyBase, moneyVar, xpBase, xpVar, numRewards = GetLFGDungeonRewards(id);
	local randoms = 4 - GetNumPartyMembers();
	local money = (moneyBase or 0) + (moneyVar or 0) * randoms;
	local xp = (xpBase or 0) + (xpVar or 0) * randoms;
	local art;
	if ( (difficulty or 0) > 0 ) then art = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-HEROIC";
	elseif ( isHoliday and texture ) then art = "Interface\\LFGFrame\\UI-LFG-HOLIDAY-BACKGROUND-"..texture;
	else art = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-RANDOMDUNGEON"; end
	if ( not randomArt:SetTexture(art) ) then randomArt:SetTexture("Interface\\LFGFrame\\UI-LFG-BACKGROUND-QUESTPAPER"); end
	if ( isHoliday ) then
		rTitle:SetText(name);
		rDesc:SetText(description or "");
		rRewardsText:SetText((doneToday and LFD_HOLIDAY_REWARD_EXPLANATION2 or LFD_HOLIDAY_REWARD_EXPLANATION1) or "");
	else
		rTitle:SetText(name or LFG_TYPE_RANDOM_DUNGEON);
		rDesc:SetText(LFD_RANDOM_EXPLANATION or "");
		rRewardsText:SetText((doneToday and LFD_RANDOM_REWARD_EXPLANATION2 or LFD_RANDOM_REWARD_EXPLANATION1) or "");
	end
	local last = rRewardsText;
	for i, b in ipairs(rewardButtons) do
		if ( i <= (numRewards or 0) ) then
			local rname, rtex, count = GetLFGDungeonRewardInfo(id, i);
			b.dungeonID, b.index = id, i;
			SetItemButtonTexture(b, rtex);
			SetItemButtonCount(b, count);
			b.label:SetText(rname);
			b:Show();
			if ( i % 2 == 1 ) then last = b; end
		else
			b:Hide();
		end
	end
	local parts = {};
	if ( money > 0 ) then table.insert(parts, (MONEY or "Money")..": "..(GetCoinTextureString and GetCoinTextureString(money) or L.Money(money))); end
	if ( xp > 0 ) then table.insert(parts, (EXPERIENCE_COLON or "Experience:").." "..xp); end
	if ( (moneyVar or 0) > 0 or (xpVar or 0) > 0 ) then table.insert(parts, "|cffaaaaaa"..(LFD_REWARDS_PUG_BONUS or "(more for each player the Dungeon Finder adds)").."|r"); end
	rMoney:ClearAllPoints();
	rMoney:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -12);
	rMoney:SetText(table.concat(parts, "    "));
	-- cooldown and deserter (you or your group)
	local text = nil;
	local deserter = GetLFGDeserterExpiration and GetLFGDeserterExpiration();
	local expire = deserter or (GetLFGRandomCooldownExpiration and GetLFGRandomCooldownExpiration());
	if ( expire and GetTime() < expire ) then
		text = ((deserter and LFG_DESERTER_YOU or LFG_RANDOM_COOLDOWN_YOU) or "You can't queue for a random dungeon yet:").."  "..SecondsToTime(math.ceil(expire - GetTime()));
	else
		for i = 1, GetNumPartyMembers() do
			if ( UnitHasLFGDeserter("party"..i) ) then text = LFG_DESERTER_OTHER or "A member of your group is a deserter."; break; end
			if ( UnitHasLFGRandomCooldown("party"..i) ) then text = LFG_RANDOM_COOLDOWN_OTHER or "A member of your group can't queue for a random dungeon yet."; end
		end
	end
	rCooldown:SetText(text or "");
end

local function UpdateStatus()
	local mode, sub = Mode();
	teleportButton:Hide();
	dfStatus2:SetText("");
	if ( mode == "queued" ) then
		local hasData, _, tankNeeds, healerNeeds, dpsNeeds, instanceType, instanceName, averageWait, _, _, _, myWait, queuedTime = GetLFGQueueStats();
		if ( hasData ) then
			if ( instanceType == TYPEID_HEROIC_DIFFICULTY ) then instanceName = format(HEROIC_PREFIX, instanceName); end
			dfStatus:SetText(format("|cffffd100%s|r  %s", QUEUED_STATUS_QUEUED or "In queue:", instanceName or ""));
			local t, h, d = L.Found(tankNeeds, healerNeeds, dpsNeeds);
			local wait = (myWait and myWait ~= -1) and SecondsToTime(myWait, false, false, 1) or (TIME_UNKNOWN or "Unknown");
			dfStatus2:SetText(format(TIME_IN_QUEUE or "Time in queue: %s", L.Clock(GetTime() - (queuedTime or GetTime())))
				.."    "..format(LFG_STATISTIC_AVERAGE_WAIT or "Average wait: %s", wait)
				..format("    %s %d/1  %s %d/1  %s %d/3", TANK or "Tank", t, HEALER or "Healer", h, DAMAGER or "Damage", d));
		else
			dfStatus:SetText("|cffffd100"..(QUEUED_STATUS_QUEUED or "In queue").."|r");
			dfStatus2:SetText(LFG_SEARCHING_FOR_GROUP or "Looking for more players...");
		end
	elseif ( mode == "rolecheck" ) then
		dfStatus:SetText("|cffffd100"..(QUEUED_STATUS_ROLE_CHECK_IN_PROGRESS or "Role check in progress").."|r");
	elseif ( mode == "proposal" ) then
		dfStatus:SetText("|cffffd100"..(QUEUED_STATUS_PROPOSAL or "Your group is ready").."|r");
		dfStatus2:SetText("Answer the popup to enter the dungeon.");
	elseif ( mode == "lfgparty" or mode == "abandonedInDungeon" ) then
		dfStatus:SetText("|cffffd100"..(QUEUED_STATUS_IN_PROGRESS or "In a Dungeon Finder group").."|r");
		teleportButton:Show();
	elseif ( mode == "listed" ) then
		dfStatus:SetText("|cffffd100"..(QUEUED_STATUS_LISTED or "Listed in the Raid Browser").."|r");
	else
		dfStatus:SetText(LFD_IsEmpowered() and "" or (LFG_UNEMPOWERED or "Only your group leader can queue the group."));
	end
end

local function UpdateDungeons()
	if ( LFGDungeonList_Setup ) then LFGDungeonList_Setup(); end
	if ( not LFGDungeonInfo ) then return; end
	if ( not typeDrop.temucraftInit ) then typeDrop.temucraftInit = true; UIDropDownMenu_Initialize(typeDrop, TypeMenu); end
	if ( LFDQueueFrame_Update ) then LFDQueueFrame_Update(); end
	local chosen = dfRoles.Update();
	if ( not LFDQueueFrame.type ) then
		local best = GetRandomDungeonBestChoice and GetRandomDungeonBestChoice();
		LFDQueueFrame.type = best or "specific";
	end
	local t = LFDQueueFrame.type;
	UIDropDownMenu_SetText(typeDrop, TypeName(t));
	if ( t == "specific" ) then
		randomView:Hide(); specificView:Show();
		dfLines = L.FilterList(LFDDungeonList, DungeonName, DungeonGroup, dfSearchText);
		DungeonRows();
	else
		specificView:Hide(); randomView:Show();
		UpdateRandom(t);
	end
	-- the find button
	local mode = Mode();
	local showBackfill = CanPartyLFGBackfill() and not backfillHidden and mode ~= "queued";
	if ( showBackfill ) then
		local name = GetPartyLFGBackfillInfo();
		backfillText:SetFormattedText(LFG_OFFER_CONTINUE or "Your group is in %s. Look for more players?", HIGHLIGHT_FONT_COLOR_CODE..(name or "").."|r");
		backfill:Show();
		if ( LFD_IsEmpowered() and mode ~= "proposal" and mode ~= "queued" ) then backfillYes:Enable(); else backfillYes:Disable(); end
	else
		backfill:Hide();
	end
	local hasChoice = t ~= "specific" or L.HasChoice(LFDDungeonList, LFGEnabledList, LFGLockList) or L.HasChoice(LFDHiddenByCollapseList, LFGEnabledList, LFGLockList);
	local label, enabled, why = L.FindButton(mode, InGroup(), LFD_IsEmpowered(), showBackfill, L.HasRole(chosen), hasChoice);
	findButton:SetText(label == "leave" and (LEAVE_QUEUE or "Leave Queue") or label == "party" and (JOIN_AS_PARTY or "Join as Party") or (FIND_A_GROUP or "Find Group"));
	if ( enabled ) then findButton:Enable(); else findButton:Disable(); end
	findButton.why = why;
	if ( mode == "listed" ) then dfLocked:Show(); else dfLocked:Hide(); end
	UpdateStatus();
end

local statusTick = 0;
dfPage:SetScript("OnUpdate", function(self, elapsed)
	statusTick = statusTick + elapsed;
	if ( statusTick < 1 ) then return; end
	statusTick = 0;
	if ( Mode() == "queued" ) then UpdateStatus(); end
end);

TemucraftGroupFinder_AddCategory("pve", "dungeons", {
	label = LOOKING_FOR_DUNGEON or "Dungeon Finder", sub = "Random or specific dungeons",
	art = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-RANDOMDUNGEON", coords = { 0, 1, 0.2, 0.55 },
	icon = "Interface\\LFGFrame\\LFGICON-DUNGEON", page = dfPage, title = LOOKING_FOR_DUNGEON or "Dungeon Finder",
	update = UpdateDungeons, onShow = function() backfillHidden = false; end,
	tooltip = "Queue for a random dungeon of your level, a holiday boss, or the dungeons you tick. The Dungeon Finder puts a group together across the realm.",
});

----------------------------------------------------------------------------------------------------------------------
-- Raid Finder (the 3.3.5 Raid Browser)
----------------------------------------------------------------------------------------------------------------------
local rfPage = CreateFrame("Frame", nil, content);
local rfView = "list";
local rfSub = {};
for i, s in ipairs({ { "list", "List Yourself" }, { "browse", LOOKING_FOR_RAID or "Raid Browser" } }) do
	local b = BarButton(rfPage, s[2], 150);
	b:SetPoint("TOPLEFT", (i - 1) * 156, 0);
	b.key = s[1];
	b:SetScript("OnClick", function(self) PlaySound("igCharacterInfoTab"); rfView = self.key; if ( rfView == "browse" and RefreshLFGList ) then RefreshLFGList(); end Later(); end);
	rfSub[s[1]] = b;
end

-- [[ list yourself ]] --
local listView = CreateFrame("Frame", nil, rfPage);
listView:SetPoint("TOPLEFT", 0, -28); listView:SetPoint("BOTTOMRIGHT", 0, 0);
local lrRolesBox = Inset(listView);
lrRolesBox:SetPoint("TOPLEFT", 0, 0); lrRolesBox:SetPoint("TOPRIGHT", 0, 0); lrRolesBox:SetHeight(66);
local lrRoles = RoleRow(lrRolesBox, false);
local lrHelp = lrRolesBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
lrHelp:SetPoint("TOPLEFT", 12 + 3 * 112, -12); lrHelp:SetPoint("RIGHT", -10, 0); lrHelp:SetJustifyH("LEFT");
lrHelp:SetText("Put yourself (or your group) in the Raid Browser, so raid leaders looking for players find you.");
local lrBody = Inset(listView);
lrBody:SetPoint("TOPLEFT", lrRolesBox, "BOTTOMLEFT", 0, -6); lrBody:SetPoint("BOTTOMRIGHT", 0, 64);
local lrArt = lrBody:CreateTexture(nil, "BACKGROUND");
lrArt:SetPoint("TOPLEFT", 4, -4); lrArt:SetPoint("BOTTOMRIGHT", -4, 4);
lrArt:SetTexture("Interface\\LFGFrame\\UI-LFG-BACKGROUND-Naxxramas");
lrArt:SetAlpha(0.2);
local lrScroll = CreateFrame("ScrollFrame", "TemucraftGroupFinderRaidScroll", lrBody, "FauxScrollFrameTemplate");
lrScroll:SetPoint("TOPLEFT", 6, -6); lrScroll:SetPoint("BOTTOMRIGHT", -28, 6);
local lrRows, lrLines = {}, {};
local RaidRows;
for i = 1, 15 do
	local b = CreateFrame("Button", nil, lrBody);
	b:SetHeight(DROW_H);
	b:SetPoint("TOPLEFT", 10, -6 - (i - 1) * DROW_H);
	b:SetPoint("RIGHT", lrScroll, "RIGHT", 0, 0);
	b.bar = TemucraftStyle_Bar(b);
	TemucraftStyle_Highlight(b);
	b.expand = CreateFrame("Button", nil, b);
	b.expand:SetWidth(14); b.expand:SetHeight(14);
	b.expand:SetPoint("LEFT", 4, 0);
	b.check = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate");
	b.check:SetWidth(20); b.check:SetHeight(20);
	b.check:SetPoint("LEFT", 20, 0);
	b.lock = b:CreateTexture(nil, "ARTWORK");
	b.lock:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-LOCK");
	b.lock:SetWidth(14); b.lock:SetHeight(16);
	b.lock:SetPoint("CENTER", b.check, "CENTER");
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	b.name:SetPoint("LEFT", b.check, "RIGHT", 4, 0); b.name:SetPoint("RIGHT", -90, 0); b.name:SetJustifyH("LEFT");
	b.size = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.size:SetPoint("RIGHT", -10, 0);
	local function Collapse(row)
		if ( row.id and row.id < 0 and LFRList_SetHeaderCollapsed ) then LFRList_SetHeaderCollapsed(row.id, not LFGCollapseList[row.id]); Later(); end
	end
	b.expand:SetScript("OnClick", function(self) Collapse(self:GetParent()); end);
	b.check:SetScript("OnClick", function(self)
		local id = self:GetParent().id;
		local on = self:GetChecked() and true or false;
		PlaySound(on and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
		if ( id < 0 ) then LFRList_SetHeaderEnabled(id, on);
		elseif ( LFR_CanQueueForMultiple() ) then
			LFRList_SetRaidEnabled(id, on);
			LFGListUpdateHeaderEnabledAndLockedStates(LFRRaidList, LFGEnabledList, LFGLockList, LFRHiddenByCollapseList);
		else
			LFRQueueFrame.selectedLFM = id;
		end
		Later();
	end);
	b:SetScript("OnClick", function(self)
		if ( self.id and self.id < 0 ) then Collapse(self);
		elseif ( self.id and self.check:IsShown() and self.check:IsEnabled() == 1 ) then self.check:Click(); end
	end);
	b:SetScript("OnEnter", function(self) if ( self.id and self.id > 0 and LFGLockList and LFGLockList[self.id] ) then LockTip(self, self.id); end end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	lrRows[i] = b;
end
lrScroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, DROW_H, function() RaidRows(); end); end);

local lrBottom = Inset(listView);
lrBottom:SetPoint("BOTTOMLEFT", 0, 0); lrBottom:SetPoint("BOTTOMRIGHT", 0, 0); lrBottom:SetHeight(58);
local commentLabel = lrBottom:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
commentLabel:SetPoint("TOPLEFT", 12, -8);
commentLabel:SetText(COMMENT or "Comment");
local comment = CreateFrame("EditBox", "TemucraftGroupFinderComment", lrBottom, "InputBoxTemplate");
comment:SetHeight(20);
comment:SetPoint("TOPLEFT", 18, -24); comment:SetPoint("RIGHT", -180, 0);
comment:SetAutoFocus(false);
comment:SetMaxLetters(63);
comment:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
comment:SetScript("OnEnterPressed", function(self)
	self:ClearFocus();
	if ( Mode() == "listed" ) then SetLFGComment(self:GetText() or ""); end
end);
local listButton = Button(lrBottom, LIST_ME or "List Me", 150);
listButton:SetPoint("RIGHT", -10, 0); listButton:SetHeight(26);
listButton:SetScript("OnClick", function()
	if ( Mode() == "listed" ) then LeaveLFG(); Later(); return; end
	if ( LFRQueueFrame_Update ) then LFRQueueFrame_Update(); end
	ClearAllLFGDungeons();
	if ( LFR_CanQueueForMultiple() ) then
		for _, id in pairs(LFRRaidList) do LFRQueueFrame_QueueForInstanceIfEnabled(id); end
		for _, id in pairs(LFRHiddenByCollapseList) do LFRQueueFrame_QueueForInstanceIfEnabled(id); end
	elseif ( LFRQueueFrame.selectedLFM ) then
		SetLFGDungeon(LFRQueueFrame.selectedLFM);
	end
	comment:ClearFocus();
	SetLFGComment(comment:GetText() or "");
	JoinLFG();
	Later();
end);
local lrLocked = CreateFrame("Frame", nil, listView);
lrLocked:SetAllPoints(lrBody);
lrLocked:SetFrameLevel(lrBody:GetFrameLevel() + 20);
lrLocked:EnableMouse(true);
lrLocked:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" });
lrLocked:SetBackdropColor(0, 0, 0, 0.8);
local lrLockedText = lrLocked:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge");
lrLockedText:SetPoint("CENTER", 0, 20); lrLockedText:SetWidth(420);
lrLockedText:SetText(NO_LFR_WHILE_LFD or "You can't use the Raid Browser while you are in the Dungeon Finder queue.");
local lrLockedButton = Button(lrLocked, LEAVE_QUEUE or "Leave Queue", 140);
lrLockedButton:SetPoint("TOP", lrLockedText, "BOTTOM", 0, -16);
lrLockedButton:SetScript("OnClick", function() LeaveLFG(); end);
lrLocked:Hide();

function RaidRows()
	local mode = Mode();
	local listed = mode == "listed";
	local editable = LFR_IsEmpowered() and not listed and mode ~= "queued" and mode ~= "rolecheck";
	local multi = LFR_CanQueueForMultiple();
	FauxScrollFrame_Update(lrScroll, #lrLines, #lrRows, DROW_H);
	local offset = FauxScrollFrame_GetOffset(lrScroll);
	for i, b in ipairs(lrRows) do
		local id = lrLines[i + offset];
		b.id = id;
		if ( id ) then
			local info = LFGGetDungeonInfoByID(id);
			b.name:SetText(info[LFG_RETURN_VALUES.name]);
			local state;
			if ( listed ) then state = LFGQueuedForList[id];
			elseif ( multi or id < 0 ) then state = LFGEnabledList[id];
			else state = (LFRQueueFrame.selectedLFM == id); end
			LFGSpecificChoiceEnableButton_SetIsRadio(b.check, not multi and id > 0);
			if ( state == 1 ) then
				b.check:SetCheckedTexture("Interface\\Buttons\\UI-MultiCheck-Up");
			elseif ( multi or id < 0 ) then
				b.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check");
			end
			b.check:SetChecked(state and state ~= 0);
			if ( editable ) then b.check:Enable(); else b.check:Disable(); end
			local locked = LFGLockList and LFGLockList[id] and not LFR_CanQueueForLockedInstances();
			if ( locked ) then b.check:Hide(); b.lock:Show(); else b.check:Show(); b.lock:Hide(); end
			if ( id < 0 ) then
				b.bar:Show(); b.expand:Show();
				b.expand:SetNormalTexture(LFGCollapseList[id] and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up");
				b.size:SetText("");
				b.name:SetFontObject(GameFontNormal);
				if ( not multi ) then b.check:Hide(); end
			else
				b.bar:Hide(); b.expand:Hide();
				b.size:SetText(format(LFD_LEVEL_FORMAT_SINGLE or "(%d)", info[LFG_RETURN_VALUES.maxPlayers] or 0));
				b.name:SetFontObject(GameFontHighlight);
			end
			b:Show();
		else
			b:Hide();
		end
	end
end

local function UpdateList()
	if ( LFGDungeonList_Setup ) then LFGDungeonList_Setup(); end
	if ( not LFGDungeonInfo ) then return; end
	if ( LFRQueueFrame_Update ) then LFRQueueFrame_Update(); end
	local chosen = lrRoles.Update();
	lrLines = {};
	for i, id in ipairs(LFRRaidList or {}) do lrLines[i] = id; end
	RaidRows();
	local mode = Mode();
	local hasRaids = LFR_CanQueueForMultiple() and (L.HasChoice(LFRRaidList, LFGEnabledList, LFR_CanQueueForLockedInstances() and {} or LFGLockList)
		or L.HasChoice(LFRHiddenByCollapseList, LFGEnabledList, LFGLockList)) or (not LFR_CanQueueForMultiple() and LFRQueueFrame.selectedLFM ~= nil);
	local label, enabled = L.ListButton(mode, InGroup(), LFR_IsEmpowered(), hasRaids, L.HasRole(chosen));
	local labels = { listme = LIST_ME or "List Me", listgroup = LIST_MY_GROUP or "List My Group", unlistme = UNLIST_ME or "Unlist Me", unlistgroup = UNLIST_MY_GROUP or "Unlist My Group" };
	listButton:SetText(labels[label]);
	if ( enabled ) then listButton:Enable(); else listButton:Disable(); end
	if ( mode == "listed" and not comment:HasFocus() ) then
		local _, joined, _, _, _, lfgComment = GetLFGInfoServer();
		if ( joined and (comment:GetText() or "") == "" ) then comment:SetText(lfgComment or ""); end
	end
	if ( mode == "queued" or mode == "proposal" or mode == "rolecheck" ) then lrLocked:Show(); else lrLocked:Hide(); end
end

-- [[ browse ]] --
local browseView = CreateFrame("Frame", nil, rfPage);
browseView:SetPoint("TOPLEFT", 0, -28); browseView:SetPoint("BOTTOMRIGHT", 0, 0);
local brTop = Inset(browseView);
brTop:SetPoint("TOPLEFT", 0, 0); brTop:SetPoint("TOPRIGHT", 0, 0); brTop:SetHeight(64);
local raidDrop = CreateFrame("Frame", "TemucraftGroupFinderRaidDropDown", brTop, "UIDropDownMenuTemplate");
raidDrop:SetPoint("TOPLEFT", -6, -8);
UIDropDownMenu_SetWidth(raidDrop, 170);
local brFilter = { kind = "all", role = nil, search = "" };
local brSearch = CreateFrame("EditBox", "TemucraftGroupFinderBrowseSearch", brTop, "InputBoxTemplate");
brSearch:SetHeight(20); brSearch:SetWidth(150);
brSearch:SetPoint("TOPLEFT", 232, -12);
brSearch:SetAutoFocus(false);
local brSearchHint = brSearch:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
brSearchHint:SetPoint("LEFT", 2, 0);
brSearchHint:SetText(SEARCH or "Search");
brSearch:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
brSearch:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
brSearch:SetScript("OnTextChanged", function(self)
	local t = self:GetText() or "";
	if ( t == "" ) then brSearchHint:Show(); else brSearchHint:Hide(); end
	if ( t ~= brFilter.search ) then brFilter.search = t; Later(); end
end);
brSearch:SetScript("OnEditFocusGained", function() brSearchHint:Hide(); end);
brSearch:SetScript("OnEditFocusLost", function(self) if ( (self:GetText() or "") == "" ) then brSearchHint:Show(); end end);
local refresh = Button(brTop, REFRESH or "Refresh", 80);
refresh:SetPoint("TOPRIGHT", -10, -10);
refresh:SetScript("OnClick", function() if ( RefreshLFGList ) then RefreshLFGList(); end end);
local kindButtons = {};
for i, k in ipairs({ { "all", ALL or "All" }, { "groups", GROUPS or "Groups" }, { "players", PLAYERS or "Players" },
	{ "tank", TANK or "Tank" }, { "healer", HEALER or "Healer" }, { "dps", DAMAGER or "Damage" } }) do
	local b = BarButton(brTop, k[2], 76);
	b:SetHeight(18);
	b:SetPoint("BOTTOMLEFT", 10 + (i - 1) * 82, 8);
	b.key = k[1];
	b:SetScript("OnClick", function(self)
		if ( self.key == "tank" or self.key == "healer" or self.key == "dps" ) then
			brFilter.role = (brFilter.role ~= self.key) and self.key or nil;
		else
			brFilter.kind = self.key;
		end
		Later();
	end);
	kindButtons[i] = b;
end

local brBody = Inset(browseView);
brBody:SetPoint("TOPLEFT", brTop, "BOTTOMLEFT", 0, -6); brBody:SetPoint("BOTTOMRIGHT", 0, 40);
local cols = { { NAME or "Name", 10 }, { LEVEL_ABBR or "Lvl", 170 }, { CLASS or "Class", 210 }, { ROLES or "Roles", 320 }, { "Bosses", 400 } };
for _, c in ipairs(cols) do
	local t = brBody:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	t:SetPoint("TOPLEFT", c[2], -8);
	t:SetText(c[1]);
end
local brLine = TemucraftStyle_Line(brBody);
brLine:SetPoint("TOPLEFT", 6, -22); brLine:SetPoint("TOPRIGHT", -6, -22);
local brScroll = CreateFrame("ScrollFrame", "TemucraftGroupFinderBrowseScroll", brBody, "FauxScrollFrameTemplate");
brScroll:SetPoint("TOPLEFT", 6, -26); brScroll:SetPoint("BOTTOMRIGHT", -28, 6);
local brEmpty = brBody:CreateFontString(nil, "OVERLAY", "GameFontDisable");
brEmpty:SetPoint("CENTER");
brEmpty:SetWidth(380);
local brRows, brShown = {}, {};
local selectedName, selectedType;
local BRow_H = 18;
local BrowseRows;
local function RoleIcon(parent, x, role)
	local t = parent:CreateTexture(nil, "ARTWORK");
	t:SetTexture(ROLE_TEX);
	t:SetTexCoord(GetTexCoordsForRole(role));
	t:SetWidth(16); t:SetHeight(16);
	t:SetPoint("LEFT", x, 0);
	return t;
end
for i = 1, 16 do
	local b = CreateFrame("Button", nil, brBody);
	b:SetHeight(BRow_H);
	b:SetPoint("TOPLEFT", 6, -26 - (i - 1) * BRow_H);
	b:SetPoint("RIGHT", brScroll, "RIGHT", 0, 0);
	TemucraftStyle_Highlight(b);
	b.sel = TemucraftStyle_Glow(b);
	b.sel:Hide();
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	b.name:SetPoint("LEFT", 4, 0); b.name:SetWidth(158); b.name:SetJustifyH("LEFT");
	b.level = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.level:SetPoint("LEFT", 164, 0);
	b.class = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.class:SetPoint("LEFT", 204, 0); b.class:SetWidth(104); b.class:SetJustifyH("LEFT");
	b.tank = RoleIcon(b, 314, "TANK");
	b.healer = RoleIcon(b, 332, "HEALER");
	b.dps = RoleIcon(b, 350, "DAMAGER");
	b.party = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.party:SetPoint("LEFT", 314, 0);
	b.bosses = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.bosses:SetPoint("LEFT", 394, 0);
	b:SetScript("OnClick", function(self)
		if ( selectedName == self.unitName ) then selectedName, selectedType = nil, nil;
		else selectedName, selectedType = self.unitName, self.kind; end
		PlaySound("igMainMenuOptionCheckBoxOn");
		BrowseRows();
	end);
	b:SetScript("OnDoubleClick", function(self) if ( self.unitName and self.unitName ~= UnitName("player") ) then ChatFrame_SendTell(self.unitName); end end);
	b:SetScript("OnEnter", function(self) if ( self.index and LFRBrowseButton_OnEnter ) then LFRBrowseButton_OnEnter(self); end end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	brRows[i] = b;
end
brScroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, BRow_H, function() BrowseRows(); end); end);
local whisper = Button(browseView, WHISPER or "Whisper", 100);
whisper:SetPoint("BOTTOMRIGHT", -114, 8);
whisper:SetScript("OnClick", function() if ( selectedName ) then ChatFrame_SendTell(selectedName); end end);
local invite = Button(browseView, INVITE or "Invite", 100);
invite:SetPoint("BOTTOMRIGHT", -8, 8);
invite:SetScript("OnClick", function() if ( selectedName ) then InviteUnit(selectedName); end end);
local brCount = browseView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
brCount:SetPoint("BOTTOMLEFT", 10, 14);

local function ReadResults()
	local out = {};
	local n = SearchLFGGetNumResults and SearchLFGGetNumResults() or 0;
	for i = 1, n do
		local name, level, areaName, className, cmt, partyMembers, status, class, encountersTotal, encountersComplete, isLeader, isTank, isHealer, isDamage = SearchLFGGetResults(i);
		out[i] = { index = i, name = name, level = level, className = className, class = class, comment = cmt, partyMembers = partyMembers or 0,
			isTank = isTank, isHealer = isHealer, isDamage = isDamage, total = encountersTotal or 0, done = encountersComplete or 0 };
	end
	return out;
end
local results = {};
function BrowseRows()
	FauxScrollFrame_Update(brScroll, #brShown, #brRows, BRow_H);
	local offset = FauxScrollFrame_GetOffset(brScroll);
	local me = UnitName("player");
	local stillThere = false;
	for _, i in ipairs(brShown) do if ( results[i].name == selectedName ) then stillThere = true; end end
	if ( not stillThere ) then selectedName, selectedType = nil, nil; end
	for i, b in ipairs(brRows) do
		local r = results[brShown[i + offset] or 0];
		if ( r ) then
			b.index, b.unitName = r.index, r.name;
			b.kind = r.partyMembers > 0 and "party" or "individual";
			b.name:SetText(r.name);
			b.level:SetText(r.level or "");
			b.class:SetText(r.className or "");
			local c = r.class and RAID_CLASS_COLORS[r.class] or NORMAL_FONT_COLOR;
			b.class:SetTextColor(c.r, c.g, c.b);
			if ( r.partyMembers > 0 ) then
				b.tank:Hide(); b.healer:Hide(); b.dps:Hide();
				b.party:SetText(format("|cffffd100%s|r %d", GROUP or "Group", r.partyMembers));
			else
				b.party:SetText("");
				if ( r.isTank ) then b.tank:Show(); else b.tank:Hide(); end
				if ( r.isHealer ) then b.healer:Show(); else b.healer:Hide(); end
				if ( r.isDamage ) then b.dps:Show(); else b.dps:Hide(); end
			end
			b.bosses:SetText(r.total > 0 and (r.done.."/"..r.total) or "");
			if ( r.name == me ) then b.name:SetTextColor(0.5, 0.5, 0.5); else b.name:SetTextColor(1, 0.82, 0); end
			if ( r.name == selectedName ) then b.sel:Show(); else b.sel:Hide(); end
			b:Show();
		else
			b:Hide();
		end
	end
	if ( selectedName and selectedName ~= me ) then whisper:Enable(); else whisper:Disable(); end
	if ( selectedName and selectedName ~= me and selectedType ~= "party" and CanGroupInvite() ) then invite:Enable(); else invite:Disable(); end
end

local function JoinedRaidName()
	local id = SearchLFGGetJoinedID and SearchLFGGetJoinedID();
	if ( not id ) then return nil; end
	local info = LFGGetDungeonInfoByID(id);
	return info and info[LFG_RETURN_VALUES.name];
end
local function RaidMenu(self, level)
	LFGDungeonList_Setup();
	if ( not LFR_FULL_RAID_LIST_HEADER_ORDER ) then LFR_FULL_RAID_LIST_HEADER_ORDER, LFR_FULL_RAID_LIST = GetFullRaidList(); end
	local active = SearchLFGGetJoinedID() or "none";
	local info = UIDropDownMenu_CreateInfo();
	if ( not level or level == 1 ) then
		info.text = NONE; info.value = "none"; info.checked = active == "none";
		info.func = function() SearchLFGLeave(); UIDropDownMenu_SetText(raidDrop, NONE); Later(); end;
		UIDropDownMenu_AddButton(info);
		for _, groupID in ipairs(LFR_FULL_RAID_LIST_HEADER_ORDER) do
			info = UIDropDownMenu_CreateInfo();
			info.text = LFGGetDungeonInfoByID(groupID)[LFG_RETURN_VALUES.name];
			info.value = groupID; info.hasArrow = true; info.notCheckable = 1;
			UIDropDownMenu_AddButton(info, 1);
		end
	elseif ( level == 2 ) then
		for _, dungeonID in ipairs(LFR_FULL_RAID_LIST[UIDROPDOWNMENU_MENU_VALUE] or {}) do
			local d = LFGGetDungeonInfoByID(dungeonID);
			info = UIDropDownMenu_CreateInfo();
			info.text = format(LFD_LEVEL_FORMAT_SINGLE or "(%d)", d[LFG_RETURN_VALUES.maxPlayers]).." "..d[LFG_RETURN_VALUES.name];
			info.value = dungeonID; info.checked = active == dungeonID;
			info.func = function(button)
				HideDropDownMenu(1);
				SearchLFGJoin(LFGGetDungeonInfoByID(button.value)[LFG_RETURN_VALUES.typeID], button.value);
				UIDropDownMenu_SetText(raidDrop, d[LFG_RETURN_VALUES.name]);
				Later();
			end;
			UIDropDownMenu_AddButton(info, level);
		end
	end
end

local brTick = 0;
browseView:SetScript("OnUpdate", function(self, elapsed)
	brTick = brTick + elapsed;
	if ( brTick >= (LFR_BROWSE_AUTO_REFRESH_TIME or 20) ) then brTick = 0; if ( SearchLFGGetJoinedID and SearchLFGGetJoinedID() ) then RefreshLFGList(); end end
end);
local function UpdateBrowse()
	if ( LFGDungeonList_Setup ) then LFGDungeonList_Setup(); end
	if ( not raidDrop.temucraftInit ) then raidDrop.temucraftInit = true; UIDropDownMenu_Initialize(raidDrop, RaidMenu); end
	UIDropDownMenu_SetText(raidDrop, JoinedRaidName() or (NONE or "None"));
	results = ReadResults();
	brShown = L.BrowseFilter(results, brFilter);
	for _, b in ipairs(kindButtons) do
		if ( b.key == brFilter.kind or b.key == brFilter.role ) then b.glow:Show(); else b.glow:Hide(); end
	end
	if ( not SearchLFGGetJoinedID() ) then brEmpty:SetText("Pick a raid on the left to see who is looking for it.");
	elseif ( #brShown == 0 ) then brEmpty:SetText(#results == 0 and "Nobody is listed for this raid yet." or "Nobody matches the filter.");
	else brEmpty:SetText(""); end
	local _, total = SearchLFGGetNumResults();
	brCount:SetText(#results > 0 and format("%d / %d", #brShown, total or #results) or "");
	BrowseRows();
end

local function UpdateRaids()
	for k, b in pairs(rfSub) do if ( k == rfView ) then b.glow:Show(); else b.glow:Hide(); end end
	if ( rfView == "browse" ) then
		listView:Hide(); browseView:Show();
		-- the stock browser stops searching 40 s after it hides; never while ours is open
		if ( LFRBrowseFrame ) then LFRBrowseFrame.timeToClear = nil; end
		UpdateBrowse();
	else
		browseView:Hide(); listView:Show();
		if ( LFRBrowseFrame and SearchLFGGetJoinedID and SearchLFGGetJoinedID() ) then LFRBrowseFrame.timeToClear = 40; end
		UpdateList();
	end
end
local function LeaveBrowse()
	if ( LFRBrowseFrame and SearchLFGGetJoinedID and SearchLFGGetJoinedID() and not (LFRParentFrame and LFRParentFrame:IsShown()) ) then
		LFRBrowseFrame.timeToClear = 40;
	end
end
rfPage:SetScript("OnHide", LeaveBrowse);

TemucraftGroupFinder_AddCategory("pve", "raids", {
	label = RAID_FINDER or "Raid Finder", sub = "The Raid Browser",
	art = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-IcecrownCitadel", coords = { 0, 1, 0.2, 0.55 },
	icon = "Interface\\LFGFrame\\LFGICON-RAID", page = rfPage, title = LOOKING_FOR_RAID or "Raid Browser",
	update = UpdateRaids, onShow = function() if ( rfView == "browse" and RefreshLFGList ) then RefreshLFGList(); end end,
	tooltip = "List yourself for raids so raid leaders can invite you, or browse the players and groups looking for a raid.",
});

----------------------------------------------------------------------------------------------------------------------
-- Taking the stock windows' place
----------------------------------------------------------------------------------------------------------------------
function TemucraftGroupFinder_IsActive(tab)
	return not (TemucraftUI_IsClassic and TemucraftUI_IsClassic(L.CLASSIC[tab or "pve"]));
end

local stock = {
	ToggleLFDParentFrame = ToggleLFDParentFrame, ToggleLFRParentFrame = ToggleLFRParentFrame, TogglePVPFrame = TogglePVPFrame,
};
local MIN = function() return { dungeons = SHOW_LFD_LEVEL or 15, pvp = SHOW_PVP_LEVEL or 10 }; end
local function Run(binding, stockFunc, ...)
	local how, tab, page = L.Route(binding, function(which) return TemucraftUI_IsClassic and TemucraftUI_IsClassic(which); end,
		UnitLevel("player"), MIN());
	if ( how == "stock" ) then
		if ( frame:IsShown() and tabKey == tab ) then HideUIPanel(frame); end
		if ( stockFunc ) then return stockFunc(...); end
	elseif ( how == "ours" ) then
		TemucraftGroupFinder_Open(tab, page, true);
	end
end
function ToggleLFDParentFrame(...) return Run("TOGGLELFGPARENT", stock.ToggleLFDParentFrame, ...); end
function ToggleLFRParentFrame(...) return Run("TOGGLELFRPARENT", stock.ToggleLFRParentFrame, ...); end
function TogglePVPFrame(...)
	-- the stock one first ends a battlemaster's "just battlegrounds" view
	if ( PVPFrame_IsJustBG and PVPFrame_IsJustBG() ) then return stock.TogglePVPFrame(...); end
	return Run("TOGGLECHARACTER4", stock.TogglePVPFrame, ...);
end

-- a ShowUIPanel of a stock window (the Dungeon Finder from gossip, the battlemaster's queue): ours, a frame later
local swap = CreateFrame("Frame");
swap:Hide();
local pending = {};
local fromGossip = false;
swap:SetScript("OnUpdate", function(self)
	self:Hide();
	for name, tab in pairs(pending) do
		local f = _G[name];
		pending[name] = nil;
		if ( f and f:IsShown() and TemucraftGroupFinder_IsActive(tab) ) then
			local page;
			if ( name == "LFDParentFrame" ) then
				page = "dungeons";
				fromGossip = f.fromGossip and true or false;
				f.fromGossip = false;   -- its OnHide would close the gossip
			elseif ( name == "LFRParentFrame" ) then page = "raids";
			elseif ( name == "PVPParentFrame" ) then
				page = "battlegrounds";
				f.justBG = false;
			end
			HideUIPanel(f);
			TemucraftGroupFinder_Open(tab, page);
		end
	end
end);
local function Watch(name, tab)
	local f = _G[name];
	if ( not f ) then return; end
	f:HookScript("OnShow", function() if ( TemucraftGroupFinder_IsActive(tab) ) then pending[name] = tab; swap:Show(); end end);
end
Watch("LFDParentFrame", "pve");
Watch("LFRParentFrame", "pve");
Watch("PVPParentFrame", "pvp");
TemucraftGroupFinder_OnHide(function()
	if ( fromGossip ) then fromGossip = false; CloseGossip(); end
end);

-- the micro buttons look pushed while ours is open (stock UpdateMicroButtons only knows the stock frames)
hooksecurefunc("UpdateMicroButtons", function()
	local pve, pvp = TemucraftGroupFinder_IsShown("pve"), TemucraftGroupFinder_IsShown("pvp");
	if ( pve and LFDMicroButton ) then LFDMicroButton:SetButtonState("PUSHED", 1); end
	if ( pvp and PVPMicroButton ) then PVPMicroButton:SetButtonState("PUSHED", 1); if ( PVPMicroButton_SetPushed ) then PVPMicroButton_SetPushed(); end end
	local ours = _G["TemucraftMicroButton_lfd"];
	if ( ours and (pve or pvp) ) then ours:SetButtonState("PUSHED", 1); end
end);

-- back to the stock window while ours is open: it closes
if ( TemucraftUI_OnChange ) then
	TemucraftUI_OnChange("classiclfg", function(on) if ( on and TemucraftGroupFinder_IsShown("pve") ) then HideUIPanel(frame); end end);
	TemucraftUI_OnChange("classicpvp", function(on) if ( on and TemucraftGroupFinder_IsShown("pvp") ) then HideUIPanel(frame); end end);
end

local events = CreateFrame("Frame");
for _, e in ipairs({ "LFG_UPDATE", "LFG_ROLE_UPDATE", "LFG_UPDATE_RANDOM_INFO", "LFG_LOCK_INFO_RECEIVED", "LFG_QUEUE_STATUS_UPDATE",
	"LFG_PROPOSAL_UPDATE", "LFG_PROPOSAL_SHOW", "LFG_PROPOSAL_FAILED", "LFG_PROPOSAL_SUCCEEDED", "LFG_ROLE_CHECK_SHOW",
	"LFG_ROLE_CHECK_HIDE", "LFG_OFFER_CONTINUE", "PARTY_MEMBERS_CHANGED", "PARTY_LEADER_CHANGED", "PLAYER_LEVEL_UP",
	"UPDATE_LFG_LIST", "PLAYER_ENTERING_WORLD" }) do
	events:RegisterEvent(e);
end
events:RegisterEvent("UNIT_AURA");
events:SetScript("OnEvent", function(self, event, unit)
	if ( event == "UNIT_AURA" and unit ~= "player" and not (unit and string.sub(unit, 1, 5) == "party") ) then return; end
	if ( event == "PARTY_MEMBERS_CHANGED" and not CanPartyLFGBackfill() ) then backfillHidden = false; end
	Later();
end);

local function Slash(tab, page) return function() TemucraftGroupFinder_SlashOpen(tab, page); end; end
function TemucraftGroupFinder_SlashOpen(tab, page)
	if ( not TemucraftGroupFinder_IsActive(tab) ) then
		if ( tab == "pvp" ) then stock.TogglePVPFrame();
		elseif ( page == "raids" ) then stock.ToggleLFRParentFrame();
		else stock.ToggleLFDParentFrame(); end
		return;
	end
	TemucraftGroupFinder_Open(tab, page, true);
end
SLASH_TEMUCRAFTGROUPFINDER1 = "/groupfinder";
SLASH_TEMUCRAFTGROUPFINDER2 = "/lfd";
SLASH_TEMUCRAFTGROUPFINDER3 = "/lfg";
SlashCmdList["TEMUCRAFTGROUPFINDER"] = Slash("pve", "dungeons");
SLASH_TEMUCRAFTRAIDFINDER1 = "/lfr";
SLASH_TEMUCRAFTRAIDFINDER2 = "/raidbrowser";
SlashCmdList["TEMUCRAFTRAIDFINDER"] = Slash("pve", "raids");
