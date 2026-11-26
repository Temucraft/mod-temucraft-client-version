-- A WoW 3.3.5a API mock for the client tests (no client): widgets with real anchors, scripts, events and tooltips,
-- the Lua the client has (no os / io / require), and a stand-in for every other Blizzard global.
--
--   local M = dofile(dir.."/tests/wowmock.lua");
--   local env = M.new();            -- a fresh global table for one UI (FrameXML or GlueXML)
--   M.load(env, path);              -- runs a file in it (errors are recorded, not thrown)
--   M.fire(env, "PLAYER_LOGIN");    -- an event to every frame that registered it
--   M.tick(env, n);                 -- n frames of OnUpdate
--   env.__errors                    -- every Lua error so far: { { where, message }, ... }
--
-- Unknown globals: our own names (Temucraft*, TEMUCRAFT*) and lower-case names are nil, as in the game when nothing
-- defined them, so a typo or a local used before it is declared ("attempt to call global 'withoutRacials'") fails like
-- it does in the game. Other names are Blizzard's: ALL_CAPS ones are their own name as a string (the client's
-- localized strings), the rest a stand-in widget that can also be called (returns nothing). GetNum*() gives 0.
local M = {};

local LUA_GLOBALS = { "assert", "collectgarbage", "error", "gcinfo", "getfenv", "getmetatable", "ipairs", "loadstring",
	"next", "newproxy", "pairs", "pcall", "rawequal", "rawget", "rawset", "select", "setfenv", "setmetatable",
	"tonumber", "tostring", "type", "unpack", "xpcall", "string", "table", "math", "coroutine", "debug" };

local function noop() end

---------------------------------------------------------------------------------------------------------------------
-- widgets
---------------------------------------------------------------------------------------------------------------------
local W = {};          -- methods of every widget
local WMT;             -- their metatable (set in new())

local function Fire(env, f, script, ...)
	local fn = f.scripts and f.scripts[script];
	if ( not fn ) then return; end
	local args = { ... };
	local n = select("#", ...);
	local ok, err = xpcall(function() return fn(f, unpack(args, 1, n)); end, debug.traceback);
	if ( not ok ) then table.insert(env.__errors, { (f:GetName() or f.kind or "?")..":"..script, err }); end
end
M.FireScript = Fire;

local function Visible(f)
	while ( f ) do
		if ( not f.shown ) then return false; end
		f = f.parent;
	end
	return true;
end

local function ShowTree(env, f, script)
	Fire(env, f, script);
	for _, c in ipairs(f.children) do if ( c.shown ) then ShowTree(env, c, script); end end
end

-- does anchoring `self` to `rel` close a loop? (the game refuses it: "X is dependent on this")
local function DependsOn(rel, self, seen)
	if ( rel == self ) then return true; end
	if ( type(rel) ~= "table" or seen[rel] ) then return false; end
	seen[rel] = true;
	for _, p in ipairs(rel.points or {}) do
		if ( DependsOn(p[2], self, seen) ) then return true; end
	end
	return false;
end

function W:GetName() return self.name; end
function W:GetObjectType() return self.kind; end
function W:IsObjectType(t) return self.kind == t or (t == "Frame" and self.isFrame) or t == "Region" or t == "UIObject"; end
function W:IsForbidden() return nil; end
function W:IsProtected() return self.protected, self.protected; end
function W:SetParent(p)
	if ( type(p) == "string" ) then p = self.env[p]; end
	if ( self.parent ) then
		for i, c in ipairs(self.parent.children) do if ( c == self ) then table.remove(self.parent.children, i); break; end end
	end
	self.parent = p;
	if ( p ) then table.insert(p.children, self); end
	self.env.__guard(self, "SetParent");
end
function W:GetParent() return self.parent; end
function W:GetChildren() local out = {}; for _, c in ipairs(self.children) do if ( c.isFrame ) then table.insert(out, c); end end return unpack(out); end
function W:GetRegions() local out = {}; for _, c in ipairs(self.children) do if ( not c.isFrame ) then table.insert(out, c); end end return unpack(out); end
function W:GetNumChildren() return select("#", self:GetChildren()); end
function W:GetNumRegions() return select("#", self:GetRegions()); end
function W:SetScript(k, f) self.scripts[k] = f; end
function W:GetScript(k) return self.scripts[k]; end
function W:HasScript(k) return true; end
function W:HookScript(k, f)
	local o = self.scripts[k];
	self.scripts[k] = o and function(...) o(...); return f(...); end or f;
end
function W:Show()
	self.env.__guard(self, "Show");
	if ( self.shown ) then return; end
	self.shown = true;
	if ( Visible(self) ) then ShowTree(self.env, self, "OnShow"); end
end
function W:Hide()
	self.env.__guard(self, "Hide");
	if ( not self.shown ) then return; end
	local was = Visible(self);
	self.shown = false;
	if ( was ) then ShowTree(self.env, self, "OnHide"); end
end
function W:SetShown(on) if ( on ) then self:Show(); else self:Hide(); end end
function W:IsShown() return self.shown and 1 or nil; end
function W:IsVisible() return Visible(self) and 1 or nil; end
function W:Enable() self.enabled = true; end
function W:Disable() self.enabled = false; end
function W:IsEnabled() return self.enabled and 1 or nil; end
function W:SetText(t)
	if ( t ~= nil ) then t = tostring(t); end
	self.text = t;
	Fire(self.env, self, "OnTextChanged", true);
end
function W:SetFormattedText(fmt, ...) self:SetText(string.format(fmt, ...)); end
function W:GetText() if ( self.kind == "EditBox" ) then return self.text or ""; end return self.text; end
function W:Insert(t) self:SetText((self.text or "")..t); end
function W:GetNumLetters() return string.len(self.text or ""); end
function W:SetCursorPosition(p) self.cursor = p; end
function W:GetCursorPosition() return self.cursor or 0; end
function W:HighlightText() end
function W:SetFocus() self.focus = true; self.env.__focus = self; end
function W:ClearFocus() self.focus = false; if ( self.env.__focus == self ) then self.env.__focus = nil; end end
function W:HasFocus() return self.focus and 1 or nil; end
function W:SetMaxLetters(n) self.maxLetters = n; end
function W:GetMaxLetters() return self.maxLetters or 0; end
function W:SetNumber(n) self:SetText(tostring(n)); end
function W:GetNumber() return tonumber(self.text) or 0; end
function W:IsMultiLine() return self.multiLine; end
function W:SetMultiLine(m) self.multiLine = m; end
function W:SetFrameLevel(l) self.level = l; end
function W:GetFrameLevel() return self.level or (self.parent and (self.parent:GetFrameLevel() + 1)) or 1; end
function W:SetFrameStrata(s) self.strata = s; end
function W:GetFrameStrata() return self.strata or "MEDIUM"; end
function W:SetID(id) self.id = id; end
function W:GetID() return self.id or 0; end
function W:SetAlpha(a) self.alpha = a; end
function W:GetAlpha() return self.alpha or 1; end
function W:GetEffectiveAlpha() return self.alpha or 1; end
function W:SetScale(s) self.scale = s; end
function W:GetScale() return self.scale or 1; end
function W:GetEffectiveScale() return self.scale or 1; end
function W:GetButtonState() return "NORMAL"; end
function W:SetButtonState(s) end
function W:GetStringWidth() return string.len(self.text or "") * 6; end
function W:GetStringHeight() local n = 1; for _ in string.gmatch(self.text or "", "\n") do n = n + 1; end return n * 12; end
function W:GetTextWidth() return self:GetStringWidth(); end
function W:GetTextHeight() return 12; end
function W:SetTextColor(r, g, b, a) self.color = { r, g, b, a }; end
function W:GetTextColor() local c = self.color or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] or 1; end
function W:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a }; end
function W:GetVertexColor() local c = self.vertex or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] or 1; end
function W:SetFont(path, size, flags) self.font = { path, size, flags }; end
function W:GetFont() local f = self.font or { "Fonts\\FRIZQT__.TTF", 12, "" }; return f[1], f[2], f[3]; end
function W:SetFontObject(o) self.fontObject = o; end
function W:GetFontObject() return self.fontObject; end
function W:SetJustifyH(j) self.justifyH = j; end
function W:GetJustifyH() return self.justifyH or "CENTER"; end
function W:SetJustifyV(j) self.justifyV = j; end
function W:GetJustifyV() return self.justifyV or "MIDDLE"; end
function W:SetTexture(t, ...) if ( select("#", ...) > 0 and type(t) == "number" ) then self.texture = "color"; else self.texture = t; end return 1; end
function W:GetTexture() return self.texture; end
function W:SetTexCoord(...) self.texcoord = { ... }; end
function W:GetTexCoord() local c = self.texcoord or { 0, 1, 0, 1 }; if ( #c == 4 ) then return c[1], c[3], c[1], c[4], c[2], c[3], c[2], c[4]; end return unpack(c); end
function W:SetDesaturated(d) self.desaturated = d and true or false; return 1; end
function W:IsDesaturated() return self.desaturated; end
function W:SetBlendMode(m) self.blend = m; end
function W:SetDrawLayer(l) self.layer = l; end
function W:GetDrawLayer() return self.layer or "ARTWORK"; end
function W:SetBackdrop(b) self.backdrop = b; end
function W:GetBackdrop() return self.backdrop; end
function W:SetBackdropColor(...) self.backdropColor = { ... }; end
function W:GetBackdropColor() return unpack(self.backdropColor or { 0, 0, 0, 1 }); end
function W:SetBackdropBorderColor(...) self.backdropBorder = { ... }; end
function W:GetBackdropBorderColor() return unpack(self.backdropBorder or { 1, 1, 1, 1 }); end

-- geometry: points are kept (and checked for loops); a frame's rect is its size at 0,0 unless a test sets it
function W:ClearAllPoints() self.env.__guard(self, "ClearAllPoints"); self.points = {}; end
function W:SetPoint(point, rel, relPoint, x, y)
	self.env.__guard(self, "SetPoint");
	if ( type(rel) == "number" ) then rel, relPoint, x, y = nil, nil, rel, relPoint; end
	if ( type(rel) == "string" ) then
		local name = rel;
		rel = rawget(self.env, rel) or self.env[rel];
		if ( not rel ) then table.insert(self.env.__errors, { (self:GetName() or "?")..":SetPoint", "no frame called "..name }); end
	end
	if ( rel == nil and self.parent ) then rel = self.parent; end
	if ( rel and DependsOn(rel, self, {}) ) then
		table.insert(self.env.__errors, { (self:GetName() or "?")..":SetPoint", (rel.GetName and rel:GetName() or "?").." is dependent on this" });
		return;
	end
	self.points = self.points or {};
	for i, p in ipairs(self.points) do if ( p[1] == point ) then table.remove(self.points, i); break; end end
	table.insert(self.points, { point, rel, relPoint or point, x or 0, y or 0 });
end
function W:SetAllPoints(rel)
	if ( type(rel) == "string" ) then rel = self.env[rel]; end
	rel = rel or self.parent;
	self:ClearAllPoints();
	self:SetPoint("TOPLEFT", rel, "TOPLEFT", 0, 0);
	self:SetPoint("BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0);
end
function W:GetNumPoints() return #(self.points or {}); end
function W:GetPoint(i) local p = (self.points or {})[i or 1]; if ( p ) then return p[1], p[2], p[3], p[4], p[5]; end end
function W:SetWidth(w) self.env.__guard(self, "SetWidth"); self.width = w; end
function W:SetHeight(h) self.env.__guard(self, "SetHeight"); self.height = h; end
function W:SetSize(w, h) self:SetWidth(w); self:SetHeight(h); end
function W:GetWidth() return self.width or 100; end
function W:GetHeight() return self.height or 20; end
function W:GetSize() return self:GetWidth(), self:GetHeight(); end
function W:GetLeft() return self.rect and self.rect.left or 0; end
function W:GetRight() return self.rect and self.rect.right or self:GetWidth(); end
function W:GetBottom() return self.rect and self.rect.bottom or 0; end
function W:GetTop() return self.rect and self.rect.top or self:GetHeight(); end
function W:GetCenter() return (self:GetLeft() + self:GetRight()) / 2, (self:GetBottom() + self:GetTop()) / 2; end
function W:GetRect() return self:GetLeft(), self:GetBottom(), self:GetWidth(), self:GetHeight(); end
function W:IsMouseOver() return nil; end
function W:EnableMouse(e) self.mouse = e; end
function W:IsMouseEnabled() return self.mouse; end
function W:EnableMouseWheel(e) self.wheel = e; end
function W:EnableKeyboard(e) self.keyboard = e; end
function W:SetMovable(m) self.movable = m; end
function W:IsMovable() return self.movable; end
function W:SetUserPlaced(m) end
function W:IsUserPlaced() return nil; end
function W:StartMoving() end
function W:StopMovingOrSizing() end
function W:SetClampedToScreen() end
function W:SetHitRectInsets() end
function W:RegisterForClicks() end
function W:RegisterForDrag() end
function W:SetHighlightTexture(t) self.highlight = t; end
function W:SetNormalTexture(t) self.normal = t; end
function W:SetPushedTexture(t) self.pushed = t; end
function W:SetDisabledTexture(t) self.disabledTex = t; end
function W:SetCheckedTexture(t) self.checkedTex = t; end
local function Region(self, key, kind)
	if ( not self[key] ) then self[key] = self.env.__new(kind or "Texture", nil, self); end
	return self[key];
end
function W:GetNormalTexture() return Region(self, "__normal"); end
function W:GetPushedTexture() return Region(self, "__pushed"); end
function W:GetHighlightTexture() return Region(self, "__highlight"); end
function W:GetDisabledTexture() return Region(self, "__disabled"); end
function W:GetCheckedTexture() return Region(self, "__checked"); end
function W:GetFontString() return Region(self, "__fontstring", "FontString"); end
function W:SetFontString(fs) self.__fontstring = fs; end
function W:SetNormalFontObject(o) end
function W:SetHighlightFontObject(o) end
function W:SetDisabledFontObject(o) end
function W:LockHighlight() self.locked = true; end
function W:UnlockHighlight() self.locked = false; end
function W:SetChecked(c) self.checked = c and true or false; end
function W:GetChecked() return self.checked and 1 or nil; end
function W:Click(button)
	if ( self.kind == "CheckButton" ) then self.checked = not self.checked; end
	Fire(self.env, self, "PreClick", button or "LeftButton", false);
	Fire(self.env, self, "OnClick", button or "LeftButton", false);
	Fire(self.env, self, "PostClick", button or "LeftButton", false);
end
function W:CreateTexture(name, layer) local r = self.env.__new("Texture", name, self); r.layer = layer; return r; end
function W:CreateFontString(name, layer, inherits) local r = self.env.__new("FontString", name, self); r.layer = layer; r.fontObject = inherits; return r; end
-- StatusBar / Slider
function W:SetMinMaxValues(a, b) self.min, self.max = a, b; end
function W:GetMinMaxValues() return self.min or 0, self.max or 1; end
function W:SetValue(v)
	self.value = v;
	Fire(self.env, self, "OnValueChanged", v);
end
function W:GetValue() return self.value or 0; end
function W:SetValueStep(s) self.step = s; end
function W:GetValueStep() return self.step or 1; end
function W:SetStatusBarTexture(t) self.barTexture = t; end
function W:GetStatusBarTexture() return Region(self, "__bar"); end
function W:SetStatusBarColor(...) self.barColor = { ... }; end
function W:SetOrientation(o) self.orientation = o; end
function W:SetThumbTexture(t) self.thumb = t; end
function W:GetThumbTexture() return Region(self, "__thumb"); end
-- ScrollFrame
function W:SetScrollChild(c) self.scrollChild = c; if ( c ) then c:SetParent(self); end end
function W:GetScrollChild() return self.scrollChild; end
function W:SetVerticalScroll(v) self.vscroll = v; Fire(self.env, self, "OnVerticalScroll", v); end
function W:GetVerticalScroll() return self.vscroll or 0; end
function W:SetHorizontalScroll(v) self.hscroll = v; end
function W:GetHorizontalScroll() return self.hscroll or 0; end
function W:GetVerticalScrollRange() return 0; end
function W:GetHorizontalScrollRange() return 0; end
function W:UpdateScrollChildRect() end
-- Model / PlayerModel
function W:SetUnit() end
function W:SetModel() end
function W:SetCamera() end
function W:SetFacing(f) self.facing = f; end
function W:GetFacing() return self.facing or 0; end
function W:SetRotation() end
function W:SetPosition() end
function W:RefreshUnit() end
function W:Undress() end
function W:TryOn() end
function W:Dress() end
function W:SetDisplayInfo() end
function W:SetCreature() end
function W:ClearModel() end
-- Cooldown / animation
function W:SetCooldown() end
function W:CreateAnimationGroup() return self.env.__new("AnimationGroup", nil, self); end
function W:CreateAnimation() return self.env.__new("Animation", nil, self); end
function W:Play() end
function W:Stop() end
function W:IsPlaying() return nil; end
-- secure frames
function W:SetAttribute(k, v)
	self.env.__guard(self, "SetAttribute");
	self.attributes = self.attributes or {};
	self.attributes[k] = v;
	Fire(self.env, self, "OnAttributeChanged", k, v);
end
function W:GetAttribute(k) return self.attributes and self.attributes[k]; end
-- events
function W:RegisterEvent(e) self.env.__events[e] = self.env.__events[e] or {}; self.env.__events[e][self] = true; end
function W:UnregisterEvent(e) if ( self.env.__events[e] ) then self.env.__events[e][self] = nil; end end
function W:UnregisterAllEvents() for _, set in pairs(self.env.__events) do set[self] = nil; end self.env.__allEvents[self] = nil; end
function W:RegisterAllEvents() self.env.__allEvents[self] = true; end
function W:IsEventRegistered(e) return self.env.__events[e] and self.env.__events[e][self] and 1 or nil; end
-- dropdown / misc
function W:SetToplevel() end
function W:Raise() end
function W:Lower() end
function W:SetDontSavePosition() end
function W:SetResizable() end
function W:SetMinResize() end
function W:SetMaxResize() end
function W:SetNonSpaceWrap() end
function W:SetWordWrap(w) self.wrap = w; end
function W:CanWordWrap() return self.wrap; end
function W:SetSpacing() end
function W:SetShadowOffset() end
function W:SetShadowColor() end
function W:SetTextInsets() end
function W:SetAutoFocus(a) self.autoFocus = a; end
function W:SetHistoryLines() end
function W:AddHistoryLine() end
function W:SetPassword() end
function W:SetNumeric() end
function W:SetMotionScriptsWhileDisabled() end
function W:GetHitRectInsets() return 0, 0, 0, 0; end
function W:SetFading() end
function W:SetMaxLines() end
function W:AddMessage(t) self.messages = self.messages or {}; table.insert(self.messages, t); end
function W:Clear() self.messages = {}; end

-- tooltips: lines, and the setters that fill them (OnTooltipCleared / OnTooltipSet... like the client)
local TT = {};
local function Line(tt, i, side)
	local key = side..i;
	tt.__lines = tt.__lines or {};
	if ( not tt.__lines[key] ) then
		local fs = tt.env.__new("FontString", (tt.name or "Tooltip").."Text"..side..i, tt);
		tt.__lines[key] = fs;
	end
	return tt.__lines[key];
end
function TT:ClearLines()
	for i = 1, self.numLines or 0 do Line(self, i, "Left").text = nil; Line(self, i, "Right").text = nil; end
	self.numLines = 0;
	self.__subject = nil;
	Fire(self.env, self, "OnTooltipCleared");
end
function TT:SetOwner(owner, anchor) self.owner = owner; self:ClearLines(); end
function TT:GetOwner() return self.owner; end
function TT:IsOwned(f) return self.owner == f and 1 or nil; end
function TT:NumLines() return self.numLines or 0; end
function TT:AddLine(text, r, g, b, wrap)
	self.numLines = (self.numLines or 0) + 1;
	local l = Line(self, self.numLines, "Left");
	l.text = text ~= nil and tostring(text) or nil; l.color = { r, g, b };
	Line(self, self.numLines, "Right").text = nil;
end
function TT:AddDoubleLine(left, right, ...)
	self:AddLine(left);
	Line(self, self.numLines, "Right").text = right ~= nil and tostring(right) or nil;
end
function TT:SetText(text, ...) self:ClearLines(); self:AddLine(text, ...); self:Show(); end
function TT:Lines()
	local out = {};
	for i = 1, self.numLines or 0 do
		local l, r = Line(self, i, "Left").text, Line(self, i, "Right").text;
		table.insert(out, r and ((l or "").." | "..r) or (l or ""));
	end
	return out;
end
function TT:AppendText(t) local l = Line(self, 1, "Left"); l.text = (l.text or "")..t; end
function TT:GetItem() local s = self.__subject; if ( s and s.kind == "item" ) then return s.name, s.link; end end
function TT:GetSpell() local s = self.__subject; if ( s and s.kind == "spell" ) then return s.name, s.rank or "", s.id; end end
function TT:GetUnit() local s = self.__subject; if ( s and s.kind == "unit" ) then return s.name, s.unit; end end
function TT:FadeOut() end
function TT:SetMinimumWidth() end
function TT:SetPadding() end
-- the client's own lines for a spell (name, then its cooldown when it has one): what the stock tooltip shows
local function ClientSpell(tt, id)
	local name = tt.env.GetSpellInfo(id) or ("Spell "..tostring(id));
	tt.__subject = { kind = "spell", id = id, name = name };
	tt:AddLine(name, 1, 1, 1);
	local start, duration = tt.env.GetSpellCooldown(id);
	if ( start and duration and duration > 1.5 ) then tt:AddLine("Cooldown remaining: 5 min", 1, 1, 1); end
	tt:Show();
	Fire(tt.env, tt, "OnTooltipSetSpell");
end
local function ClientItem(tt, id)
	tt.__subject = { kind = "item", id = id, name = "Item "..id, link = "|cffffffff|Hitem:"..id..":0:0:0:0:0:0:0|h[Item "..id.."]|h|r" };
	tt:AddLine("Item "..id, 1, 1, 1);
	tt:Show();
	Fire(tt.env, tt, "OnTooltipSetItem");
end
function TT:SetSpell(slot, book)
	self:ClearLines();
	local link = self.env.GetSpellLink(slot, book);
	local id = link and tonumber(string.match(link, "spell:(%d+)"));
	if ( id ) then ClientSpell(self, id); end
end
function TT:SetHyperlink(link)
	self:ClearLines();
	local id = tonumber(string.match(link or "", "spell:(%d+)"));
	if ( id ) then ClientSpell(self, id); return; end
	id = tonumber(string.match(link or "", "item:(%d+)"));
	if ( id ) then ClientItem(self, id); end
end
function TT:SetAction(slot)
	self:ClearLines();
	local kind, id = self.env.GetActionInfo(slot);
	if ( kind == "spell" and id ) then ClientSpell(self, id); end
end
function TT:SetUnitAura() self:ClearLines(); end
function TT:SetUnitBuff() self:ClearLines(); end
function TT:SetUnitDebuff() self:ClearLines(); end
function TT:SetBagItem(bag, slot) self:ClearLines(); ClientItem(self, 1000 + (bag or 0) * 100 + (slot or 0)); end
function TT:SetInventoryItem(unit, slot) self:ClearLines(); ClientItem(self, 2000 + (slot or 0)); return 1; end
function TT:SetUnit(unit) self:ClearLines(); self.__subject = { kind = "unit", unit = unit, name = self.env.UnitName(unit) }; self:AddLine(self.env.UnitName(unit) or unit); self:Show(); Fire(self.env, self, "OnTooltipSetUnit"); end
for _, name in ipairs({ "SetMerchantItem", "SetBuybackItem", "SetLootItem", "SetLootRollItem", "SetQuestItem",
	"SetQuestLogItem", "SetQuestRewardSpell", "SetQuestLogRewardSpell", "SetTradeSkillItem", "SetAuctionItem",
	"SetAuctionSellItem", "SetGuildBankItem", "SetInboxItem", "SetSendMailItem", "SetTradePlayerItem", "SetTradeTargetItem",
	"SetHyperlinkCompareItem", "SetTalent", "SetTrainerService", "SetPetAction", "SetShapeshift", "SetGlyph",
	"SetCurrencyToken", "SetSocketGem", "SetExistingSocketGem", "SetEquipmentSet", "SetMerchantCostItem",
	"SetBackpackToken", "SetTracking", "SetLFGDungeonReward", "SetLFGCompletionReward" }) do
	TT[name] = function(self) self:ClearLines(); end;
end

local SECURE_TEMPLATES = { "Secure", "ActionButtonTemplate", "ActionBarButtonTemplate" };

function M.new()
	local env = { __templated = {}, __errors = {}, __events = {}, __allEvents = {}, __frames = {}, __combat = false, __slash = {} };
	env._G = env;
	for _, k in ipairs(LUA_GLOBALS) do env[k] = _G[k]; end
	local function guard(f, method)
		if ( env.__combat and f.protected ) then
			table.insert(env.__errors, { (f:GetName() or "?")..":"..method, "protected frame changed in combat (taint: ADDON_ACTION_BLOCKED)" });
		end
	end
	env.__guard = guard;

	if ( not WMT ) then
		-- a method or child this mock doesn't know: one shared stand-in (callable, returns nothing). Plain tables
		-- as __index, like the client's widget method tables (code reads getmetatable(f).__index.Enable).
		WMT = { __index = W, __call = noop };
		M.TTMT = { __index = TT, __call = noop };
		setmetatable(TT, { __index = W });
		setmetatable(W, { __index = function(_, k)
			if ( type(k) == "string" and string.match(k, "^%u") ) then
				if ( not M.shared ) then M.shared = setmetatable({ env = env, kind = "Frame", scripts = {}, shown = true, enabled = true,
					children = {}, points = {}, isFrame = true, standIn = true }, WMT); end
				return M.shared;
			end
		end });
	end
	local function new(kind, name, parent, template, standIn)
		local f = setmetatable({ env = env, kind = kind or "Frame", scripts = {}, shown = true, enabled = true, children = {},
			points = {}, isFrame = not (kind == "Texture" or kind == "FontString"), standIn = standIn }, WMT);
		if ( kind == "GameTooltip" or (type(template) == "string" and string.find(template, "GameTooltipTemplate", 1, true)) ) then
			setmetatable(f, M.TTMT); f.shown = false;
		end
		if ( type(template) == "string" ) then
			for _, t in ipairs(SECURE_TEMPLATES) do if ( string.find(template, t, 1, true) ) then f.protected = true; end end
		end
		if ( parent and not standIn ) then f:SetParent(parent); end
		if ( name ) then
			if ( type(name) == "string" and parent and parent.GetName and parent:GetName() ) then
				name = string.gsub(name, "%$parent", parent:GetName());
			end
			f.name = name;
			rawset(env, name, f);
			if ( template and not standIn ) then table.insert(env.__templated, name); end
		end
		if ( not standIn ) then table.insert(env.__frames, f); end
		return f;
	end
	env.__new = new;

	-- unknown globals (see the top of the file)
	setmetatable(env, { __index = function(t, k)
		if ( type(k) ~= "string" ) then return nil; end
		if ( string.match(k, "^Temucraft") or string.match(k, "^TEMUCRAFT") or string.match(k, "^%l") or string.match(k, "^_") ) then
			-- the named parts a template makes (<name>Text, <name>ScrollBar, ...): our frames made from a template
			for _, base in ipairs(env.__templated) do
				if ( #k > #base and string.sub(k, 1, #base) == base and string.match(string.sub(k, #base + 1), "^%u") ) then
					local f = new("Frame", k, rawget(env, base));
					if ( string.match(k, "Text$") or string.match(k, "Low$") or string.match(k, "High$") ) then f.kind = "FontString"; f.isFrame = false; end
					if ( string.match(k, "ScrollBar$") ) then f.kind = "Slider"; f.min, f.max, f.value = 0, 0, 0; end
					return f;
				end
			end
			return nil;
		end
		if ( string.match(k, "^GetNum") ) then local f = function() return 0; end rawset(t, k, f); return f; end
		-- counts and limits (NUM_*, MAX_*, MIN_*): nil, so the code's own "or <default>" is used
		if ( string.match(k, "^NUM_") or string.match(k, "^MAX_") or string.match(k, "^MIN_") ) then return nil; end
		if ( string.match(k, "^[%u%d_]+$") ) then rawset(t, k, k); return k; end
		local f = new("Frame", k, nil, nil, true);
		f.shown = false;
		return f;
	end });

	dofile(M.dir.."/tests/wowmock_api.lua")(env, new, M);
	return env;
end

-- runs one file in env; its errors go to env.__errors
function M.load(env, path)
	local chunk, err = loadfile(path);
	if ( not chunk ) then table.insert(env.__errors, { path, err }); return false; end
	setfenv(chunk, env);
	local ok, e = xpcall(chunk, debug.traceback);
	if ( not ok ) then table.insert(env.__errors, { path, e }); end
	return ok;
end

function M.fire(env, event, ...)
	local targets = {};
	for f in pairs(env.__events[event] or {}) do table.insert(targets, f); end
	for f in pairs(env.__allEvents) do table.insert(targets, f); end
	for _, f in ipairs(targets) do Fire(env, f, "OnEvent", event, ...); end
end

function M.tick(env, n, elapsed)
	for _ = 1, n or 1 do
		env.__now = (env.__now or 1000) + (elapsed or 0.1);
		local list = {};
		for _, f in ipairs(env.__frames) do if ( f.scripts.OnUpdate and Visible(f) ) then table.insert(list, f); end end
		for _, f in ipairs(list) do Fire(env, f, "OnUpdate", elapsed or 0.1); end
	end
end

-- the errors as text, and a way to start counting again
function M.errors(env, from)
	local out = {};
	for i = (from or 0) + 1, #env.__errors do table.insert(out, env.__errors[i][1]..": "..tostring(env.__errors[i][2])); end
	return out;
end

-- the files of FRAME_FILES / GLUE_FILES / ROOT_GLUE_FILES in build_mpq.py, in its order (= the generated .toc's)
function M.tocFiles(buildPy, list)
	local text = assert(io.open(buildPy)):read("*a");
	local block = string.match(text, "\n"..list.." = (%b[])");
	assert(block, list.." not found in build_mpq.py");
	local out = {};
	for name in string.gmatch(string.gsub(block, "#[^\n]*", ""), '"([^"]+)"') do table.insert(out, (string.gsub(name, "\\\\", "/"))); end
	return out;
end

return M;
