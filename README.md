# mod-temucraft-client-version

Gives the Temucraft client a version of its own, shown on the login screen and checked by the server, and builds the
Temucraft interface into the client so module windows behave like Blizzard's own UI.

## The client patch (`client/`)

`python3 client/build_mpq.py [--out folder] [--stormlib path]` makes `out/patch-^.MPQ`, a **Data** patch (the same
for every language; it goes in `Data/`, not `Data/<locale>/`). Needs StormLib: `--stormlib` (or `STORMLIB`) points at
`libstorm.so` or `StormLib.dll`. It is a Data patch on purpose: the client ranks every `Data\patch-?.MPQ` above every
locale patch, and patch-5 has its own FrameXML.toc, so as a locale patch our FrameXML.toc lost and nothing of ours
ran. `^` ranks above every other Data patch with interface files. It holds:

- [`Interface\GlueXML\TemucraftVersion.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/GlueXML/TemucraftVersion.lua): the login screen shows "Temucraft 1.5.0 (3.3.5a build 12340)".
- [`Interface\FrameXML\Temucraft\TemucraftDragonUI.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftDragonUI.lua): which of our windows step aside for DragonUI (see *DragonUI* below).
- [`Interface\FrameXML\Temucraft\TemucraftCore.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftCore.lua): after login the client whispers its version to the server
  (addon message `TCV`, `HELLO~1.0.0`) and shows a popup when the server says it is out of date.
- [`Interface\FrameXML\Temucraft\TemucraftDisguise.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftDisguise.lua): the rogue Disguise button and menu ([mod-temucraft-rogue-disguise](https://github.com/Temucraft/mod-temucraft-rogue-disguise)).
- [`Interface\FrameXML\Temucraft\TemucraftAutoLearn.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftAutoLearn.lua): the spellbook's Train button and automatic-learning checkbox ([mod-temucraft-auto-learn](https://github.com/Temucraft/mod-temucraft-auto-learn)).
- [`Interface\FrameXML\Temucraft\TemucraftHeritage.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftHeritage.lua): the Heritage button beside the character window, with the second racial menu ([mod-temucraft-classes](https://github.com/Temucraft/mod-temucraft-classes)).
- [`Interface\FrameXML\Temucraft\TemucraftSpellTabs.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftSpellTabs.lua): Racials, Professions, Mounts, Companions and Guild tabs beside the spellbook, and a line in spellbook tooltips saying what a spell is ([mod-temucraft-client-version](https://github.com/Temucraft/mod-temucraft-client-version)).
- [`Interface\FrameXML\Temucraft\TemucraftMissions.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftMissions.lua): the mission table and companion window
  ([mod-temucraft-followers](https://github.com/Temucraft/mod-temucraft-followers)), loaded by FrameXML, so it can't be turned off or go
  missing like an addon. The AddOns copy shipped with mod-temucraft-followers steps aside when this one is loaded.
- [`Interface\FrameXML\Temucraft\TemucraftExpeditions.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftExpeditions.lua): the expedition window (current run, powers, relics, Wayfinder's Ledger; addon messages `TEX`)
  ([mod-temucraft-expeditions](https://github.com/Temucraft/mod-temucraft-expeditions)). The file is the same as the AddOns copy in mod-temucraft-expeditions, which steps aside when this one is loaded.
- [`Interface\FrameXML\Temucraft\TemucraftSpellInfo.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftSpellInfo.lua): extra lines on your spell tooltips (spell book and action bars): your bonuses (damage, cooldown, cost, cast time), the base and the real values (damage, healing, cost, cast, cooldown, range, duration; green better, red worse), one line per talent, glyph or other effect with its rank and what it does to the spell ("Improved Wrath (5/5): -0.5 sec cast time"), its crit chance and crit damage, and what Temucraft changed from stock 3.3.5, answered by [mod-temucraft-classes](https://github.com/Temucraft/mod-temucraft-classes) (addon messages `TSI`).
- [`Interface\FrameXML\Temucraft\TemucraftTaxi.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftTaxi.lua): retail-style flight map: the flight points on the way to the ones you know (sent by [mod-temucraft-travel](https://github.com/Temucraft/mod-temucraft-travel), addon messages `TTX`) are small grey route dots that can't be picked; hovering one says it is on the way.
- [`Interface\FrameXML\Temucraft\TemucraftIssues.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftIssues.lua): the retail-style Issue Reporter ([mod-temucraft-issues](https://github.com/Temucraft/mod-temucraft-issues), addon messages `TIR`):
  a bug button above the action bars (Shift-drag moves it; menu Zone Bug / General Bug / Feedback / Suggestion, also
  `/issue`), "Press F6 to submit an issue for this Spell" (Item, Quest, Creature) at the bottom of tooltips, quest log
  titles, quest tracker lines and world map quest POIs, and a dialog per spell, item, quest or creature. Reports go
  out with the stock `ReportBug` / `ReportSuggestion` as FeedbackUI-format JSON (the client adds its own system
  block), so they land in `bugreport` for the AzerothCore dashboard. Shown only while the server says reporting is on.
  The key is a click binding (`CLICK TemucraftIssueKeyButton:LeftButton`; this patch has no `Bindings.xml` of its
  own): F6 when free, `/issuekey <key>` or `/issuekey none` to change it. `TemucraftIssueBug.blp` is its icon.
- [`Interface\GlueXML\TemucraftCharCreate.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/GlueXML/TemucraftCharCreate.lua),
  [`TemucraftCharSelect.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/GlueXML/TemucraftCharSelect.lua),
  `TemucraftGlueData.lua` and `TemucraftGlueSafety.lua`: the retail-style login screens (see *Login screens* below).
- `Interface\TemucraftScenes.lua`: the character screens' settings ("old" scenes here; the launcher writes its own
  loose copy with the player's choice).
- `FrameXML.toc` and `GlueXML.toc`: the client's own lists (copies in `client/base/`) with those files added, in the
  order of `FRAME_FILES` / `GLUE_FILES` in `build_mpq.py` (later files use earlier ones: keep new files after what
  they call). They come from the highest-priority patches of the client (FrameXML.toc from patch-5.MPQ, GlueXML.toc
  from patch-enUS-C.MPQ); refresh `client/base/` if another patch changes them.

The version is `client/VERSION` (now 1.6.0). To release a new client: raise `VERSION`, run the stub tests (below),
rebuild the MPQ, put `patch-^.MPQ` in the launcher's `patches/` folder, write the same version in the launcher's
`client-version.txt` and in `Temucraft.ClientVersion.Required`.

## The server side

| Setting | Default | What |
|---|---|---|
| `Temucraft.ClientVersion.Enable` | 1 | check versions |
| `Temucraft.ClientVersion.Required` | 1.4.0 | oldest client allowed |
| `Temucraft.ClientVersion.RequirePatch` | 1 | also act on clients that never send a version (`GraceSeconds` after login) |
| `Temucraft.ClientVersion.Action` | 1 | 0 tell them to update, 1 also disconnect after 30 seconds (never GMs) |

`.temucraft clientversion` shows your (or your target's) client version.

Addon message `TCC` (Collections previews, `src/TemucraftCollectionsCache.cpp`): a comma list of creature entries (up to
48 a message); each one the world has gets the creature query response (`HandleCreatureQueryOpcode`), so the client's
`Model:SetCreature` can show it. No setting.

## Install

Put this folder in `modules/`, copy the conf, re-run CMake and build. The SQL adds the module's texts
(`module_string`, module `mod-temucraft-client-version`; translations in `module_string_locale`).

Part of the Temucraft modules for AzerothCore 3.3.5a.

## Token preview
[`TemucraftTokenPreview.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftTokenPreview.lua): a tier token's tooltip says how many items it buys for your class; alt-click it (or
`/tokenpreview <link>`) for a window with every item, its icon and tooltip, for your class or every class, next to
your character: click an item to try it on, "Try on set" dresses you in the whole tier set. Run
`client/tokens/token_preview.sql` and `set_pieces.sql` on the world database into `tokens.tsv` / `sets.tsv`, then
`build_token_preview.py`. The table comes from the world database: run `client/tokens/token_preview.sql` on it into
`client/tokens/tokens.tsv`, then `python3 client/tokens/build_token_preview.py` and rebuild the patch.

## Wardrobe
[`TemucraftCostumes.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftCostumes.lua): the window of [mod-temucraft-costumes](https://github.com/Temucraft/mod-temucraft-costumes) (`.temucraft costume` or `/wardrobe`). Its catalog comes from
`client/costumes/costume_catalog.sql` -> `costumes.tsv` -> `build_costume_window.py` (UI code in [`costume_window.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/costumes/costume_window.lua)).

## Vanity
[`TemucraftVanity.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftVanity.lua): the Vanity window of [mod-temucraft-account-wide](https://github.com/Temucraft/mod-temucraft-account-wide)
(`/vanity`, `.temucraft collection vanity`, or the Vanity button of the Wardrobe). It lists the vanity items your account has
unlocked (the Stones and Scrolls of Homecoming of [mod-temucraft-travel](https://github.com/Temucraft/mod-temucraft-travel) and any others in
`mod_temucraft_vanity_item`), each with its icon, name and cooldown, and a Summon button that puts it back in your bags
if this character doesn't have it. "Show locked" also lists the ones still to get. Addon prefix `TVA`.

## Spellbook, talents and collections
[`TemucraftPlayerSpells.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftPlayerSpells.lua) is a retail-style window with **Specialization / Talents / Spellbook**
tabs at the bottom. P and the spellbook micro button open it on Spellbook, N and the talent micro button on Talents
(they replace `ToggleSpellBook` / `ToggleTalentFrame`; the pet book, Shift-P, stays the stock one). `/tsb classic` (or
the "Classic spellbook" checkbox) and `/ttf classic` (the "Classic talents" checkbox) bring back the stock frames,
`/tsb new` and `/ttf new` this one; Interface Options > Temucraft has the same choices. Both ways switch at once, no
`/reload`. The window is 860 wide on all three tabs (so the frame and its bottom tabs don't move when you switch;
1672 in the spellbook's two-page view) and scales down to fit smaller screens. The Specialization cards are centred.

- **Spellbook** ([`TemucraftSpellBook.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftSpellBook.lua)): tabs *class*, *General* and *Skills*, a search box (name, subtitle, section and the
  tooltip text, read once from a hidden tooltip), a 3-column grid of icon, name and grey subtitle (the spell's subtext,
  e.g. "Shapeshift", "Racial Passive", "Guild Perk"; never "Rank n") under headings: the class (class spell tabs that
  aren't talent trees, if the server has any), then each talent tree; General, Racial, Professions, Guild Perks and any
  other spell tab (Temucraft spells) in General. Passives with the stock passive border. The expand button shows two
  pages. Pet, Collections and Train sit in the middle of the bottom bar.
  *Ranks*: the "Show all ranks" box by the search (account-wide, `TemucraftStore` key `ui.bookranks` = `all`). Off
  (default): one entry per spell, its highest rank; a spell with lower ranks has a small arrow on its icon's right edge
  that opens them in a flyout row (click casts that rank, drag puts it on a bar, each has its own tooltip). On: every
  rank, highest first, under a bar with the spell's name; a click on the bar folds / unfolds it (out of combat).
  *Skills*: the stock skill lines (`GetSkillLineInfo`, every heading opened with `ExpandSkillHeader`) under Weapon
  Skills, Armor Proficiencies, Secondary Skills, Languages, Class Skills, Professions (read only), each with an icon
  (`TemucraftSpellBookLogic.SKILL_ICONS`, class skills the talent tree's icon) and a "current / max" bar (none for
  skills without ranks, e.g. armour); the search filters it too; it refreshes on `SKILL_LINES_CHANGED`. The old Racials / Professions / Guild tabs of `TemucraftSpellTabs.lua` became these
  sections (the flags still come from the server, prefix TSB); its Mounts / Companions tabs became Collections. The
  Train button of `TemucraftAutoLearn.lua` moves into the book while it's open. The spell buttons are
  `SecureActionButtonTemplate` (type `spell`, the spell id): click casts and drag picks the spell up, in and out of
  combat. Pages, search and expand change secure buttons, so in combat they wait for the end of combat
  (`TemucraftPlayerSpells_AfterCombat`).
- **Specialization / Talents** ([`TemucraftTalents.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftTalents.lua), texts in `TemucraftTalentsData.lua`): a card per tree
  (stock tree art, role, description, preferred weapon, primary stat, two sample abilities); "Active" is the tree with the
  most points in the active talent group and Activate switches talent groups (dual spec). The Talents tab shows the
  three trees side by side and works through the client's talent preview (`previewTalents` is turned on): clicks add
  preview points, "Apply Changes" learns them, "Reset Preview" drops them. Search lights up matching talents. The Loadouts
  menu lists the server's loadout slots ([mod-temucraft-loadouts](https://github.com/Temucraft/mod-temucraft-loadouts),
  addon prefix `TLO`): each slot can be loaded (the server swaps the build, its glyphs and action bars into the active
  talent group, no gold cost), saved to, renamed, or unlocked for Temucraft Tokens or gold (with a confirm dialog);
  `.loadout` does the same from chat (for DragonUI's talent window). "Preview builds" are the older client-side builds
  that only load into the preview; without the server module they are the whole menu. Glyph sockets along the bottom (use a glyph, click a socket; shift-right-click removes). The tooltip under the
  mouse updates after each click. Some Temucraft talents sit between a talent and its prerequisite in the same column:
  the stock `TalentFrame_DrawLines` broke on those (its "blocked vertically" message indexes the wrong cell), so the
  classic frame failed, and once Blizzard_TalentUI was loaded so did every preview click here. This file replaces it
  with a copy that draws such lines straight through, and keeps the hidden stock frame from redrawing on preview
  points.
- **Collections** ([`TemucraftCollections.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftCollections.lua), `/collections` or the button in the book): tabs Mounts /
  Pet Journal (Toy Box / Heirlooms / Appearances / Campsites are written but hidden by `TAB_READY` until they have
  something). Mounts and pets:
  every one the game has (`TemucraftCollectionsData.lua`), the missing ones greyed with the item that teaches them,
  "X / Y collected" (Y: collected plus the missing ones with a known source; "Unknown source" shows the rest),
  favourites (right click; per account), a 3D preview on your race's dressing-room backdrop (`SetCreature` with the
  creature; 3.3.5 has no `SetDisplayInfo`, and a bare `SetModel` of the .m2 has no skin). The client's `SetCreature`
  shows only creatures already in its creature cache and never asks the server for one (`Script_SetCreature` looks the
  entry up without a callback), so the window sends every entry of the list to the server once (addon message `TCC`,
  comma lists of up to 40 entries, four messages a second; the selected one again at once if it isn't in), and
  `src/TemucraftCollectionsCache.cpp` answers each entry the world has with the ordinary creature query response,
  which the client keeps (also in `creaturecache.wdb`). Until it is in, `SetCreature` is retried for 6 seconds, then
  "No preview". Show Character: your character on the left with the mount behind it on the right, or the pet small at
  your feet (a model frame can't seat a character on a creature in 3.3.5: each has its own camera); drag to turn them.
  Mount /
  Summon and Summon Random Favorite (`CallCompanion`, not protected). The data table: `python3 client/collections/build_collections.py`
  (Spell.dbc, SkillLineAbility.dbc skill lines 777 / 778 and items of class 15 / subclass 5 and 2, creature models from
  CreatureDisplayInfo / CreatureModelData; defaults to `_dev/server-dbc/dbc` and the core's `data/sql/base/db_world`).
  Later: Appearances can read mod-transmog's `custom_unlocked_appearances` (characters DB: `account_id`,
  `item_template_id`, one row per unlocked item, per account); Toy Box mod-temucraft-lostlands' illusions and the
  account-wide vanity items; Campsites mod-temucraft-camping.
- **Saved between sessions** ([`TemucraftStore.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftStore.lua)): FrameXML has no SavedVariables, so favourites (per account),
  loadouts (per character) and the classic / new choice (per account) are kept by mod-temucraft-account-wide (prefix
  `TUS`, table `mod_temucraft_ui_store`). Without it they last until logout.

## Player UI (retail look, each with a Classic option)
Interface Options > Temucraft (or `/tui`) has a "Classic" box for each piece and the tooltip ID option
([`TemucraftInterface.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftInterface.lua); per account in the store, keys `ui.classicchar`,
`ui.classicmicro`, `ui.classicmenu`, `ui.classicoptions`, `ui.classicguild`, `ui.classicgbank`, `ui.classicrep`, `ui.classiccurrency`,
`ui.classicgossip`, `ui.tooltipids`, `ui.guildloginchat`). The windows themselves have no Classic checkbox any more (it
sat on their bottom tabs), except the spellbook and talents.

- **Gossip** ([`TemucraftGossip.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftGossip.lua)): the stock GossipFrame with a 36 px
  icon per NPC option by its type (binder: hearthstone, vendor: bag, trainer: book, taxi: gryphon / wyvern by faction,
  banker: coin, battlemaster: banner, healer: resurrection, gossip: note...) and taller rows; quests keep their ! / ?
  icons. Restyled after each `GossipFrameUpdate`, and put back for quests and with "Classic gossip window".

- **Character window** ([`TemucraftCharacter.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftCharacter.lua), C, U, `/tchar`, `/tchar classic|new`):
  ONE window (730 x 500, the same size, place and style on every tab; scaled down on small screens; drag the top to
  move it, the place is kept per character in TemucraftStore `ui.charwin`; Esc closes it) with the tabs Character /
  Pet (only while you have a pet) / Reputation / Skills / Currency / Professions (only with the TemucraftProfGear
  addon of mod-temucraft-professions). A tab swaps the page inside; the window and the tab strip stay put.
  The look is the shared one (`TemucraftStyle.lua`): gold border and header (the page's title; on Character and Pet
  the name and "Level 80 ..."), parchment insets for lists, details and stats, the achievement categories' dark bar
  behind section headers and their gold highlight on rows (`TemucraftCharacter_Panel` / `_Inset` / `_HeaderBar` /
  `_Highlight` for the pages of other files).
  - Character: the stock item slots (they move into the page while it is open, so clicking, Alt flyouts and the
    equipment manager work as always) down both sides and the weapons at the bottom, a bigger model on the race's
    backdrop (drag to turn, wheel to zoom), a Titles menu, and on the right the item level (average of the 17 slots,
    a two-hander counts twice) and the stats: Attributes, Enhancements (by role: melee, ranged or caster; hybrids by
    their main talent tree) and Defense. The Titles list is the solid dialog-style menu.
  - Pet: the pet's model on the same backdrop, happiness (hunters: icon, "your pet does N% damage", the headline of
    the stats), the experience bar, and its stats in the same panel (Attributes, Melee, Resistances, unspent talent
    points).
  - Reputation and Currency: the pages below (`TemucraftReputation.lua`, `TemucraftCurrency.lua`).
  - Skills: the skill lines under collapsible section headers (the spellbook Skills tab's sections, icons and
    "current (+bonus) / max" text, `TemucraftSpellBookLogic`): an icon, the name and a slim rank bar per skill; on the
    right the description, the rank bar, "How to raise it" and Unlearn for professions. Refreshes on
    `SKILL_LINES_CHANGED`. Reusable: `TemucraftSkills_Build(parent [, name])` (list + details in any frame) and
    `TemucraftSkills_Read()` (the sections).
  - Professions: TemucraftProfGear's Profession Equipment and Reagent Bag panels side by side in the window's style,
    the help text in its own line under them (`TemucraftProfGear_Host(parent)`; `/profgear` and alt-right-click open
    this tab).
  Classic: "Classic character panel" sends Character, Pet, Skills and Professions to the stock character frame
  (Professions to the addon's tab there), "Classic reputation window" / "Classic currency window" just those tabs;
  the other tabs stay in this window. With DragonUI's Character Panel module on, its window is used for Character,
  Pet, Skills and Currency, and Reputation stays ours. Other files add pages with `TemucraftCharacter_AddPage(key,
  frame, { title })` and open them with `TemucraftCharacter_Open(key [, toggle])`.
- **Micro menu** ([`TemucraftMicroMenu.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftMicroMenu.lua)): a row at the bottom right (smaller
  if need be, or above the main bar when there's no room beside it): Character, Spellbook & Talents (right click:
  talents), Achievements, Quest Log, Guild (right click: friends), Group Finder (right click: PvP), Collections, Shop,
  Game Menu (latency / memory tooltip), Help. Each calls what its stock button calls and copies its stock button's
  state (pushed, disabled below its level); the stock buttons are hidden, and come back on vehicle bars.
- **Guild & Communities** ([`TemucraftGuild.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftGuild.lua), J, the micro menu's guild button, `/tguild`,
  `/tguild classic|new`): the guild's card on the left (name, your rank, online count, message of the day, Add Member,
  Leave Guild, Classic Window for the stock tab with guild control) and the tabs Chat (guild and officer chat with
  its history and timestamps, "Load older messages", the online members beside it, a box to write to the guild or
  the officers), Roster (class colours, level, rank, zone, note, last online; click a header to sort, offline
  members too; double click whispers, right click the stock menu), News (achievements, epic items, joins, leaves,
  promotions), Info (message of the day and guild information, editable with the rights; the guild log) and Perks
  (when [mod-temucraft-guild-perks](https://github.com/Temucraft/mod-temucraft-guild-perks) is on the server). The
  history, news, the whole guild log and the perks come from [mod-temucraft-guild](https://github.com/Temucraft/mod-temucraft-guild)
  (addon messages `TGD`); without it the window shows the live chat and the stock last log entries. After login the
  last lines of guild chat are written to the chat window. J is bound to the Guild key once per account when both
  are free.
- **Guild bank** ([`TemucraftGuildBank.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftGuildBank.lua)): the stock guild bank (the same item
  buttons, tabs and popups, so moving items works as always) in a dark retail-style window: "Guild Bank", the tab's
  name with its access, a Search box that dims what doesn't match, "Remaining Daily Withdrawals for <your rank>",
  the Available Amount bar; Log and Money Log list deposits (green) and withdrawals (red) with class-coloured names,
  Gold / Silver / Copper and "(10 months ago)", every entry ever made from mod-temucraft-guild's archive ("Show
  more..."), else the stock last 25. Changed only out of combat.
- **Reputation** ([`TemucraftReputation.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftReputation.lua), the Reputation tab, U; a page of the character window):
  factions under collapsible expansion headers (Allied Races, Mists of Pandaria, Cataclysm, Wrath of the Lich King,
  The Burning Crusade, Classic, Lost Lands, Crafting Orders, the client's other headers, Inactive last), a filter
  (All / Active / Inactive / At War), bars with the standing (its value on mouse over) or "Renown N" / "Level N" for
  factions with a Renown track, "Warband Reputation" in the tooltip of account-wide factions, and a detail panel:
  description, At War, Move to Inactive, Show as Experience Bar (the stock calls and rules) and View Renown. Which of
  our factions goes in which group is in [`TemucraftReputationData.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftReputationData.lua),
  written by `client/gen_reputation_data.py` from the release patches' Faction.dbc (edit the groups there and run it
  again). 3.3.5 gives the interface no faction ids, so factions are matched by name: the English names are in that
  file, and [mod-temucraft-renown](https://github.com/Temucraft/mod-temucraft-renown) sends them in the player's
  locale. Renown and Warband need that module (addon messages `TRN`); without it the window is a plain reputation list.
- **Currency** ([`TemucraftCurrency.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftCurrency.lua), the Currency tab; a page of the character window): the same style; the
  currencies under their collapsible categories with icon and count, a detail panel with the description, Move to
  Unused and Show on Backpack (at most 3, as in the stock window).
- **Renown journeys** ([`TemucraftRenown.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftRenown.lua), View Renown, `/renown [faction]`): a
  faction's Renown track from mod-temucraft-renown: a ring with the level, "Current Progress: X / Y", the rewards
  1..N (got / next / locked, arrows to page) and the Overview with the "Journey Highlights" cards. Its own window
  until the Adventure Guide.
- **Game menu** ([`TemucraftGameMenu.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftGameMenu.lua)): the stock GameMenuFrame laid out again
  in retail's order under "Game Menu": Options (the Options window below), Shop, then AddOns, What's New
  (`TemucraftChangelog.lua`: add a block with each release), Edit Mode (DragonUI's editor; only while DragonUI has it),
  DragonUI's settings button (while DragonUI runs), Support (the stock help / ticket frame), Macros, then Log Out,
  Exit Game, Return to Game. With "Classic options menu" Options is Options +/- again, with System / Sound /
  Interface / Key Bindings (the stock windows) under it. Shop is a placeholder until a shop window defines `TemucraftShop_Show`.
- **Options** ([`TemucraftOptions.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftOptions.lua), Esc > Options, `/options`, `/settings`):
  one retail-style window instead of the four stock ones. Tabs **Game | AddOns**, **Search** (every setting's name,
  and the key bindings), **Close** (settings apply as they change). Game: **Gameplay** (Controls, Interface, Action
  Bars, Combat, Social, Keybindings, Nameplates), **Accessibility** (General, Colors), **System** (Graphics, Audio,
  Languages, Network); each page has its title, Defaults, white sub-headers and rows: gold label, then a checkbox,
  a < value > selector or a < slider > with its value; sub-options indented and greyed while their parent is off.
  The pages are rebuilt, but each row drives the stock control underneath (`InterfaceOptions*`, `VideoOptions*`,
  `AudioOptions*`: same CVars, setFuncs, dependent controls, sound restarts), so the stock windows stay in step.
  Graphics applies at once except what needs a display restart (resolution, refresh rate, multisampling, vsync,
  triple buffering, hardware cursor, window mode, UI scale on/off): those wait for its **Apply** (the stock
  `VideoOptionsFrameOkay_OnClick`, with `RestartGx`), and closing with changes waiting asks. Keybindings: Character
  Specific Keybindings, then collapsible category bars with two key buttons per action (click, press the key or
  mouse button; Esc cancels, right click unbinds); `SetBinding` / `SaveBindings` at once, never in combat. Also a
  Pick Up Action Key (`SetModifiedClick("PICKUPACTION")`) under Lock Action Bars. AddOns: every addon page of
  Interface Options (alphabetical, "+" for its sub-pages), our Temucraft page and a DragonUI link (its settings
  window and Edit Mode); the addon's own panel is moved into the window and back, gets `refresh` when shown and
  `okay` on close. `InterfaceOptionsFrame_OpenToCategory` (addons, `/tui`) lands here too. Accessibility > General
  has **Arachnophobia Mode**, a server setting row (below). Not in 3.3.5, so not here: text scale, cursor size,
  loss of control alerts, cooldown numbers, "always show nameplates" (V / Shift-V / Ctrl-V are key bindings),
  block guild invites, advanced combat logging (shown only if the client has the CVar). Battle.net toasts and voice
  chat are left out (no Battle.net on our realms); they stay in the classic windows.
- **Server setting rows** (`TemucraftOptions_ServerRow(name, label, tooltip)`): a switch the server keeps per player
  in [mod-temucraft-player-settings](https://github.com/Temucraft/mod-temucraft-player-settings). The row whispers
  `.temucraft settings <name> on|off` to yourself (a command, never said aloud) and keeps the choice per account
  (`ui.server.<name>`). Once a session it sends the stored choice again (with none stored it only asks,
  `.temucraft settings <name>`); the server's answer is a system line naming the setting with "on" / "off" (kept out
  of the chat window). "No such command", no rights or no answer in 6 seconds greys the row: "Only on servers with
  Temucraft player settings". Arachnophobia (`arachnophobia`) is the first.
- **Window look** ([`TemucraftStyle.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftStyle.lua), loaded early for every window):
  `TemucraftStyle_Window(frame, title)` (dark stone background, gold dialog border, gold header with the title),
  `TemucraftStyle_Inset(frame)` (lighter parchment inset, thin gold edge), `TemucraftStyle_Header(fontString)` and
  `TemucraftStyle_Bar(frame)` (the achievement window's dark category bar), `TemucraftStyle_Highlight(button)` /
  `TemucraftStyle_Glow(frame)` (its gold highlight), `TemucraftStyle_Line(parent)`. Stock 3.3.5 art only.
- **AddOns** ([`TemucraftAddOns.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftAddOns.lua), `/addons`): every addon with a checkbox
  (`EnableAddOn` / `DisableAddOn`, on the next UI load), its state, memory, and CPU when the "CPU profiling" box
  (CVar `scriptProfile`) is on; Enable All / Disable All / Reload UI.
- **Tooltips** ([`TemucraftTooltips.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftTooltips.lua)): SpellID on spell tooltips (spellbook,
  bars, links, auras) and ItemID on items, each with the icon's texture name (3.3.5's interface only gets the icon's
  path, never the SpellIcon / file id); "Cooldown remaining: N sec"; "You haven't added this to your action bars" on
  the new spellbook's and the flyouts' spells that no bar (or macro) has.
- **Spellbook flyouts** ([`TemucraftFlyouts.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftFlyouts.lua)): the class's teleports, its portals
  (2 or more) and the Temucraft helper items in your bags are one entry each in the book; a click opens a row of
  `SecureActionButtonTemplate` buttons beside it (cast in combat). The book's buttons are wrapped with
  `SecureHandlerWrapScript` (header `TemucraftFlyoutHeader`) so the row opens and closes in combat too; what a row
  holds changes only out of combat. Groups: `TemucraftFlyoutLogic.FLYOUTS`, `TELEPORT_IDS`, `PORTAL_IDS`, `HELPER_ITEMS`.
  The book's rank arrows use the same rows (`TemucraftFlyouts_Attach(arrow, flyout, icon)`, key `rank<button>`).

## DragonUI

[DragonUI](https://github.com/NeticSoul/DragonUI) (our fork: Temucraft/DragonUI-Temucraft, PTR first) is the base of
the in-game interface. [`TemucraftDragonUI.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftDragonUI.lua)
reads at login (`PLAYER_LOGIN`; DragonUI's AceDB is in by then) whether DragonUI runs (`IsAddOnLoaded("DragonUI")`,
its addon table `_G.DragonUI`) and which of its modules are on (`DragonUI:IsModuleEnabled(<module>)`, i.e.
`DragonUIDB.profiles[<profile>].modules.<module>.enabled`). Where one of them covers one of our windows, ours steps
aside: `TemucraftUI_IsClassic(which)` and `TemucraftPlayerSpells_IsClassic(which)` answer true, so the stock frame
opens and DragonUI replaces or dresses it. The saved Classic choices are not touched (`TemucraftUI_IsSavedClassic`);
Interface > Temucraft greys those boxes with "DragonUI's ... is used". DragonUI's modules load once, so a change (a
module or DragonUI off) takes a `/reload`, after which our windows are back.

| Ours | DragonUI module | |
|---|---|---|
| character panel (`char`), currency (`currency`) | `characterpanel` | DragonUI's |
| micro menu (`micro`) | `micromenu` | DragonUI's (our micro menu doesn't touch the stock buttons) |
| spellbook (`book`), talents (`talents`) | `spellbook`, `talents` | DragonUI's; the Train button and auto-learn box follow DragonUI's book (`TemucraftAutoLearn_Ask`) |
| gossip icons (`gossip`) | `questdialog` | DragonUI's |
| AddOns list (`addons`) | `addonmanager` | DragonUI's: our Esc menu's AddOns row and `/addons` open it |

Ours stay: reputation and Renown (the Reputation tab and U still open ours), guild, guild bank, collections
(`ToggleCollectionsJournal` is defined, so DragonUI's Pets & Mounts button opens ours), the flight map, the Issue
Reporter and the Esc menu, which takes DragonUI's settings button and an Edit Mode row (DragonUI's editor) as rows. The
fixes and defaults that live in DragonUI itself (custom races, in-column talents, route-only flight points, Temucraft
defaults) are patches in `_dev/dragonui/` for the fork.

Maps and quest trackers: Leatrix Maps (with Questie) is the standard world map, so DragonUI's World Map module is off in
our defaults (patch 0004, which also adds Leatrix Maps to the addons it steps aside for); a player who turns it on
while Leatrix Maps is loaded is told once in chat (at login or when the map opens). DragonUI's quest tracker is the
one kept: at the first login with DragonUI's tracker on, Questie's own tracker is turned off once
(`Questie.db.profile.trackerEnabled = false`, flagged `temucraftTracker` in that Questie profile, so turning it back
on in Questie's options sticks).

## New-player tutorial

[`TemucraftTutorial.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftTutorial.lua)
(client only, no server part) walks a new character through its first minutes the way retail's Exile's Reach does.
It starts for a level 1 character with under 15 minutes played (`RequestTimePlayed`, its chat lines kept quiet; no
experience yet when the answer doesn't come), unless tutorials are off.

| Step | Shows | Done when |
|---|---|---|
| hands | centred panel "Position your hands and click Okay" (keyboard with W A S D lit, a mouse) | Okay (or moving) |
| look | bar "Look around" (mouse, right button red, arrows) | the camera turned with a mouse button held (`GetPlayerFacing` while mouselooking, or a left-button drag) |
| walk | bar "Walk around" (W A S D) | moving 1.5 s (`GetUnitSpeed`) |
| talk | bar "Talk to the quest giver (!)", later "Talk to <NPC>" (`UnitName("npc")` of the last quest giver) | `GOSSIP_SHOW` / `QUEST_DETAIL` / `QUEST_GREETING` |
| accept | bar "Accept the quest" | `QUEST_ACCEPTED` or a new quest in the log (window closed without it: back to talk) |
| target | bar "Target a <mob>" (the quest's "<mob> slain" objective) | a hostile target (`UnitCanAttack`) |
| cast | pointer at the action button: "Press 1 to cast <spell>" (first spell on slots 1-12 that isn't Attack / Auto Shot / Shoot, its key binding), "Don't move while casting." (`SPELL_FAILED_MOVING`, or interrupted while moving), "Again!" | the target dies; target lost: back to target |
| turnin | pointer at the quest tracker: "Quest complete! Return to the questgiver." once the quest is complete | `QUEST_COMPLETE` (the reward window) |

A quest without a kill objective shows "Your quest: <objective>" until it is turned in, then the chain goes on with the
next quest giver (by name); after four such quests it ends anyway. Beside the chain: "You've gained experience! You'll
level up when this bar is filled." at the XP bar (first experience, 12 s), and "Open your Spellbook and find <spell>"
at the spellbook micro button, which glows (a spell learned: `LEARNED_SPELL_IN_TAB` with the "You have learned" line;
done when any spellbook opens; given up at level 6).

- **Art**: stock 3.3.5 textures only: tooltip background and border (dark bar; gold-tinted for the pointer box), the
  minimap guide arrow (`Interface\Minimap\ROTATING-MINIMAPGUIDEARROW`, turned by texture coordinates, bouncing in
  `OnUpdate`), `UI-ActionButton-Border` as the glow; the keyboard and mouse are drawn from plain textures with key labels.
- **Never in the way**: the prompts don't take the mouse; only their small buttons do. Every prompt has an "x" (skips
  that step), the panel and the bars a "Skip tutorial".
- **DragonUI**: pointers anchor to the real frames, first shown one wins: `ActionButton<n>` (wherever DragonUI put it),
  `DragonUI_XPBar` / `MainMenuExpBar`, `DragonUIObjectiveTracker` / `Questie_BaseFrame` / `WatchFrame`,
  `TemucraftMicroButton_spellbook` / `SpellbookMicroButton`; a screen position when none is shown
  (`TemucraftTutorialLogic.ANCHORS`, `FALLBACK`).
- **Saved** (TemucraftStore): per account `tutorial.off` and `tutorial.seen` (a character finished it: the next new
  one asks "This account already finished the tutorial. Skip it?"), per character `tutorial` (its step, then `done`),
  so a relog carries on.
- **Options**: Gameplay > Interface > Help, "Tutorials" (in place of the stock box: it turns this tutorial and the
  game's tips, CVar `showTutorials`, on or off together) and "Reset Tutorials" (clears the three values and calls
  `ResetTutorials()`; on a level 1 character it starts again at once). `/ttutorial [reset | skip | on | off]`.

## Login screens (GlueXML)

The client's own CharacterCreate.lua / CharacterSelect.lua still run and do the work; their frames are moved into a
hidden holder and ours sit on top. The "Classic" choice here is `TEMUCRAFT_LOGIN_UI = "classic"` in
`Interface\TemucraftScenes.lua` (written by the launcher): both screens are then the stock ones.

- **Character select** (`TemucraftCharSelect.lua`), retail style, 3.3.5 art only (DialogFrame gold border and dark
  background, AchievementFrame bars, Glue panel buttons):
  - **List panel** on the right: a Search box (magnifier, "Search"; name, class, race, faction, zone, level "70",
    "60-70", "80+", roles "tank" / "heal" / "dps") with an (i) tooltip and a square red "+" (Create Character).
    Below, the characters in **groups** with dark collapsible headers ("Characters" by default, "(3)", -/+). Right-click
    a card: Move to group > (groups) / New group...; right-click a header: Rename / Delete (its cards go back to
    "Characters"; the default group can only be renamed) / New group...; left-click a header opens or closes it.
    Drag a card onto a card (it takes that place, in that card's group) or onto a header (last in that group).
  - **Cards**: "1." small and grey, the name in gold, "Level 80 Mage" (class in its colour), the zone on one line with
    the short version bracket, the faction crest on the right (in colour on the selected card, grey and dim on the
    others); the selected card has a gold background, border and glow. Double-click enters the world. The paid service
    button and an unread mail badge sit on the card's left edge.
  - **Card tooltip** (left of the list): name, realm, spec + class in class colour, level, zone, professions, gold
    (coin icons). The character list only has name, class, level and zone; spec, professions, gold and mail come from
    `TEMUCRAFT_CHAR_SUMMARY` in `Interface\TemucraftCharSummary.lua` (empty in patch-^; the launcher writes the real
    file, loose, like `TemucraftScenes.lua`; the format is in that file) and are left out when it has nothing.
  - **Bottom**: a red Create Character button (tooltip: the realm), a square Delete Character (trash) and a square
    Restore Deleted Character button. 3.3.5 can't restore at character select; its tooltip says that the Temucraft
    Curator (mod-temucraft-shop, in game) brings deleted characters back for tokens.
  - **Delete** opens our dialog (the stock `CharacterDeleteDialog` is not used): "Do you want to delete <name> Level
    <n> <class>?", a warning icon, the client's instructions, an edit box, Okay (only when the box holds the word) and
    Cancel; then the client's `DeleteCharacter(index)`. Accepted, in any case: the client's `DELETE_CONFIRM_STRING`,
    the word for the client's language (ruRU УДАЛИТЬ, deDE LÖSCHEN, frFR SUPPRIMER, esES/esMX BORRAR, koKR 삭제,
    zhCN 删除, zhTW 刪除), always the English DELETE, and Latin spellings (UDALIT, LOESCHEN / LOSCHEN); non-English
    clients show "(or DELETE)". Cyrillic and Latin-1 upper case is done by `Logic.Upper` (Lua's only knows a-z).
  - A top bar with Menu (a gold-bordered panel of red buttons: Options, AddOns, Credits, Cinematics, Exit) and the
    realm's name; the PTR client on a realm that isn't the PTR gets a red warning and Enter World off. The eye button
    hides the interface. The Realms button is hidden (Live or PTR is picked in the launcher).
  - Groups and order are kept per account and realm in Config.wtf's `accountList` as a segment after `~`
    (`GetSavedAccountList` / `SetSavedAccountList` are wrapped so AccountLogin.lua still sees only the saved
    accounts). An entry is a name or a group header `#` + kind (`*` default, `=` the player's) + state (`+` open,
    `-` closed) + name; only the default group, open and not renamed, is saved as plain names, exactly the old
    format, so orders saved before groups read the same.
  - Not doable: retail's camp with up to four characters in the scene. The 3.3.5 glue screen has one character model
    (the CharacterSelect ModelFFX), so only the selected character stands in the scene.
- **Character create** (`TemucraftCharCreate.lua`): Alliance races in two columns on the left, Horde on the right,
  classes along the bottom, male / female at the top; step 2 Customize with the name and random-name dice, option
  arrows with "Face 3 / 9" counters (totals from the DBCs in `TemucraftGlueData.lua`, made by `gen_glue_data.py`),
  Randomize Appearance. `TEMUCRAFT_CREATE_SCENES = "race"` shows each race's own scene; `TEMUCRAFT_SCENE_PICKS`
  the player's picks.
- **Glue safety** (`TemucraftGlueSafety.lua`, loaded first): `GetAvailableRaces`, `GetAvailableClasses` and
  `GetClassesForRace` push 3 values per race or class without growing the Lua stack; with 20-30 races the stock
  Wow.exe wrote past it ("Not enough memory" crash picking Zandalari). They are wrapped to run from a Lua function
  with a big register frame. Wow-races-30.exe fixes it in the exe; the wrapper is harmless there.

## Slash commands and key bindings

| Command / key | Opens |
|---|---|
| `/options`, `/settings` [page] | the Options window (page: `controls`, `graphics`, `keybindings` ... or an addon's name) |
| `/tui` | Options > AddOns > Temucraft (every Classic box, tooltip IDs, guild chat at login) |
| C, `/tchar [classic\|new]` | character window (Character tab) |
| P / N, `/tsb [classic\|new]`, `/ttf [classic\|new]` | spellbook / talents |
| `/collections`, `/tcol` | collections |
| J, `/tguild [classic\|new]` | guild window (J is bound to the stock Guild key once per account when both are free) |
| U (Reputation tab), `/renown [faction]` | reputation, Renown journeys |
| `/addons` | addon list |
| `/ttutorial [reset\|skip\|on\|off]` | the new-player tutorial |
| `/issue`, `/bug`; F6 (`/issuekey <key>\|none`) | Issue Reporter; the key is a click binding, F6 by default when free |
| `/wardrobe`, `/vanity`, `/tokenpreview <link>`, `/heritage`, `/disguise`, `/tankrole` | module windows |
| `/missions`, `/tmt`, `/companions`, `/tex`, `/wayfinder` | mission table, companions, expeditions |

## Tests

Stub tests (no client; run from the module folder with Lua 5.1) for the grouping, search, paging, collection and
loadout logic, the player UI, the login screens and the protocols: `lua5.1 client/tests/spellbook_test.lua`,
`collections_test.lua`, `interface_test.lua`, `taxi_test.lua`, `issues_test.lua`, `guild_test.lua`,
`reputation_test.lua`, `glue_test.lua`, `loadouts_test.lua` (the server loadouts protocol), `dragonui_test.lua` (the DragonUI step-aside switch), `tutorial_test.lua` (the new-player tutorial's start rules and step machine, fed fake events) and `options_test.lua` (the Options pages, search, sliders, key names, binding groups, the AddOns list, server answers and the Esc menu rows; all in `client/tests/`). Also check every file with `luac5.1 -p`.

## Also in this module

These were separate modules; they now live here, each with its own folder under `src/`, its own config file in
`conf/` (same file and key names as before) and its notes under `docs/`. Their SQL files kept their names, so nothing
is applied twice. Remove the old module folders from `modules/` before building.

| Was | What | Code | Notes |
|---|---|---|---|
| mod-temucraft-spellbook | spellbook tabs | `src/spellbook` | [docs/spellbook.md](docs/spellbook.md) |
