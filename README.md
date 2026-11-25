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
`/reload`. The window is 860 wide on the Talents tab (820 otherwise) and scales down to fit smaller screens.

- **Spellbook** ([`TemucraftSpellBook.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftSpellBook.lua)): tabs *class* and *General*, a search box (name, subtitle, section and the
  tooltip text, read once from a hidden tooltip), a 3-column grid of icon, name and grey subtitle (the spell's subtext,
  e.g. "Shapeshift", "Racial Passive", "Guild Perk"; never "Rank n") under headings: the class (class spell tabs that
  aren't talent trees, if the server has any), then each talent tree; General, Racial, Professions, Guild Perks and any
  other spell tab (Temucraft spells) in General. Highest rank only, passives with the stock passive border. The
  expand button shows two pages. The old Racials / Professions / Guild tabs of `TemucraftSpellTabs.lua` became these
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
  favourites (right click; per account), a 3D preview (`SetCreature` with the creature, tried again for a few seconds while the client asks the
  server for it; 3.3.5 has no `SetDisplayInfo`, and a bare `SetModel` of the .m2 has no skin, so the model file is used
  only for an entry without a creature), Show Character, Mount /
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
`ui.classicmicro`, `ui.classicmenu`, `ui.classicguild`, `ui.classicgbank`, `ui.classicrep`, `ui.classiccurrency`,
`ui.classicgossip`, `ui.tooltipids`, `ui.guildloginchat`). The windows themselves have no Classic checkbox any more (it
sat on their bottom tabs), except the spellbook and talents.

- **Gossip** ([`TemucraftGossip.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftGossip.lua)): the stock GossipFrame with a 36 px
  icon per NPC option by its type (binder: hearthstone, vendor: bag, trainer: book, taxi: gryphon / wyvern by faction,
  banker: coin, battlemaster: banner, healer: resurrection, gossip: note...) and taller rows; quests keep their ! / ?
  icons. Restyled after each `GossipFrameUpdate`, and put back for quests and with "Classic gossip window".

- **Character panel** ([`TemucraftCharacter.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftCharacter.lua), C, `/tchar`, `/tchar classic|new`):
  the stock item slots (they move into the window while it is open, so clicking, Alt flyouts and the equipment manager
  work as always) down both sides and the weapons at the bottom, a bigger model on the race's backdrop (drag to turn,
  wheel to zoom), a Titles menu, and on the right the item level (average of the 17 slots, a two-hander counts twice)
  and the stats: Attributes, Enhancements (by role: melee, ranged or caster; hybrids by their main talent tree) and
  Defense. Tabs Character / Pet / Reputation / Skills / Currency / Professions, like the classic set; Pet and Skills
  open the stock frame on that tab, Reputation and Currency the windows below, Professions (only with the
  TemucraftProfGear addon of mod-temucraft-professions) its Profession Equipment panel. The Titles list is the solid
  dialog-style menu.
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
- **Reputation** ([`TemucraftReputation.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftReputation.lua), the Reputation tab, U):
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
- **Currency** ([`TemucraftCurrency.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftCurrency.lua), the Currency tab): the same style; the
  currencies under their collapsible categories with icon and count, a detail panel with the description, Move to
  Unused and Show on Backpack (at most 3, as in the stock window).
- **Renown journeys** ([`TemucraftRenown.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftRenown.lua), View Renown, `/renown [faction]`): a
  faction's Renown track from mod-temucraft-renown: a ring with the level, "Current Progress: X / Y", the rewards
  1..N (got / next / locked, arrows to page) and the Overview with the "Journey Highlights" cards. Its own window
  until the Adventure Guide.
- **Game menu** ([`TemucraftGameMenu.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftGameMenu.lua)): the stock GameMenuFrame laid out again:
  Options (opens System / Sound / Interface / Key Bindings under it), Shop, What's New (`TemucraftChangelog.lua`:
  add a block with each release), AddOns, Support (the stock help / ticket frame), Macros,
  Log Out, Exit Game, Return to Game. Edit Mode has a button in the code but no row until it exists. Shop is a placeholder until a shop window defines `TemucraftShop_Show`.
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

## Login screens (GlueXML)

The client's own CharacterCreate.lua / CharacterSelect.lua still run and do the work; their frames are moved into a
hidden holder and ours sit on top. The "Classic" choice here is `TEMUCRAFT_LOGIN_UI = "classic"` in
`Interface\TemucraftScenes.lua` (written by the launcher): both screens are then the stock ones.

- **Character select** (`TemucraftCharSelect.lua`): character cards on the right (name, level, class colour, zone
  with its version bracket from `TemucraftGlueData.lua`, faction crest), a search box (name, class, zone, level "70", "60-70", "80+", role
  words such as "tank" / "healer"), a top bar with Menu (Options, AddOns, Credits, Cinematics, Exit), an eye button
  that hides the interface, Create / Delete under the cards. The Realms button is hidden (Live or PTR is picked in
  the launcher). Cards can be reordered by drag and drop or the arrows on the selected card; the order is kept per
  account and realm in Config.wtf's `accountList` as a segment after `~` (`GetSavedAccountList` /
  `SetSavedAccountList` are wrapped so AccountLogin.lua still sees only the saved accounts).
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
| `/tui` | Interface Options > Temucraft (every Classic box, tooltip IDs, guild chat at login) |
| C, `/tchar [classic\|new]` | character panel |
| P / N, `/tsb [classic\|new]`, `/ttf [classic\|new]` | spellbook / talents |
| `/collections`, `/tcol` | collections |
| J, `/tguild [classic\|new]` | guild window (J is bound to the stock Guild key once per account when both are free) |
| U (Reputation tab), `/renown [faction]` | reputation, Renown journeys |
| `/addons` | addon list |
| `/issue`, `/bug`; F6 (`/issuekey <key>\|none`) | Issue Reporter; the key is a click binding, F6 by default when free |
| `/wardrobe`, `/vanity`, `/tokenpreview <link>`, `/heritage`, `/disguise`, `/tankrole` | module windows |
| `/missions`, `/tmt`, `/companions`, `/tex`, `/wayfinder` | mission table, companions, expeditions |

## Tests

Stub tests (no client; run from the module folder with Lua 5.1) for the grouping, search, paging, collection and
loadout logic, the player UI, the login screens and the protocols: `lua5.1 client/tests/spellbook_test.lua`,
`collections_test.lua`, `interface_test.lua`, `taxi_test.lua`, `issues_test.lua`, `guild_test.lua`,
`reputation_test.lua`, `glue_test.lua`, `loadouts_test.lua` (the server loadouts protocol) and `dragonui_test.lua` (the DragonUI step-aside switch; all in `client/tests/`). Also check every file with `luac5.1 -p`.

## Also in this module

These were separate modules; they now live here, each with its own folder under `src/`, its own config file in
`conf/` (same file and key names as before) and its notes under `docs/`. Their SQL files kept their names, so nothing
is applied twice. Remove the old module folders from `modules/` before building.

| Was | What | Code | Notes |
|---|---|---|---|
| mod-temucraft-spellbook | spellbook tabs | `src/spellbook` | [docs/spellbook.md](docs/spellbook.md) |
