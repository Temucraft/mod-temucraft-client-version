-- Temucraft Issue Reporter (retail style), the client half of mod-temucraft-issues (addon prefix TIR).
--   - "Issue Reporter" button (bug icon with an "i" badge) above the action bars, bottom centre by default; Shift-drag
--     moves it (kept per account by TemucraftStore, "ui.issuepos"). A click opens a menu: Zone Bug, General Bug,
--     Feedback / Suggestion. /issue opens the menu too.
--   - "Press F6 to submit an issue for this Spell" (Item, Quest, Creature) at the bottom of reportable tooltips, also
--     on quest log titles, quest tracker lines and world map quest POIs. The key is a CLICK binding on
--     TemucraftIssueKeyButton (FrameXML can't add a Key Bindings entry without replacing the client's Bindings.xml):
--     F6 by default when F6 is free, /issuekey <key> binds another key, /issuekey none unbinds it.
--   - The key (or a menu entry) opens a dialog: "Issue Report: <name>", the icon, a question, Bug / Feedback boxes on
--     quest and general reports, a text box (255 letters) and Submit.
--   - Reports go out like Blizzard's PTR addon FeedbackUI: ReportBug / ReportSuggestion(<JSON>). The client adds its
--     own system block (user name, computer, processors, memory, OS, version, realm, account, character, map, zone,
--     position, target, auras) to the packet by itself, so it isn't built here. The JSON has FeedbackUI's keys (the
--     AzerothCore dashboard reads them), plus temucraftClientVersion and category. The server adds what it knows and
--     answers ACK~<id> ("Thanks! Report #<id> sent."), RATE~<seconds>, OFF or ERR.
-- Everything is hidden until the server says reporting is on (STATE~1~<button>): always on the PTR, a config on Live.
TemucraftIssuesLogic = {};
local L = TemucraftIssuesLogic;

L.MAX_TEXT = 255;
L.MAX_JSON = 5000;   -- the whole CMSG_BUG must stay under 10240 bytes (the client's own block is up to 4096)
L.BINDING = "CLICK TemucraftIssueKeyButton:LeftButton";
L.DEFAULT_KEY = "F6";

-- the menu
L.CATEGORIES = {
	{ key = "zone", title = "Zone Bug", desc = "I have encountered a Bug in this Zone." },
	{ key = "general", title = "General Bug", desc = "I have encountered a Bug." },
	{ key = "feedback", title = "Feedback / Suggestion", desc = "I have feedback or a suggestion." },
};

-- per report kind: FeedbackUI's reportSubjectType, the word of the hint line, the dialog's question; choose = the
-- Bug / Feedback boxes; feedbacktype = fixed type ("0" bug, "1" suggestion) when there are no boxes
L.KINDS = {
	spell    = { subject = "Spells", word = "Spell",    question = "What was the issue with this spell?", feedbacktype = "0" },
	item     = { subject = "Items",  word = "Item",     question = "What was the issue with this item?", feedbacktype = "0" },
	quest    = { subject = "Quests", word = "Quest",    question = "What was the issue with this quest?", choose = true },
	creature = { subject = "Mobs",   word = "Creature", question = "What was the issue with this creature?", feedbacktype = "0" },
	zone     = { subject = "Zones",  word = "Zone",     question = "What was the issue in this zone?", feedbacktype = "0" },
	general  = { title = "Bug Report", question = "Please describe the issue:", choose = true },
	feedback = { title = "Feedback / Suggestion", question = "What is your feedback or suggestion?", feedbacktype = "1" },
};

function L.HintText(kind, key)
	local k = L.KINDS[kind];
	if ( not k or not k.word or not key or key == "" ) then return nil; end
	return "Press "..key.." to submit an issue for this "..k.word;
end

function L.Title(kind, name)
	local k = L.KINDS[kind];
	if ( k and k.title ) then return k.title; end
	return "Issue Report: "..(name or "");
end

-- letters, not bytes (UTF-8)
function L.Utf8Len(text)
	local _, n = string.gsub(text or "", "[^\128-\191]", "");
	return n;
end

function L.Counter(text) return L.Utf8Len(text).." / "..L.MAX_TEXT; end

function L.Trim(text) return (string.gsub(text or "", "^%s*(.-)%s*$", "%1")); end

-- Submit: some text, and on quest / general reports Bug or Feedback picked
function L.CanSubmit(kind, text, picked)
	if ( L.Trim(text) == "" ) then return false; end
	local k = L.KINDS[kind];
	if ( k and k.choose and not picked ) then return false; end
	return true;
end

-- "0" bug or "1" suggestion
function L.FeedbackType(kind, picked)
	local k = L.KINDS[kind];
	if ( k and k.choose ) then return picked == "feedback" and "1" or "0"; end
	return k and k.feedbacktype or "0";
end

-- a value as FeedbackUI writes it (line breaks and "|" become spaces), escaped for JSON
function L.Clean(value)
	local s = tostring(value);
	s = string.gsub(s, "[\r\n\t]+", " ");
	s = string.gsub(s, "|", " ");
	s = string.gsub(s, "\\", "\\\\");
	s = string.gsub(s, "\"", "\\\"");
	s = string.gsub(s, "[%z\1-\31]", "");
	return s;
end

-- { key = value } -> {"key" : "value","key2" : "value2"} (FeedbackUI's layout, keys sorted)
function L.ToJSON(t)
	local keys = {};
	for k in pairs(t) do table.insert(keys, k); end
	table.sort(keys);
	local out = {};
	for _, k in ipairs(keys) do table.insert(out, "\""..L.Clean(k).."\" : \""..L.Clean(t[k]).."\""); end
	return "{"..table.concat(out, ",").."}";
end

-- what goes first when a report is too big for the packet
L.DROP_ORDER = { "addons", "addonsdisabled", "addonsloaded", "equipment", "talents", "currentCorpsePosition" };

function L.Fit(t, max)
	max = max or L.MAX_JSON;
	local json = L.ToJSON(t);
	for _, k in ipairs(L.DROP_ORDER) do
		if ( #json <= max ) then return json; end
		t[k] = nil;
		json = L.ToJSON(t);
	end
	while ( #json > max and t.text and #t.text > 0 ) do
		t.text = string.sub(t.text, 1, math.max(0, #t.text - (#json - max) - 1));
		json = L.ToJSON(t);
	end
	return json;
end

-- date("*t") -> "08 18 2025 14:35:32" (FeedbackUI's MM/DD/YYYY with the slashes made spaces)
function L.DateString(d)
	return string.format("%02d %02d %04d %02d:%02d:%02d", d.month, d.day, d.year, d.hour, d.min, d.sec);
end

function L.CharacterString(level, race, sex, class)
	return "Lvl "..tostring(level).." "..tostring(race).." "..tostring(sex).." "..tostring(class);
end

-- "0xF130001F4A00217C" -> 8010 (creatures and vehicles; nil for players, pets and the rest)
function L.CreatureId(guid)
	if ( type(guid) ~= "string" ) then return nil; end
	local high = string.upper(string.sub(guid, 3, 6));
	if ( high ~= "F130" and high ~= "F150" ) then return nil; end
	return tonumber(string.sub(guid, 7, 12), 16);
end

-- "|cffffff00|Hquest:12345:80|h[Name]|h|r" -> 12345, "Name"
function L.QuestFromLink(link)
	if ( type(link) ~= "string" ) then return nil; end
	local id = tonumber(string.match(link, "quest:(%d+)"));
	return id, string.match(link, "|h%[(.-)%]|h");
end

-- "ACK~12" -> "ACK", "12"
function L.ParseServer(message)
	local kind, a, b = string.match(message or "", "^(%u+)~?([^~]*)~?([^~]*)$");
	return kind, a, b;
end

function L.RateText(seconds)
	seconds = tonumber(seconds) or 0;
	if ( seconds >= 60 ) then
		return string.format("You have sent a lot of reports. Please wait %d min before the next one.", math.ceil(seconds / 60));
	end
	return string.format("You have sent a lot of reports. Please wait %d sec before the next one.", math.max(1, seconds));
end

-- "x:y" offsets of the button's bottom left corner <-> numbers
function L.PosText(x, y) return string.format("%d:%d", math.floor(x + 0.5), math.floor(y + 0.5)); end
function L.ParsePos(text)
	local x, y = string.match(text or "", "^(%-?%d+):(%-?%d+)$");
	return tonumber(x), tonumber(y);
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

local PREFIX = "TIR";
local HINT_COLOR = { 0.4, 0.78, 1 };
local BUG_ICON = "Interface\\FrameXML\\Temucraft\\TemucraftIssueBug";
local BUG_ICON_FALLBACK = "Interface\\Icons\\Spell_Nature_InsectSwarm";
local BACKDROP = { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } };
local TIP_BACKDROP = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } };

local reportingOn, buttonOn = false, false;
local pending, pendingTime = false, 0;

local function Send(text) SendAddonMessage(PREFIX, text, "WHISPER", UnitName("player")); end

local function Say(text, r, g, b)
	UIErrorsFrame:AddMessage(text, r or 1, g or 0.82, b or 0, 1, 5);
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffIssue Reporter:|r "..text);
end

local function BoundKey() return GetBindingKey(L.BINDING); end

---------------------------------------------------------------------------------------------------------------------
-- the report

local function AddUnitInfo(t, unit)
	t[unit.."GUID"] = UnitGUID(unit);
	if ( UnitIsPlayer(unit) ) then
		local x, y = GetPlayerMapPosition(unit);
		t[unit.."Position"] = x..", "..y;
	end
	t[unit.."IsDeadOrGhost"] = UnitIsDeadOrGhost(unit);
	t[unit.."Mana"] = UnitMana(unit);
	t[unit.."ManaMax"] = UnitManaMax(unit);
	t[unit.."IsOnTaxi"] = UnitOnTaxi(unit);
end

local function Equipment()
	local out = {};
	for i = 1, 23 do
		local link = GetInventoryItemLink("player", i);
		out[i] = link and string.match(link, ":([%d]+:[%d]+:[%d]+:[%d]+:[%d]+):") or "0:0:0:0:0";
	end
	return table.concat(out, "/");
end

local function Talents()
	local out = {};
	for tab = 1, GetNumTalentTabs() do
		for i = 1, GetNumTalents(tab) do table.insert(out, select(5, GetTalentInfo(tab, i)) or 0); end
	end
	return table.concat(out);
end

local function AddAddons(t)
	local all, loaded, disabled = {}, {}, {};
	for i = 1, GetNumAddOns() do
		local name, _, _, enabled = GetAddOnInfo(i);
		table.insert(all, name);
		table.insert(enabled and loaded or disabled, name);
	end
	t.addons = (#all > 0) and table.concat(all, ", ") or "None";
	t.addonsloaded = (#loaded > 0) and table.concat(loaded, ", ") or nil;
	t.addonsdisabled = (#disabled > 0) and table.concat(disabled, ", ") or nil;
end

-- map, zone and coordinates of the player (the world map is put back when it was open on another map)
local function AddWhere(t)
	local mapOpen = WorldMapFrame and WorldMapFrame:IsShown();
	local continent, zone, level = GetCurrentMapContinent(), GetCurrentMapZone(), GetCurrentMapDungeonLevel();
	SetMapToCurrentZone();
	local x, y = GetPlayerMapPosition("player");
	t.coords = math.floor(x * 100)..", "..math.floor(y * 100);
	t.playerPosition = x..", "..y;
	local continents = { GetMapContinents() };
	t.map = continents[GetCurrentMapContinent()];
	t.currentWorldMapAreaId = GetCurrentMapAreaID();
	t.currentWorldMapZoneId = GetCurrentMapZone();
	t.currentWorldMapMapId = GetCurrentMapContinent();
	t.currentDungeonMapLevel = GetCurrentMapDungeonLevel();
	t.currentDungeonMapLevelCount = GetNumDungeonMapLevels();
	t.currentCorpsePosition = GetCorpseMapPosition();
	if ( mapOpen and (continent ~= GetCurrentMapContinent() or zone ~= GetCurrentMapZone()) ) then
		SetMapZoom(continent, zone);
		if ( level and level > 0 and SetDungeonMapLevel ) then SetDungeonMapLevel(level); end
	end
end

-- subject = { kind, id, name, subType }; text = what the player wrote
local function BuildReport(kind, subject, text, picked)
	local t = {};
	t.feedbacktype = L.FeedbackType(kind, picked);
	t.category = kind;
	t.temucraftClientVersion = TEMUCRAFT_CLIENT_VERSION;
	t.addonTitle = "Temucraft Issue Reporter";
	t.addonVersion = TEMUCRAFT_CLIENT_VERSION;
	t.version, t.build, t.date = GetBuildInfo();
	t.realm = GetRealmName();
	t.name = UnitName("player");
	local sex = ({ "Unknown", "Male", "Female" })[UnitSex("player")] or "Unknown";
	local race, class = UnitRace("player"), UnitClass("player");
	t.character = L.CharacterString(UnitLevel("player"), race, sex, class);
	t.level, t.race, t.sex, t.class = UnitLevel("player"), race, sex, class;
	t.locale = GetLocale();
	t.zone = GetRealZoneText();
	t.area = GetSubZoneText();
	AddWhere(t);
	AddAddons(t);
	t.talents = Talents();
	t.equipment = Equipment();
	t.combats, t.deaths, t.averagelength = 0, 0, 0;
	local _, month, day, year = CalendarGetDate();
	t.reportCalendar = year.."-"..month.."-"..day;
	t.reportDate = L.DateString(date("*t"));
	local hours, minutes = GetGameTime();
	t.reportGameTime = hours..":"..minutes;
	if ( subject ) then
		t.reportSubjectType = L.KINDS[kind] and L.KINDS[kind].subject;
		t.reportSubjectId = subject.id;
		t.reportSubjectSubType = subject.subType;
		t.objectname = subject.name;
	end
	t.currentMinimapZoneText = GetMinimapZoneText();
	t.currentRealZoneText = GetRealZoneText();
	t.currentSubZoneText = GetSubZoneText();
	t.currentZoneText = GetZoneText();
	t.currentZonePvPType, t.currentZonePvPisFFA, t.currentZonePvPfaction = GetZonePVPInfo();
	t.instanceName, t.instanceType, t.instanceDifficultyIndex, t.instanceDifficultyName, t.instanceMaxPlayers,
		t.instancePlayerDifficulty, t.instanceIsDynamic = GetInstanceInfo();
	for _, unit in ipairs({ "player", "target", "mouseover", "focus", "npc", "vehicle", "pet" }) do AddUnitInfo(t, unit); end
	t.text = text;
	return L.Fit(t), t.feedbacktype;
end

---------------------------------------------------------------------------------------------------------------------
-- the dialog

local dialog = CreateFrame("Frame", "TemucraftIssueDialog", UIParent);
dialog:SetWidth(380); dialog:SetHeight(300);
dialog:SetPoint("CENTER", 0, 80);
dialog:SetFrameStrata("DIALOG");
dialog:SetToplevel(true);
dialog:EnableMouse(true);
dialog:SetMovable(true);
dialog:RegisterForDrag("LeftButton");
dialog:SetScript("OnDragStart", dialog.StartMoving);
dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing);
dialog:SetBackdrop(BACKDROP);
dialog:Hide();
tinsert(UISpecialFrames, "TemucraftIssueDialog");
CreateFrame("Button", "TemucraftIssueDialogClose", dialog, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -6, -6);

local dialogIcon = dialog:CreateTexture(nil, "ARTWORK");
dialogIcon:SetWidth(40); dialogIcon:SetHeight(40);
dialogIcon:SetPoint("TOP", 0, -18);
local dialogTitle = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
dialogTitle:SetWidth(330);
local dialogQuestion = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
dialogQuestion:SetWidth(330); dialogQuestion:SetJustifyH("LEFT");

local checks = {};
for i, info in ipairs({ { "bug", "Bug" }, { "feedback", "Feedback" } }) do
	local c = CreateFrame("CheckButton", "TemucraftIssueDialogCheck"..i, dialog, "UICheckButtonTemplate");
	c:SetWidth(24); c:SetHeight(24);
	_G[c:GetName().."Text"]:SetText(info[2]);
	c.value = info[1];
	checks[i] = c;
end
checks[1]:SetPoint("TOPLEFT", dialogQuestion, "BOTTOMLEFT", -2, -4);
checks[2]:SetPoint("LEFT", checks[1], "RIGHT", 70, 0);

local box = CreateFrame("Frame", nil, dialog);
box:SetBackdrop(TIP_BACKDROP);
box:SetBackdropColor(0, 0, 0, 0.8);
box:SetBackdropBorderColor(0.6, 0.6, 0.6, 1);
local scroll = CreateFrame("ScrollFrame", "TemucraftIssueDialogScroll", box, "UIPanelScrollFrameTemplate");
scroll:SetPoint("TOPLEFT", 8, -8); scroll:SetPoint("BOTTOMRIGHT", -28, 8);
local edit = CreateFrame("EditBox", "TemucraftIssueDialogEdit", scroll);
edit:SetMultiLine(true);
edit:SetAutoFocus(false);
edit:SetFontObject(ChatFontNormal);
edit:SetWidth(290); edit:SetHeight(80);
edit:SetMaxLetters(L.MAX_TEXT);
scroll:SetScrollChild(edit);
box:EnableMouse(true);
box:SetScript("OnMouseDown", function() edit:SetFocus(); end);
local counter = dialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
counter:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", -4, -2);

local submit = CreateFrame("Button", "TemucraftIssueDialogSubmit", dialog, "UIPanelButtonTemplate");
submit:SetWidth(120); submit:SetHeight(24);
submit:SetPoint("BOTTOM", 0, 18);
submit:SetText("Submit");

local current = {};   -- kind, subject, picked

local function Picked()
	for _, c in ipairs(checks) do if ( c:GetChecked() ) then return c.value; end end
	return nil;
end

local function UpdateSubmit()
	counter:SetText(L.Counter(edit:GetText()));
	if ( L.CanSubmit(current.kind, edit:GetText(), Picked()) and not pending ) then submit:Enable(); else submit:Disable(); end
end

for _, c in ipairs(checks) do
	c:SetScript("OnClick", function(self)
		PlaySound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
		for _, other in ipairs(checks) do if ( other ~= self ) then other:SetChecked(nil); end end
		UpdateSubmit();
	end);
end
edit:SetScript("OnTextChanged", function(self)
	ScrollingEdit_OnTextChanged(self, scroll);
	UpdateSubmit();
end);
edit:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged);
edit:SetScript("OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, scroll); end);
edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);

-- kind: a key of L.KINDS; subject: { id, name, icon, unit, subType } or nil
function TemucraftIssues_Open(kind, subject)
	if ( not reportingOn ) then
		Say("Issue reporting is off on this realm.");
		return;
	end
	current = { kind = kind, subject = subject };
	local k = L.KINDS[kind];
	dialogTitle:SetText(L.Title(kind, subject and subject.name));
	dialogQuestion:SetText(k.question);
	local top = -18;
	dialogIcon:SetTexture(nil);
	if ( subject and subject.unit and subject.guid and UnitGUID(subject.unit) == subject.guid ) then
		SetPortraitTexture(dialogIcon, subject.unit);
		dialogIcon:Show();
	elseif ( subject and subject.icon ) then
		dialogIcon:SetTexture(subject.icon);
		dialogIcon:Show();
	else
		dialogIcon:Hide();
	end
	if ( dialogIcon:IsShown() ) then top = -64; end
	dialogTitle:ClearAllPoints(); dialogTitle:SetPoint("TOP", 0, top);
	dialogQuestion:ClearAllPoints(); dialogQuestion:SetPoint("TOPLEFT", 25, top - 30);
	for _, c in ipairs(checks) do c:SetChecked(nil); if ( k.choose ) then c:Show(); else c:Hide(); end end
	local boxTop = k.choose and 30 or 8;
	box:ClearAllPoints();
	box:SetPoint("TOPLEFT", dialogQuestion, "BOTTOMLEFT", -5, -boxTop);
	box:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -20, 50);
	dialog:SetHeight(-top + 30 + 20 + boxTop + 110 + 50);
	edit:SetText("");
	UpdateSubmit();
	dialog:Show();
	edit:SetFocus();
end

submit:SetScript("OnClick", function()
	local text = L.Trim(edit:GetText());
	if ( not L.CanSubmit(current.kind, text, Picked()) ) then return; end
	local json, feedbacktype = BuildReport(current.kind, current.subject, text, Picked());
	if ( feedbacktype == "1" ) then ReportSuggestion(json); else ReportBug(json); end
	pending, pendingTime = true, GetTime();
	dialog:Hide();
	PlaySound("igMainMenuOptionCheckBoxOn");
end);

---------------------------------------------------------------------------------------------------------------------
-- the button and its menu

local button = CreateFrame("Button", "TemucraftIssueReporterButton", UIParent);
button:SetWidth(36); button:SetHeight(36);
button:SetFrameStrata("MEDIUM");
button:SetMovable(true);
button:SetClampedToScreen(true);
button:RegisterForClicks("LeftButtonUp");
button:RegisterForDrag("LeftButton");
button:Hide();
local icon = button:CreateTexture(nil, "ARTWORK");
icon:SetAllPoints();
if ( not icon:SetTexture(BUG_ICON) ) then icon:SetTexture(BUG_ICON_FALLBACK); end
local border = button:CreateTexture(nil, "OVERLAY");
border:SetTexture("Interface\\Buttons\\UI-Quickslot2");
border:SetPoint("CENTER"); border:SetWidth(60); border:SetHeight(60);
button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress");
local badge = CreateFrame("Frame", nil, button);
badge:SetWidth(16); badge:SetHeight(16);
badge:SetPoint("TOPRIGHT", 5, 5);
badge:SetFrameLevel(button:GetFrameLevel() + 2);
local badgeBack = badge:CreateTexture(nil, "BACKGROUND");
badgeBack:SetTexture("Interface\\Minimap\\UI-Minimap-Background");
badgeBack:SetVertexColor(0.1, 0.25, 0.6);
badgeBack:SetAllPoints();
local badgeText = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
badgeText:SetPoint("CENTER", 0, 0);
badgeText:SetText("i");
badgeText:SetTextColor(1, 0.82, 0);

local function PlaceButton()
	button:ClearAllPoints();
	local x, y = L.ParsePos(TemucraftStore_Get and TemucraftStore_Get("A", "ui.issuepos"));
	if ( x and y ) then button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y);
	else button:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 150); end
end
PlaceButton();

button:SetScript("OnDragStart", function(self) if ( IsShiftKeyDown() ) then self:StartMoving(); end end);
button:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing();
	local x, y = self:GetLeft(), self:GetBottom();
	if ( x and y and TemucraftStore_Set ) then TemucraftStore_Set("A", "ui.issuepos", L.PosText(x, y)); end
end);
button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP");
	GameTooltip:SetText("How Can I Help?", 1, 1, 1);
	GameTooltip:AddLine("If possible create bugs using the tooltip keybind to help us identify the issue easier.", nil, nil, nil, true);
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("Please Provide:", 1, 1, 1);
	GameTooltip:AddLine("-What you were doing");
	GameTooltip:AddLine("-What you observed");
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("Automatically Collected:", 1, 1, 1);
	GameTooltip:AddLine("-Your world location");
	GameTooltip:AddLine("-Your character information");
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("Shift-drag to move.", 0.5, 0.5, 0.5);
	GameTooltip:Show();
end);
button:SetScript("OnLeave", function() GameTooltip:Hide(); end);

local menu = CreateFrame("Frame", "TemucraftIssueMenu", UIParent);
menu:SetWidth(280);
menu:SetFrameStrata("DIALOG");
menu:SetBackdrop(TIP_BACKDROP);
menu:SetBackdropColor(0.05, 0.05, 0.08, 0.95);
menu:SetBackdropBorderColor(0.6, 0.6, 0.6, 1);
menu:EnableMouse(true);
menu:Hide();
tinsert(UISpecialFrames, "TemucraftIssueMenu");
local menuTitle = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal");
menuTitle:SetPoint("TOP", 0, -10);
menuTitle:SetText("Issue Reporter");

local function OpenCategory(key)
	menu:Hide();
	if ( key == "zone" ) then
		TemucraftIssues_Open("zone", { id = GetCurrentMapAreaID(), name = GetRealZoneText() });
	else
		TemucraftIssues_Open(key, nil);
	end
end

local y = -30;
for i, c in ipairs(L.CATEGORIES) do
	local row = CreateFrame("Button", "TemucraftIssueMenuRow"..i, menu);
	row:SetPoint("TOPLEFT", 8, y); row:SetPoint("RIGHT", -8, 0);
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");
	local t = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	t:SetPoint("TOPLEFT", 6, -4); t:SetWidth(252); t:SetJustifyH("LEFT");
	t:SetText(c.title);
	local d = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -2); d:SetWidth(252); d:SetJustifyH("LEFT");
	d:SetText(c.desc);
	local h = 4 + t:GetHeight() + 2 + d:GetHeight() + 6;
	row:SetHeight(h);
	row:SetScript("OnClick", function() PlaySound("igMainMenuOptionCheckBoxOn"); OpenCategory(c.key); end);
	y = y - h - 2;
end
menu:SetHeight(-y + 8);

function TemucraftIssues_ToggleMenu()
	if ( menu:IsShown() ) then menu:Hide(); return; end
	if ( not reportingOn ) then Say("Issue reporting is off on this realm."); return; end
	menu:ClearAllPoints();
	if ( button:IsShown() ) then
		menu:SetPoint("BOTTOM", button, "TOP", 0, 8);
	else
		menu:SetPoint("CENTER", UIParent, "CENTER", 0, 100);
	end
	menu:Show();
end
button:SetScript("OnClick", function() GameTooltip:Hide(); TemucraftIssues_ToggleMenu(); end);

---------------------------------------------------------------------------------------------------------------------
-- tooltips: what each one shows, and the hint line

-- subject: { kind, id, name, icon, unit, subType }
local function AddHint(tooltip)
	local s = tooltip.tcIssue;
	if ( not s or tooltip.tcIssueHint or not reportingOn ) then return; end
	local text = L.HintText(s.kind, BoundKey());
	if ( not text ) then return; end
	tooltip.tcIssueHint = true;
	tooltip:AddLine(text, HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3], true);
	tooltip:Show();
end

-- other files add their lines in the same frame (some a frame later): the hint goes on after them
local queued = {};
local later = CreateFrame("Frame");
later:Hide();
later:SetScript("OnUpdate", function(self)
	self:Hide();
	for tooltip in pairs(queued) do
		queued[tooltip] = nil;
		if ( tooltip:IsShown() ) then AddHint(tooltip); end
	end
end);

local function SetSubject(tooltip, subject, now)
	if ( not subject or not subject.kind ) then return; end
	if ( tooltip.tcIssue and tooltip.tcIssue.kind == subject.kind and tooltip.tcIssue.id == subject.id ) then return; end
	tooltip.tcIssue = subject;
	tooltip.tcIssueHint = nil;
	if ( now ) then AddHint(tooltip); else queued[tooltip] = true; later:Show(); end
end

local function Cleared(tooltip) tooltip.tcIssue, tooltip.tcIssueHint = nil, nil; end

local function SpellSubject(id)
	if ( not id ) then return nil; end
	local name, _, iconPath = GetSpellInfo(id);
	return name and { kind = "spell", id = id, name = name, icon = iconPath } or nil;
end

local function QuestSubject(questIndex)
	if ( not questIndex or questIndex < 1 ) then return nil; end
	local title, _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(questIndex);
	if ( not title or isHeader ) then return nil; end
	return { kind = "quest", id = questID, name = title, icon = "Interface\\GossipFrame\\AvailableQuestIcon" };
end

for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
	local tooltip = _G[name];
	tooltip:HookScript("OnTooltipCleared", Cleared);
	tooltip:HookScript("OnTooltipSetItem", function(self)
		local itemName, link = self:GetItem();
		local id = link and tonumber(string.match(link, "item:(%d+)"));
		if ( id ) then SetSubject(self, { kind = "item", id = id, name = itemName, icon = GetItemIcon(id) }); end
	end);
	tooltip:HookScript("OnTooltipSetSpell", function(self)
		local _, _, id = self:GetSpell();
		if ( type(id) == "number" ) then SetSubject(self, SpellSubject(id)); end
	end);
	hooksecurefunc(tooltip, "SetHyperlink", function(self, link)
		if ( type(link) ~= "string" ) then return; end
		local spellId = tonumber(string.match(link, "spell:(%d+)") or string.match(link, "enchant:(%d+)"));
		if ( spellId ) then SetSubject(self, SpellSubject(spellId)); return; end
		local questId, questName = L.QuestFromLink(link);
		if ( questId ) then
			SetSubject(self, { kind = "quest", id = questId, name = questName or (self:IsShown() and _G[self:GetName().."TextLeft1"]:GetText()),
				icon = "Interface\\GossipFrame\\AvailableQuestIcon" });
		end
	end);
end

GameTooltip:HookScript("OnTooltipSetUnit", function(self)
	local name, unit = self:GetUnit();
	if ( not unit or UnitIsPlayer(unit) ) then return; end
	local guid = UnitGUID(unit);
	local id = L.CreatureId(guid);
	if ( id ) then SetSubject(self, { kind = "creature", id = id, name = name, unit = unit, guid = guid, subType = "Creature" }); end
end);

local function AuraHook(filter)
	return function(tooltip, unit, index, auraFilter)
		local id = select(11, UnitAura(unit, index, filter or auraFilter));
		SetSubject(tooltip, SpellSubject(id));
	end
end
hooksecurefunc(GameTooltip, "SetUnitAura", AuraHook(nil));
hooksecurefunc(GameTooltip, "SetUnitBuff", AuraHook("HELPFUL"));
hooksecurefunc(GameTooltip, "SetUnitDebuff", AuraHook("HARMFUL"));

-- quest log titles: a tooltip with the quest's title (stock shows one only for party members on it)
if ( QuestLogTitleButton_OnEnter ) then hooksecurefunc("QuestLogTitleButton_OnEnter", function(self)
	local subject = QuestSubject(self:GetID());
	if ( not subject or not reportingOn or not BoundKey() ) then return; end
	if ( not GameTooltip:IsOwned(self) or not GameTooltip:IsShown() ) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(subject.name);
	end
	SetSubject(GameTooltip, subject, true);
end); end

-- quest tracker lines
if ( WatchFrameLinkButtonTemplate_Highlight ) then hooksecurefunc("WatchFrameLinkButtonTemplate_Highlight", function(self, onEnter)
	if ( self.type ~= "QUEST" or not self.index ) then return; end
	if ( onEnter ) then
		local subject = QuestSubject(GetQuestIndexForWatch(self.index));
		if ( not subject or not reportingOn or not BoundKey() ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT");
		GameTooltip:SetText(subject.name);
		SetSubject(GameTooltip, subject, true);
	elseif ( GameTooltip:IsOwned(self) ) then
		GameTooltip:Hide();
	end
end); end

-- world map quest POIs (their tooltip is WorldMapTooltip)
if ( WorldMapTooltip and WorldMapQuestPOI_SetTooltip ) then
	WorldMapTooltip:HookScript("OnTooltipCleared", Cleared);
	hooksecurefunc("WorldMapQuestPOI_SetTooltip", function(poiButton, questLogIndex)
		local subject = QuestSubject(questLogIndex);
		if ( subject ) then SetSubject(WorldMapTooltip, subject, true); end
	end);
end

---------------------------------------------------------------------------------------------------------------------
-- the key

local keyButton = CreateFrame("Button", "TemucraftIssueKeyButton", UIParent);
keyButton:Hide();
keyButton:SetScript("OnClick", function()
	if ( not reportingOn ) then return; end
	for _, tooltip in ipairs({ GameTooltip, WorldMapTooltip, ItemRefTooltip }) do
		-- a clicked link's tooltip stays open: only while the mouse is on it
		if ( tooltip and tooltip:IsShown() and tooltip.tcIssue and (tooltip ~= ItemRefTooltip or MouseIsOver(tooltip)) ) then
			local s = tooltip.tcIssue;
			TemucraftIssues_Open(s.kind, s);
			return;
		end
	end
	TemucraftIssues_Open("general", nil);
end);

local function SetKey(key)
	if ( InCombatLockdown() ) then Say("Key bindings can't be changed in combat."); return; end
	for _ = 1, 5 do
		local old = BoundKey();
		if ( not old ) then break; end
		SetBinding(old);
	end
	if ( key ) then SetBinding(key, L.BINDING); end
	SaveBindings(GetCurrentBindingSet());
	if ( TemucraftStore_Set ) then TemucraftStore_Set("A", "ui.issuekey", key and "set" or "none"); end
end

-- F6 once, when nothing is bound to the report yet, F6 is free and the player never unbound it
local function DefaultKey()
	if ( BoundKey() or InCombatLockdown() ) then return; end
	if ( TemucraftStore_Get and TemucraftStore_Get("A", "ui.issuekey") == "none" ) then return; end
	local action = GetBindingAction(L.DEFAULT_KEY);
	if ( action and action ~= "" ) then return; end
	SetBinding(L.DEFAULT_KEY, L.BINDING);
	SaveBindings(GetCurrentBindingSet());
end

SLASH_TEMUCRAFTISSUE1 = "/issue";
SLASH_TEMUCRAFTISSUE2 = "/bug";
SlashCmdList["TEMUCRAFTISSUE"] = function() TemucraftIssues_ToggleMenu(); end;
SLASH_TEMUCRAFTISSUEKEY1 = "/issuekey";
SlashCmdList["TEMUCRAFTISSUEKEY"] = function(msg)
	msg = string.upper(L.Trim(msg));
	if ( msg == "" ) then
		Say("Report key: "..(BoundKey() or "none")..". /issuekey <key> (e.g. F6, SHIFT-F6) or /issuekey none.");
	elseif ( msg == "NONE" ) then
		SetKey(nil);
		Say("The report key is unbound.");
	else
		SetKey(msg);
		Say("Report key: "..(BoundKey() or "none")..".");
	end
end;

---------------------------------------------------------------------------------------------------------------------
-- the server

local function Apply()
	if ( reportingOn and buttonOn ) then button:Show(); else button:Hide(); menu:Hide(); end
	if ( not reportingOn ) then dialog:Hide(); end
end

local events = CreateFrame("Frame", "TemucraftIssuesFrame");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
events:RegisterEvent("CHAT_MSG_ADDON");
events:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		Send("HELLO");
		return;
	end
	if ( prefix ~= PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") ) then return; end
	local kind, a, b = L.ParseServer(message);
	if ( kind == "STATE" ) then
		reportingOn, buttonOn = (a == "1"), (b == "1");
		Apply();
		if ( reportingOn ) then
			if ( TemucraftStore_OnReady ) then TemucraftStore_OnReady(function() PlaceButton(); DefaultKey(); end); else DefaultKey(); end
		end
	elseif ( kind == "ACK" ) then
		pending = false;
		Say("Thanks! Report #"..a.." sent.");
	elseif ( kind == "RATE" ) then
		pending = false;
		Say(L.RateText(a), 1, 0.3, 0.3);
	elseif ( kind == "OFF" ) then
		pending = false;
		reportingOn = false;
		Apply();
		Say("Issue reporting is off on this realm.");
	elseif ( kind == "ERR" ) then
		pending = false;
		Say("The report could not be sent. Please try a shorter text.", 1, 0.3, 0.3);
	end
end);
-- no answer from the server within 10 seconds: the report went out the stock way
events:SetScript("OnUpdate", function()
	if ( pending and GetTime() - pendingTime > 10 ) then
		pending = false;
		Say("Thanks! Your report was sent.");
	end
end);
