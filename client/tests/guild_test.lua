-- Stub tests for the guild window and guild bank logic (no client): lua5.1 client/tests/guild_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
local ui = dir.."/Interface/FrameXML/Temucraft/";
dofile(ui.."TemucraftGuild.lua");
dofile(ui.."TemucraftGuildBank.lua");
local L, B = TemucraftGuildLogic, TemucraftGuildBankLogic;
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end
local now = os.time();

-- formatting
check("ago now", L.Ago(5) == "just now");
check("ago minutes", L.Ago(60) == "1 minute ago" and L.Ago(150) == "2 minutes ago");
check("ago hours", L.Ago(3 * 3600) == "3 hours ago");
check("ago days", L.Ago(2 * 86400) == "2 days ago");
check("ago months", L.Ago(300 * 86400) == "10 months ago");
check("ago years", L.Ago(800 * 86400) == "2 years ago");
check("stock seconds", L.StockSeconds(0, 0, 1, 2) == 26 * 3600 and L.StockSeconds() == 0);
check("last online", L.LastOnline(0, 3, 2, 1) == "3 months" and L.LastOnline(0, 0, 0, 0) == "< an hour" and L.LastOnline(1) == "1 year");
check("money", L.Money(123456) == "12 Gold 34 Silver 56 Copper");
check("money no zero parts", L.Money(120000) == "12 Gold" and L.Money(5) == "5 Copper" and L.Money(0) == "0 Copper" and L.Money(10050) == "1 Gold 50 Copper");
check("class colour by file", L.ClassHex("MAGE") == "ff69ccf0");
check("class colour by id", L.ClassHex(1) == L.ClassHex("WARRIOR") and L.ClassHex("4") == L.ClassHex("ROGUE"));
check("unknown class yellow", L.ClassHex(nil) == "ffffd100" and L.ClassHex(99) == "ffffd100");
check("coloured name", L.ColoredName("Bob", "PRIEST") == "|cffffffffBob|r" and string.find(L.ColoredName(nil), "Unknown"));
check("item link", L.ItemLink(19019, "Thunderfury", 5) == "|cffff8000|Hitem:19019:0:0:0:0:0:0:0|h[Thunderfury]|h|r");

-- record parsing
local f = L.Fields("H~12~g~30~8~Jaina~hello ~ world", 7);
check("fields keep the rest", f[1] == "H" and f[2] == "12" and f[6] == "Jaina" and f[7] == "hello ~ world");
check("few fields", #L.Fields("HE~P", 4) == 2);
check("pieces", L.Feed("+abc") == nil and L.Feed("+def") == nil and L.Feed("=ghi") == "abcdefghi");
check("whole record", L.Feed("HE~P~0~0") == "HE~P~0~0");
check("piece reset by a whole record", L.Feed("+zzz") == nil and L.Feed("S~1~1~1~1~50") == "S~1~1~1~1~50" and L.Feed("=x") == "x");

-- hello and chat history
check("server hello", L.OnMessage("S~1~1~0~1~50") == "S" and L.server.chat and L.server.bank and not L.server.news and L.server.perks and L.server.page == 50);
L.OnMessage("H~10~g~120~8~Jaina~first");
L.OnMessage("+H~11~o~60~1~Varian~a long line ");
L.OnMessage("=with |cffffffff|Hitem:6948:0:0:0:0:0:0:0|h[Hearthstone]|h|r ~ and more");
local logins;
L.On("login", function(lines) logins = lines; end);
check("login end", L.OnMessage("HE~L~2~1") == "HE");
check("login lines", logins and #logins == 2 and logins[1].name == "Jaina" and logins[2].ch == "o"
	and logins[2].text == "a long line with |cffffffff|Hitem:6948:0:0:0:0:0:0:0|h[Hearthstone]|h|r ~ and more");
check("login fills the chat", #L.chat == 2 and L.chatMore and L.OldestId() == 10);
check("line time from age", math.abs(L.chat[1].time - (now - 120)) <= 2);
L.AddLive("g", "Thrall", "SHAMAN", "live one");
L.AddLive("g", "Jaina", "MAGE", "first");   -- the same as a stored line but said again later
check("live lines added", #L.chat == 4 and #L.live == 2);
-- a fresh page that already holds "live one" (stored just before the page was read)
L.OnMessage("H~10~g~120~8~Jaina~first");
L.OnMessage("H~11~o~60~1~Varian~x");
L.OnMessage("H~12~g~1~7~Thrall~live one");
L.OnMessage("HE~P~3~1");
check("fresh page merges live lines", #L.chat == 4 and L.chat[3].text == "live one" and L.chat[4].text == "first" and #L.live == 0);
L.wantOlder = true;
L.OnMessage("H~8~g~500~2~Uther~older 1");
L.OnMessage("H~9~g~400~2~Uther~older 2");
L.OnMessage("HE~P~2~0");
check("older page prepended", #L.chat == 6 and L.chat[1].text == "older 1" and L.chat[2].text == "older 2" and not L.chatMore and L.OldestId() == 8);
local merged = L.MergeLive({ { ch = "g", name = "A", text = "x" } }, { { ch = "o", name = "A", text = "x" } });
check("merge keeps a line of the other channel", #merged == 2);

-- bank log
local tab;
L.On("banklog", function(t) tab = t; end);
L.OnMessage("L~5~3600~2~1~4~Garona~19019~1~1~5~Thunderfury, Blessed Blade of the Windseeker");
L.OnMessage("L~4~7200~1~1~0~~2589~20~1~1~Linen Cloth");
L.OnMessage("LE~1~0~2~1");
check("bank log page", tab == 1 and #L.bankLog[1].entries == 2 and L.bankLog[1].more and L.bankLog[1].entries[1].name == "Garona");
L.OnMessage("L~3~9000~3~1~2~Uther~2589~5~3~1~Linen Cloth");
L.OnMessage("LE~1~2~1~0");
check("bank log next page appended", #L.bankLog[1].entries == 3 and not L.bankLog[1].more);
L.OnMessage("L~2~86400~4~7~8~Jaina~123456~0~1~0~");
L.OnMessage("LE~7~0~1~0");
local function TabName(t) return "Tab "..t; end
local w = L.BankLine(L.FromArchive(L.bankLog[1].entries[1], TabName));
check("withdraw red, class colour, item, age", string.find(w, "|cfffff569Garona|r", 1, true) and string.find(w, "|cffff2020withdrew|r", 1, true)
	and string.find(w, "[Thunderfury, Blessed Blade of the Windseeker]", 1, true) and string.find(w, "(1 hour ago)", 1, true));
local d = L.BankLine(L.FromArchive(L.bankLog[1].entries[2], TabName));
check("deposit green, count, unknown name", string.find(d, "|cff20ff20deposited|r", 1, true) and string.find(d, " x20", 1, true) and string.find(d, "Unknown", 1, true));
local m = L.BankLine(L.FromArchive(L.bankLog[1].entries[3], TabName));
check("move names the tabs", string.find(m, "moved", 1, true) and string.find(m, "from Tab 1 to Tab 3", 1, true));
local money = L.BankLine(L.FromArchive(L.bankLog[7].entries[1], TabName));
check("money log", string.find(money, "deposited", 1, true) and string.find(money, "12 Gold 34 Silver 56 Copper", 1, true) and string.find(money, "(1 day ago)", 1, true));
check("stock money types", L.BankLine({ what = "repair", name = "A", money = 100, seconds = 0 }):find("for repairs", 1, true) ~= nil);

-- news, guild log, perks
L.OnMessage("N~60~a~2~Uther~6~0~");
L.OnMessage("N~120~i~8~Jaina~19019~5~Thunderfury");
L.OnMessage("N~180~p~1~Varian~1~0~Thrall");
L.OnMessage("NE~0~3~0");
check("news", #L.news == 3 and L.news[2].value == 19019 and not L.newsMore);
check("news achievement without the client", string.find(L.NewsLine(L.news[1]), "earned the achievement #6", 1, true));
check("news item", string.find(L.NewsLine(L.news[2]), "looted |cffff8000|Hitem:19019", 1, true));
check("news promotion", string.find(L.NewsLine(L.news[3], function(r) return r == 1 and "Officer" or "?"; end), "promoted to Officer by Thrall", 1, true));
L.OnMessage("E~60~3~2~Uther~8~Jaina~1");
L.OnMessage("E~70~6~1~Varian~0~~0");
L.OnMessage("EE~0~2~1");
check("guild log", #L.events == 2 and L.eventsMore);
check("guild log lines", string.find(L.EventLine(L.events[1], function() return "Officer"; end), "promoted", 1, true)
	and string.find(L.EventLine(L.events[2]), "left the guild", 1, true));
check("stock guild log type names", string.find(L.EventLine({ type = "invite", name1 = "A", name2 = "B" }), "invited", 1, true));
L.OnMessage("K~1~1~78632~Fast Track");
L.OnMessage("K~2~l~0~Mr. Popularity");
L.OnMessage("KE~2");
check("perks", #L.perks == 2 and L.perks[1].spell == 78632 and L.perks[2].state == "l");

-- roster
local members = {
	{ name = "zed", level = 80, rankIndex = 2, online = false, last = 7200 },
	{ name = "Amy", level = 70, rankIndex = 0, online = true, last = 0 },
	{ name = "bob", level = 80, rankIndex = 1, online = false, last = 60 },
};
L.SortRoster(members, "name");
check("sort by name, any case", members[1].name == "Amy" and members[2].name == "bob" and members[3].name == "zed");
L.SortRoster(members, "online");
check("sort by last online, online first", members[1].name == "Amy" and members[2].name == "bob" and members[3].name == "zed");
L.SortRoster(members, "level", true);
check("sort by level descending, then name", members[1].name == "bob" and members[2].name == "zed" and members[3].name == "Amy");
L.SortRoster(members, "rank");
check("sort by rank", members[1].name == "Amy" and members[3].name == "zed");

-- guild bank
check("search empty matches", B.Matches(nil, "") and B.Matches("Linen Cloth", nil));
check("search any case", B.Matches("Linen Cloth", "linen") and B.Matches("Linen Cloth", "CLOTH") and not B.Matches("Linen Cloth", "wool"));
check("search plain text", B.Matches("Pattern: [x]", "[x") and not B.Matches(nil, "a"));
check("name from link", B.NameFromLink("|cffffffff|Hitem:2589:0:0:0:0:0:0:0|h[Linen Cloth]|h|r") == "Linen Cloth" and B.NameFromLink(nil) == nil);
check("withdrawals", B.WithdrawText("Officer", 5) == "Remaining Daily Withdrawals for Officer: |cffffffff5 Stacks|r");
check("withdrawals one, none, unlimited", string.find(B.WithdrawText("Member", 1), "1 Stack|r", 1, true) and string.find(B.WithdrawText("Member", 0), "None", 1, true)
	and string.find(B.WithdrawText("Guild Master", -1), "Unlimited", 1, true));

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
