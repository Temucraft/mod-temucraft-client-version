-- Temucraft window look, shared by our windows: stock 3.3.5 art only (DialogFrame gold border and header, the
-- achievement window's dark stone and desaturated parchment, its category bars and highlight).
--   TemucraftStyle_Window(frame, title)     textured dark window, gold border, gold header with the title (returns
--                                            the title FontString)
--   TemucraftStyle_Inset(frame, alpha)      a slightly lighter, parchment-textured inset with a thin gold edge
--   TemucraftStyle_Header(fontString)       a dark header bar behind a section title (the bar spans its parent);
--                                            returns the bar texture
--   TemucraftStyle_Bar(frame)               the same bar filling a frame / button (list section rows, collapsible
--                                            category bars); returns the texture
--   TemucraftStyle_Highlight(button)        the gold category highlight (as a highlight texture); returns it
--   TemucraftStyle_Glow(frame)              the same gold glow as a plain texture, for "selected"; returns it
--   TemucraftStyle_Line(parent)             a thin gold separator line; returns it
TemucraftStyle = {
	WINDOW_BG = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	WINDOW_STONE = "Interface\\AchievementFrame\\UI-Achievement-StatsBackground",
	WINDOW_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	WINDOW_HEADER = "Interface\\DialogFrame\\UI-DialogBox-Gold-Header",
	INSET_BG = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal-Desaturated",
	INSET_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border",
	BAR = "Interface\\AchievementFrame\\UI-Achievement-Category-Background",
	HIGHLIGHT = "Interface\\AchievementFrame\\UI-Achievement-Category-Highlight",
};
local S = TemucraftStyle;

if ( not CreateFrame ) then return; end   -- tests load only the names

function TemucraftStyle_Window(frame, title)
	frame:SetBackdrop({ bgFile = S.WINDOW_BG, edgeFile = S.WINDOW_BORDER, tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 } });
	local stone = frame:CreateTexture(nil, "BACKGROUND");
	stone:SetTexture(S.WINDOW_STONE);
	stone:SetPoint("TOPLEFT", 11, -12); stone:SetPoint("BOTTOMRIGHT", -12, 11);
	stone:SetVertexColor(0.75, 0.75, 0.75, 0.9);
	frame.temucraftStone = stone;
	local header = frame:CreateTexture(nil, "ARTWORK");
	header:SetTexture(S.WINDOW_HEADER);
	header:SetWidth(320); header:SetHeight(64);
	header:SetPoint("TOP", 0, 12);
	frame.temucraftHeader = header;
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	text:SetPoint("TOP", header, "TOP", 0, -14);
	text:SetText(title or "");
	return text;
end

function TemucraftStyle_Inset(frame, alpha)
	frame:SetBackdrop({ bgFile = S.INSET_BG, edgeFile = S.INSET_BORDER, tile = false, edgeSize = 14,
		insets = { left = 4, right = 4, top = 4, bottom = 4 } });
	frame:SetBackdropColor(0.32, 0.30, 0.28, alpha or 0.95);
	frame:SetBackdropBorderColor(0.78, 0.62, 0.3, 1);
end

function TemucraftStyle_Bar(frame)
	local bar = frame:CreateTexture(nil, "BACKGROUND");
	bar:SetTexture(S.BAR);
	bar:SetTexCoord(0, 0.6640625, 0, 1);
	bar:SetAllPoints(frame);
	return bar;
end

function TemucraftStyle_Header(fontString)
	local parent = fontString:GetParent();
	local bar = parent:CreateTexture(nil, "BACKGROUND");
	bar:SetTexture(S.BAR);
	bar:SetTexCoord(0, 0.6640625, 0, 1);
	bar:SetHeight(28);
	bar:SetPoint("LEFT", parent, "LEFT", 2, 0);
	bar:SetPoint("RIGHT", parent, "RIGHT", -2, 0);
	bar:SetPoint("TOP", fontString, "TOP", 0, 8);
	return bar;
end

function TemucraftStyle_Highlight(button)
	button:SetHighlightTexture(S.HIGHLIGHT, "ADD");
	local t = button:GetHighlightTexture();
	t:SetTexCoord(0, 0.6640625, 0, 1);
	return t;
end

function TemucraftStyle_Glow(frame)
	local t = frame:CreateTexture(nil, "ARTWORK");
	t:SetTexture(S.HIGHLIGHT);
	t:SetTexCoord(0, 0.6640625, 0, 1);
	t:SetBlendMode("ADD");
	t:SetAllPoints(frame);
	return t;
end

function TemucraftStyle_Line(parent)
	local t = parent:CreateTexture(nil, "ARTWORK");
	t:SetTexture(1, 0.82, 0, 0.35);
	t:SetHeight(1);
	return t;
end
