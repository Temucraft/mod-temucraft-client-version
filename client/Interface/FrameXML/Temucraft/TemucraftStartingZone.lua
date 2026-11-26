-- Temucraft starting zone window: "Embark on your Journey". A new character picks where to begin from picture cards
-- (mod-temucraft-starting-zone, addon prefix TSZ). The card of the zone the character stands in comes first and reads
-- "Stay in <subzone>"; a click is the choice (the server teleports and sets the hearthstone, no extra prompt).
--   client -> server: HELLO (entering the world: "this client has the window"), PICK~<index>, CLOSE (closed unpicked)
--   server -> client: BEGIN~<count>, Z~<index>~<here>~<map>~<zone>~<area>~<x>~<y>~<name> per zone, END, DONE
-- The pictures are the client's own world map of the zone, zoomed onto the starting spot (stock 3.3.5 art); a zone
-- without map art gets its continent's loading screen. A client without this file gets the server's gossip menu.
TemucraftStartingZoneLogic = {};
local L = TemucraftStartingZoneLogic;

L.PREFIX = "TSZ";
L.PER_PAGE = 6;
L.ART_W, L.ART_H = 256, 144;      -- a card's picture
L.ZOOM = 420;                      -- map pixels (of 1002) across a picture: about 40% of the zone
L.MAP_W, L.MAP_H = 1002, 668;      -- the part of the 4x3 tiles (1024x768) the world map shows

-- loading screens by map id, for zones without world map art
L.LOADING = {
	[0] = "Interface\\Glues\\LoadingScreens\\LoadScreenEasternKingdom",
	[1] = "Interface\\Glues\\LoadingScreens\\LoadScreenKalimdor",
	[530] = "Interface\\Glues\\LoadingScreens\\LoadScreenOutland",
	[571] = "Interface\\Glues\\LoadingScreens\\LoadScreenNorthrend",
};

-- incoming list
function L.OnMessage(message)
	if ( type(message) ~= "string" ) then return nil; end
	local kind, a, b, c, d, e, f, g, name = strsplit("~", message);
	if ( kind == "BEGIN" ) then
		L.incoming = {};
		return nil;
	elseif ( kind == "Z" and L.incoming ) then
		local zone = { index = tonumber(a), here = (b == "1"), map = tonumber(c), zone = tonumber(d), area = tonumber(e),
			x = tonumber(f), y = tonumber(g), name = name or "?" };
		if ( zone.index ) then table.insert(L.incoming, zone); end
		return nil;
	elseif ( kind == "END" and L.incoming ) then
		-- the zone the character is in first ("Stay in ..."), whatever order the list came in; the rest as sent
		local here, rest = {}, {};
		for _, z in ipairs(L.incoming) do table.insert(z.here and here or rest, z); end
		for _, z in ipairs(rest) do table.insert(here, z); end
		L.incoming = here;
		L.zones = L.incoming;
		L.incoming = nil;
		return "show";
	elseif ( kind == "DONE" ) then
		return "hide";
	end
	return nil;
end

function L.CardTitle(zone)
	if ( zone.here ) then return "Stay in "..zone.name; end
	return zone.name;
end

function L.Pages(count)
	if ( count <= 0 ) then return 1; end
	return math.ceil(count / L.PER_PAGE);
end

-- 4 or fewer: 2 x 2 like the screenshot; more: 3 across
function L.Columns(count)
	if ( count <= 4 ) then return 2; end
	return 3;
end

-- the picture of a zone: { file = <world map folder>, x0, y0, w, h = crop in map pixels } or { loading = path }
function L.Art(zone)
	local m = zone and zone.zone and L.MAPS[zone.zone];
	if ( m and zone.x and zone.y ) then
		local file, left, right, top, bottom = m[1], m[2], m[3], m[4], m[5];
		local nx = (left - zone.y) / (left - right);
		local ny = (top - zone.x) / (top - bottom);
		local w = L.ZOOM;
		local h = w * L.ART_H / L.ART_W;
		local x0 = nx * L.MAP_W - w / 2;
		local y0 = ny * L.MAP_H - h / 2;
		x0 = math.max(0, math.min(L.MAP_W - w, x0));
		y0 = math.max(0, math.min(L.MAP_H - h, y0));
		return { file = file, x0 = x0, y0 = y0, w = w, h = h };
	end
	return { loading = L.LOADING[zone and zone.map or -1] or L.LOADING[0] };
end

-- the tiles a crop needs: { tile = 1..12, left, top, right, bottom (0..1 of the picture), u0, u1, v0, v1 }
function L.Tiles(art)
	local out = {};
	for row = 0, 2 do
		for col = 0, 3 do
			local tx0, ty0 = col * 256, row * 256;
			local ix0, iy0 = math.max(art.x0, tx0), math.max(art.y0, ty0);
			local ix1, iy1 = math.min(art.x0 + art.w, tx0 + 256), math.min(art.y0 + art.h, ty0 + 256);
			if ( ix1 > ix0 and iy1 > iy0 ) then
				table.insert(out, { tile = row * 4 + col + 1,
					left = (ix0 - art.x0) / art.w, right = (ix1 - art.x0) / art.w,
					top = (iy0 - art.y0) / art.h, bottom = (iy1 - art.y0) / art.h,
					u0 = (ix0 - tx0) / 256, u1 = (ix1 - tx0) / 256, v0 = (iy0 - ty0) / 256, v1 = (iy1 - ty0) / 256 });
			end
		end
	end
	return out;
end

-- WorldMapArea.dbc (the client's, with the Temucraft patch): zone id = { map folder, left, right, top, bottom }
L.MAPS = {
	[1] = { "DunMorogh", 1802.1, -3122.9, -3877.1, -7160.4 },
	[3] = { "Badlands", -2079.2, -4566.7, -5889.6, -7547.9 },
	[4] = { "BlastedLands", -1119.8, -4856.2, -10583.3, -13025.0 },
	[8] = { "SwampOfSorrows", -2222.9, -4516.7, -9620.8, -11150.0 },
	[10] = { "Duskwood", 833.3, -1866.7, -9716.7, -11516.7 },
	[11] = { "Wetlands", -389.6, -4525.0, -2147.9, -4904.2 },
	[12] = { "Elwynn", 1535.4, -1935.4, -7939.6, -10254.2 },
	[14] = { "Durotar", -1962.5, -7250.0, 1808.3, -1716.7 },
	[15] = { "Dustwallow", -975.0, -6225.0, -2033.3, -5533.3 },
	[16] = { "Aszhara", -3277.1, -8347.9, 5341.7, 1960.4 },
	[17] = { "Barrens", 2622.9, -7510.4, 1612.5, -5143.8 },
	[28] = { "WesternPlaguelands", 416.7, -3883.3, 3366.7, 500.0 },
	[33] = { "Stranglethorn", 2220.8, -4160.4, -11168.8, -15422.9 },
	[36] = { "Alterac", 783.3, -2016.7, 1500.0, -366.7 },
	[38] = { "LochModan", -1993.7, -4752.1, -4487.5, -6327.1 },
	[40] = { "Westfall", 3016.7, -483.3, -9400.0, -11733.3 },
	[41] = { "DeadwindPass", -833.3, -3333.3, -9866.7, -11533.3 },
	[44] = { "Redridge", -1570.8, -3741.7, -8575.0, -10022.9 },
	[45] = { "Arathi", -866.7, -4466.7, -133.3, -2533.3 },
	[46] = { "BurningSteppes", -266.7, -3195.8, -7031.2, -8983.3 },
	[47] = { "Hinterlands", -1575.0, -5425.0, 1466.7, -1100.0 },
	[51] = { "SearingGorge", -322.9, -2554.2, -6100.0, -7587.5 },
	[65] = { "Dragonblight", 3627.1, -1981.2, 5575.0, 1835.4 },
	[66] = { "ZulDrak", -600.0, -5593.8, 7668.7, 4339.6 },
	[67] = { "TheStormPeaks", 1841.7, -5270.8, 10197.9, 5456.2 },
	[85] = { "Tirisfal", 3033.3, -1485.4, 3837.5, 825.0 },
	[130] = { "Silverpine", 3450.0, -750.0, 1666.7, -1133.3 },
	[139] = { "EasternPlaguelands", -2287.5, -6318.8, 3704.2, 1016.7 },
	[141] = { "Teldrassil", 3814.6, -1277.1, 11831.2, 8437.5 },
	[148] = { "Darkshore", 2941.7, -3608.3, 8333.3, 3966.7 },
	[206] = { "UtgardeKeep", 0.0, 0.0, 0.0, 0.0 },
	[209] = { "ShadowfangKeep", 4500.0, 300.0, 1133.3, -1666.7 },
	[210] = { "IcecrownGlacier", 5443.8, -827.1, 9427.1, 5245.8 },
	[215] = { "Mulgore", 2047.9, -3089.6, -272.9, -3697.9 },
	[267] = { "Hilsbrad", 1066.7, -2133.3, 400.0, -1733.3 },
	[331] = { "Ashenvale", 1700.0, -4066.7, 4672.9, 829.2 },
	[357] = { "Feralas", 5441.7, -1508.3, -2366.7, -7000.0 },
	[361] = { "Felwood", 1641.7, -4108.3, 7133.3, 3300.0 },
	[394] = { "GrizzlyHills", -1110.4, -6360.4, 5516.7, 2016.7 },
	[400] = { "ThousandNeedles", -433.3, -4833.3, -3966.7, -6900.0 },
	[405] = { "Desolace", 4233.3, -262.5, 452.1, -2545.8 },
	[406] = { "StonetalonMountains", 3245.8, -1637.5, 2916.7, -339.6 },
	[440] = { "Tanaris", -218.7, -7118.7, -5875.0, -10475.0 },
	[490] = { "UngoroCrater", 533.3, -3166.7, -5966.7, -8433.3 },
	[491] = { "RazorfenKraul", 2766.7, 966.7, 2733.3, 1533.3 },
	[493] = { "Moonglade", -1381.2, -3689.6, 8491.7, 6952.1 },
	[495] = { "HowlingFjord", -1397.9, -7443.7, 3116.7, -914.6 },
	[616] = { "Hyjal", -929.2, -5175.0, 6195.8, 3364.6 },
	[618] = { "Winterspring", -316.7, -7416.7, 8533.3, 3800.0 },
	[717] = { "TheStockade", 0.0, 0.0, 0.0, 0.0 },
	[718] = { "WailingCaverns", 0.0, 0.0, 0.0, 0.0 },
	[719] = { "BlackfathomDeeps", 0.0, 0.0, 0.0, 0.0 },
	[721] = { "Gnomeregan", 0.0, 0.0, 0.0, 0.0 },
	[722] = { "RazorfenDowns", 2766.7, -633.3, 3266.7, 1000.0 },
	[796] = { "ScarletMonastery", 1508.3, -800.0, 1918.8, 379.2 },
	[1176] = { "ZulFarrak", 1625.0, 241.7, 2052.1, 1129.2 },
	[1196] = { "UtgardePinnacle", 3275.0, -3275.0, 2166.7, -2200.0 },
	[1337] = { "Uldaman", 0.0, 0.0, 0.0, 0.0 },
	[1377] = { "Silithus", 2537.5, -945.8, -5958.3, -8281.2 },
	[1477] = { "TheTempleOfAtalHakkar", 0.0, 0.0, 0.0, 0.0 },
	[1497] = { "Undercity", 873.2, -86.2, 1877.9, 1237.8 },
	[1519] = { "Stormwind", 1722.9, -14.6, -7995.8, -9154.2 },
	[1537] = { "Ironforge", -713.6, -1504.2, -4569.2, -5096.8 },
	[1581] = { "TheDeadmines", 1966.7, -3033.3, 1133.3, -2200.0 },
	[1583] = { "BlackrockSpire", 0.0, 0.0, 0.0, 0.0 },
	[1584] = { "BlackrockDepths", 0.0, 0.0, 0.0, 0.0 },
	[1637] = { "Ogrimmar", -3680.6, -5083.2, 2273.9, 1338.5 },
	[1638] = { "ThunderBluff", 516.7, -527.1, -850.0, -1545.8 },
	[1657] = { "Darnassis", 2938.4, 1880.0, 10238.3, 9532.6 },
	[1977] = { "ZulGurub", -693.8, -2570.8, -11308.3, -12560.4 },
	[2017] = { "Stratholme", -1766.7, -5166.7, 4333.3, 2066.7 },
	[2057] = { "Scholomance", 633.3, -1166.7, 600.0, -600.0 },
	[2100] = { "Maraudon", 0.0, 0.0, 0.0, 0.0 },
	[2159] = { "OnyxiasLair", 0.0, 0.0, 0.0, 0.0 },
	[2366] = { "CoTTheBlackMorass", 7650.0, 6562.5, -1500.0, -2225.0 },
	[2367] = { "CoTHillsbradFoothills", 1854.2, -477.1, 3127.1, 1572.9 },
	[2437] = { "Ragefire", 0.0, 0.0, 0.0, 0.0 },
	[2557] = { "DireMaul", 0.0, 0.0, 0.0, 0.0 },
	[2597] = { "AlteracValley", 1781.2, -2456.2, 1085.4, -1739.6 },
	[2677] = { "BlackwingLair", 633.3, -2766.7, -6333.3, -8600.0 },
	[2717] = { "MoltenCore", 0.0, 0.0, 0.0, 0.0 },
	[2817] = { "CrystalsongForest", 1443.8, -1279.2, 6502.1, 4687.5 },
	[3277] = { "WarsongGulch", 2041.7, 895.8, 1627.1, 862.5 },
	[3358] = { "ArathiBasin", 1858.3, 102.1, 1508.3, 337.5 },
	[3428] = { "AhnQiraj", 3033.3, 1233.3, -7933.3, -9133.3 },
	[3429] = { "RuinsofAhnQiraj", 3035.4, 522.9, -8233.3, -9908.3 },
	[3430] = { "EversongWoods", -2354.2, -7279.2, 8908.3, 5625.0 },
	[3433] = { "Ghostlands", -3150.0, -6450.0, 6133.3, 3933.3 },
	[3456] = { "Naxxramas", -2520.8, -4377.1, 3597.9, 2360.4 },
	[3457] = { "Karazhan", -1191.7, -2950.0, -10389.6, -11562.5 },
	[3483] = { "Hellfire", 5539.6, 375.0, 1481.2, -1962.5 },
	[3487] = { "SilvermoonCity", -4267.4, -5478.9, 8020.4, 7213.6 },
	[3518] = { "Nagrand", 10295.8, 4770.8, 41.7, -3641.7 },
	[3519] = { "TerokkarForest", 7083.3, 1683.3, -1000.0, -4600.0 },
	[3520] = { "ShadowmoonValley", 4225.0, -1275.0, -1947.9, -5614.6 },
	[3521] = { "Zangarmarsh", 9475.0, 4447.9, 1935.4, -1416.7 },
	[3522] = { "BladesEdgeMountains", 8845.8, 3420.8, 4408.3, 791.7 },
	[3523] = { "Netherstorm", 5483.3, -91.7, 5456.2, 1739.6 },
	[3524] = { "AzuremystIsle", 7633.3, 3562.5, 6806.2, 4091.7 },
	[3525] = { "BloodmystIsle", 8058.3, 4795.8, 8841.7, 6666.7 },
	[3537] = { "BoreanTundra", 8570.8, 2806.2, 4897.9, 1054.2 },
	[3557] = { "TheExodar", 7067.0, 6010.2, 5990.3, 5285.6 },
	[3562] = { "HellfireRamparts", 1935.4, 1277.1, -1041.7, -1479.2 },
	[3606] = { "CoTMountHyjal", -1525.0, -4025.0, 6145.8, 4479.2 },
	[3607] = { "CoilfangReservoir", 0.0, 0.0, 0.0, 0.0 },
	[3703] = { "ShattrathCity", 6135.3, 4829.0, -1474.0, -2344.8 },
	[3711] = { "SholazarBasin", 6929.2, 2572.9, 7287.5, 4383.3 },
	[3713] = { "TheBloodFurnace", 0.0, 0.0, 0.0, 0.0 },
	[3714] = { "TheShatteredHalls", 0.0, 0.0, 0.0, 0.0 },
	[3715] = { "TheSteamvault", 0.0, 0.0, 0.0, 0.0 },
	[3716] = { "TheUnderbog", 0.0, 0.0, 0.0, 0.0 },
	[3717] = { "TheSlavePens", 0.0, 0.0, 0.0, 0.0 },
	[3789] = { "ShadowLabyrinth", 0.0, 0.0, 0.0, 0.0 },
	[3790] = { "AuchenaiCrypts", 0.0, 0.0, 0.0, 0.0 },
	[3791] = { "SethekkHalls", 0.0, 0.0, 0.0, 0.0 },
	[3792] = { "ManaTombs", 0.0, 0.0, 0.0, 0.0 },
	[3805] = { "ZulAman", 1852.1, 583.3, 568.8, -277.1 },
	[3820] = { "NetherstormArena", 2660.4, 389.6, 2918.8, 1404.2 },
	[3836] = { "MagtheridonsLair", 0.0, 0.0, 0.0, 0.0 },
	[3845] = { "TempestKeep", 0.0, 0.0, 0.0, 0.0 },
	[3847] = { "TheBotanica", 0.0, 0.0, 0.0, 0.0 },
	[3848] = { "TheArcatraz", 0.0, 0.0, 0.0, 0.0 },
	[3849] = { "TheMechanar", 0.0, 0.0, 0.0, 0.0 },
	[3923] = { "GruulsLair", 0.0, 0.0, 0.0, 0.0 },
	[3959] = { "BlackTemple", 1150.0, 366.7, 950.0, 427.1 },
	[4075] = { "SunwellPlateau", 1206.2, 300.0, 2012.5, 1408.3 },
	[4080] = { "Sunwell", -3168.7, -6495.8, 11435.4, 9216.7 },
	[4100] = { "CoTStratholme", 2152.1, 327.1, 2297.9, 1081.2 },
	[4131] = { "MagistersTerrace", 250.0, -297.9, 325.0, -39.6 },
	[4196] = { "DrakTharonKeep", -377.1, -1004.2, -168.8, -587.5 },
	[4197] = { "LakeWintergrasp", 4329.2, 1354.2, 5716.7, 3733.3 },
	[4228] = { "Nexus80", 2337.5, -262.5, 1956.2, 222.9 },
	[4264] = { "Ulduar77", 2766.7, -633.3, 2200.0, -66.7 },
	[4265] = { "TheNexus", 0.0, 0.0, 0.0, 0.0 },
	[4272] = { "HallsofLightning", 2500.0, -900.0, 2200.0, -66.7 },
	[4273] = { "Ulduar", 1583.3, -1704.2, 1168.8, -1022.9 },
	[4277] = { "AzjolNerub", 1020.8, -52.1, 872.9, 158.3 },
	[4298] = { "ScarletEnclave", -4047.9, -7210.4, 3087.5, 979.2 },
	[4384] = { "StrandoftheAncients", 787.5, -956.2, 1883.3, 720.8 },
	[4395] = { "Dalaran", 0.0, 0.0, 0.0, 0.0 },
	[4415] = { "VioletHold", 983.3, 600.0, 2006.2, 1750.0 },
	[4416] = { "Gundrak", 1310.4, 166.7, 2122.9, 1360.4 },
	[4493] = { "TheObsidianSanctum", 1133.3, -29.2, 3616.7, 2841.7 },
	[4494] = { "Ahnkahet", -233.3, -1206.2, 850.0, 202.1 },
	[4500] = { "TheEyeofEternity", 2766.7, -633.3, 2200.0, -66.7 },
	[4603] = { "VaultofArchavon", 1033.3, -1566.7, 600.0, -1133.3 },
	[4710] = { "IsleofConquest", 525.0, -2125.0, 1708.3, -58.3 },
	[4714] = { "Gilneas", 3439.6, 293.8, -533.3, -2631.2 },
	[4720] = { "TheLostIsles", -8416.7, -12931.2, 2347.9, -662.5 },
	[4722] = { "TheArgentColiseum", 2100.0, -500.0, 2200.0, 466.7 },
	[4723] = { "TheArgentColiseum", 2100.0, -500.0, 2200.0, 466.7 },
	[4737] = { "Kezan", -10670.8, -12022.9, -8264.6, -9164.6 },
	[4742] = { "HrothgarsLanding", 2797.9, -879.2, 10781.2, 8329.2 },
	[4755] = { "GilneasCity", 1933.3, 1043.8, -1306.2, -1900.0 },
	[4809] = { "TheForgeofSouls", 7033.3, -4366.7, 6466.7, -1133.3 },
	[4812] = { "IcecrownCitadel", 6366.7, -5833.3, 5933.3, -2200.0 },
	[4813] = { "PitofSaron", 839.6, -693.8, 1256.2, 233.3 },
	[4815] = { "VashjirKelpForest", 5070.8, 2268.8, -4018.7, -5887.5 },
	[4820] = { "HallsofReflection", 7033.3, -5966.7, 6466.7, -2200.0 },
	[4922] = { "TwilightHighlands", -2437.5, -7708.3, -2156.2, -5670.8 },
	[4987] = { "TheRubySanctum", 902.1, 150.0, 3429.2, 2927.1 },
	[5034] = { "Uldum", 2441.7, -3752.1, -8029.2, -12158.3 },
	[5095] = { "TolBarad", 7877.1, 5862.5, -1093.7, -2437.5 },
	[5144] = { "VashjirRuins", 6681.2, 1831.2, -4756.2, -7989.6 },
	[5145] = { "VashjirDepths", 8233.3, 4158.3, -4906.2, -7622.9 },
	[5146] = { "Vashjir", 8754.2, 1808.3, -3720.8, -8352.1 },
	[5389] = { "TolBaradDailyArea", 8279.2, 6441.7, -156.2, -1381.2 },
	[5630] = { "TheMaelstromContinent", 0.0, 0.0, 0.0, 0.0 },
	[6066] = { "Scholomance", 1597.9, -1708.3, 1612.5, -591.7 },
	[6170] = { "Northshire", 187.5, -781.2, -8570.8, -9216.7 },
	[6176] = { "ColdridgeValley", 979.2, 14.6, -5962.5, -6606.2 },
	[6450] = { "ShadowglenStart", 1491.7, 41.7, 11033.3, 10066.7 },
	[6451] = { "ValleyofTrialsStart", -3641.7, -4991.7, 0.0, -900.0 },
	[6454] = { "DeathknellStart", 2147.9, 1058.3, 2270.8, 1543.8 },
	[6455] = { "SunstriderIsleStart", -3250.0, -4850.0, 8700.0, 7633.3 },
	[6456] = { "AmmenValeStart", 5318.8, 3500.0, 5995.8, 4783.3 },
	[7307] = { "UpperBlackrockSpire", 0.0, 0.0, 0.0, 0.0 },
	[9548] = { "IslandHavenswood", 6240.0, 4266.7, 2309.3, 960.0 },
	[10222] = { "IslandCrestfall", 11040.0, 9813.3, -5066.7, -5866.7 },
};

if ( not CreateFrame ) then return; end   -- tests load only the logic

local CARD_GAP, NAME_H = 18, 30;
local frame, cards, page = nil, {}, 1;
local picked = false;

local function Send(text)
	SendAddonMessage(L.PREFIX, text, "WHISPER", UnitName("player"));
end

local function SetArt(card, zone)
	local art = L.Art(zone);
	for _, t in ipairs(card.tiles) do t:Hide(); end
	card.loading:Hide();
	local shown = false;
	if ( art.file ) then
		for i, piece in ipairs(L.Tiles(art)) do
			local t = card.tiles[i];
			if ( t:SetTexture("Interface\\WorldMap\\"..art.file.."\\"..art.file..piece.tile) ) then
				t:ClearAllPoints();
				t:SetPoint("TOPLEFT", card.art, "TOPLEFT", piece.left * L.ART_W, -piece.top * L.ART_H);
				t:SetPoint("BOTTOMRIGHT", card.art, "TOPLEFT", piece.right * L.ART_W, -piece.bottom * L.ART_H);
				t:SetTexCoord(piece.u0, piece.u1, piece.v0, piece.v1);
				t:Show();
				shown = true;
			end
		end
	end
	if ( not shown ) then
		card.loading:SetTexture(art.loading or L.LOADING[zone.map or -1] or L.LOADING[0]);
		card.loading:SetTexCoord(0.1, 0.9, 0.25, 0.75);
		card.loading:Show();
	end
end

local function MakeCard(i)
	local card = CreateFrame("Button", "TemucraftStartingZoneCard"..i, frame);
	card:SetWidth(L.ART_W + 8); card:SetHeight(L.ART_H + NAME_H + 8);
	card:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	card:SetBackdropColor(0, 0, 0, 0.9);
	card:SetBackdropBorderColor(0.6, 0.5, 0.3, 1);
	card.art = CreateFrame("Frame", nil, card);
	card.art:SetWidth(L.ART_W); card.art:SetHeight(L.ART_H);
	card.art:SetPoint("TOP", 0, -4);
	card.tiles = {};
	for t = 1, 6 do card.tiles[t] = card.art:CreateTexture(nil, "ARTWORK"); end
	card.loading = card.art:CreateTexture(nil, "ARTWORK");
	card.loading:SetAllPoints(card.art);
	-- a dark fade at the bottom of the picture, under the name
	local fade = card.art:CreateTexture(nil, "OVERLAY");
	fade:SetTexture(0, 0, 0, 1);
	fade:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.85, 0, 0, 0, 0);
	fade:SetPoint("BOTTOMLEFT"); fade:SetPoint("BOTTOMRIGHT"); fade:SetHeight(36);
	card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	card.name:SetPoint("TOP", card.art, "BOTTOM", 0, -6);
	card.name:SetWidth(L.ART_W);
	-- gold glow on hover
	local glow = card:CreateTexture(nil, "HIGHLIGHT");
	glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");
	glow:SetBlendMode("ADD");
	glow:SetVertexColor(1, 0.82, 0.3, 0.9);
	glow:SetPoint("TOPLEFT", -26, 26); glow:SetPoint("BOTTOMRIGHT", 26, -26);
	card:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(1, 0.82, 0, 1);
		GameTooltip:SetOwner(self, "ANCHOR_TOP");
		GameTooltip:SetText(L.CardTitle(self.zone), 1, 0.82, 0);
		GameTooltip:AddLine(self.zone.here and "Begin where you are." or "Travel there and begin your journey. Your hearthstone is set there.", 1, 1, 1, 1);
		GameTooltip:Show();
	end);
	card:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.6, 0.5, 0.3, 1); GameTooltip:Hide(); end);
	card:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn");
		picked = true;
		Send("PICK~"..self.zone.index);
		frame:Hide();
	end);
	return card;
end

local function Layout()
	local zones = L.zones or {};
	local count = #zones;
	local cols = L.Columns(count);
	local perPage = (count <= 4) and 4 or L.PER_PAGE;
	local pages = math.max(1, math.ceil(count / perPage));
	if ( page > pages ) then page = pages; end
	local first = (page - 1) * perPage + 1;
	local onPage = math.min(perPage, count - first + 1);
	local rows = math.max(1, math.ceil(math.min(perPage, count) / cols));
	local cw, ch = L.ART_W + 8, L.ART_H + NAME_H + 8;
	frame:SetWidth(cols * cw + (cols - 1) * CARD_GAP + 60);
	frame:SetHeight(rows * ch + (rows - 1) * CARD_GAP + 110 + (pages > 1 and 30 or 0));
	for i = 1, math.max(#cards, onPage) do
		local card = cards[i] or MakeCard(i);
		cards[i] = card;
		local zone = zones[first + i - 1];
		if ( i <= onPage and zone ) then
			card.zone = zone;
			card.name:SetText(L.CardTitle(zone));
			if ( zone.here ) then card.name:SetTextColor(0.4, 1, 0.4); else card.name:SetTextColor(1, 0.82, 0); end
			SetArt(card, zone);
			local col, row = (i - 1) % cols, math.floor((i - 1) / cols);
			card:ClearAllPoints();
			card:SetPoint("TOPLEFT", frame, "TOPLEFT", 30 + col * (cw + CARD_GAP), -70 - row * (ch + CARD_GAP));
			card:Show();
		else
			card:Hide();
		end
	end
	frame.prev:SetShown(pages > 1);
	frame.next:SetShown(pages > 1);
	frame.pageText:SetShown(pages > 1);
	frame.pageText:SetText(format("Page %d / %d", page, pages));
	if ( page <= 1 ) then frame.prev:Disable(); else frame.prev:Enable(); end
	if ( page >= pages ) then frame.next:Disable(); else frame.next:Enable(); end
end

-- 3.3.5 has no SetShown
local function AddSetShown(region)
	region.SetShown = function(self, show) if ( show ) then self:Show(); else self:Hide(); end end;
end

local function Create()
	frame = CreateFrame("Frame", "TemucraftStartingZoneFrame", UIParent);
	frame:SetFrameStrata("DIALOG");
	frame:SetToplevel(true);
	frame:SetPoint("CENTER", 0, 40);
	frame:EnableMouse(true);
	frame:SetMovable(true);
	frame:RegisterForDrag("LeftButton");
	frame:SetScript("OnDragStart", frame.StartMoving);
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing);
	frame:SetClampedToScreen(true);
	local title = TemucraftStyle_Window and TemucraftStyle_Window(frame, "Starting Zone");
	frame.heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
	frame.heading:SetPoint("TOP", 0, -34);
	frame.heading:SetText("Embark on your Journey");
	frame.heading:SetTextColor(1, 0.82, 0);
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
	close:SetPoint("TOPRIGHT", -6, -6);
	frame.prev = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.prev:SetWidth(90); frame.prev:SetHeight(22);
	frame.prev:SetText(PREV or "Prev");
	frame.prev:SetPoint("BOTTOMLEFT", 30, 20);
	frame.prev:SetScript("OnClick", function() page = page - 1; Layout(); end);
	frame.next = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.next:SetWidth(90); frame.next:SetHeight(22);
	frame.next:SetText(NEXT or "Next");
	frame.next:SetPoint("BOTTOMRIGHT", -30, 20);
	frame.next:SetScript("OnClick", function() page = page + 1; Layout(); end);
	frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	frame.pageText:SetPoint("BOTTOM", 0, 26);
	AddSetShown(frame.prev); AddSetShown(frame.next); AddSetShown(frame.pageText);
	frame:SetScript("OnHide", function()
		if ( not picked ) then Send("CLOSE"); end
	end);
	table.insert(UISpecialFrames, "TemucraftStartingZoneFrame");   -- Esc closes it
	frame:Hide();
end

local events = CreateFrame("Frame", "TemucraftStartingZoneEvents");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
events:RegisterEvent("CHAT_MSG_ADDON");
events:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		Send("HELLO");
		return;
	end
	if ( prefix ~= L.PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") ) then return; end
	local action = L.OnMessage(message);
	if ( action == "show" ) then
		if ( not frame ) then Create(); end
		picked = false;
		page = 1;
		Layout();
		frame:Show();
		PlaySound("igQuestListOpen");
	elseif ( action == "hide" and frame and frame:IsShown() ) then
		picked = true;
		frame:Hide();
	end
end);
