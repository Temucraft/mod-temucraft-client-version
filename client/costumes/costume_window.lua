local PREFIX = "TCO";
local TYPES = { { 0, "All" }, { 7, "Humanoids" }, { 1, "Beasts" }, { 2, "Dragonkin" }, { 3, "Demons" }, { 4, "Elementals" },
	{ 5, "Giants" }, { 6, "Undead" }, { 9, "Mechanical" }, { 10, "Other" } };
local ROWS, ROW_H = 16, 18;

local state = { all = false, owned = {}, count = 0, worn = 0, loading = false, pending = {} };
local view = { type = 0, search = "", list = {}, selected = nil };

local function Send(text) SendAddonMessage(PREFIX, text, "WHISPER", UnitName("player")); end
local function Owns(d) return C[d] and (state.all or state.owned[d]); end

-- window ------------------------------------------------------------------------------------------------------------
local f = CreateFrame("Frame", "TemucraftWardrobeFrame", UIParent);
f:SetWidth(640); f:SetHeight(470); f:SetPoint("CENTER");
f:SetFrameStrata("DIALOG"); f:SetToplevel(true); f:SetClampedToScreen(true);
f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton");
f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing);
f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } });
f:Hide();
tinsert(UISpecialFrames, "TemucraftWardrobeFrame");

local header = f:CreateTexture(nil, "ARTWORK");
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header"); header:SetWidth(300); header:SetHeight(64);
header:SetPoint("TOP", f, "TOP", 0, 12);
local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal");
title:SetPoint("TOP", header, "TOP", 0, -14); title:SetText("Wardrobe");
local close = CreateFrame("Button", nil, f, "UIPanelCloseButton");
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6);
local counter = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
counter:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -30);

-- categories (left)
local catButtons = {};
local Refresh, Render;
for i, t in ipairs(TYPES) do
	local b = CreateFrame("Button", "TemucraftWardrobeCat"..i, f, "UIPanelButtonTemplate");
	b:SetWidth(100); b:SetHeight(22);
	b:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -50 - (i - 1) * 25);
	b:SetText(t[2]);
	b:SetScript("OnClick", function() view.type = t[1]; view.selected = nil; Refresh(); end);
	catButtons[i] = b;
end

-- search
local search = CreateFrame("EditBox", "TemucraftWardrobeSearch", f, "InputBoxTemplate");
search:SetWidth(200); search:SetHeight(20); search:SetAutoFocus(false);
search:SetPoint("TOPLEFT", f, "TOPLEFT", 136, -46);
local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
searchLabel:SetPoint("LEFT", search, "LEFT", 4, 0); searchLabel:SetText("Search...");
search:SetScript("OnTextChanged", function(self)
	view.search = strlower(self:GetText() or "");
	if ( view.search == "" and not self:HasFocus() ) then searchLabel:Show(); else searchLabel:Hide(); end
	Refresh();
end);
search:SetScript("OnEditFocusGained", function() searchLabel:Hide(); end);
search:SetScript("OnEditFocusLost", function(self) if ( (self:GetText() or "") == "" ) then searchLabel:Show(); end end);
search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);

-- list (middle)
local listBg = CreateFrame("Frame", nil, f);
listBg:SetPoint("TOPLEFT", f, "TOPLEFT", 130, -70); listBg:SetWidth(232); listBg:SetHeight(ROWS * ROW_H + 10);
listBg:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } });
listBg:SetBackdropColor(0, 0, 0, 0.6);
local scroll = CreateFrame("ScrollFrame", "TemucraftWardrobeScroll", listBg, "FauxScrollFrameTemplate");
scroll:SetPoint("TOPLEFT", listBg, "TOPLEFT", 0, -5); scroll:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -26, 5);
local rows = {};
for i = 1, ROWS do
	local r = CreateFrame("Button", nil, listBg);
	r:SetWidth(200); r:SetHeight(ROW_H);
	r:SetPoint("TOPLEFT", listBg, "TOPLEFT", 8, -5 - (i - 1) * ROW_H);
	r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");
	r.sel = r:CreateTexture(nil, "BACKGROUND"); r.sel:SetAllPoints(); r.sel:SetTexture(1, 0.82, 0, 0.25); r.sel:Hide();
	r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	r.text:SetPoint("LEFT", r, "LEFT", 4, 0); r.text:SetWidth(196); r.text:SetJustifyH("LEFT");
	r:SetScript("OnClick", function(self) view.selected = self.display; Render(); end);
	r:SetScript("OnDoubleClick", function(self) Send("WEAR~"..self.display); end);
	rows[i] = r;
end

-- preview (right)
local model = CreateFrame("PlayerModel", "TemucraftWardrobeModel", f);
model:SetPoint("TOPLEFT", f, "TOPLEFT", 378, -50); model:SetWidth(240); model:SetHeight(300);
local modelBg = model:CreateTexture(nil, "BACKGROUND"); modelBg:SetAllPoints(); modelBg:SetTexture(0, 0, 0, 0.35);
model.rotation = 0;
model:EnableMouse(true);
model:SetScript("OnMouseDown", function(self) self.dragX = GetCursorPosition(); end);
model:SetScript("OnMouseUp", function(self) self.dragX = nil; end);
model:SetScript("OnUpdate", function(self)
	if ( self.dragX ) then
		local x = GetCursorPosition();
		self.rotation = self.rotation + (x - self.dragX) / 80; self.dragX = x;
		self:SetFacing(self.rotation);
	end
end);
local previewName = f:CreateFontString(nil, "OVERLAY", "GameFontNormal");
previewName:SetPoint("TOP", model, "BOTTOM", 0, -6); previewName:SetWidth(240);
local previewNote = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
previewNote:SetPoint("TOP", previewName, "BOTTOM", 0, -2); previewNote:SetWidth(240);

local wear = CreateFrame("Button", "TemucraftWardrobeWear", f, "UIPanelButtonTemplate");
wear:SetWidth(110); wear:SetHeight(24); wear:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -140, 20);
wear:SetText("Wear");
wear:SetScript("OnClick", function() if ( view.selected ) then Send("WEAR~"..view.selected); end end);
local off = CreateFrame("Button", "TemucraftWardrobeOff", f, "UIPanelButtonTemplate");
off:SetWidth(110); off:SetHeight(24); off:SetPoint("LEFT", wear, "RIGHT", 6, 0);
off:SetText("Take off");
off:SetScript("OnClick", function() Send("OFF"); end);
local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 136, 26);
hint:SetText("Double-click to wear. Drag the model to turn it.");

-- filling -----------------------------------------------------------------------------------------------------------
local function Build()
	local list = {};
	for d, e in pairs(C) do
		if ( Owns(d) and (view.type == 0 or e[2] == view.type) and (view.search == "" or strfind(strlower(e[3]), view.search, 1, true)) ) then
			list[#list + 1] = d;
		end
	end
	table.sort(list, function(a, b) if ( C[a][3] ~= C[b][3] ) then return C[a][3] < C[b][3]; end return a < b; end);
	view.list = list;
end

local function Preview()
	local d = view.selected;
	if ( not d ) then
		model:SetUnit("player"); previewName:SetText(UnitName("player"));
		previewNote:SetText(state.worn > 0 and C[state.worn] and ("Wearing: "..C[state.worn][3]) or "");
		wear:Disable();
		return;
	end
	model:ClearModel();
	model:SetCreature(C[d][1]);
	model:SetFacing(model.rotation);
	previewName:SetText(C[d][3]);
	previewNote:SetText(d == state.worn and "You are wearing this." or "");
	wear:Enable();
end

Refresh = function()
	if ( not f:IsShown() ) then return; end
	Build();
	Render();
end
Render = function()
	if ( not f:IsShown() ) then return; end
	for i, b in ipairs(catButtons) do
		if ( TYPES[i][1] == view.type ) then b:LockHighlight(); else b:UnlockHighlight(); end
	end
	local n = #view.list;
	FauxScrollFrame_Update(scroll, n, ROWS, ROW_H);
	local offset = FauxScrollFrame_GetOffset(scroll);
	for i = 1, ROWS do
		local r, d = rows[i], view.list[offset + i];
		if ( d ) then
			r.display = d;
			r.text:SetText(C[d][3]);
			if ( d == state.worn ) then r.text:SetTextColor(0.4, 1, 0.4); else r.text:SetTextColor(1, 1, 1); end
			if ( d == view.selected ) then r.sel:Show(); else r.sel:Hide(); end
			r:Show();
		else
			r:Hide();
		end
	end
	counter:SetText(state.loading and "Loading your collection..." or
		(state.all and "Every costume is open to you." or (state.count.." costumes collected")).."  ("..n.." shown)");
	if ( state.worn > 0 ) then off:Enable(); else off:Disable(); end
	Preview();
end
scroll:SetScript("OnVerticalScroll", function(self, value) FauxScrollFrame_OnVerticalScroll(self, value, ROW_H, Render); end);
f:SetScript("OnShow", function() state.loading = true; Send("LIST"); Refresh(); end);

-- server ------------------------------------------------------------------------------------------------------------
local events = CreateFrame("Frame");
events:RegisterEvent("PLAYER_LOGIN");
events:RegisterEvent("CHAT_MSG_ADDON");
events:SetScript("OnEvent", function(_, event, prefix, text)
	if ( event == "PLAYER_LOGIN" ) then Send("HELLO"); return; end
	if ( prefix ~= PREFIX ) then return; end
	local cmd, a, b, c = strsplit("~", text);
	if ( cmd == "OPEN" ) then
		if ( f:IsShown() ) then f:Hide(); else f:Show(); end
	elseif ( cmd == "BEGIN" ) then
		state.all = a == "1"; state.worn = tonumber(b) or 0; state.count = tonumber(c) or 0; state.pending = {};
	elseif ( cmd == "IDS" and a ) then
		for id in gmatch(a, "%d+") do state.pending[tonumber(id)] = true; end
	elseif ( cmd == "END" ) then
		state.owned = state.pending; state.pending = {}; state.loading = false; Refresh();
	elseif ( cmd == "WORN" ) then
		state.worn = tonumber(a) or 0; Render();
	elseif ( cmd == "NEW" ) then
		local d = tonumber(a);
		if ( d and not state.owned[d] ) then state.owned[d] = true; state.count = state.count + 1; end
		Refresh();
	end
end);

SLASH_TEMUCRAFTWARDROBE1 = "/wardrobe";
SlashCmdList["TEMUCRAFTWARDROBE"] = function() if ( f:IsShown() ) then f:Hide(); else f:Show(); end end;
