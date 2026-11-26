-- Temucraft Options: one retail-style Options window (Esc > Options) in place of the four stock windows (System,
-- Sound, Interface, Key Bindings). Tabs Game | AddOns at the top left, Search at the top right, Close at the bottom.
--   Game:   the category list on the left (Gameplay / Accessibility / System), the page on the right: title,
--           Defaults, white sub-headers and rows (gold label, control on the right: checkbox, < value > selector,
--           < slider > with its value). Settings apply as they change; Graphics keeps an Apply button for what needs
--           a display restart (resolution, refresh, multisampling, vsync, window mode ...).
--   AddOns: every addon's Interface Options page (alphabetical, "+" for sub-pages), our Temucraft page and a
--           DragonUI link; the addon's own panel is shown on the right (the stock panel, moved in and back).
-- The Game pages are rebuilt, but every row drives the stock control under it (InterfaceOptions*, VideoOptions*,
-- AudioOptions* panels): the same CVars, uvars, setFuncs, dependent controls and restarts, so nothing the stock
-- frames do is lost and the classic windows stay in step. Key Bindings is rebuilt on the binding API
-- (GetBinding / SetBinding / SaveBindings), out of combat only. "Classic options menu" (Interface > Temucraft)
-- brings back the Esc menu's Options +/- with the four stock windows.
--   TemucraftOptions_Open(what, lastFrame)   what: a page key ("controls", "graphics", "keybindings" ...), an addon
--                                    panel or its name; nil = the last page. lastFrame: shown again on close (the
--                                    game menu). Opens on the next frame.
--   TemucraftOptions_Toggle()
--   TemucraftOptions_ServerRow(name, label, tooltip)   a row for a mod-temucraft-player-settings switch (see below)
TemucraftOptionsLogic = {};
local L = TemucraftOptionsLogic;

-- [[ the pages ]] --
-- a row: { stock = <stock control name>, family = "interface" | "video" | "audio", sub = indented, label = fallback,
--          fmt = slider value format, release = apply a slider when let go } or a custom row { kind = ... }
local function I(name, sub, label, extra) local r = extra or {}; r.stock = "InterfaceOptions"..name; r.family = "interface"; r.sub = sub; r.label = label; return r; end
local function V(name, sub, label, extra) local r = extra or {}; r.stock = "VideoOptions"..name; r.family = "video"; r.sub = sub; r.label = label; return r; end
local function A(name, sub, label, extra) local r = extra or {}; r.stock = "AudioOptions"..name; r.family = "audio"; r.sub = sub; r.label = label; return r; end
local function CV(cvar, label, tooltip) return { kind = "cvar", cvar = cvar, label = label, tooltip = tooltip }; end
-- a CVar slider: min, max, step (the character select Options window has the same rows, so both show the same value)
local function CVS(cvar, label, min, max, step, tooltip) return { kind = "cvarslider", cvar = cvar, label = label, min = min, max = max, step = step, tooltip = tooltip }; end

L.SECTIONS = { "Gameplay", "Accessibility", "System" };
L.PAGES = {
	{ key = "controls", section = "Gameplay", title = "Controls", groups = {
		{ rows = {
			I("ControlsPanelStickyTargeting", nil, "Sticky Targeting"),
			I("ControlsPanelAutoDismount", nil, "Auto Dismount in Flight"),
			I("ControlsPanelAutoClearAFK", nil, "Auto Clear AFK"),
			I("ControlsPanelAutoLootCorpse", nil, "Auto Loot"),
			I("ControlsPanelAutoLootKeyDropDown", true, "Auto Loot Key"),
			I("ControlsPanelLootAtMouse", nil, "Open Loot Window at Mouse"),
			CV("interactOnLeftClick", "Interact on Left Click"),
		} },
		{ header = "Mouse", rows = {
			I("MousePanelInvertMouse", nil, "Invert Mouse"),
			I("MousePanelMouseLookSpeedSlider", nil, "Mouse Look Speed"),
			I("MousePanelMouseSensitivitySlider", nil, "Mouse Sensitivity"),
			I("MousePanelWoWMouse", nil, "Enable WoW Mouse"),
			I("MousePanelClickToMove", nil, "Click-to-Move"),
			I("MousePanelClickMoveStyleDropDown", true, "Click-to-Move Camera Style"),
		} },
		{ header = "Camera", rows = {
			I("CameraPanelWaterCollision", nil, "Water Collision"),
			I("CameraPanelFollowTerrain", nil, "Follow Terrain"),
			I("CameraPanelHeadBob", nil, "Head Bob"),
			I("CameraPanelSmartPivot", nil, "Smart Pivot"),
			I("CameraPanelFollowSpeedSlider", nil, "Auto-Follow Speed"),
			I("CameraPanelMaxDistanceSlider", nil, "Max Camera Distance"),
			I("CameraPanelStyleDropDown", nil, "Camera Following Style"),
		} },
	} },
	{ key = "interface", section = "Gameplay", title = "Interface", groups = {
		{ header = "Display", rows = {
			I("DisplayPanelShowHelm", nil, "Show Helm"),
			I("DisplayPanelShowCloak", nil, "Show Cloak"),
			I("DisplayPanelRotateMinimap", nil, "Rotate Minimap"),
			I("DisplayPanelShowClock", nil, "Show Clock"),
			I("DisplayPanelShowFreeBagSpace", nil, "Show Free Bag Space"),
			I("DisplayPanelShowItemLevel", nil, "Show Item Level"),
			I("DisplayPanelDetailedLootInfo", nil, "Detailed Loot Information"),
			I("DisplayPanelScreenEdgeFlash", nil, "Show Fullscreen Status"),
			I("DisplayPanelAggroWarningDisplay", nil, "Threat Warning"),
			I("DisplayPanelShowAggroPercentage", true, "Show Threat Percentage"),
			I("DisplayPanelPlayAggroSounds", true, "Play Threat Sounds"),
			I("DisplayPanelWorldPVPObjectiveDisplay", nil, "World PvP Objectives"),
		} },
		{ header = "Status Text", rows = {
			I("StatusTextPanelPlayer", nil, "Player"),
			I("StatusTextPanelPet", nil, "Pet"),
			I("StatusTextPanelParty", nil, "Party"),
			I("StatusTextPanelTarget", nil, "Target"),
			I("StatusTextPanelPercentages", nil, "Display Percentages"),
			I("StatusTextPanelXP", nil, "Experience Bar"),
		} },
		{ header = "Quests", rows = {
			I("ObjectivesPanelInstantQuestText", nil, "Instant Quest Text"),
			I("ObjectivesPanelAutoQuestTracking", nil, "Automatic Quest Tracking"),
			I("ObjectivesPanelAutoQuestProgress", nil, "Automatic Quest Progress"),
			I("ObjectivesPanelMapQuestDifficulty", nil, "Show Quest Difficulty on the Map"),
			I("ObjectivesPanelAdvancedWorldMap", nil, "Advanced World Map"),
			I("ObjectivesPanelWatchFrameWidth", nil, "Wider Objective Tracker"),
		} },
		{ header = "Raid & Party Frames", rows = {
			I("UnitFramePanelPartyBackground", nil, "Party / Arena Background"),
			I("UnitFramePanelPartyInRaid", nil, "Hide Party Interface in Raid"),
			I("UnitFramePanelPartyPets", nil, "Show Party Pets"),
			I("UnitFramePanelRaidRange", nil, "Show Raid Range"),
			I("UnitFramePanelArenaEnemyFrames", nil, "Show Arena Enemy Frames"),
			I("UnitFramePanelArenaEnemyCastBar", true, "Arena Enemy Cast Bars"),
			I("UnitFramePanelArenaEnemyPets", true, "Arena Enemy Pets"),
			I("UnitFramePanelFullSizeFocusFrame", nil, "Larger Focus Frame"),
		} },
		{ header = "Buffs and Debuffs", rows = {
			I("BuffsPanelBuffDurations", nil, "Buff Durations"),
			I("BuffsPanelDispellableDebuffs", nil, "Show Dispellable Debuffs"),
			I("BuffsPanelCastableBuffs", nil, "Show Castable Buffs"),
			I("BuffsPanelShowCastableDebuffs", nil, "Show Only My Debuffs on Target"),
			I("BuffsPanelConsolidateBuffs", nil, "Consolidate Buffs"),
		} },
		{ header = "Help", rows = {
			-- the new-player tutorial (TemucraftTutorial.lua) and the stock tips (CVar showTutorials) together
			{ kind = "tutorials", label = "Tutorials",
				tooltip = "The new-player tutorial (look, walk, talk, your first quest and spell) for new characters, and the game's tutorial tips." },
			{ kind = "button", label = "Reset Tutorials", text = RESET or "Reset", click = function() if ( TemucraftTutorial_Reset ) then TemucraftTutorial_Reset(); end end,
				tooltip = "Shows the tutorials again: the new-player tutorial on this character (if it is level 1) or the next new one, and the game's tutorial tips." },
			I("HelpPanelLoadingScreenTips", nil, "Loading Screen Tips"),
			I("HelpPanelEnhancedTooltips", nil, "Enhanced Tooltips"),
			I("HelpPanelBeginnerTooltips", nil, "Beginner Tooltips"),
			I("HelpPanelShowLuaErrors", nil, "Display Lua Errors"),
			I("FeaturesPanelEquipmentManager", nil, "Use Equipment Manager"),
			I("FeaturesPanelPreviewTalentChanges", nil, "Preview Talent Changes"),
		} },
	} },
	{ key = "actionbars", section = "Gameplay", title = "Action Bars", groups = {
		{ rows = {
			I("ActionBarsPanelBottomLeft", nil, "Action Bar 2"),
			I("ActionBarsPanelBottomRight", nil, "Action Bar 3"),
			I("ActionBarsPanelRight", nil, "Action Bar 4"),
			I("ActionBarsPanelRightTwo", true, "Action Bar 5"),
			I("ActionBarsPanelLockActionBars", nil, "Lock Action Bars"),
			{ kind = "modifier", action = "PICKUPACTION", label = "Pick Up Action Key", sub = true, default = "SHIFT",
				tooltip = "Hold this key to drag a spell off a locked action bar." },
			I("ActionBarsPanelAlwaysShowActionBars", nil, "Always Show Action Bars"),
			I("ActionBarsPanelSecureAbilityToggle", nil, "Secure Ability Toggle"),
		} },
	} },
	{ key = "combat", section = "Gameplay", title = "Combat", groups = {
		{ rows = {
			I("CombatPanelTargetOfTarget", nil, "Target of Target"),
			I("CombatPanelTOTDropDown", true, "Show Target of Target"),
			I("CombatPanelAttackOnAssist", nil, "Attack on Assist"),
			I("CombatPanelAutoRange", nil, "Auto Attack / Auto Shot"),
			I("CombatPanelStopAutoAttack", nil, "Stop Auto Attack"),
			I("CombatPanelAutoSelfCast", nil, "Auto Self Cast"),
			I("CombatPanelSelfCastKeyDropDown", nil, "Self Cast Key"),
			I("CombatPanelFocusCastKeyDropDown", nil, "Focus Cast Key"),
			I("CombatPanelEnemyCastBarsOnPortrait", nil, "Enemy Cast Bar on Portrait"),
			I("CombatPanelEnemyCastBarsOnNameplates", nil, "Enemy Cast Bar on Nameplates"),
		} },
		{ header = "Combat Text", rows = {
			I("CombatTextPanelTargetDamage", nil, "Show Damage"),
			I("CombatTextPanelPeriodicDamage", true, "Show Periodic Damage"),
			I("CombatTextPanelPetDamage", true, "Show Pet Damage"),
			I("CombatTextPanelHealing", nil, "Show Healing"),
			I("CombatTextPanelTargetEffects", nil, "Show Effects on Target"),
			I("CombatTextPanelOtherTargetEffects", true, "Show Other Players' Effects"),
			I("CombatTextPanelEnableFCT", nil, "Scrolling Combat Text for Self"),
			I("CombatTextPanelFCTDropDown", true, "Combat Text Float Mode"),
			I("CombatTextPanelDodgeParryMiss", true, "Dodge / Parry / Miss"),
			I("CombatTextPanelDamageReduction", true, "Damage Reduction"),
			I("CombatTextPanelRepChanges", true, "Reputation Changes"),
			I("CombatTextPanelReactiveAbilities", true, "Reactive Spells and Abilities"),
			I("CombatTextPanelFriendlyHealerNames", true, "Friendly Healer Names"),
			I("CombatTextPanelCombatState", true, "Combat State"),
			I("CombatTextPanelComboPoints", true, "Combo Points"),
			I("CombatTextPanelLowManaHealth", true, "Low Mana and Health"),
			I("CombatTextPanelEnergyGains", true, "Power Gains"),
			I("CombatTextPanelPeriodicEnergyGains", true, "Periodic Power Gains"),
			I("CombatTextPanelHonorGains", true, "Honor Gains"),
			I("CombatTextPanelAuras", true, "Auras"),
		} },
	} },
	{ key = "social", section = "Gameplay", title = "Social", groups = {
		{ rows = {
			I("SocialPanelProfanityFilter", nil, "Mature Language Filter"),
			I("SocialPanelSpamFilter", nil, "Disable Spam Filter"),
			I("SocialPanelGuildMemberAlert", nil, "Guild Member Alert"),
			I("SocialPanelGuildRecruitment", nil, "Auto Join Guild Recruitment Channel"),
			I("ControlsPanelBlockTrades", nil, "Block Trades"),
		} },
		{ header = "Chat", rows = {
			I("SocialPanelChatStyle", nil, "Chat Style"),
			I("SocialPanelWholeChatWindowClickable", true, "Whole Chat Window Clickable"),
			I("SocialPanelConversationMode", nil, "New Whispers"),
			I("SocialPanelTimestamps", nil, "Chat Timestamps"),
			I("SocialPanelChatBubbles", nil, "Chat Bubbles"),
			I("SocialPanelPartyChat", true, "Party Chat Bubbles"),
			I("SocialPanelChatHoverDelay", nil, "Remove Chat Hover Delay"),
			I("SocialPanelChatMouseScroll", nil, "Chat Mouse Wheel Scroll"),
		} },
	} },
	{ key = "keybindings", section = "Gameplay", title = "Keybindings", kind = "keybindings" },
	{ key = "nameplates", section = "Gameplay", title = "Nameplates", groups = {
		{ header = "Names", rows = {
			I("NamesPanelMyName", nil, "My Name"),
			I("NamesPanelNPCNames", nil, "NPC Names"),
			I("NamesPanelNonCombatCreature", nil, "Critters and Companions"),
			I("NamesPanelGuilds", nil, "Guild Names"),
			I("NamesPanelTitles", nil, "Player Titles"),
			I("NamesPanelFriendlyPlayerNames", nil, "Friendly Players"),
			I("NamesPanelFriendlyPets", true, "Pets"),
			I("NamesPanelFriendlyGuardians", true, "Guardians"),
			I("NamesPanelFriendlyTotems", true, "Totems"),
			I("NamesPanelEnemyPlayerNames", nil, "Enemy Players"),
			I("NamesPanelEnemyPets", true, "Pets"),
			I("NamesPanelEnemyGuardians", true, "Guardians"),
			I("NamesPanelEnemyTotems", true, "Totems"),
		} },
		{ header = "Nameplates", rows = {
			I("NamesPanelUnitNameplatesEnemies", nil, "Enemy Units"),
			I("NamesPanelUnitNameplatesEnemyPets", true, "Pets"),
			I("NamesPanelUnitNameplatesEnemyGuardians", true, "Guardians"),
			I("NamesPanelUnitNameplatesEnemyTotems", true, "Totems"),
			I("NamesPanelUnitNameplatesFriends", nil, "Friendly Units"),
			I("NamesPanelUnitNameplatesFriendlyPets", true, "Pets"),
			I("NamesPanelUnitNameplatesFriendlyGuardians", true, "Guardians"),
			I("NamesPanelUnitNameplatesFriendlyTotems", true, "Totems"),
			I("NamesPanelUnitNameplatesAllowOverlap", nil, "Allow Overlapping Nameplates"),
			I("CombatPanelNameplateClassColors", nil, "Class Colors in Nameplates"),
		} },
	} },
	{ key = "a11ygeneral", section = "Accessibility", title = "General", groups = {
		{ rows = {
			{ kind = "server", name = "arachnophobia", label = "Arachnophobia Mode",
				tooltip = "Replace spiders with alternative creatures. This doesn't affect gameplay or difficulty." },
			I("DisplayPanelCinematicSubtitles", nil, "Cinematic Subtitles"),
		} },
	} },
	{ key = "colors", section = "Accessibility", title = "Colors", groups = {
		{ rows = {
			I("DisplayPanelColorblindMode", nil, "Colorblind Mode"),
		} },
	} },
	{ key = "graphics", section = "System", title = "Graphics", apply = true, groups = {
		{ header = "Display", rows = {
			V("ResolutionPanelWindowed", nil, "Windowed Mode"),
			V("ResolutionPanelMaximized", true, "Maximized"),
			V("ResolutionPanelDisableResize", true, "Disable Window Resize"),
			V("ResolutionPanelResolutionDropDown", nil, "Resolution"),
			V("ResolutionPanelRefreshDropDown", nil, "Refresh Rate"),
			V("ResolutionPanelMultiSampleDropDown", nil, "Multisampling"),
			V("ResolutionPanelVSync", nil, "Vertical Sync"),
			V("ResolutionPanelTripleBuffer", true, "Triple Buffering"),
			V("ResolutionPanelFixInputLag", nil, "Reduce Input Lag"),
			V("ResolutionPanelHardwareCursor", nil, "Hardware Cursor"),
			V("ResolutionPanelUseUIScale", nil, "Use UI Scale"),
			V("ResolutionPanelUIScaleSlider", true, "UI Scale", { release = true, fmt = "2" }),
			V("ResolutionPanelDesktopGamma", nil, "Use Desktop Gamma"),
			V("ResolutionPanelGammaSlider", true, "Gamma"),
		} },
		{ header = "Graphics Quality", box = true, rows = {
			V("EffectsPanelQualitySlider", nil, "Graphics Quality", { fmt = "quality" }),
			V("EffectsPanelViewDistance", true, "View Distance"),
			V("EffectsPanelTerrainDetail", true, "Terrain Detail"),
			V("EffectsPanelEnvironmentDetail", true, "Environment Detail"),
			V("EffectsPanelClutterDensity", true, "Ground Clutter Density"),
			V("EffectsPanelClutterRadius", true, "Ground Clutter Radius"),
			V("EffectsPanelTextureResolution", true, "Texture Resolution"),
			V("EffectsPanelTextureFiltering", true, "Texture Filtering"),
			V("EffectsPanelShadowQuality", true, "Shadow Quality"),
			V("EffectsPanelParticleDensity", true, "Particle Density"),
			V("EffectsPanelWeatherIntensity", true, "Weather Intensity"),
			V("EffectsPanelPlayerTexture", true, "Player Textures"),
			V("EffectsPanelSpecularLighting", true, "Terrain Highlights"),
			V("EffectsPanelFullScreenGlow", true, "Full Screen Glow Effect"),
			V("EffectsPanelDeathEffect", true, "Death Effect"),
			V("EffectsPanelProjectedTextures", true, "Projected Textures"),
		} },
		{ header = "Frame Rate", rows = {
			CVS("maxFPS", "Max Frame Rate", 0, 200, 5, "Frames per second at most (0 = no limit)."),
			CVS("maxFPSBk", "Max Background Frame Rate", 0, 200, 5, "Frames per second at most while the game is in the background (0 = no limit)."),
		} },
	} },
	{ key = "audio", section = "System", title = "Audio", groups = {
		{ rows = {
			A("SoundPanelEnableSound", nil, "Enable Sound"),
		} },
		{ header = "Volume", rows = {
			A("SoundPanelMasterVolume", nil, "Master Volume"),
			A("SoundPanelMusicVolume", nil, "Music"),
			A("SoundPanelSoundVolume", nil, "Effects"),
			A("SoundPanelAmbienceVolume", nil, "Ambience"),
		} },
		{ header = "Sounds", rows = {
			A("SoundPanelMusic", nil, "Music"),
			A("SoundPanelLoopMusic", true, "Loop Music"),
			A("SoundPanelSoundEffects", nil, "Sound Effects"),
			A("SoundPanelPetSounds", true, "Pet Sounds"),
			A("SoundPanelEmoteSounds", true, "Emote Sounds"),
			A("SoundPanelErrorSpeech", nil, "Error Speech"),
			A("SoundPanelAmbientSounds", nil, "Ambient Sounds"),
			A("SoundPanelSoundInBG", nil, "Sound in Background"),
			A("SoundPanelReverb", nil, "Enable Reverb"),
			A("SoundPanelHRTF", nil, "Software Sound Positioning"),
			A("SoundPanelEnableDSPs", nil, "Enable DSP Effects"),
			CV("Sound_ListenerAtCharacter", "Hear From the Character", "Sounds are heard from where your character stands, not from the camera."),
			CV("Sound_ZoneMusicNoDelay", "Zone Music Without Delay", "A zone's music starts again at once instead of after a pause."),
		} },
		{ header = "Playback", rows = {
			A("SoundPanelHardwareDropDown", nil, "Output Device"),
			A("SoundPanelUseHardware", nil, "Use Hardware"),
			A("SoundPanelSoundQuality", nil, "Sound Quality", { release = true }),
			A("SoundPanelSoundChannels", nil, "Sound Channels", { release = true }),
		} },
	} },
	{ key = "languages", section = "System", title = "Languages", groups = {
		{ rows = {
			{ kind = "text", label = "Text Language", value = "locale" },
			{ kind = "text", label = "Audio Language", value = "audiolocale" },
			{ kind = "note", text = "The client's language is set by the launcher and the installed language files." },
		} },
	} },
	{ key = "network", section = "System", title = "Network", groups = {
		{ rows = {
			CV("disableServerNagle", "Optimize Network for Speed", "Sends data at once instead of bundling it: lower latency for more bandwidth."),
			CV("advancedCombatLogging", "Advanced Combat Logging"),
			{ kind = "note", text = "Nothing else to set here: 3.3.5 has no other network options.", ifEmpty = true },
		} },
	} },
};

function L.Page(key)
	for _, p in ipairs(L.PAGES) do if ( p.key == key ) then return p; end end
end

-- the left list of the Game tab: { kind = "section", text } and { kind = "page", page }
function L.GameList()
	local out = {};
	for _, section in ipairs(L.SECTIONS) do
		table.insert(out, { kind = "section", text = section });
		for _, p in ipairs(L.PAGES) do
			if ( p.section == section ) then table.insert(out, { kind = "page", page = p, text = p.title }); end
		end
	end
	return out;
end

-- [[ small helpers ]] --
function L.StripColors(text)
	return (string.gsub(string.gsub(text or "", "|c%x%x%x%x%x%x%x%x", ""), "|r", ""));
end

function L.Matches(text, query)
	if ( not query or query == "" ) then return true; end
	return string.find(string.lower(L.StripColors(text)), string.lower(query), 1, true) ~= nil;
end

-- slider values: snap to the step from the minimum, keep in range
function L.Snap(value, min, max, step)
	if ( step and step > 0 ) then value = min + math.floor((value - min) / step + 0.5) * step; end
	if ( value < min ) then value = min; elseif ( value > max ) then value = max; end
	return value;
end

function L.Step(value, min, max, step, dir)
	step = (step and step > 0) and step or (max - min) / 10;
	return L.Snap(value + dir * step, min, max, step);
end

-- fmt: "percent", "quality", a number of decimals ("2"), or nil (from the step); names: low / high texts
function L.Format(value, min, max, step, fmt, names)
	if ( fmt == "quality" ) then
		return (names and names[math.floor(value + 0.5)]) or tostring(math.floor(value + 0.5));
	end
	if ( fmt == "percent" or (not fmt and min == 0 and max == 1 and step and step < 1) ) then
		return string.format("%d%%", math.floor(value * 100 + 0.5));
	end
	if ( names and names.low and value == min ) then return names.low; end
	if ( names and names.high and value == max ) then return names.high; end
	local decimals = tonumber(fmt);
	if ( not decimals ) then
		decimals = 0;
		if ( step and step < 1 ) then decimals = (step < 0.1) and 2 or 1; end
	end
	if ( decimals == 0 ) then return tostring(math.floor(value + 0.5)); end
	return string.format("%."..decimals.."f", value);
end

-- The numbers at a slider's ends: "0%" / "100%" for 0-1 sliders, else the real min and max (quality: the names)
function L.Ends(min, max, step, fmt, names)
	if ( fmt == "quality" ) then return L.Format(min, min, max, step, fmt, names), L.Format(max, min, max, step, fmt, names); end
	return L.Format(min, min, max, step, fmt), L.Format(max, min, max, step, fmt);
end

-- A typed value: "50", "50%", "0.5" (for a 0-1 slider shown in percent, more than 1 or a % sign means percent),
-- snapped to the step and kept in range; nil when it isn't a number
function L.Parse(text, min, max, step, fmt)
	text = string.gsub(tostring(text or ""), ",", ".");
	local num = tonumber((string.gsub(text, "[%s%%]", "")));
	if ( not num ) then return nil; end
	local percent = (fmt == "percent" or (not fmt and min == 0 and max == 1 and step and step < 1));
	if ( percent and (string.find(text, "%", 1, true) or num > 1) ) then num = num / 100; end
	return L.Snap(num, min, max, step);
end

-- a key press or mouse button as a binding key ("ALT-CTRL-SHIFT-F", "BUTTON4"), nil for a lone modifier or
-- the left / right button
local MOUSE = { LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3" };
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, UNKNOWN = true };
function L.KeyFromInput(key, shift, ctrl, alt)
	if ( not key or MODIFIERS[key] ) then return nil; end
	key = MOUSE[key] or (string.match(key, "^Button(%d+)$") and "BUTTON"..string.match(key, "^Button(%d+)$")) or key;
	if ( key == "BUTTON1" or key == "BUTTON2" ) then return nil; end
	if ( shift ) then key = "SHIFT-"..key; end
	if ( ctrl ) then key = "CTRL-"..key; end
	if ( alt ) then key = "ALT-"..key; end
	return key;
end

-- the bindings (GetBinding order: { command, key1, key2 }) under their headers ("HEADER_..."); blank headers
-- (no text) keep the group going
function L.GroupBindings(list, headerText)
	local groups, current = {}, nil;
	for _, b in ipairs(list) do
		local command = b[1];
		if ( string.sub(command, 1, 6) == "HEADER" ) then
			local text = headerText and headerText(command);
			if ( text and text ~= "" ) then
				current = { header = command, text = text, rows = {} };
				table.insert(groups, current);
			end
		else
			if ( not current ) then current = { header = "", text = "Other", rows = {} }; table.insert(groups, current); end
			table.insert(current.rows, b);
		end
	end
	return groups;
end

-- the AddOns tab list: top categories alphabetical, each one's sub-categories under it (indented) when expanded
-- cats: { name, parent }, expanded[name] = true
function L.AddonTree(cats, expanded)
	local tops, kids = {}, {};
	for _, c in ipairs(cats) do
		if ( c.parent ) then kids[c.parent] = kids[c.parent] or {}; table.insert(kids[c.parent], c);
		else table.insert(tops, c); end
	end
	local function key(c) return string.lower(L.StripColors(c.name)); end
	table.sort(tops, function(a, b) return key(a) < key(b); end);
	local out = {};
	for _, c in ipairs(tops) do
		local children = kids[c.name];
		table.insert(out, { cat = c, depth = 0, children = children and #children > 0, expanded = expanded and expanded[c.name] });
		if ( children and expanded and expanded[c.name] ) then
			for _, k in ipairs(children) do table.insert(out, { cat = k, depth = 1 }); end
		end
	end
	return out;
end

-- the server's answer to a ".temucraft settings <name> ..." command: "yes" (it knows the setting), "no" (no such
-- command, no rights, settings off), nil (not about it); and the value it reports ("on" / "off")
function L.ServerReply(name, text)
	local t = string.lower(L.StripColors(text or ""));
	if ( string.find(t, "no such command", 1, true) or string.find(t, "no such subcommand", 1, true)
		or string.find(t, "player settings are off", 1, true) ) then
		return "no";
	end
	if ( string.find(t, string.lower(name), 1, true) ) then
		local value = string.match(t, "%f[%a](on)%f[%A]") or string.match(t, "%f[%a](off)%f[%A]");
		return "yes", value;
	end
	return nil;
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

-- [[ the window ]] --
local W, H, LIST_W = 900, 620, 206;
local CONTROL_X, ROW_H = 330, 26;
local SLIDER_ROW_H = 34;   -- slider rows: room for the min / max numbers under the bar
local GOLD, WHITE, GREY = { 1, 0.82, 0 }, { 1, 1, 1 }, { 0.5, 0.5, 0.5 };

local f = CreateFrame("Frame", "TemucraftOptionsFrame", UIParent);
f:SetWidth(W); f:SetHeight(H);
f:SetPoint("CENTER");
f:SetFrameStrata("DIALOG");
f:SetToplevel(true);
f:EnableMouse(true);
f:SetMovable(true);
f:RegisterForDrag("LeftButton");
f:SetScript("OnDragStart", f.StartMoving);
f:SetScript("OnDragStop", f.StopMovingOrSizing);
f:SetClampedToScreen(true);
f:Hide();
tinsert(UISpecialFrames, "TemucraftOptionsFrame");

TemucraftStyle_Window(f, "Options");
CreateFrame("Button", nil, f, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -6, -6);

local function Solid(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer);
	t:SetTexture(r, g, b, a);
	return t;
end

-- tabs: Game | AddOns
local tabs, tab = {}, "game";
local Select, ShowTab;
for i, def in ipairs({ { "game", GAME or "Game" }, { "addons", ADDONS or "AddOns" } }) do
	local b = CreateFrame("Button", "TemucraftOptionsTab"..i, f);
	b:SetHeight(24);
	local text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	text:SetPoint("CENTER"); text:SetText(def[2]);
	b.text = text;
	b:SetWidth(text:GetStringWidth() + 24);
	if ( i == 1 ) then b:SetPoint("TOPLEFT", 22, -40); else b:SetPoint("LEFT", tabs[i - 1], "RIGHT", 6, 0); end
	local line = Solid(b, "OVERLAY", 1, 0.82, 0, 1);
	line:SetHeight(2); line:SetPoint("BOTTOMLEFT", 4, -1); line:SetPoint("BOTTOMRIGHT", -4, -1);
	b.line = line;
	TemucraftStyle_Highlight(b);
	b:SetScript("OnClick", function() PlaySound("igCharacterInfoTab"); ShowTab(def[1]); end);
	b.key = def[1];
	tabs[i] = b;
end

-- search
local search = CreateFrame("EditBox", "TemucraftOptionsSearch", f, "InputBoxTemplate");
search:SetWidth(200); search:SetHeight(20);
search:SetPoint("TOPRIGHT", -30, -42);
search:SetAutoFocus(false);
local searchHint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
searchHint:SetPoint("LEFT", 2, 0);
searchHint:SetText(SEARCH or "Search");

-- left list and right page
local left = CreateFrame("Frame", nil, f);
left:SetPoint("TOPLEFT", 18, -70); left:SetPoint("BOTTOMLEFT", 18, 46); left:SetWidth(LIST_W);
TemucraftStyle_Inset(left);
local listScroll = CreateFrame("ScrollFrame", "TemucraftOptionsListScroll", left, "UIPanelScrollFrameTemplate");
listScroll:SetPoint("TOPLEFT", 4, -6); listScroll:SetPoint("BOTTOMRIGHT", -26, 6);
local listChild = CreateFrame("Frame", nil, listScroll);
listChild:SetWidth(LIST_W - 30); listChild:SetHeight(10);
listScroll:SetScrollChild(listChild);

local right = CreateFrame("Frame", nil, f);
right:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0); right:SetPoint("BOTTOMRIGHT", -18, 46);
TemucraftStyle_Inset(right);
local pageTitle = right:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
pageTitle:SetPoint("TOPLEFT", 16, -12);
pageTitle:SetTextColor(1, 1, 1);
local sep = TemucraftStyle_Line(right); sep:SetPoint("TOPLEFT", 10, -44); sep:SetPoint("TOPRIGHT", -10, -44);
local defaults = CreateFrame("Button", "TemucraftOptionsDefaults", right, "UIPanelButtonTemplate");
defaults:SetWidth(96); defaults:SetHeight(22);
defaults:SetPoint("TOPRIGHT", -12, -12);
defaults:SetText(DEFAULTS or "Defaults");
local apply = CreateFrame("Button", "TemucraftOptionsApply", right, "UIPanelButtonTemplate");
apply:SetWidth(96); apply:SetHeight(22);
apply:SetPoint("RIGHT", defaults, "LEFT", -6, 0);
apply:SetText(APPLY or "Apply");
apply:Hide();

local scroll = CreateFrame("ScrollFrame", "TemucraftOptionsScroll", right, "UIPanelScrollFrameTemplate");
scroll:SetPoint("TOPLEFT", 6, -50); scroll:SetPoint("BOTTOMRIGHT", -28, 6);
local child = CreateFrame("Frame", nil, scroll);
local CHILD_W = W - 18 - LIST_W - 10 - 18 - 6 - 28;
child:SetWidth(CHILD_W); child:SetHeight(10);
scroll:SetScrollChild(child);

-- an addon's own panel goes here
local host = CreateFrame("Frame", nil, right);
host:SetPoint("TOPLEFT", 4, -48); host:SetPoint("BOTTOMRIGHT", -4, 4);
host:Hide();

local close = CreateFrame("Button", "TemucraftOptionsClose", f, "UIPanelButtonTemplate");
close:SetWidth(110); close:SetHeight(22);
close:SetPoint("BOTTOMRIGHT", -20, 16);
close:SetText(CLOSE or "Close");
close:SetScript("OnClick", function() f:Hide(); end);

local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
status:SetPoint("BOTTOMLEFT", 24, 22); status:SetPoint("RIGHT", close, "LEFT", -12, 0);
status:SetJustifyH("LEFT");
local function Status(text) status:SetText(text or ""); end

-- [[ stock controls ]] --
local VIDEO_PANELS = { "VideoOptionsResolutionPanel", "VideoOptionsEffectsPanel" };
local SHOWN_PANELS = { "VideoOptionsResolutionPanel", "VideoOptionsEffectsPanel", "AudioOptionsSoundPanel" };
local videoPending = false;

local function Kind(c)
	local t = c:GetObjectType();
	if ( t == "CheckButton" ) then return "check"; elseif ( t == "Slider" ) then return "slider"; end
	if ( c.initialize or _G[c:GetName().."Button"] ) then return "choice"; end
end

local function StockEnabled(c, kind)
	if ( kind == "choice" ) then
		local b = _G[c:GetName().."Button"];
		return not b or b:IsEnabled() == 1 or b:IsEnabled() == true;
	end
	if ( c.IsEnabled ) then local e = c:IsEnabled(); return e == 1 or e == true; end
	return true;
end

local function StockLabel(c, kind, fallback)
	local name = c:GetName();
	local fs = (kind == "choice") and _G[name.."Label"] or _G[name.."Text"];
	local text = fs and fs.GetText and fs:GetText();
	if ( not text or text == "" or string.find(text, "%%") ) then text = fallback; end
	return text or name;
end

-- the choices of a stock dropdown: its initialize function run against a collector
local function Choices(dd)
	local init = dd.initialize;
	local list = {};
	if ( not init ) then return list; end
	local realAdd, id = UIDropDownMenu_AddButton, 0;
	UIDropDownMenu_AddButton = function(info)
		id = id + 1;
		if ( info and info.func and not info.isTitle and not info.notClickable ) then
			table.insert(list, { id = id, text = info.text, value = info.value, func = info.func, arg1 = info.arg1,
				arg2 = info.arg2, checked = info.checked and true or false });
		end
	end;
	pcall(init, dd, 1);
	UIDropDownMenu_AddButton = realAdd;
	return list;
end

local function SelectedChoice(dd, list)
	for i, c in ipairs(list) do if ( c.checked ) then return i; end end
	local value = UIDropDownMenu_GetSelectedValue(dd);
	if ( value ~= nil ) then
		for i, c in ipairs(list) do if ( c.value == value or tostring(c.value) == tostring(value) ) then return i; end end
	end
	local id = dd.selectedID;
	if ( id ) then for i, c in ipairs(list) do if ( c.id == id ) then return i; end end end
	local text = UIDropDownMenu_GetText(dd);
	for i, c in ipairs(list) do if ( c.text == text ) then return i; end end
end

local function Choose(choice)
	local fake = { value = choice.value, arg1 = choice.arg1, arg2 = choice.arg2 };
	fake.GetID = function() return choice.id; end;
	fake.GetText = function() return choice.text; end;
	pcall(choice.func, fake, choice.arg1, choice.arg2, choice.checked);
end

-- what the video panels have waiting: the restart ones wait for Apply, the rest are applied now
local function CommitVideo()
	videoPending = false;
	for _, name in ipairs(VIDEO_PANELS) do
		local panel = _G[name];
		for _, c in ipairs(panel and panel.controls or {}) do
			if ( c.newValue ~= nil and c.value ~= c.newValue ) then
				if ( c.restart ) then
					videoPending = true;
				else
					if ( c.gameRestart ) then VideoOptionsFrame.gameRestart = true; end
					if ( c.logout ) then VideoOptionsFrame.logout = true; end
					c:SetValue(c.newValue);
					c.value = c.newValue;
					c.newValue = nil;
				end
			end
		end
	end
	if ( videoPending ) then apply:Enable(); else apply:Disable(); end
end

local function AfterChange(spec, c)
	if ( spec.family == "video" ) then
		if ( c ~= VideoOptionsEffectsPanelQualitySlider and c:GetParent() == VideoOptionsEffectsPanel and VideoOptionsEffectsPanel_UpdateVideoQuality ) then
			VideoOptionsEffectsPanel_UpdateVideoQuality();
		end
		CommitVideo();
	end
end

local function RestartAlerts()
	for _, frame in ipairs({ VideoOptionsFrame, InterfaceOptionsFrame, AudioOptionsFrame }) do
		if ( frame and frame.gameRestart ) then StaticPopup_Show("CLIENT_RESTART_ALERT"); frame.gameRestart = nil; frame.logout = nil;
		elseif ( frame and frame.logout ) then StaticPopup_Show("CLIENT_LOGOUT_ALERT"); frame.logout = nil; end
	end
end

local function ApplyVideo()
	if ( VideoOptionsFrameOkay_OnClick ) then VideoOptionsFrameOkay_OnClick(VideoOptionsFrameOkay, "LeftButton", true); end
	videoPending = false;
	apply:Disable();
	RestartAlerts();
end

local function DiscardVideo()
	if ( OptionsFrameCancel_OnClick ) then OptionsFrameCancel_OnClick(VideoOptionsFrame); end
	VideoOptionsFrame.gxRestart = nil; VideoOptionsFrame.gameRestart = nil; VideoOptionsFrame.logout = nil;
	videoPending = false;
	for _, name in ipairs(VIDEO_PANELS) do local p = _G[name]; if ( p and p.refresh ) then pcall(p.refresh, p); end end
end

StaticPopupDialogs["TEMUCRAFT_OPTIONS_APPLY_VIDEO"] = {
	text = "Apply the graphics changes you made (resolution, window or display settings)?",
	button1 = APPLY or "Apply", button2 = CANCEL or "Cancel",
	OnAccept = function() ApplyVideo(); end,
	OnCancel = function() DiscardVideo(); end,
	timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1,
};

-- [[ rows ]] --
local Refresh, RefreshRows, Layout;
local current;           -- the page shown: a page table, "search" or an addon category
local rows = {};         -- spec -> row frame
local visibleRows = {};

local function Tooltip(frame, text, titleText)
	frame:SetScript("OnEnter", function(self)
		if ( not (text or (self.tooltipFunc and self.tooltipFunc())) ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(titleText or self.label and self.label:GetText() or "", 1, 1, 1);
		GameTooltip:AddLine(text or self.tooltipFunc(), nil, nil, nil, 1);
		GameTooltip:Show();
	end);
	frame:SetScript("OnLeave", function() GameTooltip:Hide(); end);
end

local function NewRow(spec, labelText, height)
	local r = CreateFrame("Frame", nil, child);
	r:SetWidth(CHILD_W - 10); r:SetHeight(height or ROW_H);
	r:EnableMouse(true);
	local label = r:CreateFontString(nil, "ARTWORK", spec.sub and "GameFontNormalSmall" or "GameFontNormal");
	label:SetPoint("LEFT", spec.sub and 40 or 22, 0);
	label:SetWidth(CONTROL_X - (spec.sub and 46 or 28)); label:SetJustifyH("LEFT");
	label:SetText(labelText);
	r.label = label;
	r.spec = spec;
	r:Hide();
	return r;
end

local function SetRowEnabled(r, on)
	local color = on and GOLD or GREY;
	r.label:SetTextColor(color[1], color[2], color[3]);
	r.enabled = on;
	for _, w in ipairs(r.widgets or {}) do if ( on ) then w:Enable(); else w:Disable(); end end
end

local function ArrowButton(parent, dir)
	local b = CreateFrame("Button", nil, parent);
	b:SetWidth(24); b:SetHeight(24);
	local which = (dir < 0) and "Prev" or "Next";
	b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-"..which.."Page-Up");
	b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-"..which.."Page-Down");
	b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-"..which.."Page-Disabled");
	b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");
	return b;
end

local function CheckWidget(r, onClick, silent)
	local cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate");
	cb:SetWidth(26); cb:SetHeight(26);
	cb:SetPoint("LEFT", CONTROL_X, 0);
	cb:SetScript("OnClick", function(self)
		if ( not silent ) then PlaySound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff"); end
		onClick(self:GetChecked() and true or false);
	end);
	r.widgets = { cb };
	r.check = cb;
	return cb;
end

-- < value > : get() -> index, list; set(index)
local function ChoiceWidget(r, get, set)
	local prev, nextB = ArrowButton(r, -1), ArrowButton(r, 1);
	prev:SetPoint("LEFT", CONTROL_X - 4, 0);
	local box = CreateFrame("Button", nil, r);
	box:SetWidth(180); box:SetHeight(24);
	box:SetPoint("LEFT", prev, "RIGHT", 0, 0);
	box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	box:SetBackdropColor(0.05, 0.05, 0.05, 0.9); box:SetBackdropBorderColor(0.6, 0.6, 0.6);
	local text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	text:SetPoint("LEFT", 8, 0); text:SetPoint("RIGHT", -8, 0);
	box:SetFontString(text);
	nextB:SetPoint("LEFT", box, "RIGHT", 0, 0);
	local function Move(dir)
		local index, list = get();
		if ( not list or #list == 0 ) then return; end
		index = (index or 1) + dir;
		if ( index < 1 ) then index = #list; elseif ( index > #list ) then index = 1; end
		PlaySound("igMainMenuOptionCheckBoxOn");
		set(index);
		Refresh();
	end
	prev:SetScript("OnClick", function() Move(-1); end);
	nextB:SetScript("OnClick", function() Move(1); end);
	box:SetScript("OnClick", function(self, button) Move(button == "RightButton" and -1 or 1); end);
	box:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	box.Enable = function(self) getmetatable(self).__index.Enable(self); text:SetTextColor(1, 1, 1); end;
	box.Disable = function(self) getmetatable(self).__index.Disable(self); text:SetTextColor(0.5, 0.5, 0.5); end;
	r.widgets = { prev, box, nextB };
	r.UpdateChoice = function()
		local index, list = get();
		local c = index and list and list[index];
		text:SetText(c and (c.text or tostring(c.value)) or "-");
	end;
end

local sliderCount = 0;
local function SliderWidget(r, spec, c)
	sliderCount = sliderCount + 1;
	local prev, nextB = ArrowButton(r, -1), ArrowButton(r, 1);
	prev:SetPoint("LEFT", CONTROL_X - 4, 4);   -- a little up: the min / max numbers go under the bar
	local s = CreateFrame("Slider", "TemucraftOptionsSlider"..sliderCount, r);
	s:SetOrientation("HORIZONTAL");
	s:SetWidth(170); s:SetHeight(17);
	s:SetPoint("LEFT", prev, "RIGHT", 2, 0);
	s:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
		tile = true, tileSize = 8, edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 } });
	s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal");
	nextB:SetPoint("LEFT", s, "RIGHT", 2, 0);
	-- the real min and max under the bar's ends, the value in a box you can type in (Enter applies)
	local lowText = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	lowText:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 2, 1);
	local highText = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	highText:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", -2, 1);
	local value = CreateFrame("EditBox", "TemucraftOptionsSlider"..sliderCount.."Value", r);
	value:SetWidth(58); value:SetHeight(18);
	value:SetPoint("LEFT", nextB, "RIGHT", 6, 0);
	value:SetFontObject(GameFontHighlightSmall);
	value:SetAutoFocus(false);
	value:SetJustifyH("LEFT");
	value:SetTextInsets(4, 4, 0, 0);
	local vbg = value:CreateTexture(nil, "BACKGROUND");
	vbg:SetTexture(0, 0, 0, 0.5);
	vbg:SetAllPoints(value);
	local updating = false;
	local release = spec.release or c.restart;
	local function Names()
		if ( spec.fmt == "quality" ) then
			local names = {};
			for i = 1, 6 do names[i] = _G["VIDEO_QUALITY_LABEL"..i]; end
			return names;
		end
		local low, high = _G[c:GetName().."Low"], _G[c:GetName().."High"];
		local min, max = c:GetMinMaxValues();
		if ( max - min <= 1 and c:GetValueStep() >= 1 ) then
			return { low = low and low:GetText(), high = high and high:GetText() };
		end
	end
	local function Show(v)
		local min, max = c:GetMinMaxValues();
		local names = Names();
		if ( not value:HasFocus() ) then value:SetText(L.Format(v, min, max, c:GetValueStep(), spec.fmt, names)); end
		local lo, hi = L.Ends(min, max, c:GetValueStep(), spec.fmt, names);
		lowText:SetText(lo); highText:SetText(hi);
	end
	local function Apply(v)
		local min, max = c:GetMinMaxValues();
		v = L.Snap(v, min, max, c:GetValueStep());
		if ( c.SetDisplayValue ) then c:SetDisplayValue(v); else c:SetValue(v); end
		AfterChange(spec, c);
		Show(v);
	end
	s:SetScript("OnValueChanged", function(self, v)
		if ( updating ) then return; end
		local min, max = c:GetMinMaxValues();
		v = L.Snap(v, min, max, c:GetValueStep());
		Show(v);
		if ( not release ) then Apply(v); end
	end);
	s:SetScript("OnMouseUp", function(self) if ( release ) then Apply(self:GetValue()); Refresh(); end end);
	local function Nudge(dir)
		local min, max = c:GetMinMaxValues();
		local v = L.Step(c:GetValue(), min, max, c:GetValueStep(), dir);
		updating = true; s:SetValue(v); updating = false;
		Apply(v);
		Refresh();
	end
	prev:SetScript("OnClick", function() Nudge(-1); end);
	nextB:SetScript("OnClick", function() Nudge(1); end);
	value:SetScript("OnEnterPressed", function(self)
		local min, max = c:GetMinMaxValues();
		local v = (spec.fmt ~= "quality") and L.Parse(self:GetText(), min, max, c:GetValueStep(), spec.fmt);
		self:ClearFocus();
		if ( v ) then
			updating = true; s:SetValue(v); updating = false;
			Apply(v);
			Refresh();
		else
			Show(c:GetValue());
		end
	end);
	value:SetScript("OnEscapePressed", function(self) self:ClearFocus(); Show(c:GetValue()); end);
	value:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0); Show(c:GetValue()); end);
	value:SetScript("OnEditFocusGained", function(self) self:HighlightText(); end);
	s.Enable = function(self) getmetatable(self).__index.Enable(self); value:SetTextColor(1, 1, 1); value:EnableMouse(true); end;
	s.Disable = function(self) getmetatable(self).__index.Disable(self); value:SetTextColor(0.5, 0.5, 0.5); value:ClearFocus(); value:EnableMouse(false); end;
	r.widgets = { prev, s, nextB };
	r.UpdateSlider = function()
		local min, max = c:GetMinMaxValues();
		updating = true;
		s:SetMinMaxValues(min, max);
		s:SetValueStep(c:GetValueStep());
		s:SetValue(c:GetValue());
		updating = false;
		Show(c:GetValue());
	end;
end

-- the stock controls a row drives
local function StockRow(spec)
	local c = _G[spec.stock];
	if ( not c ) then return nil; end
	local kind = Kind(c);
	if ( not kind ) then return nil; end
	local r = NewRow(spec, StockLabel(c, kind, spec.label), (kind == "slider") and SLIDER_ROW_H or nil);
	r.stock, r.kind = c, kind;
	r.tooltipFunc = function() return c.tooltipText or c.tooltip or spec.tooltip; end;
	Tooltip(r);
	if ( kind == "check" ) then
		CheckWidget(r, function(on)
			c:SetChecked(on);
			local click = c:GetScript("OnClick");
			if ( click ) then click(c, "LeftButton"); end
			AfterChange(spec, c);
			Refresh();
		end, true);
	elseif ( kind == "choice" ) then
		local cache;
		ChoiceWidget(r, function()
			cache = Choices(c);
			return SelectedChoice(c, cache), cache;
		end, function(index)
			if ( cache and cache[index] ) then Choose(cache[index]); AfterChange(spec, c); end
		end);
	else
		SliderWidget(r, spec, c);
	end
	r.Update = function()
		if ( spec.family ~= "video" and BlizzardOptionsPanel_RefreshControl ) then pcall(BlizzardOptionsPanel_RefreshControl, c); end
		if ( kind == "check" ) then r.check:SetChecked(c:GetChecked());
		elseif ( kind == "choice" ) then r.UpdateChoice();
		else r.UpdateSlider(); end
		SetRowEnabled(r, StockEnabled(c, kind));
	end;
	r.Default = function()
		local d = c.defaultValue;
		if ( d == nil ) then return; end
		if ( kind == "check" ) then
			local on = (tostring(d) == "1");
			if ( c.invert ) then on = not on; end
			if ( (c:GetChecked() and true or false) ~= on ) then r.check:SetChecked(on); r.check:GetScript("OnClick")(r.check); end
		elseif ( kind == "choice" ) then
			local list = Choices(c);
			for _, choice in ipairs(list) do
				if ( tostring(choice.value) == tostring(d) ) then Choose(choice); AfterChange(spec, c); break; end
			end
		else
			if ( c.SetDisplayValue ) then c:SetDisplayValue(d); else c:SetValue(d); end
			AfterChange(spec, c);
		end
	end;
	return r;
end

local function CVarExists(cvar)
	local ok, value = pcall(GetCVar, cvar);
	return ok and value ~= nil;
end

-- [[ server setting rows (mod-temucraft-player-settings) ]] --
-- A switch the server keeps per player: the row sends ".temucraft settings <name> on|off" as a command whispered to
-- yourself (never said aloud, even on a server without the command) and keeps the choice in TemucraftStore
-- ("ui.server.<name>", "1" / "0"). The first time the page shows in a session the stored choice is sent again (or,
-- with none stored, ".temucraft settings <name>" only asks) to learn whether the server knows the setting: its
-- answer (a system line naming the setting, with "on" / "off") makes the row usable; "no such command", no rights
-- or no answer in 6 seconds greys it with "Only on servers with Temucraft player settings". Those lines are kept
-- out of the chat window.
local server = { state = {}, waiting = {} };
-- on: true / false sets it, nil only asks (".temucraft settings <name>")
local function ServerSend(name, on)
	server.waiting[name] = GetTime() + 6;
	server.echo = ".temucraft settings "..name..((on == nil) and "" or (on and " on" or " off"));
	SendChatMessage(server.echo, "WHISPER", nil, UnitName("player"));
end
local function ServerStored(name)
	local v = TemucraftStore_Get and TemucraftStore_Get("A", "ui.server."..name);
	if ( v == "1" ) then return true; elseif ( v == "0" ) then return false; end
end
local function ServerValue(name) return ServerStored(name) == true; end
local function ServerKeep(name, on)
	if ( TemucraftStore_Set ) then TemucraftStore_Set("A", "ui.server."..name, on and "1" or "0"); end
end
-- once per session: the stored choice is sent again (the server follows the account's choice), or with none
-- stored the server is only asked and its answer is taken
local function ServerProbe(name)
	if ( server.state[name] or server.waiting[name] ) then return; end
	if ( TemucraftStore_IsReady and not TemucraftStore_IsReady() ) then return; end
	ServerSend(name, ServerStored(name));
end
local function ServerFilter(self, event, msg)
	local any = false;
	for name, untilTime in pairs(server.waiting) do
		if ( GetTime() <= untilTime ) then
			any = true;
			if ( event == "CHAT_MSG_SYSTEM" ) then
				local answer, value = L.ServerReply(name, msg);
				if ( answer ) then
					server.state[name] = answer;
					if ( answer == "yes" and value and ServerStored(name) == nil ) then ServerKeep(name, value == "on"); end
					server.waiting[name] = nil;
					if ( f:IsShown() ) then Refresh(); end
					return true;
				end
			elseif ( server.echo and msg == server.echo ) then
				-- the server let the whisper through: it has no such command (or we may not use it)
				server.state[name] = "no";
				server.waiting[name] = nil;
				if ( f:IsShown() ) then Refresh(); end
				return true;
			end
		end
	end
	return false;
end
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", ServerFilter);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", ServerFilter);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", ServerFilter);
local serverTimer = CreateFrame("Frame");
serverTimer:SetScript("OnUpdate", function(self, elapsed)
	self.t = (self.t or 0) + elapsed;
	if ( self.t < 1 ) then return; end
	self.t = 0;
	for name, untilTime in pairs(server.waiting) do
		if ( GetTime() > untilTime ) then
			server.waiting[name] = nil;
			if ( not server.state[name] ) then server.state[name] = "no"; end
			if ( f:IsShown() ) then Refresh(); end
		end
	end
end);

local function ServerRow(spec)
	local r = NewRow(spec, spec.label);
	Tooltip(r, spec.tooltip, spec.label);
	CheckWidget(r, function(on)
		ServerKeep(spec.name, on);
		ServerSend(spec.name, on);
		Refresh();
	end);
	local note = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall");
	note:SetPoint("LEFT", r.check, "RIGHT", 4, 0);
	r.Update = function()
		ServerProbe(spec.name);
		r.check:SetChecked(ServerValue(spec.name));
		local known = server.state[spec.name];
		if ( known == "no" ) then
			SetRowEnabled(r, false);
			note:SetText("Only on servers with Temucraft player settings");
		else
			SetRowEnabled(r, true);
			note:SetText(known == nil and server.waiting[spec.name] and "..." or "");
		end
	end;
	r.Default = function()
		if ( r.enabled and ServerValue(spec.name) ) then
			ServerKeep(spec.name, false);
			ServerSend(spec.name, false);
		end
	end;
	return r;
end

-- more server switches for a page later (the teleport / chest prompts ...): add the row to a page's group
function TemucraftOptions_ServerRow(name, label, tooltip)
	return { kind = "server", name = name, label = label, tooltip = tooltip };
end

local MODIFIER_CHOICES = { { value = "ALT", text = ALT_KEY or "ALT key" }, { value = "CTRL", text = CTRL_KEY or "CTRL key" },
	{ value = "SHIFT", text = SHIFT_KEY or "SHIFT key" }, { value = "NONE", text = NONE_KEY or "None" } };

local function CustomRow(spec)
	if ( spec.kind == "server" ) then return ServerRow(spec); end
	if ( spec.kind == "tutorials" ) then
		local r = NewRow(spec, spec.label);
		Tooltip(r, spec.tooltip, spec.label);
		CheckWidget(r, function(on)
			SetCVar("showTutorials", on and "1" or "0");
			if ( TemucraftTutorial_SetEnabled ) then TemucraftTutorial_SetEnabled(on); end
			Refresh();
		end);
		r.Update = function()
			r.check:SetChecked((not TemucraftTutorial_IsEnabled) or TemucraftTutorial_IsEnabled());
			SetRowEnabled(r, true);
		end;
		r.Default = function()
			SetCVar("showTutorials", "1");
			if ( TemucraftTutorial_SetEnabled ) then TemucraftTutorial_SetEnabled(true); end
		end;
		return r;
	end
	-- a row with one button: { kind = "button", label, text = button text, click = func, tooltip }
	if ( spec.kind == "button" ) then
		local r = NewRow(spec, spec.label);
		Tooltip(r, spec.tooltip, spec.label);
		local b = CreateFrame("Button", nil, r, "UIPanelButtonTemplate");
		b:SetWidth(spec.width or 120); b:SetHeight(22);
		b:SetPoint("LEFT", CONTROL_X, 0);
		b:SetText(spec.text or spec.label);
		b:SetScript("OnClick", function() PlaySound("igMainMenuOptionCheckBoxOn"); spec.click(); Refresh(); end);
		r.widgets = { b };
		r.button = b;
		r.Update = function() SetRowEnabled(r, true); end;
		return r;
	end
	if ( spec.kind == "cvar" ) then
		if ( not CVarExists(spec.cvar) ) then return nil; end
		local r = NewRow(spec, spec.label);
		Tooltip(r, spec.tooltip, spec.label);
		CheckWidget(r, function(on) SetCVar(spec.cvar, on and "1" or "0"); Refresh(); end);
		r.Update = function() r.check:SetChecked(GetCVar(spec.cvar) == "1"); SetRowEnabled(r, true); end;
		r.Default = function() local d = GetCVarDefault and GetCVarDefault(spec.cvar); if ( d ) then SetCVar(spec.cvar, d); end end;
		return r;
	end
	if ( spec.kind == "cvarslider" ) then
		if ( not CVarExists(spec.cvar) ) then return nil; end
		local r = NewRow(spec, spec.label, SLIDER_ROW_H);
		Tooltip(r, spec.tooltip, spec.label);
		-- the slider widget drives a control: here a stand-in that reads and writes the CVar
		local proxy = {
			GetMinMaxValues = function() return spec.min, spec.max; end,
			GetValueStep = function() return spec.step; end,
			GetValue = function() return L.Snap(tonumber(GetCVar(spec.cvar)) or spec.min, spec.min, spec.max, spec.step); end,
			SetValue = function(_, v) SetCVar(spec.cvar, tostring(v)); end,
			GetName = function() return "TemucraftCVar"..spec.cvar; end,
			GetParent = function() return nil; end,
		};
		SliderWidget(r, spec, proxy);
		r.Update = function() r.UpdateSlider(); SetRowEnabled(r, true); end;
		r.Default = function() local d = GetCVarDefault and GetCVarDefault(spec.cvar); if ( d ) then SetCVar(spec.cvar, d); end end;
		return r;
	end
	if ( spec.kind == "modifier" ) then
		local r = NewRow(spec, spec.label);
		Tooltip(r, spec.tooltip, spec.label);
		local function Set(value)
			if ( InCombatLockdown() ) then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Not in combat.", 1, 0.1, 0.1); return; end
			SetModifiedClick(spec.action, value);
			SaveBindings(GetCurrentBindingSet());
		end
		ChoiceWidget(r, function()
			local value = GetModifiedClick(spec.action);
			for i, c in ipairs(MODIFIER_CHOICES) do if ( c.value == value ) then return i, MODIFIER_CHOICES; end end
			return nil, MODIFIER_CHOICES;
		end, function(index) Set(MODIFIER_CHOICES[index].value); end);
		r.Update = function() r.UpdateChoice(); SetRowEnabled(r, true); end;
		r.Default = function() if ( spec.default and GetModifiedClick(spec.action) ~= spec.default ) then Set(spec.default); end end;
		return r;
	end
	if ( spec.kind == "text" ) then
		local r = NewRow(spec, spec.label);
		local v = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
		v:SetPoint("LEFT", CONTROL_X + 4, 0);
		r.Update = function()
			local text = GetLocale();
			if ( spec.value == "audiolocale" ) then
				local ok, a = pcall(GetCVar, "audioLocale");
				text = (ok and a and a ~= "") and a or text;
			end
			v:SetText(text);
			SetRowEnabled(r, true);
		end;
		return r;
	end
	if ( spec.kind == "note" ) then
		local r = NewRow(spec, "");
		r.label:SetFontObject(GameFontHighlightSmall);
		r.label:SetWidth(CHILD_W - 50);
		r.label:SetText(spec.text);
		r.Update = function() r.label:SetTextColor(0.8, 0.8, 0.8); end;
		r.note = true;
		return r;
	end
end

local function RowFor(spec)
	if ( rows[spec] == nil ) then
		rows[spec] = (spec.stock and StockRow(spec) or CustomRow(spec)) or false;
	end
	return rows[spec] or nil;
end

-- sub-headers (white) and the Graphics Quality box
local headers = {};
local function Header(text)
	local h = headers[text];
	if ( not h ) then
		h = CreateFrame("Frame", nil, child);
		h:SetWidth(CHILD_W - 10); h:SetHeight(34);
		local fs = h:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge");
		fs:SetPoint("BOTTOMLEFT", 12, 6);
		h.text = fs;
		local line = TemucraftStyle_Line(h);
		line:SetPoint("BOTTOMLEFT", 8, 2); line:SetPoint("BOTTOMRIGHT", -8, 2);
		headers[text] = h;
	end
	h.text:SetText(text);
	return h;
end
local box = CreateFrame("Frame", nil, child);
TemucraftStyle_Inset(box, 0.8);
box:SetBackdropColor(0.18, 0.17, 0.16, 0.9);
box:SetFrameLevel(child:GetFrameLevel());
box:Hide();

-- [[ key bindings ]] --
local bind = { expanded = {}, rows = {}, bars = {}, capture = nil };
local CaptureStop;

local function BindingList()
	local list = {};
	for i = 1, GetNumBindings() do
		local command, key1, key2 = GetBinding(i);
		if ( command ) then table.insert(list, { command, key1, key2 }); end
	end
	return L.GroupBindings(list, function(command) return _G["BINDING_"..command]; end);
end

local function KeyText(key)
	if ( not key ) then return "|cff808080"..(NOT_BOUND or "Not Bound").."|r"; end
	return GetBindingText(key, "KEY_");
end

local function DoBind(command, slot, key)
	if ( InCombatLockdown() ) then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Not in combat.", 1, 0.1, 0.1); return; end
	local key1, key2 = GetBindingKey(command);
	local old = GetBindingAction(key);
	if ( key1 ) then SetBinding(key1); end
	if ( key2 ) then SetBinding(key2); end
	SetBinding(key);
	local ok;
	if ( slot == 1 ) then
		ok = SetBinding(key, command);
		if ( not ok and key1 ) then SetBinding(key1, command); end
		if ( key2 ) then SetBinding(key2, command); end
	else
		if ( key1 ) then SetBinding(key1, command); end
		ok = SetBinding(key, command);
		if ( not ok and key2 ) then SetBinding(key2, command); end
	end
	SaveBindings(GetCurrentBindingSet());
	if ( not ok ) then Status(KEYBINDINGFRAME_MOUSEWHEEL_ERROR or "That key can't be bound.");
	elseif ( old and old ~= "" and old ~= command ) then Status(string.format(KEY_UNBOUND_ERROR or "%s is now unbound", GetBindingText(old, "BINDING_NAME_")));
	else Status(KEY_BOUND or "Key bound."); end
end

local function Unbind(command, slot)
	if ( InCombatLockdown() ) then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Not in combat.", 1, 0.1, 0.1); return; end
	local key = select(slot, GetBindingKey(command));
	if ( key ) then SetBinding(key); SaveBindings(GetCurrentBindingSet()); end
end

function CaptureStop()
	if ( bind.capture ) then bind.capture.button:UnlockHighlight(); end
	bind.capture = nil;
	f:EnableKeyboard(false);
end

local function CaptureKey(key)
	local cap = bind.capture;
	if ( not cap ) then return; end
	if ( key == "ESCAPE" ) then CaptureStop(); Status(""); Refresh(); return; end
	local full = L.KeyFromInput(key, IsShiftKeyDown(), IsControlKeyDown(), IsAltKeyDown());
	if ( not full ) then return; end
	CaptureStop();
	DoBind(cap.command, cap.slot, full);
	Refresh();
end
f:SetScript("OnKeyDown", function(self, key) CaptureKey(key); end);

local function KeyButton(r, slot)
	local b = CreateFrame("Button", nil, r, "UIPanelButtonTemplate");
	b:SetWidth(130); b:SetHeight(22);
	b:SetPoint("LEFT", CONTROL_X - 30 + (slot - 1) * 136, 0);
	b:RegisterForClicks("AnyUp");
	b:SetScript("OnClick", function(self, button)
		local command = r.command;
		if ( bind.capture and bind.capture.button == self ) then
			if ( button == "LeftButton" or button == "RightButton" ) then CaptureStop(); Status(""); Refresh(); return; end
			CaptureKey(button);
			return;
		end
		if ( button == "RightButton" ) then CaptureStop(); Unbind(command, slot); Refresh(); return; end
		if ( button ~= "LeftButton" ) then return; end
		if ( InCombatLockdown() ) then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Not in combat.", 1, 0.1, 0.1); return; end
		CaptureStop();
		bind.capture = { command = command, slot = slot, button = self };
		self:LockHighlight();
		f:EnableKeyboard(true);
		Status(string.format(BIND_KEY_TO_COMMAND or "Press a key for %s", GetBindingText(command, "BINDING_NAME_")).."  (Esc: cancel, right click: unbind)");
	end);
	return b;
end

local function BindingRow(command)
	local r = bind.rows[command];
	if ( not r ) then
		r = NewRow({ sub = true }, GetBindingText(command, "BINDING_NAME_"), 24);
		r.label:SetWidth(CONTROL_X - 70);
		r.command = command;
		r.key1, r.key2 = KeyButton(r, 1), KeyButton(r, 2);
		r.Update = function()
			local k1, k2 = GetBindingKey(command);
			r.key1:SetText(KeyText(k1)); r.key2:SetText(KeyText(k2));
			r.label:SetTextColor(1, 1, 1);
		end;
		bind.rows[command] = r;
	end
	return r;
end

local function BindingBar(group)
	local b = bind.bars[group.header];
	if ( not b ) then
		b = CreateFrame("Button", nil, child);
		b:SetWidth(CHILD_W - 10); b:SetHeight(24);
		TemucraftStyle_Bar(b);
		local icon = b:CreateTexture(nil, "ARTWORK");
		icon:SetWidth(14); icon:SetHeight(14); icon:SetPoint("LEFT", 8, 0);
		b.icon = icon;
		local text = b:CreateFontString(nil, "ARTWORK", "GameFontNormal");
		text:SetPoint("LEFT", icon, "RIGHT", 8, 0);
		b.text = text;
		TemucraftStyle_Highlight(b);
		b:SetScript("OnClick", function()
			bind.expanded[group.header] = not bind.expanded[group.header];
			PlaySound(bind.expanded[group.header] and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
			Refresh();
		end);
		bind.bars[group.header] = b;
	end
	b.text:SetText(group.text);
	b.icon:SetTexture(bind.expanded[group.header] and "Interface\\Buttons\\UI-MinusButton-UP" or "Interface\\Buttons\\UI-PlusButton-UP");
	return b;
end

local charRow;
StaticPopupDialogs["TEMUCRAFT_OPTIONS_ACCOUNT_BINDINGS"] = {
	text = CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS or "Use your account's key bindings again? This character's own bindings will be deleted.",
	button1 = OKAY, button2 = CANCEL,
	OnAccept = function()
		if ( InCombatLockdown() ) then return; end
		LoadBindings(ACCOUNT_BINDINGS or 1); SaveBindings(ACCOUNT_BINDINGS or 1);
		if ( f:IsShown() ) then Refresh(); end
	end,
	OnCancel = function() if ( f:IsShown() ) then Refresh(); end end,
	timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1,
};
local function CharacterRow()
	if ( charRow ) then return charRow; end
	charRow = NewRow({}, CHARACTER_SPECIFIC_KEYBINDINGS or "Character Specific Keybindings");
	CheckWidget(charRow, function(on)
		if ( InCombatLockdown() ) then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Not in combat.", 1, 0.1, 0.1); Refresh(); return; end
		if ( on ) then SaveBindings(CHARACTER_BINDINGS or 2); Refresh();
		else StaticPopup_Show("TEMUCRAFT_OPTIONS_ACCOUNT_BINDINGS"); end
	end);
	charRow.Update = function() charRow.check:SetChecked(GetCurrentBindingSet() == (CHARACTER_BINDINGS or 2)); SetRowEnabled(charRow, true); end;
	return charRow;
end

-- [[ laying out a page ]] --
local function Place(frame, y, x)
	frame:ClearAllPoints();
	frame:SetPoint("TOPLEFT", child, "TOPLEFT", x or 4, -y);
	frame:Show();
	return y + frame:GetHeight();
end

local function HideAll()
	for _, r in pairs(rows) do if ( r ) then r:Hide(); end end
	for _, h in pairs(headers) do h:Hide(); end
	for _, r in pairs(bind.rows) do r:Hide(); end
	for _, b in pairs(bind.bars) do b:Hide(); end
	if ( charRow ) then charRow:Hide(); end
	box:Hide();
	wipe(visibleRows);
end

-- one page's groups; query: only the rows matching it (search), with the page name as header
local function LayoutPage(page, y, query)
	if ( page.kind == "keybindings" ) then
		local groups = BindingList();
		if ( not query ) then
			y = Place(CharacterRow(), y) + 6;
			table.insert(visibleRows, charRow);
		end
		for _, g in ipairs(groups) do
			local matching = {};
			for _, b in ipairs(g.rows) do
				if ( not query or L.Matches(GetBindingText(b[1], "BINDING_NAME_"), query) ) then table.insert(matching, b); end
			end
			if ( #matching > 0 ) then
				if ( query ) then
					y = Place(Header(page.title.." - "..g.text), y);
				else
					y = Place(BindingBar(g), y) + 2;
				end
				if ( query or bind.expanded[g.header] ) then
					for _, b in ipairs(matching) do
						local r = BindingRow(b[1]);
						y = Place(r, y);
						table.insert(visibleRows, r);
					end
				end
			end
		end
		return y;
	end
	local any = false;
	for _, g in ipairs(page.groups or {}) do
		local list = {};
		for _, spec in ipairs(g.rows) do
			local r = RowFor(spec);
			if ( r and not (r.note and (query or (spec.ifEmpty and any))) and (not query or L.Matches(r.label:GetText(), query)) ) then
				table.insert(list, r);
				if ( not r.note ) then any = true; end
			end
		end
		if ( #list > 0 ) then
			local text = g.header;
			if ( query ) then text = page.title..(g.header and (" - "..g.header) or ""); end
			if ( text ) then y = Place(Header(text), y); end
			local top = y;
			if ( g.box and not query ) then y = y + 6; end
			for _, r in ipairs(list) do
				y = Place(r, y);
				table.insert(visibleRows, r);
			end
			if ( g.box and not query ) then
				y = y + 6;
				box:ClearAllPoints();
				box:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -top);
				box:SetWidth(CHILD_W - 20); box:SetHeight(y - top);
				box:Show();
			end
			y = y + 4;
		end
	end
	return y;
end

-- [[ AddOns tab: the addon panels ]] --
local shownPanel;
local touched = {};
local addonExpanded = {};

local function TemucraftPanel() return _G.TemucraftInterfaceOptionsPanel; end

local dragonLink = { name = "DragonUI", link = true };
local function DragonUIOpen()
	if ( DragonUIGameMenuButton and DragonUIGameMenuButton:GetScript("OnClick") ) then
		f:Hide(); DragonUIGameMenuButton:GetScript("OnClick")(DragonUIGameMenuButton, "LeftButton"); return;
	end
	for key, func in pairs(SlashCmdList) do
		if ( _G["SLASH_"..key.."1"] == "/dui" ) then f:Hide(); func(""); return; end
	end
end
local dragonPage = CreateFrame("Frame", nil, host);
dragonPage:SetAllPoints(); dragonPage:Hide();
do
	local t = dragonPage:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
	t:SetPoint("TOPLEFT", 16, -12); t:SetPoint("RIGHT", -16, 0); t:SetJustifyH("LEFT");
	t:SetText("DragonUI is the base of the interface: its bars, unit frames, minimap and the windows it dresses are set in its own settings window. Edit Mode moves the bars and frames.");
	local open = CreateFrame("Button", nil, dragonPage, "UIPanelButtonTemplate");
	open:SetWidth(180); open:SetHeight(24); open:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -16);
	open:SetText("DragonUI Settings");
	open:SetScript("OnClick", DragonUIOpen);
	local edit = CreateFrame("Button", nil, dragonPage, "UIPanelButtonTemplate");
	edit:SetWidth(180); edit:SetHeight(24); edit:SetPoint("LEFT", open, "RIGHT", 8, 0);
	edit:SetText("Edit Mode");
	edit:SetScript("OnClick", function()
		local dui = _G.DragonUI;
		if ( InCombatLockdown() ) then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Not in combat.", 1, 0.1, 0.1); return; end
		if ( dui and dui.EditorMode and dui.EditorMode.Toggle ) then f:Hide(); dui.EditorMode:Toggle(); end
	end);
	dragonPage:SetScript("OnShow", function()
		local dui = _G.DragonUI;
		if ( dui and dui.EditorMode and dui.EditorMode.Toggle ) then edit:Show(); else edit:Hide(); end
	end);
end

local function AddonCategories()
	local cats = {};
	local haveDragon = false;
	for _, c in ipairs(INTERFACEOPTIONS_ADDONCATEGORIES or {}) do
		table.insert(cats, c);
		if ( c.name == "DragonUI" ) then haveDragon = true; end
	end
	local ours = TemucraftPanel();
	if ( ours ) then table.insert(cats, ours); end
	if ( not haveDragon and TemucraftDragonUI_IsLoaded and TemucraftDragonUI_IsLoaded() ) then table.insert(cats, dragonLink); end
	return cats;
end

local function ReleasePanel()
	if ( not shownPanel ) then return; end
	local p = shownPanel;
	shownPanel = nil;
	if ( p == dragonLink ) then dragonPage:Hide(); return; end
	p:Hide();
	local container = InterfaceOptionsFramePanelContainer;
	if ( container ) then
		p:SetParent(container);
		p:ClearAllPoints();
		p:SetPoint("TOPLEFT", container, "TOPLEFT");
		p:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT");
		if ( container.displayedPanel == p ) then p:Show(); end
	end
end

local function ShowAddonPanel(p)
	ReleasePanel();
	shownPanel = p;
	if ( p == dragonLink ) then dragonPage:Show(); return; end
	securecall(pcall, p.refresh, p);
	p:SetParent(host);
	p:ClearAllPoints();
	p:SetPoint("TOPLEFT", host, "TOPLEFT");
	p:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT");
	p:Show();
	touched[p] = true;
end

-- [[ the left list ]] --
local listButtons = {};
local function ListButton(i)
	local b = listButtons[i];
	if ( b ) then return b; end
	b = CreateFrame("Button", nil, listChild);
	b:SetWidth(LIST_W - 34); b:SetHeight(22);
	b.bg = TemucraftStyle_Bar(b);
	local text = b:CreateFontString(nil, "ARTWORK", "GameFontNormal");
	text:SetPoint("LEFT", 10, 0); text:SetPoint("RIGHT", -4, 0); text:SetJustifyH("LEFT");
	b.text = text;
	local hl = b:CreateTexture(nil, "HIGHLIGHT");
	hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight"); hl:SetBlendMode("ADD"); hl:SetAlpha(0.35);
	hl:SetAllPoints(); b.hl = hl;
	b.glow = TemucraftStyle_Glow(b);
	local line = Solid(b, "OVERLAY", 1, 0.82, 0, 1);
	line:SetHeight(2); line:SetPoint("BOTTOMLEFT", 6, 1); line:SetPoint("BOTTOMRIGHT", -6, 1);
	b.line = line;
	local toggle = CreateFrame("Button", nil, b);
	toggle:SetWidth(14); toggle:SetHeight(14); toggle:SetPoint("LEFT", 4, 0);
	b.toggle = toggle;
	b:SetScript("OnClick", function(self) if ( self.onClick ) then self.onClick(); end end);
	toggle:SetScript("OnClick", function() if ( b.onToggle ) then b.onToggle(); end end);
	listButtons[i] = b;
	return b;
end

local function DrawList(items)
	local y = 0;
	for i, item in ipairs(items) do
		local b = ListButton(i);
		b:ClearAllPoints();
		b:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -y);
		b.onClick, b.onToggle = item.onClick, item.onToggle;
		b.text:SetText(item.text);
		if ( item.kind == "section" ) then
			b:SetHeight(24);
			b.bg:Show(); b.hl:Hide(); b.glow:Hide(); b.line:Hide(); b.toggle:Hide();
			b.text:SetFontObject(GameFontHighlight); b.text:SetPoint("LEFT", 8, 0);
			b:EnableMouse(false);
			y = y + 26;
		else
			b:SetHeight(22);
			b.bg:Hide(); b.hl:Show();
			b:EnableMouse(true);
			b.text:SetFontObject(item.depth == 1 and GameFontNormalSmall or GameFontNormal);
			local x = (item.depth == 1) and 34 or (tab == "addons" and 22 or 14);
			b.text:SetPoint("LEFT", x, 0);
			if ( item.box ) then
				b.toggle:Show();
				b.toggle:SetNormalTexture(item.box == "-" and "Interface\\Buttons\\UI-MinusButton-UP" or "Interface\\Buttons\\UI-PlusButton-UP");
				b.toggle:SetPushedTexture(item.box == "-" and "Interface\\Buttons\\UI-MinusButton-DOWN" or "Interface\\Buttons\\UI-PlusButton-DOWN");
			else
				b.toggle:Hide();
			end
			if ( item.selected ) then b.glow:Show(); b.line:Show(); b.text:SetTextColor(1, 1, 1);
			else b.glow:Hide(); b.line:Hide(); b.text:SetTextColor(1, 0.82, 0); end
			y = y + 23;
		end
		b:Show();
	end
	for i = #items + 1, #listButtons do listButtons[i]:Hide(); end
	listChild:SetHeight(math.max(y, 10));
end

local lastGame, lastAddon = "controls", nil;

local function GameItems()
	local items = {};
	for _, item in ipairs(L.GameList()) do
		if ( item.kind == "section" ) then
			table.insert(items, item);
		else
			local page = item.page;
			table.insert(items, { kind = "page", text = page.title, selected = (current == page),
				onClick = function() PlaySound("igMainMenuOptionCheckBoxOn"); search:SetText(""); Select(page); end });
		end
	end
	return items;
end

local function AddonItems()
	local items = {};
	for _, e in ipairs(L.AddonTree(AddonCategories(), addonExpanded)) do
		local cat = e.cat;
		table.insert(items, { kind = "addon", text = cat.name, depth = e.depth, selected = (current == cat),
			box = e.children and (e.expanded and "-" or "+") or nil,
			onClick = function()
				PlaySound("igMainMenuOptionCheckBoxOn");
				search:SetText("");
				if ( e.children and not addonExpanded[cat.name] ) then addonExpanded[cat.name] = true; end
				Select(cat);
			end,
			onToggle = function() addonExpanded[cat.name] = not addonExpanded[cat.name]; Refresh(); end });
	end
	if ( #items == 0 ) then table.insert(items, { kind = "section", text = "No addon settings" }); end
	return items;
end

-- [[ the page shown ]] --
local function IsAddonCat(p) return type(p) == "table" and (p.link == true or p.GetObjectType ~= nil); end

function Refresh()
	if ( not f:IsShown() ) then return; end
	-- the list
	if ( tab == "game" ) then DrawList(GameItems()); else DrawList(AddonItems()); end
	for _, b in ipairs(tabs) do
		if ( b.key == tab ) then b.text:SetTextColor(1, 1, 1); b.line:Show(); else b.text:SetTextColor(1, 0.82, 0); b.line:Hide(); end
	end
	local query = search:GetText();
	if ( query == "" ) then query = nil; searchHint:Show(); else searchHint:Hide(); end
	if ( search:HasFocus() ) then searchHint:Hide(); end
	-- the page
	HideAll();
	apply:Hide();
	defaults:Show();
	if ( query ) then
		ReleasePanel();
		host:Hide(); scroll:Show();
		pageTitle:SetText((SEARCH or "Search")..": "..query);
		defaults:Hide();
		local y = 4;
		for _, p in ipairs(L.PAGES) do y = LayoutPage(p, y, query); end
		if ( #visibleRows == 0 ) then
			y = Place(Header("Nothing found"), y);
		end
		child:SetHeight(math.max(y + 10, 10));
	elseif ( IsAddonCat(current) ) then
		scroll:Hide(); host:Show();
		pageTitle:SetText(current.name);
		if ( shownPanel ~= current ) then ShowAddonPanel(current); end
		if ( current == dragonLink ) then defaults:Hide(); end
	elseif ( current ) then
		ReleasePanel();
		host:Hide(); scroll:Show();
		pageTitle:SetText(current.title);
		if ( current.apply ) then apply:Show(); if ( videoPending ) then apply:Enable(); else apply:Disable(); end end
		local y = LayoutPage(current, 4);
		child:SetHeight(math.max(y + 10, 10));
	end
	RefreshRows();
end

function RefreshRows()
	for _, r in ipairs(visibleRows) do if ( r.Update ) then r:Update(); end end
end

function Select(what)
	if ( IsAddonCat(what) ) then tab = "addons"; lastAddon = what; else tab = "game"; lastGame = what.key; end
	if ( current ~= what ) then scroll:SetVerticalScroll(0); end
	current = what;
	CaptureStop();
	Status("");
	Refresh();
end

function ShowTab(which)
	if ( which == "addons" ) then
		local cats = L.AddonTree(AddonCategories(), addonExpanded);
		local target = lastAddon or (cats[1] and cats[1].cat);
		tab = "addons";
		if ( target ) then Select(target); else current = nil; Refresh(); end
	else
		Select(L.Page(lastGame) or L.PAGES[1]);
	end
end

search:SetScript("OnTextChanged", function() if ( f:IsShown() ) then Refresh(); end end);
search:SetScript("OnEditFocusGained", function() searchHint:Hide(); end);
search:SetScript("OnEditFocusLost", function(self) if ( self:GetText() == "" ) then searchHint:Show(); end end);
search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); end);
search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);

apply:SetScript("OnClick", function() ApplyVideo(); Refresh(); end);

-- Defaults: the page's rows (or the addon panel's own defaults), after a yes
StaticPopupDialogs["TEMUCRAFT_OPTIONS_DEFAULTS"] = {
	text = "Reset the settings on this page to their defaults?",
	button1 = OKAY, button2 = CANCEL,
	OnAccept = function()
		local page = current;
		if ( IsAddonCat(page) ) then
			securecall(pcall, page.default, page); securecall(pcall, page.refresh, page);
		elseif ( page and page.kind == "keybindings" ) then
			if ( InCombatLockdown() ) then return; end
			LoadBindings(DEFAULT_BINDINGS or 0); SaveBindings(GetCurrentBindingSet());
		elseif ( page and page.key == "graphics" ) then
			if ( VideoOptionsFrame_SetAllToDefaults ) then VideoOptionsFrame_SetAllToDefaults(); end
			CommitVideo();
		elseif ( page and page.key == "audio" ) then
			if ( AudioOptionsFrame_SetAllToDefaults ) then AudioOptionsFrame_SetAllToDefaults(); end
		elseif ( page ) then
			for _, g in ipairs(page.groups or {}) do
				for _, spec in ipairs(g.rows) do
					local r = RowFor(spec);
					if ( r and r.Default ) then pcall(r.Default); end
				end
			end
		end
		RestartAlerts();
		Refresh();
	end,
	timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1,
};
defaults:SetScript("OnClick", function() StaticPopup_Show("TEMUCRAFT_OPTIONS_DEFAULTS"); end);

-- [[ open / close ]] --
local wasShown = {};
f:SetScript("OnShow", function(self)
	local scale = math.min(1, (UIParent:GetHeight() - 40) / H, (UIParent:GetWidth() - 40) / W);
	self:SetScale(scale);
	PlaySound("igMainMenuOpen");
	-- the stock panels count as shown (their scripts check IsShown) while their frames stay hidden
	for _, name in ipairs(SHOWN_PANELS) do
		local p = _G[name];
		if ( p ) then wasShown[name] = p:IsShown(); p:Show(); end
	end
	if ( not videoPending ) then
		for _, name in ipairs(VIDEO_PANELS) do local p = _G[name]; if ( p and p.refresh ) then pcall(p.refresh, p); end end
	end
	for _, b in ipairs(tabs) do b:SetWidth(b.text:GetStringWidth() + 24); end
	if ( not current ) then current = L.Page(lastGame) or L.PAGES[1]; end
	Refresh();
end);

f:SetScript("OnHide", function(self)
	CaptureStop();
	search:ClearFocus();
	-- the addon panels opened here get their okay, as if the stock window's Okay was pressed
	for p in pairs(touched) do securecall(pcall, p.okay, p); end
	wipe(touched);
	ReleasePanel();
	if ( IsAddonCat(current) ) then current = nil; end
	for _, name in ipairs(SHOWN_PANELS) do
		local p = _G[name];
		if ( p ) then
			local container = p:GetParent();
			if ( container and container.displayedPanel ) then
				if ( container.displayedPanel == p ) then p:Show(); else p:Hide(); end
			elseif ( not wasShown[name] ) then p:Hide(); end
		end
	end
	if ( videoPending ) then StaticPopup_Show("TEMUCRAFT_OPTIONS_APPLY_VIDEO"); end
	RestartAlerts();
	PlaySound("gsTitleOptionExit");
	if ( self.lastFrame ) then
		local last = self.lastFrame;
		self.lastFrame = nil;
		ShowUIPanel(last);
	end
end);

local events = CreateFrame("Frame");
events:RegisterEvent("PLAYER_REGEN_DISABLED");
events:RegisterEvent("UPDATE_BINDINGS");
events:SetScript("OnEvent", function(self, event)
	if ( event == "PLAYER_REGEN_DISABLED" ) then
		if ( bind.capture ) then CaptureStop(); Status(ERR_NOT_IN_COMBAT or "Not in combat."); end
	elseif ( f:IsShown() and current and current.kind == "keybindings" ) then
		RefreshRows();
	end
end);

local function Find(what)
	if ( what == nil ) then return nil; end
	if ( type(what) == "string" ) then
		local page = L.Page(what);
		if ( page ) then return page; end
		for _, c in ipairs(AddonCategories()) do if ( c.name == what ) then return c; end end
		for _, p in ipairs(L.PAGES) do if ( p.title == what ) then return p; end end
		return nil;
	end
	for _, c in ipairs(AddonCategories()) do if ( c == what ) then return c; end end
end

local function OpenNow(what)
	local target = Find(what);
	if ( target and IsAddonCat(target) and target.parent ) then addonExpanded[target.parent] = true; end
	if ( not f:IsShown() ) then
		if ( target ) then current = target; end
		f:Show();
	end
	if ( target ) then Select(target); end
end

-- opened on the next frame, from our own (secure) OnUpdate: an addon calling this can't taint the stock
-- dropdown functions our rows read
local opener = CreateFrame("Frame");
opener:Hide();
opener:SetScript("OnUpdate", function(self)
	self:Hide();
	local what, last = self.what, self.lastFrame;
	self.what, self.lastFrame = nil, nil;
	OpenNow(what);
	if ( last ) then f.lastFrame = last; end
end);
function TemucraftOptions_Open(what, lastFrame)
	opener.what, opener.lastFrame = what, lastFrame;
	opener:Show();
end

function TemucraftOptions_Toggle()
	if ( f:IsShown() ) then f:Hide(); else TemucraftOptions_Open(); end
end

function TemucraftOptions_IsClassic()
	return TemucraftUI_IsClassic ~= nil and TemucraftUI_IsClassic("options");
end

-- addons (and /tui) that open their page in Interface Options get it here instead, unless the classic menu is on
local redirecting = false;
hooksecurefunc("InterfaceOptionsFrame_OpenToCategory", function(panel)
	if ( redirecting or TemucraftOptions_IsClassic() or not InterfaceOptionsFrame:IsShown() ) then return; end
	local target = Find(panel);
	if ( not target and type(panel) == "table" and panel.name ) then target = Find(panel.name); end
	if ( not target ) then return; end
	redirecting = true;
	HideUIPanel(InterfaceOptionsFrame);
	TemucraftOptions_Open(target);
	redirecting = false;
end);

SLASH_TEMUCRAFTOPTIONS1 = "/options";
SLASH_TEMUCRAFTOPTIONS2 = "/settings";
SlashCmdList["TEMUCRAFTOPTIONS"] = function(msg)
	msg = msg and string.lower(string.match(msg, "^%s*(.-)%s*$")) or "";
	TemucraftOptions_Open(msg ~= "" and msg or nil);
end;
