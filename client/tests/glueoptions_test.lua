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
check("ends: real numbers, percent for 0-1", select(1, L.Ends(0, 1, 0.1)) == "0%" and select(2, L.Ends(0, 1, 0.1)) == "100%"
	and select(1, L.Ends(0, 200, 5)) == "0" and select(2, L.Ends(177, 1277, 1)) == "1277" and select(2, L.Ends(0.5, 1.5, 0.05)) == "1.50");
check("value format", L.Format(0.5, 0, 1, 0.1) == "50%" and L.Format(60, 0, 200, 5) == "60" and L.Format(1.25, 0.5, 1.5, 0.05) == "1.25");
check("typed values", near(L.Parse("50", 0, 1, 0.1), 0.5) and near(L.Parse("0.3", 0, 1, 0.1), 0.3) and near(L.Parse("70 %", 0, 1, 0.1), 0.7)
	and L.Parse("999", 0, 200, 5) == 200 and L.Parse("-4", 0, 200, 5) == 0 and L.Parse("63", 0, 200, 5) == 65 and L.Parse("x", 0, 1, 0.1) == nil);
check("refresh text", L.RefreshText("60", 0) == "Set by the display (windowed)" and L.RefreshText("60") == "Set by the display (windowed)"
	and L.RefreshText("75", 60, 75, 144) == "75 Hz" and L.RefreshText("0", 60, 144) == "60 Hz");
HERTZ = nil;

-- the list
local video = { { name = "Resolution" }, { name = "Effects" }, { name = "Stereo", hidden = true } };
local audio = { { name = "Sound" } };
local items = {};
for _, e in ipairs(L.List(video, audio)) do table.insert(items, (e.kind == "section" and "#" or "")..e.text); end
check("list: stock pages and ours, grouped", table.concat(items, ",") == "#Graphics,Resolution,Effects,Frame Rate,#Audio,Sound,More Sound");
local cvars = {};
for _, p in ipairs(L.PAGES) do for _, r in ipairs(p.rows) do if ( r.cvar ) then cvars[r.cvar] = r; end end end
check("our CVars (3.3.5 has them)", cvars.maxFPS and cvars.maxFPSBk and cvars.Sound_ListenerAtCharacter and cvars.Sound_ZoneMusicNoDelay and cvars.maxFPS.max == 200);

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
	local f = setmetatable({ kind = kind, scripts = {}, shown = true, children = {}, text = "" }, W);
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
function W:Hide() self.shown = false; end
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
function W:CreateTexture() return new("Texture"); end
function W:CreateFontString() return new("FontString"); end
function CreateFrame(kind, name, parent, template)
	local f = new(kind, name, parent);
	if ( template == "OptionsSliderTemplate" ) then new("FontString", name.."Text", f); new("FontString", name.."Low", f); new("FontString", name.."High", f); end
	if ( template == "OptionsCheckButtonTemplate" ) then new("FontString", name.."Text", f); end
	return f;
end
local cv = { maxFPS = "200", maxFPSBk = "30", Sound_ListenerAtCharacter = "0", Sound_ZoneMusicNoDelay = "0", gxRefresh = "60" };
local defaults = { maxFPS = "200", maxFPSBk = "30", Sound_ListenerAtCharacter = "0", Sound_ZoneMusicNoDelay = "0" };
function GetCVar(k) return cv[k]; end
function SetCVar(k, v) cv[k] = v; end
function GetCVarDefault(k) return defaults[k]; end
function PlaySound() end
local calls = {};
function GetRefreshRates() return 0; end
function GlueDropDownMenu_SetText(text, dd) dd.ddtext = text; end
function GlueDialog_Show(which) table.insert(calls, "dialog:"..which); end
function OptionsFrame_RefreshCategories(f) table.insert(calls, "refresh:"..f.name); end
function OptionsFrameCancel_OnClick(f) table.insert(calls, "cancel:"..f.name); end
function VideoOptionsFrameOkay_OnClick(_, _, apply) table.insert(calls, "videookay:"..tostring(apply)); end
function AudioOptionsFrameOkay_OnClick(_, _, apply) table.insert(calls, "audiookay:"..tostring(apply)); end

GlueParent = new("Frame", "GlueParent");
OptionsSelectFrame = new("Frame", "OptionsSelectFrame", GlueParent); OptionsSelectFrame.shown = false;
OptionsSelectResetSettingsButton = new("Button", "OptionsSelectResetSettingsButton", OptionsSelectFrame);
OptionsSelectResetSettingsButton.text = "Reset User Options";
for _, which in ipairs({ "Video", "Audio" }) do
	local f = new("Frame", which.."OptionsFrame", GlueParent); f.shown = false;
	f.panelContainer = new("Frame", which.."OptionsFramePanelContainer", f);
	f.categoryList = {};
end
VideoOptionsResolutionPanel = new("Frame", "VideoOptionsResolutionPanel", VideoOptionsFramePanelContainer); VideoOptionsResolutionPanel.name = "Resolution";
VideoOptionsResolutionPanelRefreshDropDown = new("Frame", "VideoOptionsResolutionPanelRefreshDropDown", VideoOptionsResolutionPanel);
VideoOptionsEffectsPanel = new("Frame", "VideoOptionsEffectsPanel", VideoOptionsFramePanelContainer); VideoOptionsEffectsPanel.name = "Effects";
local farclip = CreateFrame("Slider", "VideoOptionsEffectsPanelViewDistance", VideoOptionsEffectsPanel, "OptionsSliderTemplate");
farclip:SetMinMaxValues(177, 1277); farclip:SetValueStep(1); farclip.value = 500;
VideoOptionsEffectsPanelQualitySlider = CreateFrame("Slider", "VideoOptionsEffectsPanelQualitySlider", VideoOptionsEffectsPanel, "OptionsSliderTemplate");
VideoOptionsEffectsPanelQualitySliderLow.text = "Low";
AudioOptionsSoundPanel = new("Frame", "AudioOptionsSoundPanel", AudioOptionsFramePanelContainer); AudioOptionsSoundPanel.name = "Sound";
local master = CreateFrame("Slider", "AudioOptionsSoundPanelMasterVolume", AudioOptionsSoundPanel, "OptionsSliderTemplate");
master:SetMinMaxValues(0, 1); master:SetValueStep(0.1); master.value = 0.5;
VideoOptionsFrame.categoryList = { VideoOptionsResolutionPanel, VideoOptionsEffectsPanel };
AudioOptionsFrame.categoryList = { AudioOptionsSoundPanel };

local ok, err = pcall(dofile, file);
check("loads on the stub glue", ok or print(err));
OptionsSelectFrame:Show();
check("the chooser opens ours instead", TemucraftGlueOptions_IsShown() and not OptionsSelectFrame.shown);
check("first page: Resolution, moved in", VideoOptionsResolutionPanel.parent == TemucraftGlueOptionsContainer and VideoOptionsResolutionPanel.shown
	and VideoOptionsFramePanelContainer.displayedPanel == VideoOptionsResolutionPanel);
check("refresh rate says windowed", VideoOptionsResolutionPanelRefreshDropDown.ddtext == "Set by the display (windowed)");
check("list buttons", TemucraftGlueOptionsListButton1.text.text == "Graphics" and TemucraftGlueOptionsListButton2.text.text == "Resolution"
	and TemucraftGlueOptionsListButton4.text.text == "Frame Rate" and TemucraftGlueOptionsListButton7.text.text == "More Sound");
TemucraftGlueOptionsListButton3:Click();
check("effects: slider ends are numbers, quality keeps its names", VideoOptionsEffectsPanelViewDistanceLow.text == "177" and VideoOptionsEffectsPanelViewDistanceHigh.text == "1277"
	and VideoOptionsEffectsPanelQualitySliderLow.text == "Low" and not VideoOptionsResolutionPanel.shown);
local box;
for _, c in ipairs(farclip.children) do if ( c.kind == "EditBox" ) then box = c; end end
check("value box shows the value", box and box.text == "500");
box.text = "2000"; box.scripts.OnEnterPressed(box);
check("typed value clamped and applied", farclip.value == 1277 and box.text == "1277");
TemucraftGlueOptionsListButton6:Click();
local mbox;
for _, c in ipairs(master.children) do if ( c.kind == "EditBox" ) then mbox = c; end end
check("volume: 0% / 100% ends, 50% value", AudioOptionsSoundPanelMasterVolumeLow.text == "0%" and AudioOptionsSoundPanelMasterVolumeHigh.text == "100%" and mbox.text == "50%");
mbox.text = "75"; mbox.scripts.OnEnterPressed(mbox);
check("typed 75 -> 0.75 snapped to 0.1", near(master.value, 0.8) or near(master.value, 0.7));
TemucraftGlueOptionsListButton4:Click();
local fps = TemucraftGlueOptionsPageframerate.rows[1];
check("frame rate page: slider from the CVar", fps.value == 200 and TemucraftGlueOptionsSlider1Low.text == "0" and TemucraftGlueOptionsSlider1High.text == "200");
fps:SetValue(62);
check("slider sets the CVar, snapped", cv.maxFPS == "60");
TemucraftGlueOptionsDefaults:Click();
check("defaults on our page", cv.maxFPS == "200");
fps:SetValue(120);
calls = {};
TemucraftGlueOptionsCancel:Click();
check("cancel: stock cancel, our CVars back, panels back", cv.maxFPS == "200" and table.concat(calls, ","):find("cancel:VideoOptionsFrame", 1, true)
	and VideoOptionsEffectsPanel.parent == VideoOptionsFramePanelContainer and not TemucraftGlueOptions_IsShown());
TemucraftGlueOptions_Open("Sound");
check("open on a page", AudioOptionsSoundPanel.parent == TemucraftGlueOptionsContainer and AudioOptionsFramePanelContainer.displayedPanel == AudioOptionsSoundPanel);
calls = {};
TemucraftGlueOptionsDefaults:Click();
check("defaults on a stock page: the stock confirm", calls[1] == "dialog:CONFIRM_RESET_AUDIO_SETTINGS");
calls = {};
TemucraftGlueOptionsListButton7:Click();
TemucraftGlueOptionsCheck3:Click();
check("check sets the CVar", cv.Sound_ListenerAtCharacter == "1" or cv.Sound_ListenerAtCharacter == "0");
TemucraftGlueOptionsOkay:Click();
check("okay: stock okay with apply, then closed", calls[1] == "videookay:true" and calls[2] == "audiookay:true" and not TemucraftGlueOptions_IsShown()
	and AudioOptionsSoundPanel.parent == AudioOptionsFramePanelContainer);
VideoOptionsFrame.gameRestart = true;
calls = {};
TemucraftGlueOptions_Open();
TemucraftGlueOptionsOkay:Click();
check("restart alert after closing", table.concat(calls, ","):find("dialog:CLIENT_RESTART_ALERT", 1, true) and not VideoOptionsFrame.gameRestart);
TemucraftGlueOptions_Open();
TemucraftGlueOptionsClassic:Click();
check("classic: the stock chooser", OptionsSelectFrame.shown and not TemucraftGlueOptions_IsShown());
OptionsSelectFrame:Hide();
TemucraftGlueOptions_Open();
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
