-- Temucraft new-player tutorial, like retail's Exile's Reach prompts. Client only.
-- A new character (level 1, under 15 minutes played, or no experience yet when the played time doesn't come) is shown:
--   "Position your hands and click Okay" (a centred panel: keyboard with W A S D lit, a mouse), then dark bars at the
--   lower centre: "Look around" (camera turned with a mouse button held), "Walk around" (moving), "Talk to <NPC>" (a
--   gossip or quest window opened; the NPC's name is remembered from UnitName("npc")), "Accept the quest"
--   (QUEST_ACCEPTED, or the quest log growing), then for a kill quest "Target a <mob>" (the quest's "<mob> slain"
--   objective; a hostile target), a gold pointer at the action button: "Press 1 to cast <spell>" (the first spell on
--   action slots 1-12 that isn't Attack / Auto Shot / Shoot), "Don't move while casting." (the cast stopped by moving),
--   "Again!" (cast done, the enemy still up) until it dies, then "Quest complete! Return to the questgiver." at the
--   quest tracker once the quest is complete. A quest without a kill objective shows its objective ("Your quest: ...")
--   until it is turned in, and the chain goes on with the next quest giver. Beside the chain: "You've gained experience!"
--   at the XP bar (first experience), "Open your Spellbook and find <spell>" at the spellbook micro button, which
--   glows (a spell learned; done when a spellbook opens).
-- Nothing blocks input: only the small buttons take the mouse. Each prompt has an "x" (skips that step), the bars and
-- the panel a "Skip tutorial". Pointers follow DragonUI's frames (ActionButton<n> wherever DragonUI put it,
-- DragonUI_XPBar, DragonUI's quest tracker, the moved SpellbookMicroButton) or ours (TemucraftMicroButton_spellbook),
-- with a screen position when none is shown.
-- Saved with TemucraftStore: per account "tutorial.off" ("1" = tutorials off) and "tutorial.seen" ("1" = one character
-- finished it: the next new one is asked "This account already finished the tutorial. Skip it?"), per character
-- "tutorial" (the step it is on, then "done").
--   TemucraftTutorial_IsEnabled() / TemucraftTutorial_SetEnabled(on)   the Options window's "Tutorials" box
--   TemucraftTutorial_Reset()                                           its "Reset Tutorials" button (and /ttutorial reset)
--   /ttutorial [reset | skip | on | off]
TemucraftTutorialLogic = {};
local L = TemucraftTutorialLogic;

L.MAX_PLAYED = 15 * 60;        -- seconds: older characters don't start it
L.GIVE_UP_LEVEL = 6;           -- the spellbook prompt waits up to this level
L.MAX_FOLLOW = 4;              -- non-kill quests in a row before the chain ends anyway
L.SKIP_SPELLS = { ["Attack"] = true, ["Auto Shot"] = true, ["Shoot"] = true, ["Auto Attack"] = true };

-- the main chain, in order (route: after "accept" a kill quest goes to "target", any other to "follow")
L.STEPS = { "hands", "look", "walk", "talk", "accept", "follow", "target", "cast", "turnin" };

-- what to do at login: "start", "ask" (the account finished it already), "resume", or nil
--   o = { enabled, progress (saved step or "done"), accountSeen, level, played (seconds or nil), xp }
function L.Start(o)
	if ( not o.enabled ) then return nil; end
	local p = o.progress;
	if ( p == "done" ) then return nil; end
	if ( p and p ~= "" ) then
		if ( (o.level or 1) >= L.GIVE_UP_LEVEL ) then return nil; end
		return "resume";
	end
	if ( (o.level or 1) > 1 ) then return nil; end
	if ( o.played ) then
		if ( o.played >= L.MAX_PLAYED ) then return nil; end
	elseif ( (o.xp or 0) > 0 ) then
		return nil;
	end
	return o.accountSeen and "ask" or "start";
end

-- the mob of a kill objective: objs = { { text = "Kobold Vermin slain: 0/6", type = "monster" }, ... }
function L.KillTarget(objs)
	for _, o in ipairs(objs or {}) do
		if ( o.type == "monster" and o.text ) then
			local name = string.match(o.text, "^(.-) slain") or string.match(o.text, "^(.-):");
			if ( name and name ~= "" ) then return name; end
			return "";
		end
	end
	return nil;
end

-- the action slot to teach: actions = { [slot] = { kind = "spell", name = "Fireball" }, ... } (slots 1-12)
function L.PickSpell(actions)
	for slot = 1, 12 do
		local a = actions[slot];
		if ( a and a.kind == "spell" and a.name and not L.SKIP_SPELLS[a.name] ) then return slot, a.name; end
	end
	return nil;
end

-- a learned-spell line ("You have learned a new spell: |cff71d5ff|Hspell:133|h[Fireball]|h|r.") -> "Fireball"
function L.LearnedName(msg, patterns)
	for _, pattern in ipairs(patterns) do
		local lua = "^"..string.gsub(string.gsub(pattern, "([%%%(%)%.%[%]%*%+%-%?%^%$])", "%%%1"), "%%%%s", "(.+)").."$";
		local name = string.match(msg, lua);
		if ( name ) then
			name = string.match(name, "%[(.-)%]") or string.gsub(name, "|c%x%x%x%x%x%x%x%x", "");
			name = string.gsub(name, "|r", "");
			return name;
		end
	end
	return nil;
end

-- resume: steps that only make sense with a window open or a target go back one
local RESUME = { hands = "hands", accept = "talk", cast = "target" };

-- a machine: progress = the saved string ("look", "turnin;x;b" ...) or nil
function L.New(progress)
	local m = { step = "hands", npc = nil, spell = nil, text = nil, ready = false, follows = 0,
		xpShown = false, bookDone = false, side = nil, mainDone = false, done = false, changed = true };
	if ( progress and progress ~= "" ) then
		local step, flags = string.match(progress, "^([^;]*)(.*)$");
		if ( step == "end" ) then m.mainDone = true; m.step = nil; else m.step = RESUME[step] or step; end
		m.xpShown = string.find(flags, ";x") ~= nil;
		m.bookDone = string.find(flags, ";b") ~= nil;
		local valid = m.step == nil;
		for _, s in ipairs(L.STEPS) do if ( s == m.step ) then valid = true; end end
		if ( not valid ) then m.step = "look"; end
		if ( m.step == "turnin" or m.step == "follow" ) then m.step = "talk"; end   -- the quest is not known after a relog
	end
	return m;
end

-- what to save
function L.Progress(m)
	if ( m.done ) then return "done"; end
	return (m.step or "end")..(m.xpShown and ";x" or "")..(m.bookDone and ";b" or "");
end

local function Go(m, step)
	m.step = step;
	m.text = nil;
	m.changed = true;
	if ( step == nil ) then m.mainDone = true; end
end

local function CheckDone(m, level)
	if ( m.mainDone and (m.bookDone or (level or 1) >= L.GIVE_UP_LEVEL) and m.side == nil ) then m.done = true; m.changed = true; end
end

-- events: OKAY, LOOK, MOVE, TALK (npc name), TALK_CLOSED, ACCEPT / QUEST_INFO ({ title, kill = mob or nil, objective }),
-- TURNIN (npc name), TARGET
-- ({ hostile = bool, spell = { slot, name, key } or nil }), CAST_MOVED, CAST_DONE, KILL, READY, TURNIN, XP, LEARN
-- (spell name), BOOK_OPEN, XP_TIMEOUT, CLOSE ("main" | "side"), SKIP, LEVEL (n). Returns true if what shows changed.
function L.Handle(m, ev, arg)
	m.changed = false;
	if ( m.done ) then return false; end
	local s = m.step;
	if ( ev == "SKIP" ) then
		m.step = nil; m.mainDone = true; m.side = nil; m.bookDone = true; m.done = true; m.skipped = true; m.changed = true;
		return true;
	end
	-- quest facts kept whatever the step
	if ( ev == "TALK" and arg and arg ~= "" ) then m.talking = arg; end
	if ( ev == "ACCEPT" and m.talking ) then m.npc = m.talking; end
	if ( ev == "TALK_CLOSED" ) then m.npc = nil; end
	if ( ev == "TURNIN" and arg and arg ~= "" ) then m.npc = arg; end
	if ( ev == "READY" ) then m.ready = true; end
	-- side prompts
	if ( ev == "XP" and not m.xpShown and s ~= "hands" ) then
		m.xpShown = true;
		if ( not m.side ) then m.side = "xp"; end
		m.changed = true;
	elseif ( ev == "XP_TIMEOUT" and m.side == "xp" ) then
		m.side = m.pendingBook and "book" or nil; m.pendingBook = nil; m.changed = true;
	elseif ( ev == "LEARN" and not m.bookDone ) then
		m.bookSpell = arg or m.bookSpell;
		if ( m.side == "xp" ) then m.pendingBook = true; else m.side = "book"; end
		m.changed = true;
	elseif ( ev == "BOOK_OPEN" and (m.side == "book" or m.pendingBook) ) then
		m.bookDone = true; m.pendingBook = nil;
		if ( m.side == "book" ) then m.side = nil; end
		m.changed = true;
	elseif ( ev == "CLOSE" and arg == "side" and m.side ) then
		if ( m.side == "book" ) then m.bookDone = true; end
		m.side = m.pendingBook and "book" or nil; m.pendingBook = nil;
		m.changed = true;
	elseif ( ev == "LEVEL" ) then
		CheckDone(m, arg);
		return m.changed;
	end
	-- the main chain
	if ( ev == "CLOSE" and arg == "main" and s ) then
		if ( s == "hands" ) then Go(m, "look");
		elseif ( s == "look" ) then Go(m, "walk");
		elseif ( s == "walk" ) then Go(m, "talk");
		elseif ( s == "talk" or s == "accept" or s == "follow" ) then Go(m, "target");
		elseif ( s == "target" ) then Go(m, "turnin");
		elseif ( s == "cast" ) then Go(m, "turnin");
		else Go(m, nil); end
	elseif ( s == "hands" ) then
		if ( ev == "OKAY" or ev == "MOVE" ) then Go(m, "look"); end
	elseif ( s == "look" ) then
		if ( ev == "LOOK" ) then Go(m, "walk"); end
	elseif ( s == "walk" ) then
		if ( ev == "MOVE" ) then Go(m, "talk"); end
	elseif ( s == "talk" ) then
		if ( ev == "TALK" ) then Go(m, "accept");
		elseif ( ev == "ACCEPT" ) then m.step = "accept"; return L.Handle(m, ev, arg) or true; end
	elseif ( s == "accept" ) then
		if ( ev == "ACCEPT" ) then
			arg = arg or {};
			m.ready = false;
			m.quest = arg.title;
			if ( arg.kill ) then
				m.mob = (arg.kill ~= "") and arg.kill or nil;
				Go(m, "target");
			else
				m.objective = arg.objective;
				Go(m, "follow");
			end
		elseif ( ev == "TALK_CLOSED" ) then
			Go(m, "talk");
		end
	elseif ( s == "follow" ) then
		if ( ev == "TURNIN" ) then
			m.follows = m.follows + 1;
			if ( m.follows >= L.MAX_FOLLOW ) then Go(m, nil); else Go(m, "talk"); end
		elseif ( ev == "QUEST_INFO" and arg and arg.title == m.quest ) then
			if ( arg.kill ) then
				m.mob = (arg.kill ~= "") and arg.kill or nil;
				Go(m, "target");
			elseif ( arg.objective and arg.objective ~= m.objective ) then
				m.objective = arg.objective; m.changed = true;
			end
		end
	elseif ( s == "target" ) then
		if ( ev == "TARGET" and arg and arg.hostile ) then
			m.spell = arg.spell;
			if ( m.spell ) then Go(m, "cast"); m.text = "press"; else Go(m, "cast"); m.text = "melee"; end
		elseif ( ev == "KILL" ) then
			Go(m, "turnin");
		end
	elseif ( s == "cast" ) then
		if ( ev == "CAST_MOVED" and m.spell ) then m.text = "moving"; m.changed = true;
		elseif ( ev == "CAST_DONE" and m.spell ) then m.text = "again"; m.changed = true;
		elseif ( ev == "KILL" ) then Go(m, "turnin");
		elseif ( ev == "TARGET" and arg and not arg.hostile ) then Go(m, "target");
		elseif ( ev == "TARGET" and arg and arg.hostile and arg.spell ) then m.spell = arg.spell; end
	elseif ( s == "turnin" ) then
		if ( ev == "READY" ) then m.changed = true;
		elseif ( ev == "TURNIN" ) then Go(m, nil); end
	end
	CheckDone(m, arg and type(arg) == "number" and arg or nil);
	return m.changed;
end

-- what shows: main = { kind = "panel" | "bar" | "pointer", text, icon, anchor } or nil, side = the same or nil
function L.View(m)
	if ( m.done ) then return {}; end
	local v = {};
	local s = m.step;
	if ( s == "hands" ) then
		v.main = { kind = "panel", text = "Position your hands and click Okay" };
	elseif ( s == "look" ) then
		v.main = { kind = "bar", text = "Look around", icon = "look" };
	elseif ( s == "walk" ) then
		v.main = { kind = "bar", text = "Walk around", icon = "wasd" };
	elseif ( s == "talk" ) then
		v.main = { kind = "bar", text = m.npc and ("Talk to "..m.npc) or "Talk to the quest giver (!)", icon = "right" };
	elseif ( s == "accept" ) then
		v.main = { kind = "bar", text = "Accept the quest", icon = "left" };
	elseif ( s == "follow" ) then
		local o = m.objective;
		if ( o and #o > 70 ) then o = string.sub(o, 1, 67).."..."; end
		v.main = { kind = "bar", text = o and o ~= "" and ("Your quest: "..o) or "Follow your quest", icon = "quest" };
	elseif ( s == "target" ) then
		local mob = m.mob;
		local an = mob and (string.find(mob, "^[AEIOUaeiou]") and "an " or "a ") or "";
		v.main = { kind = "bar", text = mob and ("Target "..an..mob) or "Target an enemy", icon = "left" };
	elseif ( s == "cast" ) then
		if ( m.spell ) then
			local text;
			if ( m.text == "moving" ) then text = "Don't move while casting.";
			elseif ( m.text == "again" ) then text = "Again!";
			else text = "Press "..(m.spell.key or tostring(m.spell.slot)).." to cast "..m.spell.name; end
			v.main = { kind = "pointer", text = text, anchor = "action", slot = m.spell.slot };
		else
			v.main = { kind = "bar", text = "Right-click the enemy to attack", icon = "right" };
		end
	elseif ( s == "turnin" ) then
		if ( m.ready ) then
			v.main = { kind = "pointer", text = "Quest complete! Return to the questgiver.", anchor = "tracker" };
		end
	end
	if ( m.side == "xp" ) then
		v.side = { kind = "pointer", text = "You've gained experience! You'll level up when this bar is filled.", anchor = "xp" };
	elseif ( m.side == "book" ) then
		v.side = { kind = "pointer", text = m.bookSpell and ("Open your Spellbook and find "..m.bookSpell) or "Open your Spellbook to see your new spell",
			anchor = "book", glow = true };
	end
	return v;
end

-- where a pointer box goes beside its frame: "above" (arrow down), "left" (arrow right) or "right" (arrow left)
function L.Side(cx, cy, screenW, screenH)
	if ( cy < screenH * 0.3 ) then return "above"; end
	if ( cx > screenW * 0.5 ) then return "left"; end
	return "right";
end

-- the frames a pointer can point at, first shown one wins (DragonUI's or ours before the stock ones)
L.ANCHORS = {
	xp = { "DragonUI_XPBar", "MainMenuExpBar" },
	tracker = { "DragonUIObjectiveTracker", "DragonUI_QuestTrackerFrame", "Questie_BaseFrame", "WatchFrame" },
	book = { "TemucraftMicroButton_spellbook", "SpellbookMicroButton" },
};
-- with nothing shown: a point on the screen (UIParent point, x, y)
L.FALLBACK = {
	action = { "BOTTOM", -230, 30 }, xp = { "BOTTOM", 0, 50 }, tracker = { "RIGHT", -60, 120 }, book = { "BOTTOMRIGHT", -200, 30 },
};
-- the spellbook windows that end the spellbook prompt
L.BOOKS = { "SpellBookFrame", "DragonUI_SpellbookFrame", "TemucraftSpellBook", "TemucraftPlayerSpellsFrame" };

if ( not CreateFrame ) then return; end   -- tests load only the logic

-- [[ saved values ]] --
local function Get(scope, key) return TemucraftStore_Get and TemucraftStore_Get(scope, key); end
local function Set(scope, key, text) if ( TemucraftStore_Set ) then TemucraftStore_Set(scope, key, text); end end

function TemucraftTutorial_IsEnabled() return Get("A", "tutorial.off") ~= "1"; end

local machine;               -- the running tutorial, or nil
local Show, Stop, Begin;     -- below

function TemucraftTutorial_SetEnabled(on)
	Set("A", "tutorial.off", on and "" or "1");
	if ( not on and machine ) then Stop(); end
end

local GOLD = { 1, 0.82, 0 };
local function Say(text) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Temucraft:|r "..text); end

-- [[ art: stock 3.3.5 textures only ]] --
local BACKDROP = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } };
local ARROW = "Interface\\Minimap\\ROTATING-MINIMAPGUIDEARROW";   -- a gold arrowhead pointing up, centred
-- texture corners for the arrow pointing down / right / left / up
local ARROW_COORDS = {
	down = { 0, 1, 0, 0, 1, 1, 1, 0 }, right = { 0, 1, 1, 1, 0, 0, 1, 0 },
	left = { 1, 0, 0, 0, 1, 1, 0, 1 }, up = { 0, 0, 0, 1, 1, 0, 1, 1 },
};
local function PointArrow(tex, dir) tex:SetTexCoord(unpack(ARROW_COORDS[dir])); end

local function Solid(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer);
	t:SetTexture(r, g, b, a);
	return t;
end

-- a key cap: dark square with a grey (or gold, lit) edge and its label
local function Key(parent, label, w, h, lit)
	local k = CreateFrame("Frame", nil, parent);
	k:SetWidth(w); k:SetHeight(h);
	k:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } });
	if ( lit ) then
		k:SetBackdropColor(0.35, 0.27, 0.05, 1); k:SetBackdropBorderColor(1, 0.82, 0, 1);
	else
		k:SetBackdropColor(0.12, 0.12, 0.12, 1); k:SetBackdropBorderColor(0.45, 0.45, 0.45, 1);
	end
	local t = k:CreateFontString(nil, "OVERLAY", h >= 24 and "GameFontNormal" or "GameFontNormalSmall");
	t:SetPoint("CENTER", 0, 1);
	t:SetText(label);
	if ( lit ) then t:SetTextColor(1, 0.9, 0.4); else t:SetTextColor(0.75, 0.75, 0.75); end
	return k;
end

-- a mouse: body, two buttons (red = the one to press), a wheel
local function Mouse(parent, w, red)
	local h = w * 1.55;
	local m = CreateFrame("Frame", nil, parent);
	m:SetWidth(w); m:SetHeight(h);
	m:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	m:SetBackdropColor(0.16, 0.16, 0.16, 1); m:SetBackdropBorderColor(0.6, 0.6, 0.6, 1);
	local half = (w - 6) / 2;
	local function Button(which, x)
		local b = Solid(m, "ARTWORK", 0.26, 0.26, 0.26, 1);
		if ( red == which ) then b:SetTexture(0.85, 0.1, 0.05, 1); end
		b:SetWidth(half - 1); b:SetHeight(h * 0.38);
		b:SetPoint("TOPLEFT", m, "TOPLEFT", x, -3);
		return b;
	end
	Button("left", 3); Button("right", 3 + half + 1);
	local wheel = Solid(m, "OVERLAY", 0.6, 0.6, 0.6, 1);
	wheel:SetWidth(math.max(3, w * 0.1)); wheel:SetHeight(h * 0.16);
	wheel:SetPoint("TOP", m, "TOP", 0, -6);
	local line = Solid(m, "ARTWORK", 0.05, 0.05, 0.05, 1);
	line:SetHeight(1); line:SetPoint("TOPLEFT", 3, -3 - h * 0.38); line:SetPoint("TOPRIGHT", -3, -3 - h * 0.38);
	return m;
end

local function SmallArrow(parent, dir, size)
	local t = parent:CreateTexture(nil, "OVERLAY");
	t:SetTexture(ARROW); t:SetWidth(size); t:SetHeight(size);
	PointArrow(t, dir);
	return t;
end

-- the bar's icons, built once each
local icons = {};
local function Icon(holder, kind)
	if ( icons[kind] ) then return icons[kind]; end
	local f = CreateFrame("Frame", nil, holder);
	f:SetAllPoints(holder);
	if ( kind == "look" ) then
		local m = Mouse(f, 20, "right"); m:SetPoint("CENTER");
		SmallArrow(f, "left", 16):SetPoint("RIGHT", m, "LEFT", 2, 0);
		SmallArrow(f, "right", 16):SetPoint("LEFT", m, "RIGHT", -2, 0);
	elseif ( kind == "right" or kind == "left" ) then
		Mouse(f, 22, kind):SetPoint("CENTER");
	elseif ( kind == "wasd" ) then
		Key(f, "W", 16, 16, true):SetPoint("BOTTOM", f, "CENTER", 0, 1);
		Key(f, "S", 16, 16, true):SetPoint("TOP", f, "CENTER", 0, -1);
		local a = Key(f, "A", 16, 16, true); a:SetPoint("TOP", f, "CENTER", -17, -1);
		local d = Key(f, "D", 16, 16, true); d:SetPoint("TOP", f, "CENTER", 17, -1);
	elseif ( kind == "quest" ) then
		local t = f:CreateTexture(nil, "ARTWORK");
		t:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon");
		t:SetWidth(24); t:SetHeight(24); t:SetPoint("CENTER");
	end
	icons[kind] = f;
	return f;
end

-- the small "x" (it alone takes the mouse)
local function CloseX(parent, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelCloseButton");
	b:SetWidth(24); b:SetHeight(24);
	b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 2, 2);
	b:SetScript("OnClick", onClick);
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Skip this step"); GameTooltip:Show();
	end);
	b:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	return b;
end

local function SkipLink(parent)
	local b = CreateFrame("Button", nil, parent);
	b:SetHeight(16);
	local t = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	t:SetPoint("CENTER"); t:SetText("Skip tutorial");
	b:SetWidth(t:GetStringWidth() + 10);
	b:SetScript("OnEnter", function() t:SetTextColor(1, 0.82, 0); end);
	b:SetScript("OnLeave", function() t:SetTextColor(0.5, 0.5, 0.5); end);
	b:SetScript("OnClick", function()
		if ( machine ) then L.Handle(machine, "SKIP"); Show(); end
		Say("tutorial skipped. Options > Gameplay > Interface > Reset Tutorials shows it again.");
	end);
	return b;
end

-- [[ the centred panel: "Position your hands and click Okay" ]] --
local panel = CreateFrame("Frame", "TemucraftTutorialPanel", UIParent);
panel:SetWidth(460); panel:SetHeight(250);
panel:SetPoint("CENTER", 0, 90);
panel:SetFrameStrata("HIGH");
panel:EnableMouse(false);
panel:SetBackdrop(BACKDROP);
panel:SetBackdropColor(0.03, 0.03, 0.03, 0.9);
panel:SetBackdropBorderColor(0.5, 0.5, 0.5, 1);
panel:Hide();
do
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	title:SetPoint("TOP", 0, -18);
	title:SetText("Position your hands and click Okay");
	local board = CreateFrame("Frame", nil, panel);
	board:SetWidth(250); board:SetHeight(120);
	board:SetPoint("TOPLEFT", 30, -52);
	local rows = { { "Q", "W", "E", "R", "T" }, { "A", "S", "D", "F", "G" }, { "Z", "X", "C", "V", "B" } };
	local LIT = { W = true, A = true, S = true, D = true };
	for r, keys in ipairs(rows) do
		for i, label in ipairs(keys) do
			Key(board, label, 32, 30, LIT[label]):SetPoint("TOPLEFT", (r - 1) * 12 + (i - 1) * 36, -(r - 1) * 34);
		end
	end
	Key(board, "", 150, 22, false):SetPoint("TOPLEFT", 40, -104);
	local mouse = Mouse(panel, 64, nil);
	mouse:SetPoint("TOPRIGHT", -60, -60);
	local ok = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate");
	ok:SetWidth(110); ok:SetHeight(24);
	ok:SetPoint("BOTTOM", 0, 18);
	ok:SetText(OKAY or "Okay");
	ok:SetScript("OnClick", function() if ( machine ) then L.Handle(machine, "OKAY"); Show(); end end);
	CloseX(panel, function() if ( machine ) then L.Handle(machine, "CLOSE", "main"); Show(); end end);
	SkipLink(panel):SetPoint("BOTTOMRIGHT", -10, 8);
end

-- [[ the bar at the lower centre ]] --
local bar = CreateFrame("Frame", "TemucraftTutorialBar", UIParent);
bar:SetHeight(52); bar:SetWidth(320);
bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190);
bar:SetFrameStrata("HIGH");
bar:EnableMouse(false);
bar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 20, insets = { left = 5, right = 5, top = 5, bottom = 5 } });
bar:SetBackdropColor(0, 0, 0, 0.8);
bar:SetBackdropBorderColor(0.35, 0.35, 0.35, 1);
bar:Hide();
bar.iconHolder = CreateFrame("Frame", nil, bar);
bar.iconHolder:SetWidth(56); bar.iconHolder:SetHeight(44);
bar.iconHolder:SetPoint("LEFT", 8, 0);
bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
bar.text:SetPoint("LEFT", bar.iconHolder, "RIGHT", 6, 0);
bar.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
CloseX(bar, function() if ( machine ) then L.Handle(machine, "CLOSE", "main"); Show(); end end);
SkipLink(bar):SetPoint("TOP", bar, "BOTTOM", 0, -2);

-- [[ pointer boxes: yellow frame, white text, bouncing arrow ]] --
local function Pointer(name, which)
	local p = CreateFrame("Frame", name, UIParent);
	p:SetWidth(230); p:SetHeight(60);
	p:SetFrameStrata("HIGH");
	p:EnableMouse(false);
	p:SetBackdrop(BACKDROP);
	p:SetBackdropColor(0.04, 0.04, 0.04, 0.92);
	p:SetBackdropBorderColor(1, 0.82, 0, 1);
	p.text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	p.text:SetPoint("TOPLEFT", 12, -12); p.text:SetPoint("RIGHT", -20, 0);
	p.text:SetJustifyH("LEFT");
	p.arrow = p:CreateTexture(nil, "OVERLAY");
	p.arrow:SetTexture(ARROW);
	p.arrow:SetWidth(44); p.arrow:SetHeight(44);
	p.arrow:SetVertexColor(1, 0.9, 0.2);
	-- the glow over the target (the spellbook button, the action button)
	p.glow = CreateFrame("Frame", nil, UIParent);
	p.glow:SetFrameStrata("HIGH");
	p.glow:EnableMouse(false);
	p.glow.tex = p.glow:CreateTexture(nil, "OVERLAY");
	p.glow.tex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");
	p.glow.tex:SetBlendMode("ADD");
	p.glow.tex:SetAllPoints(p.glow);
	p.glow:Hide();
	CloseX(p, function() if ( machine ) then L.Handle(machine, "CLOSE", which); Show(); end end);
	p:Hide();
	return p;
end
local mainPointer = Pointer("TemucraftTutorialPointer", "main");
local sidePointer = Pointer("TemucraftTutorialSidePointer", "side");

local function Usable(f)
	return f and f.IsVisible and f:IsVisible() and f:GetLeft() ~= nil and (f:GetEffectiveAlpha() or 1) > 0.05;
end

local function AnchorFrame(view)
	if ( view.anchor == "action" ) then
		local b = _G["ActionButton"..(view.slot or 1)];
		return Usable(b) and b or nil;
	end
	for _, name in ipairs(L.ANCHORS[view.anchor] or {}) do
		local f = _G[name];
		if ( Usable(f) ) then return f; end
	end
	return nil;
end

-- place the box beside its frame (or at the fallback), the arrow between, bouncing
local function Place(p, view, t)
	local target = AnchorFrame(view);
	local bounce = math.abs(math.sin(t * 5)) * 8;
	p:ClearAllPoints(); p.arrow:ClearAllPoints();
	local side;
	if ( target ) then
		local scale = target:GetEffectiveScale() / UIParent:GetEffectiveScale();
		local cx, cy = target:GetCenter();
		cx, cy = cx * scale, cy * scale;
		side = L.Side(cx, cy, UIParent:GetWidth(), UIParent:GetHeight());
		if ( side == "above" ) then
			p.arrow:SetPoint("BOTTOM", target, "TOP", 0, 2 + bounce);
			p:SetPoint("BOTTOM", p.arrow, "TOP", 0, -6);
		elseif ( side == "left" ) then
			p.arrow:SetPoint("RIGHT", target, "LEFT", -2 - bounce, 0);
			p:SetPoint("RIGHT", p.arrow, "LEFT", 6, 0);
		else
			p.arrow:SetPoint("LEFT", target, "RIGHT", 2 + bounce, 0);
			p:SetPoint("LEFT", p.arrow, "RIGHT", -6, 0);
		end
		if ( view.glow or view.anchor == "action" ) then
			p.glow:ClearAllPoints();
			p.glow:SetPoint("CENTER", target, "CENTER");
			p.glow:SetWidth(target:GetWidth() * scale * 1.9); p.glow:SetHeight(target:GetHeight() * scale * 1.9);
			p.glow.tex:SetVertexColor(1, 0.85, 0.1, 0.55 + 0.45 * math.abs(math.sin(t * 3)));
			p.glow:Show();
		else
			p.glow:Hide();
		end
	else
		local fb = L.FALLBACK[view.anchor] or { "CENTER", 0, 0 };
		side = (fb[1] == "RIGHT") and "left" or "above";
		if ( side == "above" ) then
			p.arrow:SetPoint("BOTTOM", UIParent, fb[1], fb[2], fb[3] + bounce);
			p:SetPoint("BOTTOM", p.arrow, "TOP", 0, -6);
		else
			p.arrow:SetPoint("RIGHT", UIParent, fb[1], fb[2] - bounce, fb[3]);
			p:SetPoint("RIGHT", p.arrow, "LEFT", 6, 0);
		end
		p.glow:Hide();
	end
	PointArrow(p.arrow, side == "above" and "down" or side == "left" and "right" or "left");
end

local function Fill(p, view)
	p.view = view;
	p.text:SetText(view.text);
	p:SetHeight(math.max(44, p.text:GetStringHeight() + 26));
	p:Show();
end

-- [[ showing the machine's view ]] --
local barIcon;
local function Save()
	if ( not machine ) then return; end
	Set("C", "tutorial", L.Progress(machine));
	if ( machine.mainDone and not machine.seenSaved and not machine.skipped ) then
		machine.seenSaved = true;
		Set("A", "tutorial.seen", "1");
	end
end

function Show()
	if ( not machine ) then return; end
	Save();
	local v = L.View(machine);
	local main, side = v.main, v.side;
	if ( main and main.kind == "panel" ) then panel:Show(); else panel:Hide(); end
	if ( main and main.kind == "bar" ) then
		if ( barIcon ) then barIcon:Hide(); end
		barIcon = main.icon and Icon(bar.iconHolder, main.icon);
		if ( barIcon ) then barIcon:Show(); end
		bar.text:SetText(main.text);
		bar:SetWidth(math.max(260, bar.text:GetStringWidth() + 56 + 50));
		bar:Show();
	else
		bar:Hide();
	end
	if ( main and main.kind == "pointer" ) then Fill(mainPointer, main); else mainPointer:Hide(); mainPointer.glow:Hide(); end
	if ( side ) then Fill(sidePointer, side); else sidePointer:Hide(); sidePointer.glow:Hide(); end
	if ( side and side.anchor == "xp" ) then sidePointer.xpTime = sidePointer.xpTime or 0; else sidePointer.xpTime = nil; end
	if ( machine.done ) then
		if ( machine.skipped ) then Set("A", "tutorial.seen", "1"); end
		Stop(true);
	end
end

-- [[ watching the player ]] --
local watch = CreateFrame("Frame");
local lastFacing, turned, leftHeld, moved, clock = nil, 0, 0, 0, 0;
local castGuid;

local function Feed(ev, arg)
	if ( machine and L.Handle(machine, ev, arg) ) then Show(); end
end

local function SpellOnBar()
	local actions = {};
	for slot = 1, 12 do
		local kind, id, subType, spellID = GetActionInfo(slot);
		if ( kind == "spell" ) then
			local name = spellID and GetSpellInfo(spellID);
			if ( not name and id ) then name = GetSpellName(id, BOOKTYPE_SPELL or "spell"); end
			actions[slot] = { kind = "spell", name = name };
		end
	end
	local slot, name = L.PickSpell(actions);
	if ( not slot ) then return nil; end
	local key = GetBindingKey("ACTIONBUTTON"..slot);
	key = key and (GetBindingText and GetBindingText(key, "KEY_") or key) or tostring(slot);
	return { slot = slot, name = name, key = key };
end

-- the quest just accepted: its title, the kill objective's mob, its objective text
local knownQuests;
local function QuestInfo(index)
	if ( not index or index < 1 ) then return nil; end
	local title, _, _, _, isHeader = GetQuestLogTitle(index);
	if ( not title or isHeader ) then return nil; end
	local objs = {};
	for i = 1, GetNumQuestLeaderBoards(index) or 0 do
		local text, kind = GetQuestLogLeaderBoard(i, index);
		table.insert(objs, { text = text, type = kind });
	end
	local old = GetQuestLogSelection();
	SelectQuestLogEntry(index);
	local _, objective = GetQuestLogQuestText();
	SelectQuestLogEntry(old or 0);
	return { title = title, kill = L.KillTarget(objs), objective = objective };
end

local function QuestTitles()
	local titles = {};
	for i = 1, GetNumQuestLogEntries() do
		local title, _, _, _, isHeader, _, isComplete = GetQuestLogTitle(i);
		if ( title and not isHeader ) then titles[title] = { index = i, complete = isComplete == 1 }; end
	end
	return titles;
end

local function QuestLogChanged()
	if ( not machine ) then return; end
	local titles = QuestTitles();
	if ( knownQuests ) then
		for title, q in pairs(titles) do
			if ( not knownQuests[title] and machine.step == "accept" ) then Feed("ACCEPT", QuestInfo(q.index)); end
		end
	end
	knownQuests = titles;
	local q = machine.quest and titles[machine.quest];
	if ( q and q.complete and not machine.ready ) then Feed("READY"); end
	-- the objectives can come after QUEST_ACCEPTED: a kill objective that shows up later still routes to "Target"
	if ( q and machine.step == "follow" ) then Feed("QUEST_INFO", QuestInfo(q.index)); end
end

watch:SetScript("OnUpdate", function(self, elapsed)
	clock = clock + elapsed;
	if ( not machine ) then return; end
	local step = machine.step;
	if ( step == "look" ) then
		local facing = GetPlayerFacing and GetPlayerFacing();
		if ( facing and lastFacing and (IsMouselooking() or IsMouseButtonDown("RightButton")) ) then
			local d = math.abs(facing - lastFacing);
			if ( d > math.pi ) then d = 2 * math.pi - d; end
			turned = turned + d;
		end
		lastFacing = facing;
		if ( IsMouseButtonDown("LeftButton") and GetMouseFocus() == WorldFrame ) then leftHeld = leftHeld + elapsed; end
		if ( turned > 1.2 or leftHeld > 1.2 ) then Feed("LOOK"); end
	elseif ( step == "walk" or step == "hands" ) then
		if ( (GetUnitSpeed("player") or 0) > 0 ) then moved = moved + elapsed; end
		if ( moved > 1.5 ) then moved = 0; Feed("MOVE"); end
	elseif ( step == "cast" and castGuid and UnitGUID("target") == castGuid and UnitIsDead("target") ) then
		castGuid = nil;
		Feed("KILL");
	end
	if ( mainPointer:IsShown() ) then Place(mainPointer, mainPointer.view, clock); end
	if ( sidePointer:IsShown() ) then
		Place(sidePointer, sidePointer.view, clock);
		if ( sidePointer.xpTime ) then
			sidePointer.xpTime = sidePointer.xpTime + elapsed;
			if ( sidePointer.xpTime > 12 ) then sidePointer.xpTime = nil; Feed("XP_TIMEOUT"); end
		end
	end
end);
watch:Hide();

local EVENTS = { "GOSSIP_SHOW", "QUEST_DETAIL", "QUEST_GREETING", "GOSSIP_CLOSED", "QUEST_FINISHED", "QUEST_ACCEPTED",
	"QUEST_LOG_UPDATE", "QUEST_COMPLETE", "PLAYER_TARGET_CHANGED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED",
	"UI_ERROR_MESSAGE", "CHAT_MSG_COMBAT_XP_GAIN", "PLAYER_XP_UPDATE", "CHAT_MSG_SYSTEM", "LEARNED_SPELL_IN_TAB",
	"PLAYER_LEVEL_UP" };
local LEARN_PATTERNS = {};
for _, g in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S" }) do
	if ( _G[g] ) then table.insert(LEARN_PATTERNS, _G[g]); end
end
if ( #LEARN_PATTERNS == 0 ) then LEARN_PATTERNS = { "You have learned a new spell: %s.", "You have learned a new ability: %s." }; end
local learnedName, lastXP;

watch:SetScript("OnEvent", function(self, event, a1, a2)
	if ( not machine ) then return; end
	if ( event == "GOSSIP_SHOW" or event == "QUEST_DETAIL" or event == "QUEST_GREETING" ) then
		Feed("TALK", UnitName("npc"));
	elseif ( event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" ) then
		-- the quest window closing right after an accept is not a "closed without accepting": look again a moment later
		if ( machine.step == "accept" ) then self.pendingClose = clock + 0.5; end
	elseif ( event == "QUEST_ACCEPTED" ) then
		if ( machine.step == "accept" or machine.step == "talk" ) then
			Feed("ACCEPT", QuestInfo(a1));
		end
		knownQuests = QuestTitles();
	elseif ( event == "QUEST_LOG_UPDATE" ) then
		QuestLogChanged();
	elseif ( event == "QUEST_COMPLETE" ) then
		Feed("TURNIN", UnitName("npc"));
	elseif ( event == "PLAYER_TARGET_CHANGED" ) then
		local hostile = UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target") and true or false;
		Feed("TARGET", { hostile = hostile, spell = hostile and SpellOnBar() or nil });
	elseif ( event == "UNIT_SPELLCAST_INTERRUPTED" and a1 == "player" ) then
		if ( (GetUnitSpeed("player") or 0) > 0 ) then Feed("CAST_MOVED"); end
	elseif ( event == "UI_ERROR_MESSAGE" ) then
		if ( SPELL_FAILED_MOVING and a1 == SPELL_FAILED_MOVING ) then Feed("CAST_MOVED"); end
	elseif ( event == "UNIT_SPELLCAST_SUCCEEDED" and a1 == "player" ) then
		if ( machine.spell and a2 == machine.spell.name ) then
			castGuid = UnitGUID("target");
			if ( UnitExists("target") and not UnitIsDead("target") ) then Feed("CAST_DONE"); end
		end
	elseif ( event == "CHAT_MSG_COMBAT_XP_GAIN" ) then
		if ( machine.step == "cast" or machine.step == "target" ) then Feed("KILL"); end
		Feed("XP");
	elseif ( event == "PLAYER_XP_UPDATE" ) then
		local xp = UnitXP("player");
		if ( lastXP and xp > lastXP ) then Feed("XP"); end
		lastXP = xp;
	elseif ( event == "CHAT_MSG_SYSTEM" ) then
		local name = L.LearnedName(a1 or "", LEARN_PATTERNS);
		if ( name ) then learnedName = learnedName or name; end
	elseif ( event == "LEARNED_SPELL_IN_TAB" ) then
		-- the chat line comes first or right after: give it a moment
		self.learnAt = clock + 0.3;
	elseif ( event == "PLAYER_LEVEL_UP" ) then
		Feed("LEVEL", a1);
	end
end);

-- the delayed bits (a quest window closing, the learned spell's name)
local later = CreateFrame("Frame", nil, watch);
later:SetScript("OnUpdate", function()
	if ( watch.pendingClose and clock >= watch.pendingClose ) then
		watch.pendingClose = nil;
		local open = (QuestFrame and QuestFrame:IsShown()) or (GossipFrame and GossipFrame:IsShown());
		if ( machine and machine.step == "accept" and not open ) then Feed("TALK_CLOSED"); end
	end
	if ( watch.learnAt and clock >= watch.learnAt ) then
		watch.learnAt = nil;
		Feed("LEARN", learnedName);
		learnedName = nil;
	end
end);

-- the spellbook windows end the spellbook prompt
local hooked = {};
local function HookBooks()
	for _, name in ipairs(L.BOOKS) do
		local f = _G[name];
		if ( f and not hooked[name] and f.HookScript ) then
			hooked[name] = true;
			f:HookScript("OnShow", function() Feed("BOOK_OPEN"); end);
		end
	end
end

function Begin(progress)
	machine = L.New(progress);
	lastFacing, turned, leftHeld, moved = nil, 0, 0, 0;
	lastXP = UnitXP("player");
	knownQuests = QuestTitles();
	HookBooks();
	for _, e in ipairs(EVENTS) do pcall(watch.RegisterEvent, watch, e); end
	watch:Show();
	Show();
end

function Stop(finished)
	if ( machine and not finished ) then Save(); end
	machine = nil;
	watch:UnregisterAllEvents();
	watch:Hide();
	panel:Hide(); bar:Hide();
	mainPointer:Hide(); mainPointer.glow:Hide();
	sidePointer:Hide(); sidePointer.glow:Hide();
end

-- [[ "This account already finished the tutorial. Skip it?" ]] --
local ask = CreateFrame("Frame", "TemucraftTutorialAsk", UIParent);
ask:SetWidth(330); ask:SetHeight(96);
ask:SetPoint("TOP", 0, -160);
ask:SetFrameStrata("HIGH");
ask:EnableMouse(false);
ask:SetBackdrop(BACKDROP);
ask:SetBackdropColor(0.03, 0.03, 0.03, 0.9);
ask:SetBackdropBorderColor(1, 0.82, 0, 1);
ask:Hide();
do
	local t = ask:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	t:SetPoint("TOP", 0, -16); t:SetWidth(300);
	t:SetText("This account already finished the tutorial. Skip it?");
	local skip = CreateFrame("Button", nil, ask, "UIPanelButtonTemplate");
	skip:SetWidth(110); skip:SetHeight(22);
	skip:SetPoint("BOTTOMRIGHT", ask, "BOTTOM", -6, 16);
	skip:SetText("Skip");
	skip:SetScript("OnClick", function() ask:Hide(); Set("C", "tutorial", "done"); end);
	local show = CreateFrame("Button", nil, ask, "UIPanelButtonTemplate");
	show:SetWidth(110); show:SetHeight(22);
	show:SetPoint("BOTTOMLEFT", ask, "BOTTOM", 6, 16);
	show:SetText("Show it");
	show:SetScript("OnClick", function() ask:Hide(); Begin(nil); end);
end

-- [[ deciding at login ]] --
local played, waitPlayed;
local realDisplay;
local function Decide()
	if ( machine ) then return; end
	local what = L.Start({ enabled = TemucraftTutorial_IsEnabled(), progress = Get("C", "tutorial"),
		accountSeen = Get("A", "tutorial.seen") == "1", level = UnitLevel("player"), played = played, xp = UnitXP("player") });
	if ( what == "start" ) then Begin(nil);
	elseif ( what == "resume" ) then Begin(Get("C", "tutorial"));
	elseif ( what == "ask" ) then ask:Show(); end
end

local login = CreateFrame("Frame");
login:RegisterEvent("PLAYER_LOGIN");
login:RegisterEvent("TIME_PLAYED_MSG");
login:SetScript("OnEvent", function(self, event, total)
	if ( event == "PLAYER_LOGIN" ) then
		TemucraftStore_OnReady(function()
			if ( not TemucraftTutorial_IsEnabled() or Get("C", "tutorial") == "done" or UnitLevel("player") > 1 ) then
				Decide();
				return;
			end
			-- ask the played time without its chat lines
			waitPlayed = true;
			if ( ChatFrame_DisplayTimePlayed and not realDisplay ) then
				realDisplay = ChatFrame_DisplayTimePlayed;
				ChatFrame_DisplayTimePlayed = function(...) if ( waitPlayed ) then return; end return realDisplay(...); end;
			end
			RequestTimePlayed();
			local wait = 0;
			self:SetScript("OnUpdate", function(f, elapsed)
				wait = wait + elapsed;
				if ( not waitPlayed or wait > 5 ) then
					f:SetScript("OnUpdate", nil);
					waitPlayed = false;
					Decide();
				end
			end);
		end);
	elseif ( event == "TIME_PLAYED_MSG" and waitPlayed ) then
		played = total;
		-- the chat frames get the event after us: let it pass silently, then show them again
		local f = CreateFrame("Frame");
		f:SetScript("OnUpdate", function() f:SetScript("OnUpdate", nil); waitPlayed = false; end);
	end
end);

function TemucraftTutorial_Reset()
	if ( machine ) then Stop(true); end
	ask:Hide();
	Set("A", "tutorial.seen", "");
	Set("A", "tutorial.off", "");
	Set("C", "tutorial", "");
	if ( ResetTutorials ) then pcall(ResetTutorials); end
	if ( UnitLevel("player") <= 1 ) then
		Begin(nil);
		Say("tutorial reset: it starts again.");
	else
		Say("tutorials reset: the next new character gets the tutorial.");
	end
end

SLASH_TEMUCRAFTTUTORIAL1 = "/ttutorial";
SlashCmdList["TEMUCRAFTTUTORIAL"] = function(msg)
	msg = string.lower(msg or "");
	if ( msg == "reset" ) then TemucraftTutorial_Reset();
	elseif ( msg == "skip" ) then
		if ( machine ) then L.Handle(machine, "SKIP"); Show(); end
		Set("C", "tutorial", "done");
		Say("tutorial skipped.");
	elseif ( msg == "off" ) then TemucraftTutorial_SetEnabled(false); Say("tutorials off.");
	elseif ( msg == "on" ) then TemucraftTutorial_SetEnabled(true); Say("tutorials on."); Decide();
	else
		Say("/ttutorial reset | skip | on | off. Tutorials are "..(TemucraftTutorial_IsEnabled() and "on" or "off")..".");
	end
end
