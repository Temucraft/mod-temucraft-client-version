#!/usr/bin/env python3
"""Writes Interface/FrameXML/Temucraft/TemucraftTokenPreview.lua: alt-clicking a tier token opens a window with
what it can be exchanged for (your class, or every class); its tooltip says how many. Input: the TSV of token_preview.sql run on the world database
(mysql acore_world < token_preview.sql > tokens.tsv)."""
import csv, os, sys
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'tokens', 'tokens.tsv')
tokens = {}
with open(src, encoding='utf-8') as f:
    for r in csv.DictReader(f, delimiter='\t'):
        tokens.setdefault(int(r['token']), []).append((int(r['item']), r['iname'], int(r['cls']), int(r['q']), int(r['ilvl']), int(r.get('sett') or 0)))
sets = {}
sets_src = os.path.join(os.path.dirname(src), 'sets.tsv')
if os.path.exists(sets_src):
    with open(sets_src, encoding='utf-8') as f:
        for r in csv.DictReader(f, delimiter='\t'):
            sets.setdefault(int(r['sett']), []).append((int(r['item']), int(r['slot']), int(r['ilvl'])))
def q(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
lines = ['-- Temucraft token preview: hovering a tier token lists the items it buys for your class.',
         '-- Made by build_token_preview.py from the world database; do not edit by hand.',
         'local T = {']
for tok in sorted(tokens):
    items = sorted(tokens[tok], key=lambda x: (x[4], x[1]))
    lines.append('[%d]={%s},' % (tok, ','.join('{%d,%s,%d,%d,%d,%d}' % (i, q(n), c, qu, il, st) for i, n, c, qu, il, st in items)))
lines.append('};')
lines.append('-- item set -> its pieces { item, slot, item level }')
lines.append('local S = {')
for st in sorted(sets):
    lines.append('[%d]={%s},' % (st, ','.join('{%d,%d,%d}' % p for p in sets[st])))
lines.append('};')
lines.append(r'''
local CLASS_BIT = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, DEATHKNIGHT = 32, SHAMAN = 64,
	MAGE = 128, WARLOCK = 256, DRUID = 1024 };
local COLS, SIZE, GAP = 4, 37, 8;

local function ForMe(e)
	local _, class = UnitClass("player");
	local bit = CLASS_BIT[class] or 0;
	return e[3] == -1 or e[3] == 0 or (e[3] % (bit * 2)) >= bit;
end

local function SetPieces(set, ilvl)
	local best = {};
	for _, p in ipairs(S[set] or {}) do
		local slot = p[2] == 20 and 5 or p[2];   -- robes count as chest
		local b = best[slot];
		if ( not b or math.abs(p[3] - ilvl) < math.abs(b[3] - ilvl) ) then best[slot] = p; end
	end
	return best;
end

local function Mine(list, all)
	local out = {};
	for _, e in ipairs(list) do if ( all or ForMe(e) ) then out[#out + 1] = e; end end
	return out;
end

-- the window
local frame = CreateFrame("Frame", "TemucraftTokenPreviewFrame", UIParent);
frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:SetClampedToScreen(true);
frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton");
frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing);
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80);
frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } });
frame:Hide();
tinsert(UISpecialFrames, "TemucraftTokenPreviewFrame");   -- Escape closes it

local header = frame:CreateTexture(nil, "ARTWORK");
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header"); header:SetWidth(320); header:SetHeight(64);
header:SetPoint("TOP", frame, "TOP", 0, 12);
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
title:SetPoint("TOP", header, "TOP", 0, -14);
local tokenIcon = frame:CreateTexture(nil, "ARTWORK");
tokenIcon:SetWidth(40); tokenIcon:SetHeight(40); tokenIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -30);
local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
subtitle:SetPoint("LEFT", tokenIcon, "RIGHT", 10, 6); subtitle:SetJustifyH("LEFT");
local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
hint:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -4); hint:SetJustifyH("LEFT");
local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6);

-- your character, to try pieces on
local model = CreateFrame("DressUpModel", "TemucraftTokenPreviewModel", frame);
model:SetWidth(200); model:SetHeight(300);
local modelBg = model:CreateTexture(nil, "BACKGROUND"); modelBg:SetAllPoints(); modelBg:SetTexture(0, 0, 0, 0.35);
model.rotation = 0; model:EnableMouse(true);
model:SetScript("OnMouseDown", function(self) self.dragX = GetCursorPosition(); end);
model:SetScript("OnMouseUp", function(self) self.dragX = nil; end);
model:SetScript("OnUpdate", function(self)
	if ( self.dragX ) then
		local x = GetCursorPosition();
		self.rotation = self.rotation + (x - self.dragX) / 80; self.dragX = x;
		self:SetFacing(self.rotation);
	end
end);
local trySet = CreateFrame("Button", "TemucraftTokenPreviewTrySet", frame, "UIPanelButtonTemplate");
trySet:SetWidth(98); trySet:SetHeight(22); trySet:SetText("Try on set");
local reset = CreateFrame("Button", "TemucraftTokenPreviewReset", frame, "UIPanelButtonTemplate");
reset:SetWidth(98); reset:SetHeight(22); reset:SetText("Reset");
reset:SetScript("OnClick", function() model:Dress(); end);

local allBox = CreateFrame("CheckButton", "TemucraftTokenPreviewAll", frame, "UICheckButtonTemplate");
allBox:SetWidth(22); allBox:SetHeight(22);
_G[allBox:GetName().."Text"]:SetText("All classes");

local buttons = {};
local function Button(i)
	if ( buttons[i] ) then return buttons[i]; end
	local b = CreateFrame("Button", "TemucraftTokenPreviewItem"..i, frame, "ItemButtonTemplate");
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	b.name:SetPoint("LEFT", b, "RIGHT", 6, 0); b.name:SetWidth(118); b.name:SetJustifyH("LEFT");
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetHyperlink("item:"..self.item);
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	b:SetScript("OnClick", function(self)
		local _, link = GetItemInfo(self.item);
		if ( IsModifiedClick() and link ) then HandleModifiedItemClick(link); return; end
		model:TryOn(link or ("item:"..self.item));   -- a plain click tries it on
		frame.lastSet, frame.lastIlvl = self.set, self.ilvl;
	end);
	buttons[i] = b;
	return b;
end

local current;
local function Fill()
	if ( not current ) then return; end
	local list = Mine(T[current], allBox:GetChecked());
	local name, _, quality, _, _, _, _, _, _, icon = GetItemInfo(current);
	title:SetText(name or "Token");
	tokenIcon:SetTexture(icon or GetItemIcon(current));
	subtitle:SetText(#list.." item"..(#list == 1 and "" or "s").." for "..(allBox:GetChecked() and "every class" or UnitClass("player")));
	hint:SetText("Click to try on, shift-click to link. Drag the model to turn it.");
	for i, b in ipairs(buttons) do b:Hide(); end
	local rows = math.max(1, math.ceil(#list / 2));
	for i, e in ipairs(list) do
		local b = Button(i);
		b.item = e[1]; b.set = e[6]; b.ilvl = e[5];
		if ( i == 1 ) then frame.lastSet, frame.lastIlvl = e[6], e[5]; end
		local iname, _, q = GetItemInfo(e[1]);
		SetItemButtonTexture(b, GetItemIcon(e[1]));
		local r, g, bl = GetItemQualityColor(q or e[4]);
		b.name:SetText(iname or e[2]); b.name:SetTextColor(r, g, bl);
		local col, row = (i - 1) % 2, floor((i - 1) / 2);
		b:ClearAllPoints();
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", 22 + col * 170, -84 - row * (SIZE + GAP));
		b:Show();
	end
	frame:SetWidth(590);
	frame:SetHeight(math.max(84 + rows * (SIZE + GAP) + 40, 430));
	allBox:ClearAllPoints(); allBox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 14);
	model:ClearAllPoints(); model:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -36);
	trySet:ClearAllPoints(); trySet:SetPoint("TOPLEFT", model, "BOTTOMLEFT", 0, -6);
	reset:ClearAllPoints(); reset:SetPoint("LEFT", trySet, "RIGHT", 4, 0);
	if ( frame.lastSet and frame.lastSet > 0 and S[frame.lastSet] ) then trySet:Enable(); else trySet:Disable(); end
end
allBox:SetScript("OnClick", Fill);
trySet:SetScript("OnClick", function()
	if ( not frame.lastSet ) then return; end
	model:Undress();
	for _, p in pairs(SetPieces(frame.lastSet, frame.lastIlvl or 0)) do model:TryOn("item:"..p[1]); end
end);

frame:RegisterEvent("GET_ITEM_INFO_RECEIVED");
frame:SetScript("OnEvent", function() if ( frame:IsShown() ) then Fill(); end end);

local function Open(id)
	current = id; allBox:SetChecked(false);
	for _, e in ipairs(T[id]) do GetItemInfo(e[1]); end   -- ask the server for anything not cached yet
	frame.lastSet = nil;
	frame:Show(); model:SetUnit("player"); model:SetFacing(0); model.rotation = 0;
	Fill();
end

-- tooltip: a short note on tokens; alt-click opens the window
local function AddHint(tooltip)
	local _, link = tooltip:GetItem();
	local id = link and tonumber(link:match("item:(%d+)"));
	if ( not id or not T[id] ) then return; end
	tooltip:AddLine(" ");
	tooltip:AddLine("Exchanges for "..#Mine(T[id]).." items for your class.", 1, 0.82, 0);
	tooltip:AddLine("<Alt-click to preview>", 0, 1, 0);
	tooltip:Show();
end
GameTooltip:HookScript("OnTooltipSetItem", AddHint);
ItemRefTooltip:HookScript("OnTooltipSetItem", AddHint);

local OrigModifiedClick = HandleModifiedItemClick;
function HandleModifiedItemClick(link)
	local id = link and tonumber(link:match("item:(%d+)"));
	if ( id and T[id] and IsAltKeyDown() ) then Open(id); return true; end
	return OrigModifiedClick(link);
end

SLASH_TEMUCRAFTTOKEN1 = "/tokenpreview";
SlashCmdList["TEMUCRAFTTOKEN"] = function(msg)
	local id = tonumber(msg) or tonumber((msg or ""):match("item:(%d+)"));
	if ( id and T[id] ) then Open(id); else DEFAULT_CHAT_FRAME:AddMessage("Usage: /tokenpreview <token link or id>"); end
end
''')
out = os.path.join(HERE, 'Interface', 'FrameXML', 'Temucraft', 'TemucraftTokenPreview.lua')
os.makedirs(os.path.dirname(out), exist_ok=True)
open(out, 'w', encoding='utf-8').write('\n'.join(lines))
print(len(tokens), 'tokens ->', out)
