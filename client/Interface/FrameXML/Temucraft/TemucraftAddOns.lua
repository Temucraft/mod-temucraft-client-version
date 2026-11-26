-- Temucraft AddOn list (in game; 3.3.5 only has one on the character screen): every addon with an enable checkbox,
-- its state (loaded, load on demand, disabled, out of date, missing dependency ...), its memory and, when script
-- profiling is on, its CPU time. Enable All / Disable All. EnableAddOn / DisableAddOn take effect at the next UI load:
-- "Reload UI" lights up when something changed. "CPU profiling" sets the scriptProfile CVar (costs some speed; also
-- needs a reload). Open it from the game menu (AddOns) or /addons.
TemucraftAddOnsLogic = {};
local L = TemucraftAddOnsLogic;

function L.StripColors(text)
	text = string.gsub(text or "", "|c%x%x%x%x%x%x%x%x", "");
	return (string.gsub(text, "|r", ""));
end

-- kilobytes -> "512 KB" / "1.25 MB"
function L.FormatMemory(kb)
	kb = kb or 0;
	if ( kb >= 1024 ) then return string.format("%.2f MB", kb / 1024); end
	return string.format("%d KB", math.floor(kb + 0.5));
end

-- what the list says about one addon: a = { enabled, loaded, loadable, reason, demand }
function L.Status(a)
	if ( a.loaded ) then
		if ( not a.enabled ) then return "Loaded (disabled on reload)", "warn"; end
		return "Loaded", "ok";
	end
	if ( a.enabled ) then
		if ( a.reason == "INTERFACE_VERSION" ) then return "Out of date", "bad"; end
		if ( a.reason and a.reason ~= "DISABLED" and a.reason ~= "DEMAND_LOADED" ) then
			return (a.reasonText or string.lower(string.gsub(a.reason, "_", " "))), "bad";
		end
		if ( a.demand ) then return "Load on demand", "dim"; end
		return "Loads on reload", "warn";
	end
	return "Disabled", "dim";
end

-- sorted by title (colour codes ignored), then name
function L.Sort(list)
	table.sort(list, function(a, b)
		local x, y = string.lower(L.StripColors(a.title or a.name)), string.lower(L.StripColors(b.title or b.name));
		if ( x == y ) then return (a.name or "") < (b.name or ""); end
		return x < y;
	end);
	return list;
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

local ROWS, ROW_HEIGHT = 16, 22;
local STATUS_COLOR = { ok = { 0.4, 1, 0.4 }, warn = { 1, 0.82, 0 }, bad = { 1, 0.3, 0.3 }, dim = { 0.6, 0.6, 0.6 } };

local frame = CreateFrame("Frame", "TemucraftAddOnListFrame", UIParent);
frame:SetWidth(620); frame:SetHeight(110 + ROWS * ROW_HEIGHT);
frame:SetPoint("CENTER");
frame:SetFrameStrata("DIALOG");
frame:SetToplevel(true);
frame:EnableMouse(true);
frame:SetMovable(true);
frame:SetClampedToScreen(true);
frame:RegisterForDrag("LeftButton");
frame:SetScript("OnDragStart", frame.StartMoving);
frame:SetScript("OnDragStop", frame.StopMovingOrSizing);
frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } });
frame:Hide();
tinsert(UISpecialFrames, "TemucraftAddOnListFrame");

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
title:SetPoint("TOP", 0, -18);
title:SetText(ADDONS or "AddOns");
local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
close:SetPoint("TOPRIGHT", -6, -6);

local note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
note:SetPoint("BOTTOMLEFT", 20, 46);
note:SetText("Changes take effect after Reload UI.");

local headName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
headName:SetPoint("TOPLEFT", 50, -46); headName:SetText(NAME or "Name");
local headStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
headStatus:SetPoint("TOPLEFT", 300, -46); headStatus:SetText("Status");
local headMem = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
headMem:SetPoint("TOPRIGHT", -120, -46); headMem:SetText("Memory");
local headCpu = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
headCpu:SetPoint("TOPRIGHT", -44, -46); headCpu:SetText("CPU");

local scroll = CreateFrame("ScrollFrame", "TemucraftAddOnListScroll", frame, "FauxScrollFrameTemplate");
scroll:SetPoint("TOPLEFT", 16, -62);
scroll:SetWidth(560); scroll:SetHeight(ROWS * ROW_HEIGHT);

local addons, changed = {}, false;
local reload;

local function Profiling() return GetCVar("scriptProfile") == "1"; end

local function Read()
	wipe(addons);
	for i = 1, GetNumAddOns() do
		local name, titleText, notes, enabled, loadable, reason = GetAddOnInfo(i);
		local demand = IsAddOnLoadOnDemand and IsAddOnLoadOnDemand(i);
		table.insert(addons, { index = i, name = name, title = titleText or name, notes = notes, enabled = enabled and true or false,
			loadable = loadable, reason = reason, reasonText = reason and _G["ADDON_"..reason], demand = demand and true or false,
			loaded = IsAddOnLoaded(i) and true or false, deps = { GetAddOnDependencies(i) } });
	end
	L.Sort(addons);
end

local function Usage()
	UpdateAddOnMemoryUsage();
	if ( Profiling() ) then UpdateAddOnCPUUsage(); end
	for _, a in ipairs(addons) do
		a.memory = a.loaded and GetAddOnMemoryUsage(a.index) or nil;
		a.cpu = (a.loaded and Profiling()) and GetAddOnCPUUsage(a.index) or nil;
	end
end

local rows = {};
local function Update()
	local offset = FauxScrollFrame_GetOffset(scroll);
	for i = 1, ROWS do
		local r, a = rows[i], addons[offset + i];
		if ( a ) then
			r.addon = a;
			r.check:SetChecked(a.enabled);
			r.name:SetText(a.title);
			local text, kind = L.Status(a);
			r.status:SetText(text);
			local c = STATUS_COLOR[kind];
			r.status:SetTextColor(c[1], c[2], c[3]);
			r.memory:SetText(a.memory and L.FormatMemory(a.memory) or "");
			r.cpu:SetText(a.cpu and string.format("%.0f ms", a.cpu) or (Profiling() and "" or "off"));
			r:Show();
		else
			r:Hide();
		end
	end
	FauxScrollFrame_Update(scroll, #addons, ROWS, ROW_HEIGHT);
	if ( changed ) then reload:LockHighlight(); else reload:UnlockHighlight(); end
end

local function Changed() changed = true; Read(); Usage(); Update(); end

for i = 1, ROWS do
	local r = CreateFrame("Button", nil, frame);
	r:SetHeight(ROW_HEIGHT);
	r:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT);
	r:SetPoint("RIGHT", scroll, "RIGHT", 0, 0);
	r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");
	r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate");
	r.check:SetWidth(22); r.check:SetHeight(22);
	r.check:SetPoint("LEFT", 8, 0);
	r.check:SetScript("OnClick", function(self)
		local a = r.addon;
		if ( not a ) then return; end
		if ( self:GetChecked() ) then EnableAddOn(a.index); else DisableAddOn(a.index); end
		PlaySound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
		Changed();
	end);
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	r.name:SetPoint("LEFT", 34, 0); r.name:SetWidth(240); r.name:SetJustifyH("LEFT");
	r.status = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	r.status:SetPoint("LEFT", 284, 0); r.status:SetWidth(150); r.status:SetJustifyH("LEFT");
	r.memory = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	r.memory:SetPoint("RIGHT", -86, 0); r.memory:SetJustifyH("RIGHT");
	r.cpu = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	r.cpu:SetPoint("RIGHT", -8, 0); r.cpu:SetJustifyH("RIGHT");
	r:SetScript("OnEnter", function(self)
		local a = self.addon;
		if ( not a ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:AddLine(a.title);
		if ( a.notes and a.notes ~= "" ) then GameTooltip:AddLine(a.notes, 1, 1, 1, true); end
		if ( #a.deps > 0 ) then GameTooltip:AddLine("Needs: "..table.concat(a.deps, ", "), 0.7, 0.7, 0.7, true); end
		GameTooltip:AddLine(a.name, 0.5, 0.5, 0.5);
		GameTooltip:Show();
	end);
	r:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	rows[i] = r;
end
scroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, Update); end);

local function Button(text, width, point, x, onClick)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	b:SetWidth(width); b:SetHeight(22);
	b:SetText(text);
	b:SetPoint(point, x, 16);
	b:SetScript("OnClick", onClick);
	return b;
end
Button("Enable All", 100, "BOTTOMLEFT", 18, function() EnableAllAddOns(); Changed(); end);
Button("Disable All", 100, "BOTTOMLEFT", 122, function() DisableAllAddOns(); Changed(); end);
reload = Button(RELOADUI or "Reload UI", 110, "BOTTOMRIGHT", -18, function() ReloadUI(); end);

local cpu = CreateFrame("CheckButton", "TemucraftAddOnListCpuCheck", frame, "UICheckButtonTemplate");
cpu:SetWidth(22); cpu:SetHeight(22);
cpu:SetPoint("BOTTOMLEFT", 232, 16);
_G[cpu:GetName().."Text"]:SetText("CPU profiling");
cpu:SetScript("OnClick", function(self)
	SetCVar("scriptProfile", self:GetChecked() and "1" or "0");
	Changed();
end);
cpu:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText("CPU profiling");
	GameTooltip:AddLine("Measures each addon's CPU time (the scriptProfile setting). Slows the game a little; takes effect after Reload UI.", 1, 1, 1, true);
	GameTooltip:Show();
end);
cpu:SetScript("OnLeave", function() GameTooltip:Hide(); end);

-- memory and CPU every 3 seconds while open
local wait = 0;
frame:SetScript("OnUpdate", function(self, elapsed)
	wait = wait + elapsed;
	if ( wait < 3 ) then return; end
	wait = 0;
	Usage(); Update();
end);
frame:SetScript("OnShow", function()
	PlaySound("igMainMenuOpen");
	cpu:SetChecked(Profiling());
	Read(); Usage(); Update();
end);
frame:SetScript("OnHide", function() PlaySound("igMainMenuClose"); end);

function TemucraftAddOnList_Toggle()
	if ( frame:IsShown() ) then frame:Hide(); else frame:Show(); end
end
SLASH_TEMUCRAFTADDONS1 = "/addons";
-- with DragonUI's Addon Manager on, its list (TemucraftGameMenu_AddOns, the Esc menu's AddOns row)
SlashCmdList["TEMUCRAFTADDONS"] = function()
	if ( TemucraftGameMenu_AddOns ) then TemucraftGameMenu_AddOns(); return; end
	TemucraftAddOnList_Toggle();
end;
