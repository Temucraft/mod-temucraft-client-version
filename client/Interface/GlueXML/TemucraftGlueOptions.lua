--[[
	Temucraft Options on the login and character screens: one window in place of the stock chooser (Options: Video /
	Sound / Reset User Options / Close) and its two separate windows. Menu > Options (and the login screen's Options)
	opens it straight away.

	Left: two pages, Graphics and Audio. Right: the page, one scrolling list with section headers like retail's:
	  Graphics: Display (resolution, refresh rate, multisampling, window mode, vsync ..., brightness), Quality (the
	            video quality preset and every detail slider), Effects (specular, glow, death effect, projected
	            textures), Frame Rate (max FPS, max background FPS).
	  Audio:    Volume (master, sound, music, ambience), Playback (every sound check), Output (device, channels,
	            hardware, quality), Other (Hear From the Character, Zone Music Without Delay).
	Bottom: Defaults (this page, with the stock confirm: All Settings / Current Settings), Reset User Options (the stock
	button and its confirm), Classic (the stock chooser), Apply, Cancel, Okay.

	The stock controls are the stock panels' own (VideoOptions*Panel, AudioOptionsSoundPanel): the panels are moved
	into the page while the window is open and their controls laid out in the list; on close every anchor, size and
	shown state is put back, so the classic windows look as before. Every CVar, check, restart and dependent control
	works as before; Okay / Apply / Cancel run the stock frames' own okay / cancel code (VideoOptionsFrameOkay_OnClick
	with apply, OptionsFrameCancel_OnClick ...), RestartGx and the restart alerts included. Our rows (Frame Rate, Other)
	set CVars that 3.3.5 has but the stock glue hides, the same rows as in the in-game Options window
	(TemucraftOptions.lua); Cancel puts them back.

	Every slider: its name on the left and its value on the right on one line above the bar (the value is a box you can
	type in: Enter applies, clamped and snapped to the step), the real minimum and maximum under the bar's ends (0% /
	100% for 0-1 sliders). Multisampling shows plain choices (None, 2x, 4x, 8x; the colour / depth format in the
	tooltip, and in the name only when two formats have the same multisampling). The Refresh Rate menu is empty in
	windowed mode (the client has no rates then): it says so instead.

	Classic opens the stock chooser and keeps it: the choice is saved in the CVar temucraftOptionsStyle ("classic" /
	"new"), which the in-game interface registers (glue code can't make CVars), so it lasts from the first login on;
	until then it lasts while the game runs. The classic windows (chooser, Video, Sound) get a "Use the new Options
	window" button that switches back. If the window fails to open, the stock chooser opens; TEMUCRAFT_GLUE_OPTIONS =
	"classic" in Interface\TemucraftScenes.lua always uses the stock one.
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
		return tostring(math.floor(value * 100 + 0.5)).."%";
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

-- Multisampling choices from GetMultisampleFormats() (colour bits, depth bits, samples, ...): { text, full } each.
-- "None" / "2x" / "4x" / "8x"; the format only in the name when two formats share the samples.
function L.MultisampleChoices(...)
	local out, count = {}, {};
	for i = 1, select("#", ...), 3 do
		local color, depth, ms = select(i, ...);
		ms = tonumber(ms) or 1;
		local text = (ms <= 1) and (NONE or "None") or (ms.."x");
		local full = MULTISAMPLING_FORMAT_STRING and string.format(MULTISAMPLING_FORMAT_STRING, color or 0, depth or 0, ms)
			or string.format("%d-bit color %d-bit depth %dx multisample", color or 0, depth or 0, ms);
		table.insert(out, { text = text, full = full, color = color, depth = depth, ms = ms });
		count[text] = (count[text] or 0) + 1;
	end
	for _, c in ipairs(out) do
		if ( count[c.text] > 1 ) then c.text = c.text.." ("..tostring(c.color).."/"..tostring(c.depth).."-bit)"; end
	end
	return out;
end

-- The window's style: "classic" (the stock chooser) or "new". Saved in a CVar the in-game interface registers.
L.STYLE_CVAR = "temucraftOptionsStyle";
local sessionStyle;
function L.GetStyle()
	if ( GetCVar ) then
		local ok, v = pcall(GetCVar, L.STYLE_CVAR);
		if ( ok and (v == "classic" or v == "new") ) then return v; end
	end
	return sessionStyle or "new";
end
function L.SetStyle(style)
	sessionStyle = style;
	if ( SetCVar ) then pcall(SetCVar, L.STYLE_CVAR, style); end
end

-- [[ the pages: stock controls by name, our rows as tables (the in-game window has the same rows) ]] --
local R, E, S = "VideoOptionsResolutionPanel", "VideoOptionsEffectsPanel", "AudioOptionsSoundPanel";
L.PAGES = {
	{ key = "graphics", title = "Graphics", frame = "VideoOptionsFrame", panels = { R, E },
	  hide = { R.."Title", R.."SubText", R.."Brightness", E.."Title", E.."SubText", E.."Shaders" },
	  sections = {
		{ title = "Display", rows = {
			{ kind = "drops", R.."ResolutionDropDown", R.."RefreshDropDown", R.."MultiSampleDropDown" },
			{ kind = "checks", R.."Windowed", R.."Maximized", R.."DisableResize", R.."VSync", R.."TripleBuffer",
				R.."HardwareCursor", R.."FixInputLag", R.."DesktopGamma" },
			{ kind = "sliders", R.."GammaSlider" },
		} },
		{ title = "Quality", rows = {
			{ kind = "box", box = E.."Quality", slider = E.."QualitySlider" },
			{ kind = "sliders", E.."ViewDistance", E.."EnvironmentDetail", E.."TerrainDetail", E.."ClutterDensity",
				E.."ParticleDensity", E.."ClutterRadius", E.."ShadowQuality", E.."TextureResolution",
				E.."TextureFiltering", E.."WeatherIntensity", E.."PlayerTexture" },
		} },
		{ title = "Effects", rows = {
			{ kind = "checks", E.."SpecularLighting", E.."DeathEffect", E.."FullScreenGlow", E.."ProjectedTextures" },
		} },
		{ title = "Frame Rate", rows = {
			{ kind = "sliders",
				{ kind = "slider", cvar = "maxFPS", label = "Max Frame Rate", min = 0, max = 200, step = 5, tooltip = "Frames per second at most (0 = no limit)." },
				{ kind = "slider", cvar = "maxFPSBk", label = "Max Background Frame Rate", min = 0, max = 200, step = 5, tooltip = "Frames per second at most while the game is in the background (0 = no limit)." },
			},
		} },
		{ title = "Character Screens", rows = {
			{ kind = "checks",
				-- saved in the saved account list (TemucraftGlueSetting_Set, TemucraftCharSelect.lua): the glue screens
				-- can't register a CVar of their own
				{ kind = "check", label = "Classic race portraits", tooltip = "Character create shows the old race icons instead of the sharp retail portraits.",
				  get = function() return TemucraftRacePortraits_IsClassic and TemucraftRacePortraits_IsClassic(); end,
				  set = function(on) if ( TemucraftRacePortraits_SetClassic ) then TemucraftRacePortraits_SetClassic(on); end end },
			},
		} },
	} },
	{ key = "audio", title = "Audio", frame = "AudioOptionsFrame", panels = { S },
	  hide = { S.."Title", S.."SubText", S.."Playback", S.."Hardware", S.."Volume" },
	  sections = {
		{ title = "Volume", rows = {
			{ kind = "sliders", S.."MasterVolume", S.."SoundVolume", S.."MusicVolume", S.."AmbienceVolume" },
		} },
		{ title = "Playback", rows = {
			{ kind = "checks", S.."EnableSound", S.."SoundEffects", S.."ErrorSpeech", S.."EmoteSounds", S.."PetSounds",
				S.."Music", S.."LoopMusic", S.."AmbientSounds", S.."SoundInBG", S.."Reverb", S.."HRTF", S.."EnableDSPs" },
		} },
		{ title = "Output", rows = {
			{ kind = "drops", S.."HardwareDropDown" },
			{ kind = "sliders", S.."SoundChannels", S.."SoundQuality" },
			{ kind = "checks", S.."UseHardware" },
		} },
		{ title = "Other", rows = {
			{ kind = "checks",
				{ kind = "check", cvar = "Sound_ListenerAtCharacter", label = "Hear From the Character", tooltip = "Sounds are heard from where your character stands, not from the camera." },
				{ kind = "check", cvar = "Sound_ZoneMusicNoDelay", label = "Zone Music Without Delay", tooltip = "A zone's music starts again at once instead of after a pause." },
			},
		} },
	} },
};

-- our rows of a page (or of every page)
function L.OurRows(page)
	local out = {};
	for _, p in ipairs(page and { page } or L.PAGES) do
		for _, sec in ipairs(p.sections) do
			for _, row in ipairs(sec.rows) do
				for _, item in ipairs(row) do if ( type(item) == "table" and item.cvar ) then table.insert(out, item); end end
			end
		end
	end
	return out;
end

-- The list: one entry per page
function L.List()
	local out = {};
	for _, p in ipairs(L.PAGES) do table.insert(out, { kind = "page", text = p.title, page = p }); end
	return out;
end

-- Two columns: { x, y, w, h } of each item of a row, from y on; returns the cells and the y under the row
L.COL_W, L.COL_GAP, L.PAD = 236, 16, 10;
L.ROW_H = { checks = 26, sliders = 50, drops = 54 };
function L.Cells(kind, n, y)
	local cells, h = {}, L.ROW_H[kind] or 26;
	for i = 1, n do
		local col, line = (i - 1) % 2, math.floor((i - 1) / 2);
		table.insert(cells, { x = L.PAD + col * (L.COL_W + L.COL_GAP), y = y + line * h, w = L.COL_W, h = h });
	end
	return cells, y + math.ceil(n / 2) * h;
end

-- Which items are wholly inside the view (the rest is hidden, so it can't take clicks outside the scroll frame)
function L.Inside(top, h, offset, view)
	return top >= offset - 2 and top + h <= offset + view + 2;
end

---------------------------------------------------------------------------------------------------------------------
-- The window (only in the client)
---------------------------------------------------------------------------------------------------------------------
if ( not CreateFrame or not GlueParent or not OptionsSelectFrame ) then
	return;
end

local W, list, entries, current, bypass;
local moved = {};          -- [panel] = { parent =, frame =, displayed = the stock frame's displayed panel before }
local kept = {};           -- [stock object] = { points, w, justify, shown } as they were (put back on close)
local decorated = {};      -- [slider] = its value box
local saved = {};          -- our CVars as they were when the window opened (Cancel puts them back)
local pages = {};          -- [key] = { scroll, child, bar, cells, ours }

local function Active()
	return TEMUCRAFT_GLUE_OPTIONS ~= "classic" and L.GetStyle() ~= "classic";
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

-- remember a stock object as it is (once per opening)
local function Keep(obj)
	if ( not obj or kept[obj] ) then return; end
	local k = { points = {}, shown = obj:IsShown() and true or false };
	for i = 1, (obj.GetNumPoints and obj:GetNumPoints() or 0) do
		local p, rel, rp, x, y = obj:GetPoint(i);
		table.insert(k.points, { p, rel, rp, x, y });
	end
	kept[obj] = k;
end
local function SetW(obj, w)
	Keep(obj);
	if ( kept[obj].w == nil ) then kept[obj].w = obj:GetWidth() or 0; end
	obj:SetWidth(w);
end
local function SetJustify(fs, j)
	Keep(fs);
	if ( kept[fs].justify == nil and fs.GetJustifyH ) then kept[fs].justify = fs:GetJustifyH() or false; end
	fs:SetJustifyH(j);
end
local function Restore()
	for obj, k in pairs(kept) do
		if ( #k.points > 0 ) then
			obj:ClearAllPoints();
			for _, p in ipairs(k.points) do obj:SetPoint(p[1], p[2] or obj:GetParent(), p[3], p[4], p[5]); end
		end
		if ( k.w ) then obj:SetWidth(k.w); end
		if ( k.justify ) then obj:SetJustifyH(k.justify); end
		if ( k.shown ) then obj:Show(); else obj:Hide(); end
	end
	kept = {};
end
local function Wanted(obj) return not kept[obj] or kept[obj].shown; end

-- a slider's value box (stock sliders and ours); fmt: see L.Format
local valueCount = 0;
local function DecorateSlider(s, fmt)
	if ( decorated[s] or not s.GetMinMaxValues ) then return decorated[s]; end
	local name = s:GetName();
	local low, high = name and _G[name.."Low"], name and _G[name.."High"];
	valueCount = valueCount + 1;
	local box = CreateFrame("EditBox", "TemucraftGlueOptionsValue"..valueCount, s);
	decorated[s] = box;
	box:SetWidth(54); box:SetHeight(16);
	box:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 2);
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
	box:Hide();   -- only in our window (the classic windows' sliders are too narrow for it)
	Show();
	return box;
end

local function FixRefresh()
	local dd = VideoOptionsResolutionPanelRefreshDropDown;
	if ( not dd or not GetRefreshRates or not GlueDropDownMenu_SetText ) then return; end
	local text = L.RefreshText(GetCVarSafe("gxRefresh"), GetRefreshRates());
	GlueDropDownMenu_SetText(text, dd);
end

-- Multisampling: plain choices (the stock menu's own buttons and click, only the names change)
if ( VideoOptionsResolutionPanel_GetMultisampleFormats and GlueDropDownMenu_CreateInfo ) then
	VideoOptionsResolutionPanel_GetMultisampleFormats = function(...)
		local dd = VideoOptionsResolutionPanelMultiSampleDropDown;
		local info = GlueDropDownMenu_CreateInfo();
		for index, c in ipairs(L.MultisampleChoices(...)) do
			info.text = c.text;
			info.tooltipTitle = c.text;
			info.tooltipText = c.full;
			info.func = VideoOptionsResolutionPanelMultiSampleDropDown_OnClick;
			if ( index == GlueDropDownMenu_GetSelectedID(dd) ) then
				info.checked = 1;
				GlueDropDownMenu_SetText(c.text, dd);
			else
				info.checked = nil;
			end
			GlueDropDownMenu_AddButton(info);
		end
	end
	if ( VideoOptionsResolutionPanelMultiSampleDropDown and VideoOptionsResolutionPanelMultiSampleDropDown_Initialize and GlueDropDownMenu_Initialize ) then
		pcall(GlueDropDownMenu_Initialize, VideoOptionsResolutionPanelMultiSampleDropDown, VideoOptionsResolutionPanelMultiSampleDropDown_Initialize);
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Our rows
---------------------------------------------------------------------------------------------------------------------
local rowCount = 0;
local function OurControl(item, parent)
	rowCount = rowCount + 1;
	local r;
	if ( item.kind == "slider" ) then
		r = CreateFrame("Slider", "TemucraftGlueOptionsSlider"..rowCount, parent, "OptionsSliderTemplate");
		r:SetHeight(17);
		r:SetMinMaxValues(item.min, item.max);
		r:SetValueStep(item.step);
		local text = _G[r:GetName().."Text"];
		if ( text ) then text:SetText(item.label); end
		r:SetScript("OnValueChanged", function(self, v)
			v = L.Snap(v, item.min, item.max, item.step);
			if ( not self.updating ) then SetCVar(item.cvar, tostring(v)); end
		end);
		r.Update = function(self)
			self.updating = true;
			self:SetValue(L.Snap(tonumber(GetCVarSafe(item.cvar)) or item.min, item.min, item.max, item.step));
			self.updating = false;
			if ( self.temucraftShowValue ) then self.temucraftShowValue(); end
		end;
		DecorateSlider(r);
	else
		r = CreateFrame("CheckButton", "TemucraftGlueOptionsCheck"..rowCount, parent, "OptionsCheckButtonTemplate");
		local text = _G[r:GetName().."Text"];
		if ( text ) then text:SetText(item.label); end
		-- a CVar, or (item.get / item.set) a setting kept elsewhere
		r:SetScript("OnClick", function(self)
			if ( item.set ) then item.set(self:GetChecked() and true or false); else SetCVar(item.cvar, self:GetChecked() and "1" or "0"); end
		end);
		r.Update = function(self)
			if ( item.get ) then self:SetChecked(item.get() and true or false); else self:SetChecked(GetCVarSafe(item.cvar) == "1"); end
		end;
	end
	r.item = item;
	r:SetScript("OnEnter", function(self) Tooltip(self, item.tooltip and (item.label.."\n|cffffffff"..item.tooltip.."|r") or item.label); end);
	r:SetScript("OnLeave", HideTooltip);
	return r;
end

local function DefaultOurs(page)
	for _, item in ipairs(L.OurRows(page)) do
		local d = GetCVarDefault and GetCVarDefault(item.cvar);
		if ( d ) then SetCVar(item.cvar, d); end
	end
	local pg = page and pages[page.key];
	if ( pg ) then for _, c in ipairs(pg.ours) do c:Update(); end end
end

---------------------------------------------------------------------------------------------------------------------
-- A page: a scroll frame with the stock panels' controls laid out in sections
---------------------------------------------------------------------------------------------------------------------
local VIEW_INSET = 6;
local function UpdateVisible(pg)
	local offset = pg.scroll:GetVerticalScroll() or 0;
	local view = pg.scroll:GetHeight() or 0;
	for _, cell in ipairs(pg.cells) do
		local inside = L.Inside(cell.y, cell.h, offset, view);
		for _, obj in ipairs(cell.objs) do
			if ( inside and Wanted(obj) ) then obj:Show(); else obj:Hide(); end
		end
	end
end

local function BuildPage(p)
	local pg = { page = p, ours = {}, headers = {}, cells = {} };
	local scroll = CreateFrame("ScrollFrame", "TemucraftGlueOptionsScroll"..p.key, W.container);
	scroll:SetPoint("TOPLEFT", W.container, "TOPLEFT", VIEW_INSET, -VIEW_INSET);
	scroll:SetPoint("BOTTOMRIGHT", W.container, "BOTTOMRIGHT", -24, VIEW_INSET);
	local child = CreateFrame("Frame", "TemucraftGlueOptionsChild"..p.key, scroll);
	child:SetWidth(2 * L.COL_W + L.COL_GAP + 2 * L.PAD);
	child:SetHeight(10);
	scroll:SetScrollChild(child);
	local bar = CreateFrame("Slider", "TemucraftGlueOptionsScrollBar"..p.key, W.container);
	bar:SetOrientation("VERTICAL");
	bar:SetWidth(16);
	bar:SetPoint("TOPRIGHT", W.container, "TOPRIGHT", -6, -10);
	bar:SetPoint("BOTTOMRIGHT", W.container, "BOTTOMRIGHT", -6, 10);
	bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob");
	local thumb = bar.GetThumbTexture and bar:GetThumbTexture();
	if ( thumb ) then thumb:SetWidth(18); thumb:SetHeight(24); thumb:SetTexCoord(0.2, 0.8, 0.125, 0.875); end
	local track = bar:CreateTexture(nil, "BACKGROUND");
	track:SetTexture(0, 0, 0, 0.4);
	track:SetAllPoints(bar);
	bar:SetMinMaxValues(0, 0);
	bar:SetValueStep(1);
	bar:SetScript("OnValueChanged", function(self, v) scroll:SetVerticalScroll(v); UpdateVisible(pg); end);
	scroll:EnableMouseWheel(true);
	scroll:SetScript("OnMouseWheel", function(self, delta) bar:SetValue(bar:GetValue() - delta * 40); end);
	pg.scroll, pg.child, pg.bar = scroll, child, bar;
	for si, sec in ipairs(p.sections) do
		local h = child:CreateFontString(nil, "OVERLAY", "GlueFontNormal");
		h:SetText(sec.title);
		h:SetJustifyH("LEFT");
		local line = child:CreateTexture(nil, "ARTWORK");
		line:SetTexture(1, 0.82, 0, 0.35);
		line:SetHeight(1);
		line:SetPoint("LEFT", h, "RIGHT", 8, 0);
		line:SetPoint("RIGHT", child, "RIGHT", -L.PAD, 0);
		pg.headers[si] = { text = h, line = line };
		for _, row in ipairs(sec.rows) do
			for _, item in ipairs(row) do
				if ( type(item) == "table" ) then
					local c = OurControl(item, child);
					row[item] = c;
					table.insert(pg.ours, c);
				end
			end
		end
	end
	scroll:Hide(); bar:Hide();
	pages[p.key] = pg;
	return pg;
end

local function Place(obj, pg, x, y)
	Keep(obj);
	obj:ClearAllPoints();
	obj:SetPoint("TOPLEFT", pg.child, "TOPLEFT", x, -y);
end

-- every slider: name left and value right on one line above the bar, min / max under its ends
local function LaySlider(s, pg, cell)
	Place(s, pg, cell.x + 4, cell.y + 20);
	SetW(s, cell.w - 8);
	local name = s:GetName();
	local text, label = _G[name.."Text"], _G[name.."Label"];
	local low, high = _G[name.."Low"], _G[name.."High"];
	-- the name: the slider's Text, or its Label where the stock hides the Text (Sound / Music / Ambience);
	-- Master Volume's Label is a second value ("50%"): hidden
	local title = text;
	if ( label and (not text or not text:IsShown() or (text:GetText() or "") == "") ) then title = label; end
	if ( label and title ~= label ) then Keep(label); label:Hide(); end
	if ( title ) then
		Keep(title);
		title:ClearAllPoints();
		title:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4);
		SetW(title, cell.w - 70);
		SetJustify(title, "LEFT");
		title:Show();
	end
	for i, fs in ipairs({ low, high }) do
		Keep(fs);
		fs:ClearAllPoints();
		if ( i == 1 ) then fs:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, 1); else fs:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, 1); end
		fs:Show();
	end
	local box = DecorateSlider(s);
	if ( box ) then
		box:ClearAllPoints();
		box:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 2);
		box:Show();
		if ( s.temucraftShowValue ) then s.temucraftShowValue(); end
	end
end

local function Layout(pg)
	local p = pg.page;
	local frame = _G[p.frame];
	for _, pname in ipairs(p.panels) do
		local panel = _G[pname];
		if ( panel ) then
			if ( not moved[panel] ) then
				moved[panel] = { parent = panel:GetParent(), frame = frame, shown = panel:IsShown() and true or false,
					displayed = frame and frame.panelContainer and frame.panelContainer.displayedPanel };
			end
			panel:SetParent(pg.child);
			panel:ClearAllPoints();
			panel:SetAllPoints(pg.child);
			panel:Show();
		end
	end
	-- Defaults > Current Settings and the stock code ask the stock frame which panel is shown
	if ( frame and frame.panelContainer and _G[p.panels[1]] ) then frame.panelContainer.displayedPanel = _G[p.panels[1]]; end
	for _, n in ipairs(p.hide) do local o = _G[n]; if ( o ) then Keep(o); o:Hide(); end end
	pg.cells = {};
	local y = 8;
	for si, sec in ipairs(p.sections) do
		local hd = pg.headers[si];
		hd.text:ClearAllPoints();
		hd.text:SetPoint("TOPLEFT", pg.child, "TOPLEFT", L.PAD - 2, -y);
		table.insert(pg.cells, { y = y, h = 20, objs = { hd.text, hd.line } });
		y = y + 30;
		for _, row in ipairs(sec.rows) do
			if ( row.kind == "box" ) then
				local box, slider = _G[row.box], _G[row.slider];
				if ( box ) then
					local w = 2 * L.COL_W + L.COL_GAP;
					Place(box, pg, L.PAD, y);
					SetW(box, w);
					if ( slider ) then Keep(slider); SetW(slider, w - 32); end
					table.insert(pg.cells, { y = y, h = box:GetHeight() or 88, objs = { box, slider } });
					y = y + (box:GetHeight() or 88) + 14;
				end
			else
				local objs = {};
				for _, item in ipairs(row) do
					local o = (type(item) == "table") and row[item] or _G[item];
					if ( o ) then table.insert(objs, o); end
				end
				local cells;
				cells, y = L.Cells(row.kind, #objs, y);
				for i, o in ipairs(objs) do
					local cell = cells[i];
					if ( row.kind == "checks" ) then
						Place(o, pg, cell.x, cell.y);
					elseif ( row.kind == "drops" ) then
						Place(o, pg, cell.x - 16, cell.y + 16);   -- the menu's label sits above it; its art has a 16 px edge
					else
						LaySlider(o, pg, cell);
					end
					if ( o.Update and o.item ) then o:Update(); end
					table.insert(pg.cells, { y = cell.y, h = cell.h, objs = { o } });
				end
				y = y + 6;
			end
		end
		y = y + 8;
	end
	pg.child:SetHeight(y);
	local view = pg.scroll:GetHeight() or 0;
	local range = math.max(0, y - view);
	pg.bar:SetMinMaxValues(0, range);
	if ( pg.bar:GetValue() > range ) then pg.bar:SetValue(range); end
	if ( range > 0 ) then pg.bar:Show(); else pg.bar:Hide(); end
	pg.scroll:SetVerticalScroll(pg.bar:GetValue() or 0);
	UpdateVisible(pg);
	if ( p.key == "graphics" ) then
		if ( VideoOptionsResolutionPanelMultiSampleDropDown and VideoOptionsResolutionPanelMultiSampleDropDown_Initialize and GlueDropDownMenu_Initialize ) then
			pcall(GlueDropDownMenu_Initialize, VideoOptionsResolutionPanelMultiSampleDropDown, VideoOptionsResolutionPanelMultiSampleDropDown_Initialize);
		end
		FixRefresh();
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Moving the stock panels in and out
---------------------------------------------------------------------------------------------------------------------
local function PutBack()
	Restore();
	for _, box in pairs(decorated) do box:ClearFocus(); box:Hide(); end
	for panel, info in pairs(moved) do
		panel:Hide();
		panel:SetParent(info.parent);
		panel:ClearAllPoints();
		panel:SetPoint("TOPLEFT", info.parent, "TOPLEFT");
		panel:SetPoint("BOTTOMRIGHT", info.parent, "BOTTOMRIGHT");
		if ( info.shown ) then panel:Show(); end   -- the classic window's shown page stays shown
		if ( info.frame and info.frame.panelContainer ) then info.frame.panelContainer.displayedPanel = info.displayed; end
	end
	moved = {};
	for _, pg in pairs(pages) do pg.scroll:Hide(); pg.bar:Hide(); end
end

local function ShowEntry(e)
	if ( not e or e.kind ~= "page" ) then return; end
	if ( current and pages[current.page.key] and current ~= e ) then
		local old = pages[current.page.key];
		old.scroll:Hide(); old.bar:Hide();
	end
	current = e;
	local pg = pages[e.page.key] or BuildPage(e.page);
	pg.scroll:Show();
	Layout(pg);
	for _, b in ipairs(list.buttons) do
		if ( b.entry == e ) then b.selected:Show(); else b.selected:Hide(); end
	end
end

local function UpdateList()
	entries = L.List();
	local y = -10;
	for i, e in ipairs(entries) do
		local b = list.buttons[i];
		if ( not b ) then
			b = CreateFrame("Button", "TemucraftGlueOptionsListButton"..i, list);
			b:SetWidth(160); b:SetHeight(24);
			b.text = b:CreateFontString(nil, "OVERLAY", "GlueFontNormal");
			b.text:SetJustifyH("LEFT");
			b.text:SetPoint("LEFT", b, "LEFT", 10, 0);
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
			b:SetScript("OnClick", function(self) if ( self.entry ) then PlaySound("igMainMenuOptionCheckBoxOn"); ShowEntry(self.entry); end end);
			list.buttons[i] = b;
		end
		b.entry = e;
		b:ClearAllPoints();
		b:SetPoint("TOPLEFT", list, "TOPLEFT", 8, y);
		b.text:SetText(e.text);
		b:Show();
		y = y - 26;
	end
	for i = #entries + 1, #list.buttons do list.buttons[i]:Hide(); list.buttons[i].entry = nil; end
end

---------------------------------------------------------------------------------------------------------------------
-- Okay / Apply / Cancel / Defaults
---------------------------------------------------------------------------------------------------------------------
local function SaveOurs()
	saved = {};
	for _, item in ipairs(L.OurRows()) do saved[item.cvar] = GetCVarSafe(item.cvar); end
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

-- Defaults: the stock confirm of the page's frame (All Settings / Current Settings). A page is all of its frame's
-- panels, so both answers reset the whole page here, our rows included.
local function Defaults()
	if ( not current ) then return; end
	local p = current.page;
	if ( p.frame == "VideoOptionsFrame" and VideoOptionsFrame ) then
		GlueDialog_Show("CONFIRM_RESET_VIDEO_SETTINGS");
	elseif ( p.frame == "AudioOptionsFrame" and AudioOptionsFrame ) then
		GlueDialog_Show("CONFIRM_RESET_AUDIO_SETTINGS");
	else
		DefaultOurs(p);
	end
end
local function WrapDefaults(allName, curName, key)
	local all, cur = _G[allName], _G[curName];
	if ( not all ) then return; end
	local function Page() for _, p in ipairs(L.PAGES) do if ( p.key == key ) then return p; end end end
	_G[allName] = function(...)
		all(...);
		if ( W and W:IsShown() ) then DefaultOurs(Page()); if ( current ) then ShowEntry(current); end end
	end
	_G[curName] = function(...)
		if ( W and W:IsShown() ) then
			all(...);
			DefaultOurs(Page());
			if ( current ) then ShowEntry(current); end
		elseif ( cur ) then
			cur(...);
		end
	end
end
WrapDefaults("VideoOptionsFrame_SetAllToDefaults", "VideoOptionsFrame_SetCurrentToDefaults", "graphics");
WrapDefaults("AudioOptionsFrame_SetAllToDefaults", "AudioOptionsFrame_SetCurrentToDefaults", "audio");

-- Reset User Options: the stock chooser's button (its confirm; it turns into "Cancel Reset" after)
local function ResetText()
	return (OptionsSelectResetSettingsButton and OptionsSelectResetSettingsButton:GetText()) or RESET_SETTINGS or "Reset User Options";
end
local function Reset()
	if ( OptionsSelectResetSettingsButton ) then OptionsSelectResetSettingsButton:Click(); end
end

local function Classic()
	L.SetStyle("classic");
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
	W.box:SetWidth(760); W.box:SetHeight(600);
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
	-- the page
	W.container = CreateFrame("Frame", "TemucraftGlueOptionsContainer", W.box);
	W.container:SetPoint("TOPLEFT", list, "TOPRIGHT", 10, 0);
	W.container:SetPoint("BOTTOMRIGHT", W.box, "BOTTOMRIGHT", -18, 58);
	W.container:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	W.container:SetBackdropColor(0, 0, 0, 0.35);
	W.container:SetBackdropBorderColor(0.6, 0.6, 0.6, 1);
	-- bottom row
	W.defaults = Button("TemucraftGlueOptionsDefaults", DEFAULTS or "Defaults", 100, Defaults);
	W.defaults:SetPoint("BOTTOMLEFT", W.box, "BOTTOMLEFT", 18, 18);
	W.reset = Button("TemucraftGlueOptionsReset", ResetText(), 160, Reset);
	W.reset:SetPoint("LEFT", W.defaults, "RIGHT", 6, 0);
	W.reset:SetScript("OnEnter", function(self) Tooltip(self, ResetText().."\n|cffffffffPuts every setting of the game back to its default (asks first; done at the next start).|r"); end);
	W.reset:SetScript("OnLeave", HideTooltip);
	W.classic = Button("TemucraftGlueOptionsClassic", "Classic", 90, Classic);
	W.classic:SetPoint("LEFT", W.reset, "RIGHT", 6, 0);
	W.classic:SetScript("OnEnter", function(self) Tooltip(self, "Classic\n|cffffffffThe stock Video and Sound windows (kept until you pick \"Use the new Options window\" there).|r"); end);
	W.classic:SetScript("OnLeave", HideTooltip);
	W.okay = Button("TemucraftGlueOptionsOkay", OKAY or "Okay", 96, Okay);
	W.okay:SetPoint("BOTTOMRIGHT", W.box, "BOTTOMRIGHT", -18, 18);
	W.cancel = Button("TemucraftGlueOptionsCancel", CANCEL or "Cancel", 96, function() PlaySound("gsTitleOptionExit"); Cancel(); end);
	W.cancel:SetPoint("RIGHT", W.okay, "LEFT", -6, 0);
	W.apply = Button("TemucraftGlueOptionsApply", APPLY or "Apply", 96, function() PlaySound("igMainMenuOptionCheckBoxOn"); Apply(); end);
	W.apply:SetPoint("RIGHT", W.cancel, "LEFT", -6, 0);
	-- the reset button's text follows the stock one ("Cancel Reset" after a reset)
	local wait = 0;
	W:SetScript("OnUpdate", function(self, elapsed)
		wait = wait - (elapsed or 0);
		if ( wait > 0 ) then return; end
		wait = 0.25;
		local t = ResetText();
		if ( W.reset:GetText() ~= t ) then W.reset:SetText(t); end
	end);
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
	W.reset:SetText(ResetText());
	W:Show();
	local first, wanted;
	which = which and string.lower(which);
	for _, e in ipairs(entries) do
		first = first or e;
		if ( which and (string.lower(e.text) == which or e.page.key == which
			or ((which == "sound" or which == "more sound" or which == "moresound") and e.page.key == "audio")
			or ((which == "resolution" or which == "effects" or which == "display" or which == "frame rate" or which == "framerate") and e.page.key == "graphics")) ) then
			wanted = wanted or e;
		end
	end
	ShowEntry(wanted or first);
	PlaySound("gsTitleOptions");
end

function TemucraftGlueOptions_Close() if ( W and W:IsShown() ) then Cancel(); end end
function TemucraftGlueOptions_IsShown() return W and W:IsShown() or false; end

-- Every way to the stock chooser (the login screen's Options, Menu > Options on character select) opens ours instead,
-- unless Classic was chosen; if ours fails, the chooser stays
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

-- The classic windows: "Use the new Options window" (saved, like Classic)
local function UseNew(from)
	PlaySound("igMainMenuOptionCheckBoxOn");
	L.SetStyle("new");
	if ( from ~= OptionsSelectFrame ) then
		-- the stock Cancel (puts back what wasn't applied, closes; the chooser it came from opens ours)
		local cancel = from and _G[from:GetName().."Cancel"];
		if ( cancel and from:IsShown() ) then cancel:Click(); elseif ( from ) then from:Hide(); end
	end
	if ( OptionsSelectFrame:IsShown() ) then OptionsSelectFrame:Hide(); end
	if ( not TemucraftGlueOptions_IsShown() ) then
		local ok = pcall(TemucraftGlueOptions_Open);
		if ( not ok and W ) then pcall(PutBack); W:Hide(); L.SetStyle("classic"); OptionsSelectFrame:Show(); end
	end
end
local function NewButton(frame, anchor)
	if ( not frame or not anchor or not frame.GetName or not frame:GetName() ) then return; end
	local b = CreateFrame("Button", frame:GetName().."TemucraftNewOptions", frame, "GlueButtonSmallTemplate");
	b:SetWidth(260); b:SetHeight(32);
	b:SetPoint("TOP", anchor, "BOTTOM", 0, -6);
	b:SetText("Use the new Options window");
	b:SetScript("OnClick", function() UseNew(frame); end);
	b:SetScript("OnEnter", function(self) Tooltip(self, "Use the new Options window\n|cffffffffGraphics and Audio in one window, like retail. Menu > Options opens it from now on.|r"); end);
	b:SetScript("OnLeave", HideTooltip);
	return b;
end
NewButton(OptionsSelectFrame, OptionsSelectFrameBackground or OptionsSelectFrame);
NewButton(VideoOptionsFrame, VideoOptionsFrame);
NewButton(AudioOptionsFrame, AudioOptionsFrame);
