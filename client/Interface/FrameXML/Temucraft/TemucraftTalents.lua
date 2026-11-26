-- Temucraft talents (the Specialization and Talents tabs of TemucraftPlayerSpells.lua).
--   Specialization: one card per talent tree (its art, role, description, preferred weapon, primary stat, two sample
--     abilities). 3.3.5 has no specs, so a card is "Active" when its tree has the most points in the active talent
--     group, and Activate switches to the other talent group (dual talent specialization) when that one is built
--     around this tree (or is still empty).
--   Talents: the three trees side by side on their backgrounds, with the points spent and left. Clicks go to the
--     client's own talent preview (previewTalents): left click adds a point, right click takes one back, nothing is
--     learned until "Apply Changes". A search box lights up the talents whose name or tooltip match. The Loadouts
--     menu lists the server's loadout slots (mod-temucraft-loadouts: save, load, rename, unlock; loading swaps the
--     build, its glyphs and action bars into the active talent group with no gold cost). The older "Preview builds"
--     save a build to a name (per character, TemucraftStore) and load it back into the preview only; without the
--     server module they are the whole menu. The glyph sockets are along the bottom.
-- Applying, resetting and switching talent groups are refused in combat, like the stock frame.
-- loadouts: "name=ranks.ranks.ranks@name=...", one digit per talent (per character)
TemucraftTalentsLogic = {};
function TemucraftTalentsLogic.Parse(text)
	local out = {};
	for entry in string.gmatch(text or "", "[^@]+") do
		local name, ranks = string.match(entry, "^(.-)=(.*)$");
		if ( name and name ~= "" ) then
			local list = {};
			for tree in string.gmatch(ranks.."." , "([^%.]*)%.") do table.insert(list, tree); end
			table.insert(out, { name = name, trees = list });
		end
	end
	return out;
end
function TemucraftTalentsLogic.Serialize(list)
	local parts = {};
	for _, l in ipairs(list) do table.insert(parts, l.name.."="..table.concat(l.trees, ".")); end
	return table.concat(parts, "@");
end
function TemucraftTalentsLogic.CleanName(name)
	name = string.gsub(name or "", "[^%w %-_']", "");
	return string.sub(strtrim and strtrim(name) or name, 1, 24);
end

-- Server loadouts (mod-temucraft-loadouts, addon prefix TLO): up to 10 slots kept by the server, each with the
-- talents, glyphs and action bars of the active talent group; loading swaps one into the active group (no gold).
-- The server sends S~enabled~slots~castMs~cooldown~actions~glyphs~tokenItem, L~n~state~tokens~gold~a/b/c~name per
-- slot, E; C~n~ms (loading), X~n (interrupted), D~n (loaded). Slot states: 0 locked, 1 locked and next to buy,
-- 2 needs dual spec, 3 empty, 4 saved. Without the module (no answer) the menu keeps the local preview builds.
TemucraftLoadoutsLogic = { PREFIX = "TLO", server = nil, slots = {}, loading = nil };
local LO = TemucraftLoadoutsLogic;
function LO.Fields(text, max)
	local out, pos = {}, 1;
	while ( true ) do
		if ( max and #out == max - 1 ) then table.insert(out, string.sub(text, pos)); break; end
		local at = string.find(text, "~", pos, true);
		if ( not at ) then table.insert(out, string.sub(text, pos)); break; end
		table.insert(out, string.sub(text, pos, at - 1));
		pos = at + 1;
	end
	return out;
end
-- returns the record kind
function LO.OnMessage(text)
	local kind = string.match(text or "", "^[^~]*");
	if ( kind == "S" ) then
		local f = LO.Fields(text, 8);
		LO.pending = { enabled = f[2] == "1", count = tonumber(f[3]) or 0, castMs = tonumber(f[4]) or 0,
			cooldown = tonumber(f[5]) or 0, actions = f[6] == "1", glyphs = f[7] == "1", tokenItem = tonumber(f[8]) or 0 };
		LO.pendingSlots = {};
	elseif ( kind == "L" and LO.pending ) then
		local f = LO.Fields(text, 7);
		local n = tonumber(f[2]);
		if ( n ) then
			LO.pendingSlots[n] = { slot = n, state = tonumber(f[3]) or 0, tokens = tonumber(f[4]) or 0, gold = tonumber(f[5]) or 0,
				trees = f[6] or "0/0/0", name = f[7] or ("Loadout "..n) };
		end
	elseif ( kind == "E" and LO.pending ) then
		LO.server, LO.slots = LO.pending, LO.pendingSlots;
		LO.pending, LO.pendingSlots = nil, nil;
	elseif ( kind == "C" ) then
		local f = LO.Fields(text, 3);
		LO.loading = { slot = tonumber(f[2]), ms = tonumber(f[3]) or 0 };
	elseif ( kind == "X" or kind == "D" ) then
		LO.loading = nil;
	end
	return kind;
end
function LO.Active() return LO.server ~= nil and LO.server.enabled; end
function LO.Unlocked(s) return s and (s.state == 3 or s.state == 4); end
function LO.Gold(n)
	local s = tostring(n or 0);
	while ( true ) do
		local k;
		s, k = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2");
		if ( k == 0 ) then break; end
	end
	return s.." gold";
end
function LO.Cost(s)
	if ( s.tokens == 0 and s.gold == 0 ) then return "free"; end
	local parts = {};
	if ( s.tokens > 0 ) then table.insert(parts, s.tokens.." Temucraft Token"..(s.tokens == 1 and "" or "s")); end
	if ( s.gold > 0 ) then table.insert(parts, LO.Gold(s.gold)); end
	return table.concat(parts, " or ");
end
function LO.Label(s)
	if ( s.state == 4 ) then return s.slot..". "..s.name.."  |cff999999("..s.trees..")|r"; end
	if ( s.state == 3 ) then return s.slot..". "..s.name.."  |cff999999(empty)|r"; end
	if ( s.state == 2 ) then return "|cff999999"..s.slot..". Needs Dual Talent Specialization|r"; end
	if ( s.state == 1 ) then return "|cff999999"..s.slot..". Locked|r  |cffffd100"..LO.Cost(s).."|r"; end
	return "|cff666666"..s.slot..". Locked|r";
end
-- a request to the server; nil when the record is not valid
function LO.Request(kind, slot, extra)
	if ( kind == "HELLO" or kind == "LIST" or kind == "CANCEL" ) then return kind; end
	if ( not tonumber(slot) ) then return nil; end
	local text = kind.."~"..slot;
	if ( extra ) then text = text.."~"..string.gsub(extra, "[~|\t]", " "); end
	return string.sub(text, 1, 240);
end
if ( not CreateFrame ) then return; end   -- tests load only the logic
local P = TemucraftTalentsLogic;
local KEY = "talent.loadouts";

local TAB_SPEC, TAB_TALENTS = TEMUCRAFT_PLAYERSPELLS_TAB_SPEC, TEMUCRAFT_PLAYERSPELLS_TAB_TALENTS;
local TREE_WIDTH, TREE_HEIGHT, NODE, STEP_X, STEP_Y = 256, 476, 32, 54, 39;
local MAX_TALENTS, MAX_TIERS = 40, 11;

local function Group() return GetActiveTalentGroup(false, false); end
local function Unspent()
	return GetUnspentTalentPoints(false, false, Group()) - GetGroupPreviewTalentPointsSpent(false, Group());
end
local function Primary(group)
	local best, bestPoints = nil, 0;
	for t = 1, GetNumTalentTabs() do
		local _, _, points = GetTalentTabInfo(t, false, false, group);
		if ( points and points > bestPoints ) then best, bestPoints = t, points; end
	end
	return best;
end
local function SpecInfo(t)
	local _, token = UnitClass("player");
	local class = TEMUCRAFT_TALENT_SPECS and TEMUCRAFT_TALENT_SPECS[token];
	return class and class[t] or { roles = { "DAMAGER" }, text = "", weapon = "-", stat = "-", samples = {} };
end
local function Background(t)
	local _, _, _, background = GetTalentTabInfo(t, false, false, Group());
	return "Interface\\TalentFrame\\"..(background or "MageFire").."-";
end
local function Notice(text) UIErrorsFrame:AddMessage(text, 1, 0.1, 0.1); end

----------------------------------------------------------------------------------------------------------------------
-- Specialization
----------------------------------------------------------------------------------------------------------------------
local spec = CreateFrame("Frame", "TemucraftSpecialization", UIParent);
local cards = {};
for t = 1, 3 do
	local c = CreateFrame("Frame", "TemucraftSpecializationCard"..t, spec);
	c:SetWidth(252); c:SetHeight(560);
	c:SetPoint("TOP", spec, "TOP", (t - 2) * (252 + 18), -40);   -- centred: 20 px margins in the 860 window
	c:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } });
	c:SetBackdropColor(0, 0, 0, 0.75);
	c.art = c:CreateTexture(nil, "ARTWORK");
	c.art:SetPoint("TOPLEFT", 5, -5); c.art:SetPoint("TOPRIGHT", -5, -5); c.art:SetHeight(200);
	c.art:SetTexCoord(0, 1, 0, 0.8);
	c.shade = c:CreateTexture(nil, "OVERLAY");
	c.shade:SetTexture(0, 0, 0, 0.6);
	c.shade:SetPoint("BOTTOMLEFT", c.art, "BOTTOMLEFT"); c.shade:SetPoint("BOTTOMRIGHT", c.art, "BOTTOMRIGHT"); c.shade:SetHeight(46);
	c.icon = c:CreateTexture(nil, "OVERLAY");
	c.icon:SetWidth(36); c.icon:SetHeight(36); c.icon:SetPoint("BOTTOMLEFT", c.art, "BOTTOMLEFT", 6, 5);
	c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	c.name:SetPoint("LEFT", c.icon, "RIGHT", 8, 0); c.name:SetJustifyH("LEFT");
	c.roleIcon = c:CreateTexture(nil, "ARTWORK");
	c.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES");
	c.roleIcon:SetWidth(22); c.roleIcon:SetHeight(22); c.roleIcon:SetPoint("TOPLEFT", c.art, "BOTTOMLEFT", 6, -8);
	c.role = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	c.role:SetPoint("LEFT", c.roleIcon, "RIGHT", 6, 0);
	c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	c.text:SetPoint("TOPLEFT", c.roleIcon, "BOTTOMLEFT", 0, -10); c.text:SetWidth(232); c.text:SetJustifyH("LEFT");
	c.weapon = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	c.weapon:SetPoint("TOPLEFT", c.text, "BOTTOMLEFT", 0, -12); c.weapon:SetWidth(232); c.weapon:SetJustifyH("LEFT");
	c.stat = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	c.stat:SetPoint("TOPLEFT", c.weapon, "BOTTOMLEFT", 0, -6); c.stat:SetWidth(232); c.stat:SetJustifyH("LEFT");
	c.samplesLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	c.samplesLabel:SetPoint("TOPLEFT", c.stat, "BOTTOMLEFT", 0, -14);
	c.samplesLabel:SetText("Sample abilities");
	c.samples = {};
	for k = 1, 2 do
		local s = CreateFrame("Button", nil, c);
		s:SetWidth(36); s:SetHeight(36);
		s:SetPoint("TOPLEFT", c.samplesLabel, "BOTTOMLEFT", (k - 1) * 44, -6);
		s.icon = s:CreateTexture(nil, "ARTWORK"); s.icon:SetAllPoints();
		s:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
		s:SetScript("OnEnter", function(self)
			if ( not self.spell ) then return; end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("spell:"..self.spell); GameTooltip:Show();
		end);
		s:SetScript("OnLeave", function() GameTooltip:Hide(); end);
		c.samples[k] = s;
	end
	c.points = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	c.points:SetPoint("BOTTOM", 0, 52); c.points:SetWidth(232);
	c.active = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	c.active:SetTextColor(0.1, 1, 0.1);
	c.active:SetPoint("BOTTOM", 0, 18);
	c.active:SetText("Active");
	c.button = CreateFrame("Button", "TemucraftSpecializationCard"..t.."Activate", c, "UIPanelButtonTemplate");
	c.button:SetWidth(120); c.button:SetHeight(24);
	c.button:SetPoint("BOTTOM", 0, 14);
	c.button:SetScript("OnClick", function(self)
		if ( self.group == "talents" ) then TemucraftPlayerSpells_Show(TAB_TALENTS); return; end
		if ( InCombatLockdown() ) then Notice(ERR_NOT_IN_COMBAT); return; end
		if ( self.group ) then SetActiveTalentGroup(self.group); end
	end);
	c.button:SetScript("OnEnter", function(self)
		if ( not self.tip ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(self.tip, 1, 1, 1, 1, 1); GameTooltip:Show();
	end);
	c.button:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	cards[t] = c;
end
local specNote = spec:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
specNote:SetPoint("TOPLEFT", 16, -18);
specNote:SetJustifyH("LEFT");

local function UpdateSpec()
	local numTabs = GetNumTalentTabs();
	local active = Group();
	local groups = GetNumTalentGroups(false, false);
	local primary = Primary(active);
	local other = groups > 1 and (active == 1 and 2 or 1) or nil;
	local otherPrimary = other and Primary(other);
	if ( groups > 1 ) then
		local o = otherPrimary and GetTalentTabInfo(otherPrimary, false, false, other) or "no talents yet";
		specNote:SetText(format("Active: %s talents. Your other talent group: %s.", active == 1 and "primary" or "secondary", o));
	else
		specNote:SetText("Learn Dual Talent Specialization from a class trainer to switch between two sets of talents.");
	end
	for t, c in ipairs(cards) do
		if ( t > numTabs ) then c:Hide(); else
			c:Show();
			local name, icon, points = GetTalentTabInfo(t, false, false, active);
			local info = SpecInfo(t);
			c.art:SetTexture(Background(t).."TopLeft");
			c.icon:SetTexture(icon);
			c.name:SetText(name);
			local role = info.roles[1];
			local coords = TEMUCRAFT_ROLE_COORDS[role];
			c.roleIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]);
			local roleNames = {};
			for _, r in ipairs(info.roles) do table.insert(roleNames, TEMUCRAFT_ROLE_NAMES[r]); end
			c.role:SetText(table.concat(roleNames, " / "));
			c.text:SetText(info.text);
			c.weapon:SetText("|cffffd100Preferred weapon:|r "..info.weapon);
			c.stat:SetText("|cffffd100Primary stat:|r "..info.stat);
			for k, s in ipairs(c.samples) do
				local id = info.samples[k];
				local _, _, sampleIcon = id and GetSpellInfo(id);
				s.spell = sampleIcon and id or nil;
				if ( sampleIcon ) then s.icon:SetTexture(sampleIcon); s:Show(); else s:Hide(); end
			end
			local otherPoints = other and select(3, GetTalentTabInfo(t, false, false, other)) or nil;
			c.points:SetText(format("%d points%s", points or 0, otherPoints and format("  (other group: %d)", otherPoints) or ""));
			c.button.group, c.button.tip = nil, nil;
			if ( primary == t ) then
				c.active:Show(); c.button:Hide();
			elseif ( not primary ) then
				c.active:Hide(); c.button:Show(); c.button:Enable();
				c.button:SetText("Choose");
				c.button.group = "talents";
				c.button.tip = "Spend your talent points in this tree on the Talents tab.";
			elseif ( other and (otherPrimary == t or not otherPrimary) ) then
				c.active:Hide(); c.button:Show();
				c.button:SetText("Activate");
				c.button.group = other;
				c.button.tip = otherPrimary and "Switches to your other talent group, built around "..name.."."
					or "Switches to your other talent group, which has no talents yet.";
				if ( InCombatLockdown() ) then c.button:Disable(); else c.button:Enable(); end
			else
				c.active:Hide(); c.button:Show(); c.button:Disable();
				c.button:SetText("Activate");
				c.button.tip = other and ("Your other talent group is built around "..(GetTalentTabInfo(otherPrimary, false, false, other))..
					". Changing learned talents needs a respec at a class trainer.")
					or "Changing learned talents needs a respec at a class trainer, or Dual Talent Specialization.";
			end
		end
	end
end

TemucraftPlayerSpells_AddPanel(TAB_SPEC, spec, UpdateSpec);

----------------------------------------------------------------------------------------------------------------------
-- Talents
----------------------------------------------------------------------------------------------------------------------
local talents = CreateFrame("Frame", "TemucraftTalents", UIParent);
local query = "";
local described = {};
local scan = CreateFrame("GameTooltip", "TemucraftTalentsScanTooltip", nil, "GameTooltipTemplate");
local trees = {};

local function Describe(t, i)
	local key = t..":"..i;
	if ( not described[key] ) then
		scan:SetOwner(WorldFrame, "ANCHOR_NONE");
		scan:SetTalent(t, i, false, false, Group(), false);
		local parts = {};
		for l = 1, scan:NumLines() do
			local left = _G["TemucraftTalentsScanTooltipTextLeft"..l];
			if ( left and left:GetText() ) then table.insert(parts, left:GetText()); end
		end
		scan:Hide();
		described[key] = string.lower(table.concat(parts, " "));
	end
	return described[key];
end

local function Matches(t, i)
	if ( query == "" ) then return false; end
	local text = Describe(t, i);
	for word in string.gmatch(string.lower(query), "%S+") do
		if ( not string.find(text, word, 1, true) ) then return false; end
	end
	return true;
end

local function NodePosition(tier, column)
	return 34 + (column - 1) * STEP_X, -44 - (tier - 1) * STEP_Y;
end

local function MakeNode(tree, i)
	local name = tree:GetName().."Talent"..i;
	local b = CreateFrame("Button", name, tree);
	b:SetWidth(NODE); b:SetHeight(NODE);
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints();
	b.slot = b:CreateTexture(nil, "BACKGROUND");
	b.slot:SetTexture("Interface\\Buttons\\UI-Quickslot2");
	b.slot:SetWidth(56); b.slot:SetHeight(56); b.slot:SetPoint("CENTER", 0, -1);
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
	b.glow = b:CreateTexture(nil, "OVERLAY");
	b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");
	b.glow:SetBlendMode("ADD");
	b.glow:SetVertexColor(1, 0.9, 0.2);
	b.glow:SetWidth(64); b.glow:SetHeight(64); b.glow:SetPoint("CENTER");
	b.glow:Hide();
	b.rankBorder = b:CreateTexture(nil, "OVERLAY");
	b.rankBorder:SetTexture("Interface\\TalentFrame\\TalentFrame-RankBorder");
	b.rankBorder:SetWidth(32); b.rankBorder:SetHeight(32); b.rankBorder:SetPoint("CENTER", b, "BOTTOMRIGHT", 0, 0);
	b.rank = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	b.rank:SetPoint("CENTER", b.rankBorder, "CENTER", 0, 0);
	b:SetScript("OnClick", function(self, button)
		local t, group = self:GetParent().tab, Group();
		if ( IsModifiedClick("CHATLINK") ) then
			local link = GetTalentLink(t, self.index, false, false, group, true);
			if ( link ) then ChatEdit_InsertLink(link); end
			return;
		end
		AddPreviewTalentPoints(t, self.index, button == "RightButton" and -1 or 1, false, group);
	end);
	-- the client's own talent tooltip has the green / red "Left click to add a point" lines (preview on)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetTalent(self:GetParent().tab, self.index, false, false, Group(), true);
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	b.index = i;
	return b;
end

for t = 1, 3 do
	local tree = CreateFrame("Frame", "TemucraftTalentsTree"..t, talents);
	tree.tab = t;
	tree:SetWidth(TREE_WIDTH); tree:SetHeight(TREE_HEIGHT);
	tree:SetPoint("TOPLEFT", 20 + (t - 1) * (TREE_WIDTH + 12), -44);   -- the window is 860 wide on this tab (TemucraftPlayerSpells.lua)
	tree.bg = {};
	local pieces = { { "TopLeft", 0, 0, 0.8 * TREE_WIDTH, 0.75 * TREE_HEIGHT }, { "TopRight", 0.8 * TREE_WIDTH, 0, 0.2 * TREE_WIDTH, 0.75 * TREE_HEIGHT },
		{ "BottomLeft", 0, 0.75 * TREE_HEIGHT, 0.8 * TREE_WIDTH, 0.25 * TREE_HEIGHT }, { "BottomRight", 0.8 * TREE_WIDTH, 0.75 * TREE_HEIGHT, 0.2 * TREE_WIDTH, 0.25 * TREE_HEIGHT } };
	for _, p in ipairs(pieces) do
		local tex = tree:CreateTexture(nil, "BACKGROUND");
		tex:SetPoint("TOPLEFT", p[2], -p[3]); tex:SetWidth(p[4]); tex:SetHeight(p[5]);
		tex.piece = p[1];
		table.insert(tree.bg, tex);
	end
	local strip = tree:CreateTexture(nil, "BORDER");
	strip:SetTexture(0, 0, 0, 0.65);
	strip:SetPoint("TOPLEFT"); strip:SetPoint("TOPRIGHT"); strip:SetHeight(26);
	tree.icon = tree:CreateTexture(nil, "ARTWORK");
	tree.icon:SetWidth(20); tree.icon:SetHeight(20); tree.icon:SetPoint("TOPLEFT", 4, -3);
	tree.title = tree:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	tree.title:SetPoint("LEFT", tree.icon, "RIGHT", 6, 0);
	tree.points = tree:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	tree.points:SetPoint("TOPRIGHT", -8, -7);
	tree.nodes, tree.lines = {}, {};
	for i = 1, MAX_TALENTS do tree.nodes[i] = MakeNode(tree, i); tree.nodes[i]:Hide(); end
	trees[t] = tree;
end

local function Line(tree, n)
	local line = tree.lines[n];
	if ( not line ) then
		line = tree:CreateTexture(nil, "BORDER");
		tree.lines[n] = line;
	end
	line:ClearAllPoints();
	line:Show();
	return line;
end

-- prerequisite line from (pt, pc) to (tier, column): across the prerequisite's row, then down
local function DrawPrereq(tree, n, pt, pc, tier, column, met)
	local r, g, b = 0.5, 0.5, 0.5;
	if ( met ) then r, g, b = 1, 0.82, 0; end
	local x1, y1 = NodePosition(pt, pc);
	local x2, y2 = NodePosition(tier, column);
	local half = NODE / 2;
	if ( pc ~= column ) then
		n = n + 1;
		local h = Line(tree, n);
		h:SetTexture(r, g, b, 0.9);
		local left = min(x1, x2) + half;
		h:SetPoint("TOPLEFT", tree, "TOPLEFT", left, y1 - half + 2);
		h:SetWidth(abs(x2 - x1)); h:SetHeight(4);
	end
	if ( pt ~= tier ) then
		n = n + 1;
		local v = Line(tree, n);
		v:SetTexture(r, g, b, 0.9);
		local top = (pc ~= column) and (y1 - half + 2) or (y1 - NODE);
		v:SetPoint("TOPLEFT", tree, "TOPLEFT", x2 + half - 2, top);
		v:SetWidth(4); v:SetHeight(max(2, top - y2));
	end
	return n;
end

local pointsText = talents:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
pointsText:SetPoint("BOTTOMLEFT", 16, 46);
local note = talents:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
note:SetPoint("BOTTOMLEFT", 16, 32);
note:SetText("Learned talents can only be changed by a respec at a class trainer, or by switching talent groups.");

local function UpdateTree(tree)
	local t, group = tree.tab, Group();
	local name, icon, spent, _, previewSpent = GetTalentTabInfo(t, false, false, group);
	if ( not name ) then tree:Hide(); return; end
	tree:Show();
	local base = Background(t);
	for _, tex in ipairs(tree.bg) do tex:SetTexture(base..tex.piece); end
	tree.icon:SetTexture(icon);
	tree.title:SetText(name);
	local tabPoints = (spent or 0) + (previewSpent or 0);
	tree.points:SetText(previewSpent and previewSpent > 0 and format("%d |cff40ff40(+%d)|r", spent, previewSpent) or tostring(spent));
	local unspent = Unspent();
	local num = GetNumTalents(t, false, false);
	local lines = 0;
	for i = 1, MAX_TALENTS do
		local b = tree.nodes[i];
		if ( i > num ) then b:Hide(); else
			local tname, ticon, tier, column, rank, maxRank, _, _, previewRank, meetsPreviewPrereq = GetTalentInfo(t, i, false, false, group);
			if ( not tname or tier > MAX_TIERS ) then b:Hide(); else
				b:ClearAllPoints();
				local x, y = NodePosition(tier, column);
				b:SetPoint("TOPLEFT", tree, "TOPLEFT", x, y);
				b.icon:SetTexture(ticon);
				previewRank = previewRank or rank;
				local open = ((tier - 1) * 5 <= tabPoints) and meetsPreviewPrereq;
				local lit = previewRank > 0 or (open and unspent > 0);
				b.icon:SetDesaturated(not lit);
				b.rank:SetText(previewRank);
				if ( not lit ) then
					b.slot:SetVertexColor(0.5, 0.5, 0.5);
					b.rankBorder:Hide(); b.rank:Hide();
				else
					b.rankBorder:Show(); b.rank:Show();
					if ( previewRank > rank ) then
						b.slot:SetVertexColor(0.3, 0.8, 1); b.rank:SetTextColor(0.4, 0.85, 1);
					elseif ( previewRank < maxRank ) then
						b.slot:SetVertexColor(0.1, 1, 0.1); b.rank:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b);
					else
						b.slot:SetVertexColor(1, 0.82, 0); b.rank:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
					end
				end
				if ( Matches(t, i) ) then b.glow:Show(); else b.glow:Hide(); end
				b:Show();
				local prereqs = { GetTalentPrereqs(t, i, false, false, group) };
				for k = 1, #prereqs, 4 do
					local pt, pc, _, previewLearnable = prereqs[k], prereqs[k + 1], prereqs[k + 2], prereqs[k + 3];
					if ( pt and pc ) then lines = DrawPrereq(tree, lines, pt, pc, tier, column, previewLearnable); end
				end
			end
		end
	end
	for n = lines + 1, #tree.lines do tree.lines[n]:Hide(); end
end

local applyButton = CreateFrame("Button", "TemucraftTalentsApplyButton", talents, "UIPanelButtonTemplate");
applyButton:SetWidth(130); applyButton:SetHeight(24);
applyButton:SetPoint("BOTTOMRIGHT", -16, 40);
applyButton:SetText("Apply Changes");
local resetButton = CreateFrame("Button", "TemucraftTalentsResetButton", talents, "UIPanelButtonTemplate");
resetButton:SetWidth(110); resetButton:SetHeight(24);
resetButton:SetPoint("RIGHT", applyButton, "LEFT", -6, 0);
resetButton:SetText("Reset Preview");

StaticPopupDialogs["TEMUCRAFT_LEARN_PREVIEW_TALENTS"] = {
	text = CONFIRM_LEARN_PREVIEW_TALENTS, button1 = YES, button2 = NO,
	OnAccept = function() if ( not InCombatLockdown() ) then LearnPreviewTalents(false); end end,
	hideOnEscape = 1, timeout = 0, exclusive = 1,
};
applyButton:SetScript("OnClick", function()
	if ( InCombatLockdown() ) then Notice(ERR_NOT_IN_COMBAT); return; end
	StaticPopup_Show("TEMUCRAFT_LEARN_PREVIEW_TALENTS");
end);
resetButton:SetScript("OnClick", function()
	ResetGroupPreviewTalentPoints(false, Group());
end);

-- search
local search = CreateFrame("EditBox", "TemucraftTalentsSearch", talents, "InputBoxTemplate");
search:SetWidth(200); search:SetHeight(20); search:SetAutoFocus(false);
search:SetPoint("TOPRIGHT", -40, -16);   -- clear of the close button
local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
hint:SetPoint("LEFT", 2, 0); hint:SetText("Search talents");
search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
search:SetScript("OnEditFocusGained", function() hint:Hide(); end);
search:SetScript("OnEditFocusLost", function(self) if ( self:GetText() == "" ) then hint:Show(); end end);

-- glyphs along the bottom
local glyphs = {};
StaticPopupDialogs["TEMUCRAFT_REMOVE_GLYPH"] = {
	text = CONFIRM_REMOVE_GLYPH or "Remove %s?", button1 = YES, button2 = NO,
	OnAccept = function(self) RemoveGlyphFromSocket(self.data); end,
	hideOnEscape = 1, timeout = 0, exclusive = 1,
};
StaticPopupDialogs["TEMUCRAFT_REPLACE_GLYPH"] = {
	text = "Replace this glyph?", button1 = YES, button2 = NO,
	OnAccept = function(self) PlaceGlyphInSocket(self.data); end,
	OnCancel = function() ClearCursor(); end,
	hideOnEscape = 1, timeout = 0, exclusive = 1,
};
local glyphLabel = talents:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
glyphLabel:SetPoint("BOTTOMLEFT", 16, 14);
glyphLabel:SetText("Glyphs");
for i = 1, 6 do
	local g = CreateFrame("Button", "TemucraftTalentsGlyph"..i, talents);
	g:SetID(i);
	g:SetWidth(24); g:SetHeight(24);
	g:SetPoint("LEFT", glyphLabel, "RIGHT", 10 + (i - 1) * 30, 0);
	g:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	g.icon = g:CreateTexture(nil, "ARTWORK"); g.icon:SetAllPoints();
	g:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
	g:SetScript("OnClick", function(self, button)
		local id, group = self:GetID(), Group();
		local _, _, glyphSpell = GetGlyphSocketInfo(id, group);
		if ( IsModifiedClick("CHATLINK") ) then
			local link = GetGlyphLink(id, group);
			if ( link ) then ChatEdit_InsertLink(link); end
		elseif ( button == "RightButton" ) then
			if ( IsShiftKeyDown() and glyphSpell ) then
				local dialog = StaticPopup_Show("TEMUCRAFT_REMOVE_GLYPH", (GetSpellInfo(glyphSpell)));
				if ( dialog ) then dialog.data = id; end
			end
		elseif ( glyphSpell and SpellIsTargeting() ) then
			local dialog = StaticPopup_Show("TEMUCRAFT_REPLACE_GLYPH");
			if ( dialog ) then dialog.data = id; end
		else
			PlaceGlyphInSocket(id);
		end
	end);
	g:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP");
		GameTooltip:SetGlyph(self:GetID(), Group());
		GameTooltip:AddLine("Use a glyph, then click a socket. Shift-right-click removes one.", 0.6, 0.6, 0.6, 1);
		GameTooltip:Show();
	end);
	g:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	glyphs[i] = g;
end
local function UpdateGlyphs()
	local group = Group();
	for i, g in ipairs(glyphs) do
		local enabled, glyphType, glyphSpell, icon = GetGlyphSocketInfo(i, group);
		if ( glyphSpell and icon ) then
			g.icon:SetTexture(icon); g.icon:SetVertexColor(1, 1, 1);
		else
			g.icon:SetTexture("Interface\\Buttons\\UI-EmptySlot-Disabled");
			if ( glyphType == 1 ) then g.icon:SetVertexColor(1, 0.82, 0.4); else g.icon:SetVertexColor(0.6, 0.8, 1); end
		end
		g:SetAlpha(enabled and 1 or 0.35);
	end
end

local function UpdateTalents()
	if ( not talents:IsShown() ) then return; end
	for _, tree in ipairs(trees) do UpdateTree(tree); end
	local unspent = Unspent();
	local preview = GetGroupPreviewTalentPointsSpent(false, Group());
	pointsText:SetText(format("Points left: |cffffffff%d|r", unspent)..(preview > 0 and format("   |cff66ccffPreview: %d to apply|r", preview) or ""));
	if ( preview > 0 and not InCombatLockdown() ) then applyButton:Enable(); resetButton:Enable();
	else applyButton:Disable(); if ( preview > 0 ) then resetButton:Enable(); else resetButton:Disable(); end end
	UpdateGlyphs();
end

search:SetScript("OnTextChanged", function(self)
	local text = self:GetText();
	if ( text ~= "" ) then hint:Hide(); end
	query = text;
	UpdateTalents();
end);


local function Loadouts() return P.Parse(TemucraftStore_Get and TemucraftStore_Get("C", KEY)); end
local function SaveLoadouts(list) if ( TemucraftStore_Set ) then TemucraftStore_Set("C", KEY, P.Serialize(list)); end end

local function CurrentBuild()
	local out = {};
	for t = 1, GetNumTalentTabs() do
		local digits = {};
		for i = 1, GetNumTalents(t) do
			local _, _, _, _, rank, _, _, _, previewRank = GetTalentInfo(t, i, false, false, Group());
			table.insert(digits, tostring(min(9, previewRank or rank or 0)));
		end
		out[t] = table.concat(digits);
	end
	return out;
end

local function LoadBuild(l)
	local group = Group();
	ResetGroupPreviewTalentPoints(false, group);
	local short = nil;
	-- tier by tier, a few passes, so prerequisites and tier points come first
	for pass = 1, 12 do
		local changed = false;
		for t = 1, GetNumTalentTabs() do
			local digits = l.trees[t] or "";
			for i = 1, GetNumTalents(t) do
				local want = tonumber(string.sub(digits, i, i)) or 0;
				local tname, _, _, _, rank, _, _, _, previewRank = GetTalentInfo(t, i, false, false, group);
				previewRank = previewRank or rank;
				if ( want < rank ) then short = short or tname; end
				if ( want > previewRank and Unspent() > 0 ) then
					AddPreviewTalentPoints(t, i, 1, false, group);
					local _, _, _, _, _, _, _, _, after = GetTalentInfo(t, i, false, false, group);
					if ( after and after > previewRank ) then changed = true; end
				end
			end
		end
		if ( not changed ) then break; end
	end
	if ( short ) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTemucraft:|r \""..l.name.."\" has fewer points in "..short..
			" than you have learned: respec at a class trainer (or switch talent groups) to use all of it.");
	end
	UpdateTalents();
end

StaticPopupDialogs["TEMUCRAFT_SAVE_LOADOUT"] = {
	text = "Save your talents (with the preview) as:", button1 = SAVE or "Save", button2 = CANCEL,
	hasEditBox = 1, maxLetters = 24,
	OnAccept = function(self)
		local name = P.CleanName(_G[self:GetName().."EditBox"]:GetText());
		if ( name == "" ) then return; end
		local list = Loadouts();
		local build = { name = name, trees = CurrentBuild() };
		local replaced = false;
		for k, l in ipairs(list) do if ( l.name == name ) then list[k] = build; replaced = true; end end
		if ( not replaced ) then table.insert(list, build); end
		SaveLoadouts(list);
	end,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent();
		StaticPopupDialogs["TEMUCRAFT_SAVE_LOADOUT"].OnAccept(parent);
		parent:Hide();
	end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide(); end,
	hideOnEscape = 1, timeout = 0, exclusive = 1, whileDead = 1,
};

-- the server loadouts (mod-temucraft-loadouts)
local function SendLoadouts(kind, slot, extra)
	local text = LO.Request(kind, slot, extra);
	if ( text ) then SendAddonMessage(LO.PREFIX, text, "WHISPER", UnitName("player")); end
end
StaticPopupDialogs["TEMUCRAFT_LOADOUT_UNLOCK"] = {
	text = "Unlock loadout slot %s for %s?", button1 = YES or "Yes", button2 = NO or "No",
	OnAccept = function(self, data) SendLoadouts("UNLOCK", data.slot, data.currency); end,
	hideOnEscape = 1, timeout = 0, exclusive = 1, whileDead = 1,
};
StaticPopupDialogs["TEMUCRAFT_LOADOUT_OVERWRITE"] = {
	text = "Save your learned talents, glyphs and action bars to loadout %s (%s)? This replaces what it holds.",
	button1 = SAVE or "Save", button2 = CANCEL,
	OnAccept = function(self, data) SendLoadouts("SAVE", data); end,
	hideOnEscape = 1, timeout = 0, exclusive = 1, whileDead = 1,
};
StaticPopupDialogs["TEMUCRAFT_LOADOUT_RENAME"] = {
	text = "Name of loadout %s:", button1 = ACCEPT or "Accept", button2 = CANCEL,
	hasEditBox = 1, maxLetters = 24,
	OnShow = function(self) _G[self:GetName().."EditBox"]:SetText(""); _G[self:GetName().."EditBox"]:SetFocus(); end,
	OnAccept = function(self, data)
		local name = strtrim(_G[self:GetName().."EditBox"]:GetText() or "");
		if ( name ~= "" ) then SendLoadouts("RENAME", data, name); end
	end,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent();
		StaticPopupDialogs["TEMUCRAFT_LOADOUT_RENAME"].OnAccept(parent, parent.data);
		parent:Hide();
	end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide(); end,
	hideOnEscape = 1, timeout = 0, exclusive = 1, whileDead = 1,
};

local dropdown = CreateFrame("Frame", "TemucraftTalentsLoadoutDropDown", talents, "UIDropDownMenuTemplate");
dropdown:SetPoint("TOPLEFT", 0, -12);
UIDropDownMenu_SetWidth(dropdown, 170);
local function Button(level, text, func, disabled, tooltip)
	local info = UIDropDownMenu_CreateInfo();
	info.text = text; info.notCheckable = 1; info.func = func; info.disabled = disabled;
	if ( tooltip ) then info.tooltipTitle = text; info.tooltipText = tooltip; end
	UIDropDownMenu_AddButton(info, level);
end
-- the local preview builds (per character, TemucraftStore); with the server loadouts they are a submenu
local function LocalMenu(level, deleteLevel)
	if ( UIDROPDOWNMENU_MENU_VALUE == "localdel" and level == deleteLevel ) then
		for k, l in ipairs(Loadouts()) do
			Button(level, l.name, function() local list = Loadouts(); table.remove(list, k); SaveLoadouts(list); CloseDropDownMenus(); end);
		end
		return;
	end
	local list = Loadouts();
	for _, l in ipairs(list) do
		Button(level, l.name, function() LoadBuild(l); end, nil, "Loads it into the preview; press Apply Changes to learn it.");
	end
	Button(level, "Save current talents...", function() StaticPopup_Show("TEMUCRAFT_SAVE_LOADOUT"); end);
	if ( #list > 0 ) then
		local info = UIDropDownMenu_CreateInfo();
		info.text = "Delete"; info.notCheckable = 1; info.hasArrow = 1; info.value = "localdel";
		UIDropDownMenu_AddButton(info, level);
	end
end
local function SlotMenu(level, s)
	if ( LO.Unlocked(s) ) then
		local busy = LO.loading ~= nil or InCombatLockdown();
		Button(level, "Load", function() CloseDropDownMenus(); SendLoadouts("LOAD", s.slot); end, s.state ~= 4 or busy,
			"Swaps this build into your active talent group (no gold cost). Stand still for a moment, out of combat.");
		Button(level, "Save current talents here", function()
			CloseDropDownMenus();
			if ( s.state == 4 ) then StaticPopup_Show("TEMUCRAFT_LOADOUT_OVERWRITE", s.slot, s.name, s.slot);
			else SendLoadouts("SAVE", s.slot); end
		end, LO.loading ~= nil, "Learned talents only: apply your preview first.");
		Button(level, "Rename...", function() CloseDropDownMenus(); StaticPopup_Show("TEMUCRAFT_LOADOUT_RENAME", s.slot, nil, s.slot); end);
	elseif ( s.state == 1 ) then
		local function Unlock(currency, cost)
			CloseDropDownMenus();
			StaticPopup_Show("TEMUCRAFT_LOADOUT_UNLOCK", s.slot, cost, { slot = s.slot, currency = currency });
		end
		if ( s.tokens == 0 and s.gold == 0 ) then
			Button(level, "Unlock (free)", function() Unlock("token", "free"); end);
		end
		if ( s.tokens > 0 ) then
			local cost = s.tokens.." Temucraft Token"..(s.tokens == 1 and "" or "s");
			Button(level, "Unlock for "..cost, function() Unlock("token", cost); end);
		end
		if ( s.gold > 0 ) then
			Button(level, "Unlock for "..LO.Gold(s.gold), function() Unlock("gold", LO.Gold(s.gold)); end);
		end
	elseif ( s.state == 2 ) then
		Button(level, "Learn Dual Talent Specialization at your class trainer", nil, 1);
	else
		Button(level, "Unlock the slots before it first", nil, 1);
	end
end
UIDropDownMenu_Initialize(dropdown, function(self, level)
	level = level or 1;
	if ( not LO.Active() ) then LocalMenu(level, 2); return; end
	if ( level >= 2 ) then
		local value = UIDROPDOWNMENU_MENU_VALUE;
		if ( value == "local" or value == "localdel" ) then LocalMenu(level, 3); return; end
		if ( LO.slots[value] ) then SlotMenu(level, LO.slots[value]); end
		return;
	end
	local info = UIDropDownMenu_CreateInfo();
	info.text = "Talent loadouts"; info.isTitle = 1; info.notCheckable = 1;
	UIDropDownMenu_AddButton(info, level);
	for n = 1, LO.server.count do
		local s = LO.slots[n];
		if ( s ) then
			info = UIDropDownMenu_CreateInfo();
			info.text = LO.Label(s); info.notCheckable = 1; info.hasArrow = 1; info.value = n;
			UIDropDownMenu_AddButton(info, level);
		end
	end
	info = UIDropDownMenu_CreateInfo();
	info.text = "Preview builds"; info.notCheckable = 1; info.hasArrow = 1; info.value = "local";
	info.tooltipTitle = info.text; info.tooltipText = "Builds kept by this client, loaded into the preview only.";
	UIDropDownMenu_AddButton(info, level);
end);
UIDropDownMenu_SetText(dropdown, "Loadouts");
local function LoadoutText()
	local l = LO.loading and LO.slots[LO.loading.slot];
	UIDropDownMenu_SetText(dropdown, l and ("Loading "..l.name.."...") or "Loadouts");
end
local loadoutEvents = CreateFrame("Frame");
loadoutEvents:RegisterEvent("CHAT_MSG_ADDON");
loadoutEvents:RegisterEvent("PLAYER_ENTERING_WORLD");
loadoutEvents:SetScript("OnEvent", function(self, event, prefix, text, channel, sender)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		if ( not self.asked ) then self.asked = true; SendLoadouts("HELLO"); end
		return;
	end
	if ( prefix ~= LO.PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") ) then return; end
	local kind = LO.OnMessage(text);
	if ( kind == "E" or kind == "C" or kind == "X" or kind == "D" ) then
		LoadoutText();
		if ( kind == "E" and UIDROPDOWNMENU_OPEN_MENU == dropdown ) then CloseDropDownMenus(); end
	end
end);

local classic = CreateFrame("CheckButton", "TemucraftTalentsClassicCheck", talents, "UICheckButtonTemplate");
classic:SetWidth(24); classic:SetHeight(24);
classic:SetPoint("BOTTOMRIGHT", -150, 8);
_G[classic:GetName().."Text"]:SetText("Classic talents");
classic:SetScript("OnClick", function(self)
	self:SetChecked(false);
	TemucraftPlayerSpells_SetClassic("talents", true);
	TemucraftStockToggleTalentFrame();
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTemucraft:|r classic talent frame on (/ttf new for this one).");
end);

TemucraftPlayerSpells_AddPanel(TAB_TALENTS, talents, function()
	-- the retail way: nothing is learned until Apply Changes
	if ( not GetCVarBool("previewTalents") ) then SetCVar("previewTalents", "1"); end
	if ( LO.server ) then SendLoadouts("LIST"); end
	UpdateTalents();
end);

local events = CreateFrame("Frame");
for _, e in ipairs({ "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "PREVIEW_TALENT_POINTS_CHANGED",
	"ACTIVE_TALENT_GROUP_CHANGED", "GLYPH_ADDED", "GLYPH_REMOVED", "GLYPH_UPDATED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
	events:RegisterEvent(e);
end
events:SetScript("OnEvent", function(self, event)
	if ( event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE" ) then wipe(described); end
	if ( talents:IsShown() ) then
		UpdateTalents();
		-- the tooltip of the talent under the mouse shows its new rank at once
		local owner = GameTooltip:IsShown() and GameTooltip:GetOwner();
		if ( owner and owner.index and owner.rank and owner:GetParent() and owner:GetParent().tab ) then
			owner:GetScript("OnEnter")(owner);
		end
	end
	if ( spec:IsShown() ) then UpdateSpec(); end
end);

----------------------------------------------------------------------------------------------------------------------
-- The stock talent frame (Classic talent window) with Temucraft's talents
----------------------------------------------------------------------------------------------------------------------
-- Temucraft's added talents sit between some talents and their prerequisite in the same column. The stock
-- TalentFrame_DrawLines (TalentFrameBase.lua) then takes the "blocked vertically" branch, whose message indexes
-- TALENT_BRANCH_ARRAY[buttonTier][tier] and breaks ("attempt to index field '?'"), so the stock frame failed on every
-- update, and once Blizzard_TalentUI was loaded its hidden frame broke on every preview point of this window too
-- (PREVIEW_TALENT_POINTS_CHANGED). This copy draws such a line straight through (like retail) and skips any
-- position outside the frame's grid.
local function Branch(frame, tier, column)
	local row = frame.TALENT_BRANCH_ARRAY and frame.TALENT_BRANCH_ARRAY[tier];
	return row and row[column];
end
local function SafeDrawLines(buttonTier, buttonColumn, tier, column, requirementsMet, frame)
	if ( not (buttonTier and buttonColumn and tier and column and Branch(frame, buttonTier, buttonColumn) and Branch(frame, tier, column)) ) then return; end
	requirementsMet = requirementsMet and 1 or -1;
	local A = frame.TALENT_BRANCH_ARRAY;
	if ( buttonColumn == column ) then
		for i = tier, buttonTier - 1 do
			A[i][buttonColumn].down = requirementsMet;
			if ( i + 1 <= buttonTier - 1 ) then A[i + 1][buttonColumn].up = requirementsMet; end
		end
		A[buttonTier][buttonColumn].topArrow = requirementsMet;
		return;
	end
	local left, right = min(buttonColumn, column), max(buttonColumn, column);
	if ( buttonTier == tier ) then
		for i = left + 1, right - 1 do if ( A[tier][i].id ) then return; end end
		for i = left, right - 1 do A[tier][i].right = requirementsMet; A[tier][i + 1].left = requirementsMet; end
		if ( buttonColumn < column ) then A[buttonTier][buttonColumn].rightArrow = requirementsMet;
		else A[buttonTier][buttonColumn].leftArrow = requirementsMet; end
		return;
	end
	-- diagonal: across the prerequisite's row, then down; if that row is blocked, down first, then across
	local l, r = left, right;
	if ( l == column ) then l = l + 1; else r = r - 1; end
	local blocked = false;
	for i = l, r do if ( A[tier][i].id ) then blocked = true; end end
	if ( not blocked ) then
		A[tier][buttonColumn].down = requirementsMet;
		A[buttonTier][buttonColumn].up = requirementsMet;
		for i = tier, buttonTier - 1 do A[i][buttonColumn].down = requirementsMet; A[i + 1][buttonColumn].up = requirementsMet; end
		for i = left, right - 1 do A[tier][i].right = requirementsMet; A[tier][i + 1].left = requirementsMet; end
		A[buttonTier][buttonColumn].topArrow = requirementsMet;
		return;
	end
	l, r = left, right;
	if ( l == buttonColumn ) then l = l + 1; else r = r - 1; end
	for i = l, r do if ( A[buttonTier][i].id ) then return; end end
	for i = tier, buttonTier - 1 do A[i][column].up = requirementsMet; A[i + 1][column].down = requirementsMet; end
	if ( buttonColumn < column ) then A[buttonTier][buttonColumn].rightArrow = requirementsMet;
	else A[buttonTier][buttonColumn].leftArrow = requirementsMet; end
end
TalentFrame_DrawLines = SafeDrawLines;
TemucraftTalents_DrawLines = SafeDrawLines;   -- for debugging (/run)
-- the stock frame, while hidden, does not redraw on every preview point of this window (it redraws when shown)
local hooked = false;
local function QuietStockFrame()
	if ( hooked or not PlayerTalentFrame ) then return; end
	hooked = true;
	local onEvent = PlayerTalentFrame:GetScript("OnEvent");
	PlayerTalentFrame:SetScript("OnEvent", function(self, event, ...)
		if ( not self:IsShown() and (event == "PREVIEW_TALENT_POINTS_CHANGED" or event == "PREVIEW_PET_TALENT_POINTS_CHANGED"
			or event == "PLAYER_TALENT_UPDATE" or event == "PET_TALENT_UPDATE") ) then return; end
		if ( onEvent ) then return onEvent(self, event, ...); end
	end);
end
events:RegisterEvent("ADDON_LOADED");
local onEvent = events:GetScript("OnEvent");
events:SetScript("OnEvent", function(self, event, name, ...)
	if ( event == "ADDON_LOADED" ) then
		if ( name == "Blizzard_TalentUI" ) then QuietStockFrame(); end
		-- something loaded after FrameXML may have put the stock function back
		if ( TalentFrame_DrawLines ~= SafeDrawLines ) then TalentFrame_DrawLines = SafeDrawLines; end
		return;
	end
	return onEvent(self, event, name, ...);
end);
QuietStockFrame();
