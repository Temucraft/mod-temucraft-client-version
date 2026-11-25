-- Temucraft guild bank (retail look): the stock GuildBankFrame (Blizzard_GuildBankUI, loaded when the bank opens)
-- dressed again: a dark window with the title "Guild Bank", the tab's name with its access ("Tab 1 (Full Access)"),
-- the tab icons down the right side, a Search box that dims every item whose name doesn't match, "Remaining Daily
-- Withdrawals for <your rank>: N Stacks", the "Available Amount" bar, Withdraw / Deposit, and the bottom tabs Guild
-- Bank / Log / Money Log / Info. Log and Money Log list who deposited (green) or withdrew (red) what, names in class
-- colours, money as Gold / Silver / Copper, and how long ago ("(10 months ago)"): every entry ever made when
-- mod-temucraft-guild keeps the archive ("Show more..." pages back), else the stock last 25.
-- The item buttons, tabs and buttons stay the stock ones with their stock scripts (PickupGuildBankItem,
-- SplitGuildBankItem, the withdraw / deposit popups), so moving items works as it always does; only the look and
-- the texts change, and only out of combat. "Classic guild bank" (Interface Options > Temucraft, /tui) leaves the
-- stock frame alone.

TemucraftGuildBankLogic = {};
local B = TemucraftGuildBankLogic;

-- whether an item name matches the search text (plain, any case; an empty search matches everything)
function B.Matches(name, query)
	if ( not query or query == "" ) then return true; end
	if ( not name ) then return false; end
	return string.find(string.lower(name), string.lower(query), 1, true) ~= nil;
end

function B.NameFromLink(link) return link and string.match(link, "%[(.-)%]"); end

-- "Remaining Daily Withdrawals for Officer: 5 Stacks" (remaining < 0: unlimited)
function B.WithdrawText(rank, remaining)
	local stacks;
	if ( remaining > 0 ) then stacks = remaining.." "..(remaining == 1 and "Stack" or "Stacks");
	elseif ( remaining == 0 ) then stacks = "None";
	else stacks = "Unlimited"; end
	return "Remaining Daily Withdrawals for "..(rank or "your rank")..": |cffffffff"..stacks.."|r";
end

-- the stock bank log line's type -> the same as the archive's
B.STOCK_MONEY = { deposit = "deposit", withdraw = "withdraw", repair = "repair", withdrawForTab = "withdrawForTab", buyTab = "buyTab" };

if ( not CreateFrame ) then return; end   -- tests load only the logic

local G = TemucraftGuildLogic;
local MONEY_TAB = (MAX_GUILDBANK_TABS or 6) + 1;
local skinned, hidden, ours = false, {}, {};
local searchBox, logList;
local requested = {};

local function Classic() return TemucraftUI_IsClassic("gbank"); end

local function TabName(tab)
	local name = GetGuildBankTabInfo(tab);
	if ( not name or name == "" ) then name = "Tab "..tab; end
	return name;
end

-- dim what the search doesn't find
local function ApplySearch()
	if ( not GuildBankFrame or GuildBankFrame.mode ~= "bank" ) then return; end
	local query = (not Classic() and searchBox) and strtrim(searchBox:GetText() or "") or "";
	local tab = GetCurrentGuildBankTab();
	for i = 1, (MAX_GUILDBANK_SLOTS_PER_TAB or 98) do
		local column, index = ceil((i - 0.5) / 14), mod(i, 14);
		if ( index == 0 ) then index = 14; end
		local button = _G["GuildBankColumn"..column.."Button"..index];
		if ( button ) then
			local match = query == "" or B.Matches(B.NameFromLink(GetGuildBankItemLink(tab, i)), query);
			button:SetAlpha(match and 1 or 0.2);
		end
	end
end

-- Log / Money Log: the archive's entries, else the stock ones
local function RefreshLog()
	if ( not skinned or Classic() or not logList or not GuildBankFrameLog:IsShown() ) then return; end
	local mode = GuildBankFrame.mode;
	if ( mode ~= "log" and mode ~= "moneylog" ) then return; end
	local tab = (mode == "moneylog") and MONEY_TAB or GetCurrentGuildBankTab();
	GuildBankTransactionsScrollFrame:Hide();
	local items = {};
	if ( TemucraftGuild_HasServer and TemucraftGuild_HasServer("bank") ) then
		if ( not requested[tab] ) then
			requested[tab] = true;
			G.Ask("BLOG~"..tab.."~0");
		end
		local log = G.bankLog[tab];
		for _, e in ipairs(log and log.entries or {}) do
			local line = G.FromArchive(e, TabName);
			table.insert(items, { text = G.BankLine(line), link = line.link });
		end
		logList.onMore = function() G.Ask("BLOG~"..tab.."~"..#((G.bankLog[tab] or {}).entries or {})); end;
		logList:SetItems(items, log and log.more);
	elseif ( mode == "log" ) then
		for i = GetNumGuildBankTransactions(tab), 1, -1 do
			local type, name, link, count, tab1, tab2, year, month, day, hour = GetGuildBankTransaction(tab, i);
			local line = { what = type, name = name, class = G.ClassOf(name), link = link, count = count,
				tab1 = tab1 and TabName(tab1), tab2 = tab2 and TabName(tab2), seconds = G.StockSeconds(year, month, day, hour) };
			table.insert(items, { text = G.BankLine(line), link = link });
		end
		logList:SetItems(items, false);
	else
		for i = GetNumGuildBankMoneyTransactions(), 1, -1 do
			local type, name, amount, year, month, day, hour = GetGuildBankMoneyTransaction(i);
			local line = { what = B.STOCK_MONEY[type] or type, name = name, class = G.ClassOf(name), money = amount or 0,
				seconds = G.StockSeconds(year, month, day, hour) };
			table.insert(items, { text = G.BankLine(line) });
		end
		logList:SetItems(items, false);
	end
end
G.On("banklog", function(tab) RefreshLog(); end);

-- the texts the stock code writes on every update
local function AfterUpdateTabs()
	if ( not skinned or Classic() ) then return; end
	for _, name in ipairs({ "GuildBankTabTitleBackground", "GuildBankTabTitleBackgroundLeft", "GuildBankTabTitleBackgroundRight",
		"GuildBankTabLimitBackground", "GuildBankTabLimitBackgroundLeft", "GuildBankTabLimitBackgroundRight" }) do
		if ( _G[name] ) then _G[name]:Hide(); end
	end
	if ( GuildBankLimitLabel:IsShown() ) then
		local _, _, _, _, _, remaining = GetGuildBankTabInfo(GetCurrentGuildBankTab());
		local _, rank = GetGuildInfo("player");
		GuildBankLimitLabel:SetText(B.WithdrawText(rank, remaining or 0));
	end
	ours.guild:SetText(GetGuildInfo("player") or "");
end

local function SetSkin(on)
	for _, region in ipairs(hidden) do if ( on ) then region:Hide(); else region:Show(); end end
	for key, region in pairs(ours) do if ( on ) then region:Show(); else region:Hide(); end end
	GuildBankFrame:SetBackdrop(on and {
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } } or nil);
	GuildBankMessageFrame:SetAlpha(on and 0 or 1);
	if ( on ) then logList:Show(); else logList:Hide(); end
	if ( not on and searchBox ) then searchBox:SetText(""); end
	if ( GuildBankFrame:IsShown() ) then
		GuildBankFrame_UpdateTabs();
		GuildBankFrame_Update();
		if ( GuildBankFrame.mode == "log" ) then GuildBankFrame_UpdateLog(); elseif ( GuildBankFrame.mode == "moneylog" ) then GuildBankFrame_UpdateMoneyLog(); end
	end
end

local function Skin()
	if ( skinned or not GuildBankFrame ) then return; end
	skinned = true;
	local f = GuildBankFrame;
	for _, name in ipairs({ "GuildBankFrameLeft", "GuildBankFrameRight", "GuildBankFramePortrait", "GuildBankEmblemFrame" }) do
		if ( _G[name] ) then table.insert(hidden, _G[name]); end
	end

	ours.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	ours.title:SetPoint("TOPLEFT", 24, -18);
	ours.title:SetText(GUILD_BANK or "Guild Bank");
	ours.guild = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	ours.guild:SetPoint("LEFT", ours.title, "RIGHT", 10, -1);

	-- the search box above the grid, on the right
	searchBox = CreateFrame("EditBox", "TemucraftGuildBankSearch", f, "InputBoxTemplate");
	searchBox:SetWidth(170); searchBox:SetHeight(20);
	searchBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -34, -42);
	searchBox:SetAutoFocus(false);
	local hint = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	hint:SetPoint("LEFT", 2, 0);
	hint:SetText(SEARCH or "Search");
	local function Hint() if ( searchBox:HasFocus() or (searchBox:GetText() or "") ~= "" ) then hint:Hide(); else hint:Show(); end end
	searchBox:SetScript("OnTextChanged", function() Hint(); ApplySearch(); end);
	searchBox:SetScript("OnEditFocusGained", Hint);
	searchBox:SetScript("OnEditFocusLost", Hint);
	searchBox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); end);
	searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
	ours.search = searchBox;

	-- the "Available Amount" bar behind the label and the money (a texture of the frame, under its texts)
	local bar = f:CreateTexture(nil, "BORDER");
	bar:SetPoint("LEFT", GuildBankMoneyLimitLabel, "LEFT", -8, 0);
	bar:SetPoint("RIGHT", GuildBankFrameWithdrawButton, "LEFT", -10, 0);
	bar:SetHeight(22);
	bar:SetTexture(0, 0, 0, 0.65);
	ours.bar = bar;

	-- the log list, over the stock message frame
	logList = TemucraftGuild_CreateList(GuildBankFrameLog, 19, 16);
	logList:SetAllPoints(GuildBankMessageFrame);
	logList:SetFrameLevel(GuildBankMessageFrame:GetFrameLevel() + 2);
	logList.empty = "Nothing in this log.";

	hooksecurefunc("GuildBankFrame_UpdateTabs", AfterUpdateTabs);
	hooksecurefunc("GuildBankFrame_Update", function() ApplySearch(); RefreshLog(); end);
	hooksecurefunc("GuildBankFrame_UpdateLog", RefreshLog);
	hooksecurefunc("GuildBankFrame_UpdateMoneyLog", RefreshLog);
	hooksecurefunc("GuildBankLogScroll", function() if ( not Classic() ) then GuildBankTransactionsScrollFrame:Hide(); end end);
	-- a log page asked again whenever its tab is shown again
	hooksecurefunc("GuildBankFrameTab_OnClick", function() wipe(requested); RefreshLog(); end);
	hooksecurefunc("GuildBankTab_OnClick", function() wipe(requested); RefreshLog(); end);
	f:HookScript("OnShow", function() wipe(requested); end);

	SetSkin(not Classic());
end

-- layout changes only out of combat
local pending = false;
local function TrySkin()
	if ( skinned or not GuildBankFrame ) then return; end
	if ( InCombatLockdown() ) then pending = true; return; end
	Skin();
end

TemucraftUI_OnChange("classicgbank", function(on)
	if ( not skinned ) then return; end
	if ( InCombatLockdown() ) then pending = true; return; end
	SetSkin(not on);
end);

local events = CreateFrame("Frame");
events:RegisterEvent("ADDON_LOADED");
events:RegisterEvent("PLAYER_REGEN_ENABLED");
events:SetScript("OnEvent", function(self, event, name)
	if ( event == "ADDON_LOADED" ) then
		if ( name == "Blizzard_GuildBankUI" ) then TrySkin(); end
	elseif ( pending ) then
		pending = false;
		if ( not skinned ) then TrySkin(); else SetSkin(not Classic()); end
	end
end);
if ( IsAddOnLoaded and IsAddOnLoaded("Blizzard_GuildBankUI") ) then TrySkin(); end
