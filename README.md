# mod-temucraft-client-version

Gives the Temucraft client a version of its own, shown on the login screen and checked by the server, and builds the
Temucraft interface into the client so module windows behave like Blizzard's own UI.

## The client patch (`client/`)

`python3 client/build_mpq.py` makes `Data/<locale>/patch-<locale>-T.MPQ` (needs StormLib; `--stormlib` points at
`libstorm.so` or `StormLib.dll`). It holds:

- [`Interface\GlueXML\TemucraftVersion.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/GlueXML/TemucraftVersion.lua): the login screen shows "Temucraft 1.5.0 (3.3.5a build 12340)".
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
- `FrameXML.toc` and `GlueXML.toc`: the client's own lists (copies in `client/base/`) with those files added. They
  come from the highest-priority patches of the client (FrameXML.toc from patch-enUS-3.MPQ, GlueXML.toc from
  patch-enUS-C.MPQ); refresh `client/base/` if another patch changes them.

The version is `client/VERSION`. To release a new client: raise `VERSION`, rebuild the MPQ, put it in the launcher's
`locales/<locale>/` folder, write the same version in the launcher's `client-version.txt` and in
`Temucraft.ClientVersion.Required`.

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
`/tsb new` and `/ttf new` this one.

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
  preview points, "Apply Changes" learns them, "Reset Preview" drops them. Search lights up matching talents. Loadouts
  save the build to a name and load one into the preview (learned points still need a respec or the other talent
  group). Glyph sockets along the bottom (use a glyph, click a socket; shift-right-click removes).
- **Collections** ([`TemucraftCollections.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftCollections.lua), `/collections` or the button in the book): tabs Mounts /
  Pet Journal / Toy Box / Heirlooms / Appearances / Campsites (the last four are placeholders for now). Mounts and pets:
  every one the game has (`TemucraftCollectionsData.lua`), the missing ones greyed with the item that teaches them,
  "X / Y collected" (Y: collected plus the missing ones with a known source; "Unknown source" shows the rest),
  favourites (right click; per account), a 3D preview (`SetCreature`, else the model file), Show Character, Mount /
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
`ui.classicmicro`, `ui.classicmenu`, `ui.tooltipids`).

- **Character panel** ([`TemucraftCharacter.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftCharacter.lua), C, `/tchar`, `/tchar classic|new`):
  the stock item slots (they move into the window while it is open, so clicking, Alt flyouts and the equipment manager
  work as always) down both sides and the weapons at the bottom, a bigger model on the race's backdrop (drag to turn,
  wheel to zoom), a Titles menu, and on the right the item level (average of the 17 slots, a two-hander counts twice)
  and the stats: Attributes, Enhancements (by role: melee, ranged or caster; hybrids by their main talent tree) and
  Defense. Tabs Character / Pet / Reputation / Currency; the last three open the stock frame on that tab.
- **Micro menu** ([`TemucraftMicroMenu.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftMicroMenu.lua)): a row at the bottom right (smaller
  if need be, or above the main bar when there's no room beside it): Character, Spellbook & Talents (right click:
  talents), Achievements, Quest Log, Guild (right click: friends), Group Finder (right click: PvP), Collections, Shop,
  Game Menu (latency / memory tooltip), Help. Each calls what its stock button calls and copies its stock button's
  state (pushed, disabled below its level); the stock buttons are hidden, and come back on vehicle bars.
- **Game menu** ([`TemucraftGameMenu.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftGameMenu.lua)): the stock GameMenuFrame laid out again:
  Options (opens System / Sound / Interface / Key Bindings under it), Shop, What's New (`TemucraftChangelog.lua`:
  add a block with each release), AddOns, Edit Mode (placeholder), Support (the stock help / ticket frame), Macros,
  Log Out, Exit Game, Return to Game. Shop is a placeholder until a shop window defines `TemucraftShop_Show`.
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

Tests of the grouping, search, paging, collection and loadout logic, and of the player UI logic:
`lua5.1 client/tests/spellbook_test.lua`, `lua5.1 client/tests/collections_test.lua` and
`lua5.1 client/tests/interface_test.lua` (from the module folder).

## Also in this module

These were separate modules; they now live here, each with its own folder under `src/`, its own config file in
`conf/` (same file and key names as before) and its notes under `docs/`. Their SQL files kept their names, so nothing
is applied twice. Remove the old module folders from `modules/` before building.

| Was | What | Code | Notes |
|---|---|---|---|
| mod-temucraft-spellbook | spellbook tabs | `src/spellbook` | [docs/spellbook.md](docs/spellbook.md) |
