-- Stub tests for the login / character screens' Options window (no client):
-- lua5.1 client/tests/glueoptions_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
local file = dir.."/Interface/GlueXML/TemucraftGlueOptions.lua";
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end
local function near(x, y) return x and math.abs(x - y) < 1e-9; end

dofile(file);
local L = assert(TemucraftGlueOptionsLogic);

-- sliders
check("ends: real numbers, percent for 0-1 (one % sign)", select(1, L.Ends(0, 1, 0.1)) == "0%" and select(2, L.Ends(0, 1, 0.1)) == "100%"
	and select(1, L.Ends(0, 200, 5)) == "0" and select(2, L.Ends(177, 1277, 1)) == "1277" and select(2, L.Ends(0.5, 1.5, 0.05)) == "1.50");
check("value format", L.Format(0.5, 0, 1, 0.1) == "50%" and L.Format(60, 0, 200, 5) == "60" and L.Format(1.25, 0.5, 1.5, 0.05) == "1.25");
check("typed values", near(L.Parse("50", 0, 1, 0.1), 0.5) and near(L.Parse("0.3", 0, 1, 0.1), 0.3) and near(L.Parse("70 %", 0, 1, 0.1), 0.7)
	and L.Parse("999", 0, 200, 5) == 200 and L.Parse("-4", 0, 200, 5) == 0 and L.Parse("63", 0, 200, 5) == 65 and L.Parse("x", 0, 1, 0.1) == nil);
check("refresh text", L.RefreshText("60", 0) == "Set by the display (windowed)" and L.RefreshText("60") == "Set by the display (windowed)"
	and L.RefreshText("75", 60, 75, 144) == "75 Hz" and L.RefreshText("0", 60, 144) == "60 Hz");
HERTZ = nil;

-- multisampling
local function texts(t) local o = {}; for _, c in ipairs(t) do table.insert(o, c.text); end return table.concat(o, ","); end
local ms = L.MultisampleChoices(24, 24, 1, 24, 24, 2, 24, 24, 4, 24, 24, 8);
check("multisampling: plain choices", texts(ms) == "None,2x,4x,8x" and ms[3].full == "24-bit color 24-bit depth 4x multisample");
check("multisampling: the format only when two share the samples", texts(L.MultisampleChoices(24, 16, 4, 24, 24, 4, 32, 24, 1)) == "4x (24/16-bit),4x (24/24-bit),None");

-- the list and the layout
local items = {};
for _, e in ipairs(L.List()) do table.insert(items, e.text); end
check("list: Graphics and Audio only", table.concat(items, ",") == "Graphics,Audio");
local secs = {};
for _, p in ipairs(L.PAGES) do for _, s in ipairs(p.sections) do table.insert(secs, s.title); end end
check("sections like retail", table.concat(secs, ",") == "Display,Quality,Effects,Frame Rate,Volume,Playback,Output,Other");
local cvars = {};
for _, r in ipairs(L.OurRows()) do cvars[r.cvar] = r; end
check("our CVars (3.3.5 has them)", cvars.maxFPS and cvars.maxFPSBk and cvars.Sound_ListenerAtCharacter and cvars.Sound_ZoneMusicNoDelay and cvars.maxFPS.max == 200);
local cells, y = L.Cells("sliders", 3, 100);
check("two columns", cells[1].x == L.PAD and cells[2].x == L.PAD + L.COL_W + L.COL_GAP and cells[2].y == 100 and cells[3].y == 150 and cells[3].x == L.PAD and y == 200);
check("inside the view", L.Inside(10, 20, 0, 100) and not L.Inside(90, 20, 0, 100) and L.Inside(90, 20, 20, 100) and not L.Inside(0, 20, 20, 100));

---------------------------------------------------------------------------------------------------------------------
-- stub load
---------------------------------------------------------------------------------------------------------------------
local W = {};
W.__index = function(self, k)
	local v = rawget(W, k);
	if ( v ) then return v; end
	if ( string.match(k, "^%u") ) then return function() end; end
end
local function new(kind, name, parent)
	local f = setmetatable({ kind = kind, scripts = {}, shown = true, children = {}, text = "", points = {} }, W);
	if ( parent ) then f:SetParent(parent); end
	if ( name ) then _G[name] = f; f.name = name; end
	return f;
end
function W:SetParent(p)
	if ( self.parent ) then for i, c in ipairs(self.parent.children) do if ( c == self ) then table.remove(self.parent.children, i); break; end end end
	self.parent = p;
	if ( p ) then table.insert(p.children, self); end
end
function W:GetParent() return self.parent; end
function W:GetChildren() return unpack(self.children); end
function W:GetName() return self.name; end
function W:GetObjectType() return self.kind; end
function W:SetScript(k, f) self.scripts[k] = f; end
function W:GetScript(k) return self.scripts[k]; end
function W:HookScript(k, f) local o = self.scripts[k]; self.scripts[k] = function(...) if ( o ) then o(...); end f(...); end end
function W:Show() local was = self.shown; self.shown = true; if ( not was and self.scripts.OnShow ) then self.scripts.OnShow(self); end end
function W:Hide() local was = self.shown; self.shown = false; if ( was and self.scripts.OnHide ) then self.scripts.OnHide(self); end end
function W:IsShown() return self.shown; end
function W:SetText(t) self.text = t; end
function W:GetText() return self.text; end
function W:HasFocus() return self.focus; end
function W:ClearFocus() self.focus = nil; end
function W:SetChecked(c) self.checked = c and true or false; end
function W:GetChecked() return self.checked and 1 or nil; end
function W:SetMinMaxValues(a, b) self.min, self.max = a, b; end
function W:GetMinMaxValues() return self.min or 0, self.max or 1; end
function W:SetValueStep(s) self.step = s; end
function W:GetValueStep() return self.step or 0; end
function W:SetValue(v) self.value = v; if ( self.scripts.OnValueChanged ) then self.scripts.OnValueChanged(self, v); end end
function W:GetValue() return self.value or 0; end
function W:Click() if ( self.scripts.OnClick ) then self.scripts.OnClick(self, "LeftButton"); end end
function W:CreateTexture() return new("Texture", nil, self); end
function W:CreateFontString() return new("FontString", nil, self); end
function W:ClearAllPoints() self.points = {}; end
function W:SetPoint(p, rel, rp, x, y) table.insert(self.points, { p, rel, rp, x, y }); end
function W:SetAllPoints(rel) self.points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }; end
function W:GetNumPoints() return #self.points; end
function W:GetPoint(i) local p = self.points[i]; return p[1], p[2], p[3], p[4], p[5]; end
function W:SetWidth(w) self.w = w; end
function W:GetWidth() return self.w or 100; end
function W:SetHeight(h) self.h = h; end
function W:GetHeight() return self.h or (self.kind == "ScrollFrame" and 420) or 0; end
function W:SetJustifyH(j) self.justify = j; end
function W:GetJustifyH() return self.justify or "CENTER"; end
function W:SetVerticalScroll(v) self.vscroll = v; end
function W:GetVerticalScroll() return self.vscroll or 0; end
function CreateFrame(kind, name, parent, template)
	local f = new(kind, name, parent);
	if ( template == "OptionsSliderTemplate" ) then new("FontString", name.."Text", f); new("FontString", name.."Low", f); new("FontString", name.."High", f); end
	if ( template == "OptionsCheckButtonTemplate" ) then new("FontString", name.."Text", f); end
	return f;
end
local function errorCVar(k) error("Couldn't find CVar named '"..tostring(k).."'"); end
local cv = { maxFPS = "200", maxFPSBk = "30", Sound_ListenerAtCharacter = "0", Sound_ZoneMusicNoDelay = "0", gxRefresh = "60" };
local defaults = { maxFPS = "200", maxFPSBk = "30", Sound_ListenerAtCharacter = "0", Sound_ZoneMusicNoDelay = "0" };
function GetCVar(k) if ( cv[k] == nil ) then errorCVar(k); end return cv[k]; end
function SetCVar(k, v) if ( cv[k] == nil ) then errorCVar(k); end cv[k] = v; end
function GetCVarDefault(k) return defaults[k]; end
function PlaySound() end
local calls = {};
function GetRefreshRates() return 0; end
function GetMultisampleFormats() return 24, 24, 1, 24, 24, 2, 24, 24, 4, 24, 24, 8; end
MULTISAMPLING_FORMAT_STRING = "%d-bit color %d-bit depth %dx multisample";
function GlueDropDownMenu_SetText(text, dd) dd.ddtext = text; end
function GlueDropDownMenu_CreateInfo() return {}; end
local menu = {};
function GlueDropDownMenu_AddButton(info) table.insert(menu, { text = info.text, tip = info.tooltipText }); end
function GlueDropDownMenu_GetSelectedID(dd) return dd.selectedID; end
function GlueDropDownMenu_Initialize(dd, f) menu = {}; f(); end
function GlueDialog_Show(which) table.insert(calls, "dialog:"..which); end
function OptionsFrame_RefreshCategories(f) table.insert(calls, "refresh:"..f.name); end
function OptionsFrameCancel_OnClick(f) table.insert(calls, "cancel:"..f.name); end
function VideoOptionsFrameOkay_OnClick(_, _, apply) table.insert(calls, "videookay:"..tostring(apply)); end
function AudioOptionsFrameOkay_OnClick(_, _, apply) table.insert(calls, "audiookay:"..tostring(apply)); end
function VideoOptionsFrame_SetAllToDefaults() table.insert(calls, "videoall"); end
function VideoOptionsFrame_SetCurrentToDefaults() table.insert(calls, "videocurrent"); end
function AudioOptionsFrame_SetAllToDefaults() table.insert(calls, "audioall"); end
function AudioOptionsFrame_SetCurrentToDefaults() table.insert(calls, "audiocurrent"); end

GlueParent = new("Frame", "GlueParent");
OptionsSelectFrame = new("Frame", "OptionsSelectFrame", GlueParent); OptionsSelectFrame.shown = false;
new("Frame", "OptionsSelectFrameBackground", OptionsSelectFrame);
OptionsSelectResetSettingsButton = new("Button", "OptionsSelectResetSettingsButton", OptionsSelectFrame);
OptionsSelectResetSettingsButton.text = "Reset User Options";
OptionsSelectResetSettingsButton:SetScript("OnClick", function(self) table.insert(calls, "reset"); self.text = "Cancel Reset"; end);
for _, which in ipairs({ "Video", "Audio" }) do
	local f = new("Frame", which.."OptionsFrame", GlueParent); f.shown = false;
	f.panelContainer = new("Frame", which.."OptionsFramePanelContainer", f);
	f.categoryList = {};
	f:SetScript("OnHide", function(self) if ( self.lastFrame ) then self.lastFrame:Show(); self.lastFrame = nil; end end);
	local c = new("Button", which.."OptionsFrameCancel", f);
	c:SetScript("OnClick", function() table.insert(calls, "stockcancel:"..which); f:Hide(); end);
end
local function stockSlider(name, parent, min, max, step, value, x, y)
	local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate");
	s:SetMinMaxValues(min, max); s:SetValueStep(step); s.value = value; s:SetWidth(112);
	s:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0);
	return s;
end
local function stock(kind, name, parent) local f = new(kind, name, parent); f:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5); return f; end
local R, E, S = "VideoOptionsResolutionPanel", "VideoOptionsEffectsPanel", "AudioOptionsSoundPanel";
VideoOptionsResolutionPanel = new("Frame", R, VideoOptionsFramePanelContainer); VideoOptionsResolutionPanel.name = "Resolution";
VideoOptionsEffectsPanel = new("Frame", E, VideoOptionsFramePanelContainer); VideoOptionsEffectsPanel.name = "Effects"; VideoOptionsEffectsPanel.shown = false;
AudioOptionsSoundPanel = new("Frame", S, AudioOptionsFramePanelContainer); AudioOptionsSoundPanel.name = "Sound";
for _, n in ipairs({ "Title", "SubText" }) do stock("FontString", R..n, VideoOptionsResolutionPanel); stock("FontString", E..n, VideoOptionsEffectsPanel); stock("FontString", S..n, AudioOptionsSoundPanel); end
for _, n in ipairs({ "ResolutionDropDown", "RefreshDropDown", "MultiSampleDropDown" }) do stock("Frame", R..n, VideoOptionsResolutionPanel); end
VideoOptionsResolutionPanelMultiSampleDropDown.selectedID = 3;
function VideoOptionsResolutionPanelMultiSampleDropDown_Initialize() VideoOptionsResolutionPanel_GetMultisampleFormats(GetMultisampleFormats()); end
function VideoOptionsResolutionPanel_GetMultisampleFormats(...) GlueDropDownMenu_SetText("24-bit color 24-bit depth 4x multisample", VideoOptionsResolutionPanelMultiSampleDropDown); end
VideoOptionsResolutionPanelMultiSampleDropDown.ddtext = "24-bit color 24-bit depth 4x multisample";
for _, n in ipairs({ "Windowed", "Maximized", "DisableResize", "VSync", "TripleBuffer", "HardwareCursor", "FixInputLag", "DesktopGamma" }) do stock("CheckButton", R..n, VideoOptionsResolutionPanel); end
VideoOptionsResolutionPanelDisableResize.shown = false;   -- hidden by the stock (Mac)
stock("Frame", R.."Brightness", VideoOptionsResolutionPanel);
local gamma = stockSlider(R.."GammaSlider", VideoOptionsResolutionPanel, -0.5, 0.5, 0.1, 0); gamma.text = nil; _G[R.."GammaSliderText"].text = "Gamma";
stock("Frame", E.."Quality", VideoOptionsEffectsPanel).h = 88;
stockSlider(E.."QualitySlider", VideoOptionsEffectsPanel, 1, 6, 1, 4); _G[E.."QualitySliderLow"].text = "Low";
local farclip;
for i, n in ipairs({ "ViewDistance", "EnvironmentDetail", "TerrainDetail", "ClutterDensity", "ParticleDensity", "ClutterRadius", "ShadowQuality",
	"TextureResolution", "TextureFiltering", "WeatherIntensity", "PlayerTexture" }) do
	local s = stockSlider(E..n, VideoOptionsEffectsPanel, 0, 10, 1, 5, i * 3, -i * 5);
	_G[E..n.."Text"].text = n;
	if ( n == "ViewDistance" ) then farclip = s; s:SetMinMaxValues(177, 1277); s.value = 500; end
end
stock("Frame", E.."Shaders", VideoOptionsEffectsPanel);
for _, n in ipairs({ "SpecularLighting", "DeathEffect", "FullScreenGlow", "ProjectedTextures" }) do stock("CheckButton", E..n, VideoOptionsEffectsPanel); end
for _, n in ipairs({ "Playback", "Hardware", "Volume", "HardwareDropDown" }) do stock("Frame", S..n, AudioOptionsSoundPanel); end
for _, n in ipairs({ "EnableSound", "SoundEffects", "ErrorSpeech", "EmoteSounds", "PetSounds", "Music", "LoopMusic", "AmbientSounds", "SoundInBG",
	"Reverb", "HRTF", "EnableDSPs", "UseHardware" }) do stock("CheckButton", S..n, AudioOptionsSoundPanel); end
local master = stockSlider(S.."MasterVolume", AudioOptionsSoundPanel, 0, 1, 0.1, 0.5);
_G[S.."MasterVolumeText"].text = "Master Volume";
new("FontString", S.."MasterVolumeLabel", master).text = "50%";
_G[S.."MasterVolumeLow"].shown = false; _G[S.."MasterVolumeHigh"].shown = false;
for _, n in ipairs({ "SoundVolume", "MusicVolume", "AmbienceVolume" }) do
	local s = stockSlider(S..n, AudioOptionsSoundPanel, 0, 1, 0.1, 0.3);
	_G[S..n.."Text"].shown = false;
	local lab = new("FontString", S..n.."Label", s); lab.text = n; lab.w = 64; lab:SetPoint("RIGHT", s, "LEFT", -4, 1);
end
_G[S.."SoundVolumeLow"]:SetPoint("BOTTOMLEFT", _G[S.."SoundVolume"], "TOPLEFT", -2, 4);
stockSlider(S.."SoundChannels", AudioOptionsSoundPanel, 32, 64, 32, 64); _G[S.."SoundChannelsText"].text = "Sound Channels";
stockSlider(S.."SoundQuality", AudioOptionsSoundPanel, 0, 2, 1, 2); _G[S.."SoundQualityText"].text = "Sound Quality";
VideoOptionsFrame.categoryList = { VideoOptionsResolutionPanel, VideoOptionsEffectsPanel };
AudioOptionsFrame.categoryList = { AudioOptionsSoundPanel };
local farPoints = farclip.points[1];

local ok, err = pcall(dofile, file);
check("loads on the stub glue", ok or print(err));
L = TemucraftGlueOptionsLogic;
check("multisample menu: plain names, format in the tooltip", menu[3] and menu[3].text == "4x" and menu[3].tip == "24-bit color 24-bit depth 4x multisample"
	and VideoOptionsResolutionPanelMultiSampleDropDown.ddtext == "4x");
check("style: new by default (no CVar yet)", L.GetStyle() == "new");
check("classic windows: a Use the new Options window button", OptionsSelectFrameTemucraftNewOptions and OptionsSelectFrameTemucraftNewOptions.text == "Use the new Options window"
	and VideoOptionsFrameTemucraftNewOptions and AudioOptionsFrameTemucraftNewOptions);
OptionsSelectFrame:Show();
check("the chooser opens ours instead", TemucraftGlueOptions_IsShown() and not OptionsSelectFrame.shown);
check("list buttons: Graphics, Audio", TemucraftGlueOptionsListButton1.text.text == "Graphics" and TemucraftGlueOptionsListButton2.text.text == "Audio"
	and not TemucraftGlueOptionsListButton3);
local child = TemucraftGlueOptionsChildgraphics;
check("graphics: both stock panels moved in and shown", VideoOptionsResolutionPanel.parent == child and VideoOptionsEffectsPanel.parent == child
	and VideoOptionsEffectsPanel.shown and VideoOptionsFramePanelContainer.displayedPanel == VideoOptionsResolutionPanel);
check("graphics: titles and stock boxes hidden", not VideoOptionsResolutionPanelTitle.shown and not VideoOptionsEffectsPanelShaders.shown and not VideoOptionsResolutionPanelBrightness.shown);
check("refresh rate says windowed", VideoOptionsResolutionPanelRefreshDropDown.ddtext == "Set by the display (windowed)");
local p1 = farclip.points[1];
check("view distance laid out in the list", p1[2] == child and p1[1] == "TOPLEFT" and farclip.w == L.COL_W - 8);
local text = VideoOptionsEffectsPanelViewDistanceText;
local box;
for _, c in ipairs(farclip.children) do if ( c.kind == "EditBox" ) then box = c; end end
check("slider: name left above the bar, value right above the bar", text.points[1][1] == "BOTTOMLEFT" and text.points[1][2] == farclip and text.points[1][3] == "TOPLEFT"
	and text.justify == "LEFT" and box and box.shown and box.points[1][1] == "BOTTOMRIGHT" and box.points[1][3] == "TOPRIGHT");
check("slider: name and value don't overlap", text.w + box.w + 8 <= farclip.w);
check("slider: min / max under the ends", VideoOptionsEffectsPanelViewDistanceLow.points[1][3] == "BOTTOMLEFT" and VideoOptionsEffectsPanelViewDistanceLow.text == "177"
	and VideoOptionsEffectsPanelViewDistanceHigh.text == "1277" and box.text == "500");
box.text = "2000"; box.scripts.OnEnterPressed(box);
check("typed value clamped and applied", farclip.value == 1277 and box.text == "1277");
check("quality slider keeps its names and has no value box", VideoOptionsEffectsPanelQualitySliderLow.text == "Low");
check("stock-hidden control stays hidden", not VideoOptionsResolutionPanelDisableResize.shown);
-- scrolling: only what's wholly in view is shown
local fps = TemucraftGlueOptionsSlider1;
check("frame rate rows below the view are hidden", fps and not fps.shown and VideoOptionsResolutionPanelVSync.shown);
local bar = TemucraftGlueOptionsScrollBargraphics;
local _, range = bar:GetMinMaxValues();
check("scroll bar range", range > 0 and bar.shown);
bar:SetValue(range);
check("scrolled down: frame rate shown, display hidden", fps.shown and not VideoOptionsResolutionPanelVSync.shown and child.parent.vscroll == range);
check("frame rate slider from the CVar", fps.value == 200 and TemucraftGlueOptionsSlider1Low.text == "0" and TemucraftGlueOptionsSlider1High.text == "200");
fps:SetValue(62);
check("slider sets the CVar, snapped", cv.maxFPS == "60");
calls = {};
TemucraftGlueOptionsDefaults:Click();
check("defaults: the stock video confirm", calls[1] == "dialog:CONFIRM_RESET_VIDEO_SETTINGS");
calls = {};
VideoOptionsFrame_SetCurrentToDefaults();
check("current settings = the whole page, our rows too", calls[1] == "videoall" and cv.maxFPS == "200");
-- audio
TemucraftGlueOptionsListButton2:Click();
check("audio page: sound panel moved in, graphics page hidden", AudioOptionsSoundPanel.parent == TemucraftGlueOptionsChildaudio and not TemucraftGlueOptionsScrollgraphics.shown
	and TemucraftGlueOptionsScrollaudio.shown);
local mbox;
for _, c in ipairs(master.children) do if ( c.kind == "EditBox" ) then mbox = c; end end
check("master volume: one value (the stock second one hidden), 0% / 100% under the bar", not AudioOptionsSoundPanelMasterVolumeLabel.shown and mbox.text == "50%"
	and AudioOptionsSoundPanelMasterVolumeHigh.text == "100%" and AudioOptionsSoundPanelMasterVolumeHigh.shown
	and AudioOptionsSoundPanelMasterVolumeText.points[1][1] == "BOTTOMLEFT");
local sl = AudioOptionsSoundPanelSoundVolumeLabel;
check("sound volume: its name on the line above, value on the same line, ends under", sl.points[1][1] == "BOTTOMLEFT" and sl.points[1][2] == AudioOptionsSoundPanelSoundVolume
	and AudioOptionsSoundPanelSoundVolumeLow.points[1][1] == "TOPLEFT" and AudioOptionsSoundPanelSoundVolumeLow.points[1][3] == "BOTTOMLEFT"
	and #AudioOptionsSoundPanelSoundVolumeLow.points == 1);
mbox.text = "75"; mbox.scripts.OnEnterPressed(mbox);
check("typed 75 -> 0.75 snapped to 0.1", near(master.value, 0.8) or near(master.value, 0.7));
calls = {};
TemucraftGlueOptionsDefaults:Click();
check("defaults on audio: the stock audio confirm", calls[1] == "dialog:CONFIRM_RESET_AUDIO_SETTINGS");
local hear;
for _, c in ipairs(TemucraftGlueOptionsChildaudio.children) do if ( c.item and c.item.cvar == "Sound_ListenerAtCharacter" ) then hear = c; end end
hear.checked = true; hear:Click();
check("our check sets the CVar", cv.Sound_ListenerAtCharacter == "1");
-- reset user options in the bottom bar
calls = {};
TemucraftGlueOptionsReset:Click();
TemucraftGlueOptionsFrame.scripts.OnUpdate(TemucraftGlueOptionsFrame, 1);
check("reset user options: the stock button, its text follows", calls[1] == "reset" and TemucraftGlueOptionsReset.text == "Cancel Reset");
calls = {};
TemucraftGlueOptionsCancel:Click();
check("cancel: stock cancel, our CVars back, closed", cv.Sound_ListenerAtCharacter == "0" and table.concat(calls, ","):find("cancel:VideoOptionsFrame", 1, true) and not TemucraftGlueOptions_IsShown());
check("closed: panels back, anchors / widths / shown put back", VideoOptionsEffectsPanel.parent == VideoOptionsFramePanelContainer and not VideoOptionsEffectsPanel.shown
	and VideoOptionsResolutionPanel.shown
	and (farclip.points[1][1] == farPoints[1] and farclip.points[1][2] == farPoints[2] and farclip.points[1][4] == farPoints[4] and farclip.w == 112
	and VideoOptionsResolutionPanelTitle.shown and AudioOptionsSoundPanelMasterVolumeLabel.shown and not AudioOptionsSoundPanelMasterVolumeLow.shown
	and not box.shown and AudioOptionsSoundPanelSoundVolumeLabel.w == 64 and #AudioOptionsSoundPanelSoundVolumeLabel.points == 1
	and AudioOptionsSoundPanelSoundVolumeLabel.points[1][1] == "RIGHT" and VideoOptionsFramePanelContainer.displayedPanel == nil));
TemucraftGlueOptions_Open("Sound");
check("open on a page by an old name", TemucraftGlueOptionsScrollaudio.shown and AudioOptionsFramePanelContainer.displayedPanel == AudioOptionsSoundPanel);
calls = {};
TemucraftGlueOptionsOkay:Click();
check("okay: stock okay with apply, then closed", calls[1] == "videookay:true" and calls[2] == "audiookay:true" and not TemucraftGlueOptions_IsShown()
	and AudioOptionsSoundPanel.parent == AudioOptionsFramePanelContainer);
VideoOptionsFrame.gameRestart = true;
calls = {};
TemucraftGlueOptions_Open();
TemucraftGlueOptionsOkay:Click();
check("restart alert after closing", table.concat(calls, ","):find("dialog:CLIENT_RESTART_ALERT", 1, true) and not VideoOptionsFrame.gameRestart);
-- classic and back
TemucraftGlueOptions_Open();
TemucraftGlueOptionsClassic:Click();
check("classic: the stock chooser", OptionsSelectFrame.shown and not TemucraftGlueOptions_IsShown() and L.GetStyle() == "classic");
OptionsSelectFrame:Hide();
OptionsSelectFrame:Show();
check("classic is kept: Menu > Options opens the chooser", OptionsSelectFrame.shown and not TemucraftGlueOptions_IsShown());
OptionsSelectFrameTemucraftNewOptions:Click();
check("chooser: Use the new Options window", TemucraftGlueOptions_IsShown() and not OptionsSelectFrame.shown and L.GetStyle() == "new");
TemucraftGlueOptionsClassic:Click();
VideoOptionsFrame.lastFrame = OptionsSelectFrame; OptionsSelectFrame:Hide(); VideoOptionsFrame:Show();
calls = {};
VideoOptionsFrameTemucraftNewOptions:Click();
check("video window: Use the new Options window (its own cancel first)", calls[1] == "stockcancel:Video" and not VideoOptionsFrame.shown
	and TemucraftGlueOptions_IsShown() and not OptionsSelectFrame.shown and L.GetStyle() == "new");
TemucraftGlueOptionsCancel:Click();
-- saved in the CVar once the game has registered it
cv.temucraftOptionsStyle = "new";
TemucraftGlueOptions_Open();
TemucraftGlueOptionsClassic:Click();
check("the choice is saved in temucraftOptionsStyle", cv.temucraftOptionsStyle == "classic");
OptionsSelectFrameTemucraftNewOptions:Click();
check("and back", cv.temucraftOptionsStyle == "new" and TemucraftGlueOptions_IsShown());
TemucraftGlueOptionsFrame.scripts.OnKeyDown(TemucraftGlueOptionsFrame, "ESCAPE");
check("escape cancels", not TemucraftGlueOptions_IsShown());
-- a broken window falls back to the chooser
local realOpen = TemucraftGlueOptions_Open;
TemucraftGlueOptions_Open = function() error("boom"); end
OptionsSelectFrame:Show();
check("fallback: the chooser if ours fails", OptionsSelectFrame.shown);
TemucraftGlueOptions_Open = realOpen;
OptionsSelectFrame:Hide();
TEMUCRAFT_GLUE_OPTIONS = "classic";
OptionsSelectFrame:Show();
check("classic setting keeps the chooser", OptionsSelectFrame.shown and not TemucraftGlueOptions_IsShown());

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
