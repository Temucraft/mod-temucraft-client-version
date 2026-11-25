-- Temucraft: safe calls for the character create functions that push many Lua values.
-- GetAvailableRaces, GetAvailableClasses and GetClassesForRace push 3 values per race or class without asking
-- Lua for room (no lua_checkstack); a C function only gets 20 free slots. With our 20-30 races (60-90 values) the
-- stock Wow.exe writes past the Lua stack and corrupts memory: the game then dies with "Not enough memory"
-- (lmemPool.cpp) a little later, as when picking Zandalari on 2026-11-25. Wow-races-30.exe fixes it in the exe;
-- for the stock exe these wrappers call the originals from a Lua function with a big register frame, so the
-- values land in stack space that is already allocated, and hand them back with unpack (which checks the stack).

local function Big(fn, ...)
	local results = { fn(...) };
	local r0, r1, r2, r3, r4, r5, r6, r7, r8, r9;
	local r10, r11, r12, r13, r14, r15, r16, r17, r18, r19;
	local r20, r21, r22, r23, r24, r25, r26, r27, r28, r29;
	local r30, r31, r32, r33, r34, r35, r36, r37, r38, r39;
	local r40, r41, r42, r43, r44, r45, r46, r47, r48, r49;
	local r50, r51, r52, r53, r54, r55, r56, r57, r58, r59;
	local r60, r61, r62, r63, r64, r65, r66, r67, r68, r69;
	local r70, r71, r72, r73, r74, r75, r76, r77, r78, r79;
	local r80, r81, r82, r83, r84, r85, r86, r87, r88, r89;
	local r90, r91, r92, r93, r94, r95, r96, r97, r98, r99;
	local r100, r101, r102, r103, r104, r105, r106, r107, r108, r109;
	local r110, r111, r112, r113, r114, r115, r116, r117, r118, r119;
	return results;
end

local function Wrap(name)
	local original = _G[name];
	if ( type(original) ~= "function" or _G["Temucraft_Original_"..name] ) then
		return;
	end
	_G["Temucraft_Original_"..name] = original;
	_G[name] = function(...)
		return unpack(Big(original, ...));
	end
end

Wrap("GetAvailableRaces");
Wrap("GetAvailableClasses");
Wrap("GetClassesForRace");
