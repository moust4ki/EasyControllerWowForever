# Roadmap

Everything planned for Easy Controller - Forever, so nothing gets lost. Each feature is built, tested
in game, then released on GitHub and CurseForge. Done items move to the [CHANGELOG](CHANGELOG.md)
(1.2.0: vibrations, supplies, consumables wheel; 1.2.1: the game's gamepad functions anywhere, its
buttons replaceable; 1.3.0: your own wheels, every button remappable from the start; 1.4.0: the new
configuration panel; 1.4.1: better items in the bags, selling and repairing at merchants).

## 1.2.1: the game's own gamepad functions, on any button

How WoW Forever does it: jump, back (stop casting / targeting, clear the target), interact and
inspect are the four fixed buttons of the gamepad bar's top layer (A, B, X, Y alone), with their
function built in; the Start menu, interface focus, ping, ally / enemy targeting and the left /
right bars are the game's own key bindings, which it sets again whenever one of its gamepad windows
closes.

- [x] **Move a game function to another button** (a back paddle, L3, a free combination...): the
  Gamepad tab's Game list gets a "gamepad functions" section. The four fixed ones press the game's
  own button (its behaviour exactly: the smart interact, jump and sit...); the others are the
  game's own bindings.
- [x] **Put something else on a button the game uses** (A, B, X, Y alone, the D-pad, LB / RB alone,
  Start, Select, L3 / R3); since 1.3.0 open to all, with a Restore button in the Gamepad tab: a
  priority binding of ours over the game's, taken away while one of its gamepad windows has the focus (so its menus keep
  A / B), and set again when it closes. LT and RT become modifiers (a key per layer); the other
  layers of a replaced button are bound to what the game does there. Checked in game; still to
  watch: a menu opened in combat (bindings can't change then), `/ec binds`.

## 1.3.0: your own wheels

- [x] **Wheels of your own, like the consumables wheel** (1.3.0), each filled with the spells, items and
  macros you choose, and opened by a shortcut:
  - same look and handling as the consumables wheel: the left stick points, A uses, B cancels,
    LB / RB turn the pages, usable in combat;
  - created, named, filled and reordered from the configuration panel with the gamepad, from the
    same lists as the Gamepad tab (spells, items, macros); several wheels;
  - each wheel's shortcut: any free button, a back paddle, a game button replaced, or a key binding
    of the game (its Key Bindings menu);
  - limit: what a wheel holds can only change out of combat (the game locks secure buttons in
    combat).

## 1.4.1: automation at merchants

Both turned on or off in a new Home › Automation section (under Look).

- [x] **Auto-sell junk**: at a merchant, the grey (poor quality) items of the bags are sold by
  themselves; a line in the chat says how much they brought.
- [x] **Auto-repair**: at a merchant who repairs, the equipment is repaired by itself; a line in the
  chat says what it cost (or that the money was short). With the guild's money first, as an option.

## 1.4.1: inventory, better items

A new Alerts › Inventory section.

- [x] **Upgrades in the bags**: a green up arrow at the bottom right of an item that would be better
  than what is equipped in its slot.
  - What the client gives: the item level (`C_Item.GetDetailedItemLevelInfo`, or `GetItemInfo`'s
    fourth value), the item's slot (`itemEquipLoc`), the equipped items (`GetInventoryItemLink`), the
    items that fit a slot (`GetInventoryItemsForSlot`, what the game's own new player tips use), and
    the game's own green arrow picture (atlas `bags-greenarrow`). The game itself never computes
    "better" in WoW Forever: its equipment flyout leaves it empty.
  - "Better": a higher item level for the same slot (rings, trinkets and one-hand weapons against the
    weaker of the two), only for what the character can wear (armor type, weapons, level, class).
    Chosen: a score from the item's stats weighed for the class (and a hybrid's talent tree), the
    class's armor type (or the type already worn in that slot); the item level when no stats.

## Set aside

- **Tap / hold on the D-pad and A / B / X / Y** (asked 2026-11-11): a tap casts the slot's spell, a
  button held casts another. Blocked: the game's secure code (the only one that casts in combat)
  has no clock (no GetTime in its restricted environment, no timer), and the addon can't hand it
  one in combat (an unprotected frame can't be read there, a protected one can't be written). The
  state driver manager's 0.2 s ticks are too coarse to tell a tap from a hold. To look at again if
  the game adds a press-and-hold for any spell (today only its empowered spells,
  `IsPressHoldReleaseSpell`).
- **Chat keyboard, writing in the chat box**: let the game send the message natively when the text
  is unchanged. Writing in the game's chat box can block its gamepad UI and freeze the client; the
  secure macro sending stays.

## By hand on CurseForge (no API for these)

- [x] Rename the project to "Easy Controller - Forever".
- [ ] Paste [docs/curseforge.md](docs/curseforge.md) as the description, the one-line summary, and
  [docs/icon.png](docs/icon.png) as the logo.
