--[[
	Temucraft Options on the login and character screens: one window in place of the stock chooser (Options: Video /
	Sound / Reset User Options / Close) and its two separate windows. Menu > Options (and the login screen's Options)
	opens it straight away.

	Left: the pages, grouped (Graphics: the stock video pages, Display and Effects, and Frame Rate; Audio: the stock
	sound page(s) and More Sound). Right: the page. Bottom: Defaults (this page, with the stock confirm: All Settings /
	Current Settings), Classic (the stock chooser), Apply, Cancel, Okay.

	The stock pages are the stock panels themselves (VideoOptions*Panel, AudioOptions*Panel), moved into this window
	while it is open and back when it closes, so every CVar, check, restart and dependent control works as before;
	Okay / Apply / Cancel run the stock frames' own okay / cancel code (VideoOptionsFrameOkay_OnClick with apply,
	OptionsFrameCancel_OnClick ...), RestartGx and the restart alerts included. Our pages (Frame Rate, More Sound) set
	CVars that 3.3.5 has but the stock glue hides, the same rows as in the in-game Options window (TemucraftOptions.lua),
	so both show the same values; Cancel puts them back.

	Every slider (stock and ours) shows its real minimum and maximum at its ends (0% / 100% for 0-1 sliders) and its
	value in a box you can type in (Enter applies, clamped and snapped to the slider's step). The Refresh Rate menu is
	empty in windowed mode (the client has no rates then): it says so instead.

	If the window fails to open, the stock chooser opens (TEMUCRAFT_GLUE_OPTIONS = "classic" in
	Interface\TemucraftScenes.lua always uses the stock one).
--]]

TemucraftGlueOptionsLogic = {};
local L = TemucraftGlueOptionsLogic;

-- [[ sliders: the same rules as the in-game window (TemucraftOptionsLogic) ]] --
function L.Snap(value, min, max, step)
	if ( step and step > 0 ) then value = min + math.floor((value - min) / step + 0.5) * step; end
	if ( value < min ) then value = min; elseif ( value > max ) then value = max; end
	return value;
end

function L.Format(value, min, max, step, fmt)
	if ( fmt == "percent" or (not fmt and min == 0 and max == 1 and step and step < 1) ) then
		return string.format("%d%%", math.floor(value * 100 + 0.5));
	end
	local decimals = tonumber(fmt);
	if ( not decimals ) then
		decimals = 0;
		if ( step and step > 0 and step < 1 ) then decimals = (step < 0.1) and 2 or 1; end
	end
	if ( decimals == 0 ) then return tostring(math.floor(value + 0.5)); end
	return string.format("%."..decimals.."f", value);
end

function L.Ends(min, max, step, fmt)
	return L.Format(min, min, max, step, fmt), L.Format(max, min, max, step, fmt);
end

function L.Parse(text, min, max, step, fmt)
	text = string.gsub(tostring(text or ""), ",", ".");
	local num = tonumber((string.gsub(text, "[%s%%]", "")));
	if ( not num ) then return nil; end
	local percent = (fmt == "percent" or (not fmt and min == 0 and max == 1 and step and step < 1));
	if ( percent and (string.find(text, "%", 1, true) or num > 1) ) then num = num / 100; end
	return L.Snap(num, min, max, step);
end

-- The Refresh Rate menu's text: the client's rates (GetRefreshRates) are a single 0 in windowed mode
function L.RefreshText(value, ...)
	local n = select("#", ...);
	if ( n == 0 or (n == 1 and (select(1, ...) or 0) == 0) ) then
		return "Set by the display (windowed)", false;
	end
	local hz = HERTZ or " Hz";
	value = tonumber(value);
	for i = 1, n do
		if ( value and tonumber((select(i, ...))) == value ) then return (select(i, ...))..hz, true; end
	end
	return (select(1, ...))..hz, true;
end

-- [[ our pages: CVars the stock glue doesn't show (the in-game window has the same rows) ]] --
L.PAGES = {
	{ key = "framerate", section = "Graphics", title = "Frame Rate", rows = {
		{ kind = "slider", cvar = "maxFPS", label = "Max Frame Rate", min = 0, max = 200, step = 5, tooltip = "Frames per second at most (0 = no limit)." },
		{ kind = "slider", cvar = "maxFPSBk", label = "Max Background Frame Rate", min = 0, max = 200, step = 5, tooltip = "Frames per second at most while the game is in the background (0 = no limit)." },
	} },
	{ key = "moresound", section = "Audio", title = "More Sound", rows = {
		{ kind = "check", cvar = "Sound_ListenerAtCharacter", label = "Hear From the Character", tooltip = "Sounds are heard from where your character stands, not from the camera." },
		{ kind = "check", cvar = "Sound_ZoneMusicNoDelay", label = "Zone Music Without Delay", tooltip = "A zone's music starts again at once instead of after a pause." },
		{ kind = "reset", label = "Reset All Settings", tooltip = "Puts every setting of the game back to its default (the stock Reset User Options; the game restarts its settings at the next login)." },
	} },
};

-- The list: { kind = "section", text } and { kind = "page", text, panel = stock panel, frame = its stock frame } or
-- { kind = "page", text, page = one of ours }. video / audio: the stock frames' categoryList.
function L.List(video, audio)
	local out = {};
	local function add(section, frame, list)
		table.insert(out, { kind = "section", text = section });
		for _, panel in ipairs(list or {}) do
			if ( not panel.hidden and panel.name ) then table.insert(out, { kind = "page", text = panel.name, panel = panel, frame = frame }); end
		end
		for _, p in ipairs(L.PAGES) do
			if ( p.section == section ) then table.insert(out, { kind = "page", text = p.title, page = p }); end
		end
	end
	add("Graphics", VideoOptionsFrame, video);
	add("Audio", AudioOptionsFrame, audio);
	return out;
end

---------------------------------------------------------------------------------------------------------------------
-- The window (only in the client)
---------------------------------------------------------------------------------------------------------------------
if ( not CreateFrame or not GlueParent or not OptionsSelectFrame ) then
	return;
end

local W, list, entries, current, bypass;
local moved = {};          -- [panel] = { parent =, displayed = the stock frame's displayed panel before }
local decorated = {};      -- [slider] = true
local saved = {};          -- our CVars as they were when the window opened (Cancel puts them back)
local pageFrames = {};

local function Active()
	return TEMUCRAFT_GLUE_OPTIONS ~= "classic";
end

local function Tooltip(owner, text)
	if ( text and GlueTooltip and GlueTooltip_SetOwner ) then
		GlueTooltip:ClearAllPoints();
		GlueTooltip_SetOwner(owner);
		GlueTooltip_SetText(text);
	end
end
local function HideTooltip() if ( GlueTooltip ) then GlueTooltip:Hide(); end end

local function GetCVarSafe(cvar)
	local ok, v = pcall(GetCVar, cvar);
	return ok and v or nil;
end

-- a slider's ends and a value box (stock sliders and ours); fmt: see L.Format
local valueCount = 0;
local function DecorateSlider(s, fmt)
	if ( decorated[s] or not s.GetMinMaxValues ) then return; end
	decorated[s] = true;
	local name = s:GetName();
	local low, high = name and _G[name.."Low"], name and _G[name.."High"];
	valueCount = valueCount + 1;
	local box = CreateFrame("EditBox", "TemucraftGlueOptionsValue"..valueCount, s);
	box:SetWidth(50); box:SetHeight(16);
	box:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 1);
	box:SetFontObject(GlueFontHighlightSmall);
	box:SetAutoFocus(false);
	box:SetJustifyH("RIGHT");
	box:SetTextInsets(3, 3, 0, 0);
	local bg = box:CreateTexture(nil, "BACKGROUND");
	bg:SetTexture(0, 0, 0, 0.55);
	bg:SetAllPoints(box);
	local function Show()
		local min, max = s:GetMinMaxValues();
		local step = s:GetValueStep();
		if ( not box:HasFocus() ) then box:SetText(L.Format(s:GetValue(), min, max, step, fmt)); end
		local lo, hi = L.Ends(min, max, step, fmt);
		if ( low ) then low:SetText(lo); end
		if ( high ) then high:SetText(hi); end
	end
	s.temucraftShowValue = Show;
	if ( s.HookScript ) then s:HookScript("OnValueChanged", Show); s:HookScript("OnShow", Show); end
	box:SetScript("OnEnterPressed", function(self)
		local min, max = s:GetMinMaxValues();
		local v = L.Parse(self:GetText(), min, max, s:GetValueStep(), fmt);
		self:ClearFocus();
		if ( v ) then s:SetValue(v); end
		Show();
	end);
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); Show(); end);
	box:SetScript("OnEditFocusLost", function() Show(); end);
	box:SetScript("OnEditFocusGained", function(self) self:HighlightText(); end);
	Show();
end

-- every slider of a stock panel (the graphics quality slider keeps its names)
local function DecoratePanel(panel)
	local function walk(f)
		for _, c in ipairs({ f:GetChildren() }) do
			if ( c.GetObjectType and c:GetObjectType() == "Slider" and c ~= VideoOptionsEffectsPanelQualitySlider ) then
				DecorateSlider(c);
			end
			walk(c);
		end
	end
	walk(panel);
end

local function FixRefresh()
	local dd = VideoOptionsResolutionPanelRefreshDropDown;
	if ( not dd or not GetRefreshRates or not GlueDropDownMenu_SetText ) then return; end
	local text = L.RefreshText(GetCVarSafe("gxRefresh"), GetRefreshRates());
	GlueDropDownMenu_SetText(text, dd);
end

---------------------------------------------------------------------------------------------------------------------
-- Our pages
---------------------------------------------------------------------------------------------------------------------
local rowCount = 0;
local function BuildPage(p)
	local f = CreateFrame("Frame", "TemucraftGlueOptionsPage"..p.key, W.container);
	f:SetAllPoints(W.container);
	local title = f:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
	title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -16);
	title:SetText(p.title);
	f.rows = {};
	local y = -60;
	for _, row in ipairs(p.rows) do
		rowCount = rowCount + 1;
		local r;
		if ( row.kind == "slider" ) then
			r = CreateFrame("Slider", "TemucraftGlueOptionsSlider"..rowCount, f, "OptionsSliderTemplate");
			r:SetWidth(240); r:SetHeight(17);
			r:SetPoint("TOPLEFT", f, "TOPLEFT", 26, y - 16);
			r:SetMinMaxValues(row.min, row.max);
			r:SetValueStep(row.step);
			local text = _G[r:GetName().."Text"];
			if ( text ) then text:SetText(row.label); text:ClearAllPoints(); text:SetPoint("BOTTOMLEFT", r, "TOPLEFT", 0, 3); end
			r:SetScript("OnValueChanged", function(self, v)
				v = L.Snap(v, row.min, row.max, row.step);
				if ( not self.updating ) then SetCVar(row.cvar, tostring(v)); end
			end);
			r.Update = function(self)
				self.updating = true;
				self:SetValue(L.Snap(tonumber(GetCVarSafe(row.cvar)) or row.min, row.min, row.max, row.step));
				self.updating = false;
				if ( self.temucraftShowValue ) then self.temucraftShowValue(); end
			end;
			DecorateSlider(r);
			y = y - 64;
		elseif ( row.kind == "check" ) then
			r = CreateFrame("CheckButton", "TemucraftGlueOptionsCheck"..rowCount, f, "OptionsCheckButtonTemplate");
			r:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y);
			local text = _G[r:GetName().."Text"];
			if ( text ) then text:SetText(row.label); end
			r:SetScript("OnClick", function(self) SetCVar(row.cvar, self:GetChecked() and "1" or "0"); end);
			r.Update = function(self) self:SetChecked(GetCVarSafe(row.cvar) == "1"); end;
			y = y - 32;
		elseif ( row.kind == "reset" ) then
			r = CreateFrame("Button", "TemucraftGlueOptionsReset"..rowCount, f, "GlueButtonSmallTemplate");
			r:SetWidth(220); r:SetHeight(30);
			r:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y - 10);
			r:SetScript("OnClick", function() if ( OptionsSelectResetSettingsButton ) then OptionsSelectResetSettingsButton:Click(); end end);
			r.Update = function(self)
				self:SetText((OptionsSelectResetSettingsButton and OptionsSelectResetSettingsButton:GetText()) or row.label);
			end;
			y = y - 48;
		end
		if ( r ) then
			r.row = row;
			r:SetScript("OnEnter", function(self) Tooltip(self, row.tooltip and (row.label.."\n|cffffffff"..row.tooltip.."|r") or row.label); end);
			r:SetScript("OnLeave", HideTooltip);
			table.insert(f.rows, r);
		end
	end
	f.Update = function() for _, r in ipairs(f.rows) do r:Update(); end end;
	f:Hide();
	pageFrames[p.key] = f;
	return f;
end

local function DefaultPage(p)
	for _, row in ipairs(p.rows) do
		if ( row.cvar ) then
			local d = GetCVarDefault and GetCVarDefault(row.cvar);
			if ( d ) then SetCVar(row.cvar, d); end
		end
	end
	if ( pageFrames[p.key] ) then pageFrames[p.key].Update(); end
end

---------------------------------------------------------------------------------------------------------------------
-- Moving the stock panels in and out
---------------------------------------------------------------------------------------------------------------------
local function PutBack()
	for panel, info in pairs(moved) do
		panel:Hide();
		panel:SetParent(info.parent);
		panel:ClearAllPoints();
		panel:SetPoint("TOPLEFT", info.parent, "TOPLEFT");
		panel:SetPoint("BOTTOMRIGHT", info.parent, "BOTTOMRIGHT");
		if ( info.frame and info.frame.panelContainer ) then info.frame.panelContainer.displayedPanel = info.displayed; end
	end
	moved = {};
end

local function ShowEntry(e)
	if ( not e or e.kind ~= "page" ) then return; end
	if ( current and current.panel ) then current.panel:Hide(); end
	if ( current and current.page and pageFrames[current.page.key] ) then pageFrames[current.page.key]:Hide(); end
	current = e;
	if ( e.panel ) then
		local panel = e.panel;
		if ( not moved[panel] ) then
			moved[panel] = { parent = panel:GetParent(), frame = e.frame, displayed = e.frame and e.frame.panelContainer and e.frame.panelContainer.displayedPanel };
			panel:SetParent(W.container);
		end
		panel:ClearAllPoints();
		panel:SetPoint("TOPLEFT", W.container, "TOPLEFT");
		panel:SetPoint("BOTTOMRIGHT", W.container, "BOTTOMRIGHT");
		-- Defaults > Current Settings and the stock code ask the stock frame which panel is shown
		if ( e.frame and e.frame.panelContainer ) then e.frame.panelContainer.displayedPanel = panel; end
		panel:Show();
		DecoratePanel(panel);
		if ( panel == VideoOptionsResolutionPanel ) then FixRefresh(); end
	else
		local f = pageFrames[e.page.key] or BuildPage(e.page);
		f.Update();
		f:Show();
	end
	for _, b in ipairs(list.buttons) do
		if ( b.entry == e ) then b.selected:Show(); else b.selected:Hide(); end
	end
end

local function UpdateList()
	entries = L.List(VideoOptionsFrame and VideoOptionsFrame.categoryList, AudioOptionsFrame and AudioOptionsFrame.categoryList);
	local y = -8;
	for i, e in ipairs(entries) do
		local b = list.buttons[i];
		if ( not b ) then
			b = CreateFrame("Button", "TemucraftGlueOptionsListButton"..i, list);
			b:SetWidth(160); b:SetHeight(20);
			b.text = b:CreateFontString(nil, "OVERLAY", "GlueFontNormal");
			b.text:SetJustifyH("LEFT");
			b.selected = b:CreateTexture(nil, "BACKGROUND");
			b.selected:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight");
			b.selected:SetBlendMode("ADD");
			b.selected:SetAllPoints(b);
			b.selected:Hide();
			b.hl = b:CreateTexture(nil, "HIGHLIGHT");
			b.hl:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2");
			b.hl:SetBlendMode("ADD");
			b.hl:SetAlpha(0.4);
			b.hl:SetAllPoints(b);
			b:SetScript("OnClick", function(self) if ( self.entry and self.entry.kind == "page" ) then PlaySound("igMainMenuOptionCheckBoxOn"); ShowEntry(self.entry); end end);
			list.buttons[i] = b;
		end
		b.entry = e;
		b:ClearAllPoints();
		b:SetPoint("TOPLEFT", list, "TOPLEFT", 8, y);
		b.text:ClearAllPoints();
		if ( e.kind == "section" ) then
			b.text:SetFontObject(GlueFontHighlight);
			b.text:SetPoint("LEFT", b, "LEFT", 2, 0);
			b:EnableMouse(false);
			if ( i > 1 ) then y = y - 6; b:SetPoint("TOPLEFT", list, "TOPLEFT", 8, y); end
		else
			b.text:SetFontObject(GlueFontNormal);
			b.text:SetPoint("LEFT", b, "LEFT", 14, 0);
			b:EnableMouse(true);
		end
		b.text:SetText(e.text);
		b:Show();
		y = y - 22;
	end
	for i = #entries + 1, #list.buttons do list.buttons[i]:Hide(); list.buttons[i].entry = nil; end
end

---------------------------------------------------------------------------------------------------------------------
-- Okay / Apply / Cancel / Defaults
---------------------------------------------------------------------------------------------------------------------
local function SaveOurs()
	saved = {};
	for _, p in ipairs(L.PAGES) do
		for _, row in ipairs(p.rows) do if ( row.cvar ) then saved[row.cvar] = GetCVarSafe(row.cvar); end end
	end
end

local function RestartAlerts()
	for _, frame in ipairs({ VideoOptionsFrame, AudioOptionsFrame }) do
		if ( frame and frame.gameRestart ) then
			frame.gameRestart = nil;
			if ( GlueDialog_Show ) then GlueDialog_Show("CLIENT_RESTART_ALERT"); end
		end
	end
end

local function Close()
	HideTooltip();
	if ( current and current.page and pageFrames[current.page.key] ) then pageFrames[current.page.key]:Hide(); end
	PutBack();
	current = nil;
	W:Hide();
	PlaySound("gsTitleOptionExit");
	RestartAlerts();
end

local function Apply()
	if ( VideoOptionsFrameOkay_OnClick ) then VideoOptionsFrameOkay_OnClick(VideoOptionsFrameOkay, "LeftButton", true); end
	if ( AudioOptionsFrameOkay_OnClick ) then AudioOptionsFrameOkay_OnClick(AudioOptionsFrameOkay, "LeftButton", true); end
	if ( VideoOptionsFrame and OptionsFrame_RefreshCategories ) then pcall(OptionsFrame_RefreshCategories, VideoOptionsFrame); end
	if ( AudioOptionsFrame and OptionsFrame_RefreshCategories ) then pcall(OptionsFrame_RefreshCategories, AudioOptionsFrame); end
	SaveOurs();
	if ( current ) then ShowEntry(current); end
end

local function Okay()
	PlaySound("gsTitleOptionOK");
	Apply();
	Close();
end

local function Cancel()
	if ( VideoOptionsFrame and OptionsFrameCancel_OnClick ) then
		OptionsFrameCancel_OnClick(VideoOptionsFrame);
		VideoOptionsFrame.gxRestart, VideoOptionsFrame.gameRestart = nil, nil;
	end
	if ( AudioOptionsFrame and OptionsFrameCancel_OnClick ) then
		OptionsFrameCancel_OnClick(AudioOptionsFrame);
		if ( AudioOptionsFrame.audioRestart and AudioOptionsFrame_AudioRestart ) then AudioOptionsFrame_AudioRestart(); end
		AudioOptionsFrame.gameRestart = nil;
	end
	for cvar, v in pairs(saved) do
		if ( v ~= nil and GetCVarSafe(cvar) ~= v ) then SetCVar(cvar, v); end
	end
	Close();
end

local function Defaults()
	if ( not current ) then return; end
	if ( current.page ) then
		DefaultPage(current.page);
	elseif ( current.frame == VideoOptionsFrame ) then
		GlueDialog_Show("CONFIRM_RESET_VIDEO_SETTINGS");
	elseif ( current.frame == AudioOptionsFrame ) then
		GlueDialog_Show("CONFIRM_RESET_AUDIO_SETTINGS");
	end
end

local function Classic()
	Cancel();
	bypass = true;
	OptionsSelectFrame:Show();
	bypass = false;
end

---------------------------------------------------------------------------------------------------------------------
-- Building it
---------------------------------------------------------------------------------------------------------------------
local function Button(name, text, width, onClick)
	local b = CreateFrame("Button", name, W.box, "GlueButtonSmallTemplate");
	b:SetWidth(width); b:SetHeight(30);
	b:SetText(text);
	b:SetScript("OnClick", onClick);
	return b;
end

local function Build()
	W = CreateFrame("Frame", "TemucraftGlueOptionsFrame", GlueParent);
	W:SetAllPoints(GlueParent);
	W:SetFrameStrata("HIGH");
	W:SetToplevel(true);
	W:EnableMouse(true);
	W:EnableKeyboard(true);
	local shade = W:CreateTexture(nil, "BACKGROUND");
	shade:SetAllPoints(W);
	shade:SetTexture(0, 0, 0, 0.6);
	W.box = CreateFrame("Frame", "TemucraftGlueOptionsBox", W);
	W.box:SetWidth(700); W.box:SetHeight(590);
	W.box:SetPoint("CENTER", W, "CENTER", 0, 0);
	W.box:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
		tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } });
	W.box:SetBackdropColor(1, 1, 1, 0.97);
	local title = W.box:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
	title:SetPoint("TOP", W.box, "TOP", 0, -16);
	title:SetText(OPTIONS or "Options");
	-- the page list
	list = CreateFrame("Frame", "TemucraftGlueOptionsList", W.box);
	list:SetPoint("TOPLEFT", W.box, "TOPLEFT", 18, -44);
	list:SetPoint("BOTTOMLEFT", W.box, "BOTTOMLEFT", 18, 58);
	list:SetWidth(178);
	list:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	list:SetBackdropColor(0, 0, 0, 0.55);
	list:SetBackdropBorderColor(0.6, 0.6, 0.6, 1);
	list.buttons = {};
	-- the page (the stock panels were made for 413 x 429-449)
	W.container = CreateFrame("Frame", "TemucraftGlueOptionsContainer", W.box);
	W.container:SetPoint("TOPLEFT", list, "TOPRIGHT", 10, 0);
	W.container:SetPoint("BOTTOMRIGHT", W.box, "BOTTOMRIGHT", -18, 58);
	W.container:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	W.container:SetBackdropColor(0, 0, 0, 0.35);
	W.container:SetBackdropBorderColor(0.6, 0.6, 0.6, 1);
	-- bottom row
	W.defaults = Button("TemucraftGlueOptionsDefaults", DEFAULTS or "Defaults", 110, Defaults);
	W.defaults:SetPoint("BOTTOMLEFT", W.box, "BOTTOMLEFT", 18, 18);
	W.classic = Button("TemucraftGlueOptionsClassic", "Classic", 90, Classic);
	W.classic:SetPoint("LEFT", W.defaults, "RIGHT", 6, 0);
	W.classic:SetScript("OnEnter", function(self) Tooltip(self, "The stock Video and Sound windows"); end);
	W.classic:SetScript("OnLeave", HideTooltip);
	W.okay = Button("TemucraftGlueOptionsOkay", OKAY or "Okay", 100, Okay);
	W.okay:SetPoint("BOTTOMRIGHT", W.box, "BOTTOMRIGHT", -18, 18);
	W.cancel = Button("TemucraftGlueOptionsCancel", CANCEL or "Cancel", 100, function() PlaySound("gsTitleOptionExit"); Cancel(); end);
	W.cancel:SetPoint("RIGHT", W.okay, "LEFT", -6, 0);
	W.apply = Button("TemucraftGlueOptionsApply", APPLY or "Apply", 100, function() PlaySound("igMainMenuOptionCheckBoxOn"); Apply(); end);
	W.apply:SetPoint("RIGHT", W.cancel, "LEFT", -6, 0);
	W:SetScript("OnKeyDown", function(self, key)
		if ( key == "ESCAPE" ) then Cancel();
		elseif ( key == "ENTER" ) then Okay();
		elseif ( key == "PRINTSCREEN" and Screenshot ) then Screenshot(); end
	end);
	W:Hide();
end

function TemucraftGlueOptions_Open(which)
	if ( not W ) then Build(); end
	for _, f in ipairs({ OptionsSelectFrame, VideoOptionsFrame, AudioOptionsFrame }) do
		if ( f and f:IsShown() ) then f:Hide(); end
	end
	if ( VideoOptionsFrame and OptionsFrame_RefreshCategories ) then pcall(OptionsFrame_RefreshCategories, VideoOptionsFrame); end
	if ( AudioOptionsFrame and OptionsFrame_RefreshCategories ) then pcall(OptionsFrame_RefreshCategories, AudioOptionsFrame); end
	SaveOurs();
	UpdateList();
	W:Show();
	local first, wanted;
	for _, e in ipairs(entries) do
		if ( e.kind == "page" ) then
			first = first or e;
			if ( which and (e.text == which or (e.page and e.page.key == which)) ) then wanted = wanted or e; end
		end
	end
	ShowEntry(wanted or first);
	PlaySound("gsTitleOptions");
end

function TemucraftGlueOptions_Close() if ( W and W:IsShown() ) then Cancel(); end end
function TemucraftGlueOptions_IsShown() return W and W:IsShown() or false; end

-- Every way to the stock chooser (the login screen's Options, Menu > Options on character select) opens ours instead;
-- if ours fails, the chooser stays
local function OnChooserShow(self)
	if ( bypass or not Active() ) then return; end
	self:Hide();
	local ok, err = pcall(TemucraftGlueOptions_Open);
	if ( not ok ) then
		if ( W ) then pcall(PutBack); W:Hide(); end
		bypass = true;
		self:Show();
		bypass = false;
	end
end
if ( OptionsSelectFrame.HookScript ) then
	OptionsSelectFrame:HookScript("OnShow", OnChooserShow);
else
	local old = OptionsSelectFrame:GetScript("OnShow");
	OptionsSelectFrame:SetScript("OnShow", function(...) if ( old ) then old(...); end OnChooserShow(...); end);
end
