# Changelog

## 1.11.9

Fixes contributed by rampagingrhinoceros (thanks!):

- **Learned words**: past the limit (8000 by default), only the excess is forgotten, the least
  used first. Before, every word seen only once was erased at once, a large part of what was learned.
- **Next-word suggestions**: the filler words ("and", "the"...) follow the chosen language; they
  were French for every language.
- **Upgrade arrows**: an equipped item the game hasn't loaded yet is no longer taken for an empty
  slot (wrong "upgrade" arrows); the comparison waits for it.
- **Vibrations**: an important one (death, loss of control) is no longer cut by the small
  vibration of a key or a wheel.

## 1.11.8

- **Red when out of range**: drawn as a red veil of the addon's own over the game's gamepad bar
  buttons, which are no longer hooked at all (reported: a Lua error, "attempt to call a nil value"
  in ActionButton.lua, when the game refreshed its bar with its taint log on).

## 1.11.7

- **Macros**: the keyboard no longer opens in the macro window, nor in any field of several lines
  (reported: macros could not be edited, and were saved on one line, "/startattack /cast ..."
  running nothing but /startattack). Those fields are typed on a physical keyboard as before.
- **Red when out of range**, off (the default): the game's bar buttons are no longer touched at all;
  they are only hooked once the option is turned on.
- **Profiles with WoW Forever's surnames** (reported: a bind removed on the warlock was gone on the
  shaman too): characters are named with a first name and a surname there ("Fraicheur Rog",
  "Fraicheur Hunt"), and the profiles were kept by the first name alone, so every character sharing
  a first name shared one. They are kept by the full name now. At its first login after the update,
  each character starts from a copy of the profile it shared, so nothing is lost, then they are
  apart. Realms without surnames: no change.

## 1.11.6

- **/ec profile**: the character recognised and whether its settings are its own, what each
  character holds (buttons, game buttons replaced, wheels), and a reminder that the slots of the
  game's gamepad bar (D-pad, A / B / X / Y) are saved by the game, outside the profiles.
- **A character not known when the addon loaded** (its name or realm not given yet) gets its own
  settings once the world is loaded, instead of the ones common to every character.

## 1.11.5

- **Macros work again with the addon on** (reported: a macro with /startattack and /cast did
  nothing while the addon was on, from its buttons or the game's bar). Choosing a channel on the
  keyboard wrote it into the game's chat box, as its own sticky channel; the game copies that box's
  channel into the one that runs every macro line, and a value an addon wrote there taints the
  macro: the game then blocks its /cast, /startattack... The keyboard now keeps the chosen channel
  itself (Keyboard › Messages › Channel sticks) and never writes into the game's chat. A channel
  chosen in the game's chat since (a /p typed on a keyboard) wins. A /reload clears a session
  already affected.

## 1.11.4

- **Stay seated while eating** (Wheels › Consumables, on by default, reported: food picked from a
  wheel with the left stick, the stick still pushed when it closed, and the character walked off,
  the meal wasted): while you eat or drink, a stick nudged doesn't stand you up; push the left stick
  all the way for half a second to get up. The camera stays still too while you eat. Never in
  combat.
- **Supplies buttons**: their tooltip says they are Easy Controller's, and where to set or hide them
  (Alerts › Supplies, with the panel's shortcut): players didn't know what the buttons over the bars
  were.

## 1.11.3

- **L3 / R3 trigger layers, LT + RB and RT + LB** (reported: a spell on LT + L3 never ran; LT + RB
  neither): while the button alone keeps the game's function (L3: autorun, R3: ping, LB / RB:
  targeting), the game takes its trigger layers too, the controller sending the button without the
  trigger (checked in game). Those layers are now shown unavailable, with why and what to do. Put a
  spell, a wheel or **Nothing** (new, first in the Game list) on the button alone, and its trigger
  layers work, read with the triggers held. What was already on them is kept and works once the
  button alone is freed. LT + LB and RT + RB stay the game's class actions.

## 1.11.2

- **Profiles are automatic**: each character keeps its own buttons, paddles, wheels and supplies,
  with no option any more (no Profiles tab, no shared settings, no copy, no start from scratch).
  Reported: start from scratch on an alt erased every character's settings. Two causes found and
  fixed: a character on the shared settings changed the configuration new characters start from,
  and an error at logout could save a character's settings in its place. A character left on the
  shared settings keeps what it used, as its own. A character is also found again when the game gives
  its realm name late at login.
- **Start and Select stay the game's** (its radial menu, the interface's focus): they can no longer
  be changed or replaced, in any layer (reported: a spell put on RT + Start never ran). What an older
  version saved on them is removed, and the chat says once what was there, to put it on another
  button. L3 and R3 stay free.

## 1.11.1

- **Stealth, forms and stances**: in a stance, the game's stance bar takes the place of one of the
  gamepad bars (its gamepad settings, Stance bar) with slots of its own. The Gamepad tab now shows and
  sets that bar's slots while you are in the stance (reported: in stealth it couldn't be set). And a
  layer left to the game on a replaced button (or a game bar button chosen for a free button or a
  paddle) pressed the hidden bar's button: RT + a button ran the spell from outside stealth. It now
  presses the stance bar's in a stance, in combat too. Characters with no stance or form keep their
  bindings as they were.

## 1.11.0

- **The keyboard in the game's other fields** (requested on CurseForge): it also opens when a field of
  the game gets the focus, like the Auction House search, the bags' search, mail or notes (Keyboard ›
  Opening, on by default). What you type goes into the field; A is Enter there (the Auction House
  searches), B closes the keyboard and leaves the field, what you typed kept. A field for numbers
  opens on the numbers. Never for the chat (it keeps its own keyboard), password fields, the game's
  confirmation popups, settings and key bindings, nor in combat.
- **Supplies**: a character without ammo no longer gets a row named "item:0" (WoW Forever answers 0
  for an empty ammo slot).

## 1.10.0

- **Hold to show a wheel** (Wheels › Opening, off by default, requested on CurseForge): hold a
  wheel's button to show it, aim with the left stick, let go to use what it aims at; the stick in the
  middle closes it without using anything. A still uses while it is held. Every wheel, on any button
  or paddle, in combat too. With Triggers: press to switch on and a bar switched on, the wheel opens
  on a press as before.
- **Each layer of a button runs its own, wheels too** (reported on CurseForge): a wheel on a button
  opened in every layer (the consumables wheel on D-pad down opened with RT held too, the game's
  RT + D-pad down lost), and a wheel on a trigger layer (LT + D-pad down) never opened, the button's
  own function ran instead. The key could reach the addon without the trigger's modifier. The
  gamepad's buttons with something of yours on them (spells, items, macros, wheels, replaced
  buttons) now read the triggers held when pressed, like the back paddles since 1.8.2: each layer
  runs what you put there, else the game's bar button of that layer. A button with a game function
  on one of its layers keeps working as before.
- **The character and the camera back right after a wheel** (reported on CurseForge): closing a
  wheel with a stick still pushed kept the sticks up to 6 seconds, while any stick read as pushed
  (keep pushing to walk on, or a stick that never reads as let go). Now only the stick that aims the
  wheel counts, and only for a moment (0.4 s at most), so the character doesn't walk off.
- **/ec config typed in the chat** opens the panel at once: it waited for a game window that was
  only shown (the gamepad on the character) to close.
- **A saved file with broken entries** no longer stops the addon: a button, a supplies entry, an
  item added, a wheel or a wheel's slot that the addon can't read is left out at load and when a
  character's profile is put in use; the good ones are kept. Another character's broken profile is
  left out of the Profiles tab.

## 1.9.0

- **Profiles** (a new tab, issue #4): each character has its own buttons and paddles, its own wheels,
  supplies and consumables wheel categories. On first load, every character starts from a copy of the
  configuration, so nothing is lost and a player with one character sees no change. The Profiles tab
  sets a character on its own settings or on the shared ones, copies another character's, or starts
  from scratch. The paddles' keys, the look, the keyboard and the vibrations stay the same for all.
- **LT + RB and RT + LB in the Gamepad tab** (issue #5): in 1.8.2 their cells still showed
  "Unavailable"; they now open on A like the other cells.

### Also since 1.8.0 (1.8.1 and 1.8.2)

- **Triggers: press to switch** (Home › Gamepad, off by default): LT pressed alone keeps the left bar
  on, pressed again back to the top bar; same for RT; LT then RT: the bottom bar. Holding still works.
  Needs the game's compact action bar.
- **Back paddle layers with Steam Input** (Steam Deck, Steam Controller): each trigger layer of a
  paddle sent as a keyboard key now runs its own action.
- **Trigger layers kept apart**: an action on one layer of a button no longer runs on its other layers.
- **Spells cast by name**, with the rank you chose: Ghost Wolf and the shapeshift forms now cast from
  buttons, paddles and wheels.
- **LT + RB and RT + LB** can take a spell, an item, a macro or a wheel. LT + LB and RT + RB stay the
  game's class and pet actions.
- **Aggro lost vibration** for tanks (off by default). No critical hit vibration: WoW Forever keeps the
  combat log to its own UI.
- **The panel's shortcut alone**: RB + D-pad down no longer also runs what you put on D-pad down.
- `/ec keys` shows the modifiers and triggers held with each key; `/ec fish` lists the game's events
  for a minute.
- **Fixes**: the merchant's sale total counts grey items whose price wasn't loaded yet; greyed rows at
  the end of a section scroll into view; the vibration rows' help bar shows the D-pad first; an old
  saved tab name reopens on its section; the panel no longer redraws itself once closed.

## 1.8.2

- **Back paddle layers with Steam Input** (issue #3): with the paddles sent as keyboard keys (Steam
  Controller, Steam Deck), the key could reach the game without the triggers' modifiers, and every
  layer ran the paddle's "alone" action. Each paddle now has one secure button for its four layers,
  bound to its key with every modifier: the layer comes from the triggers held (the gamepad's state),
  or the modifier in the key, or the modifier held. A layer with nothing does nothing.
- **Spells cast by name** (issue #2): some spells (Ghost Wolf, shapeshift forms) didn't cast from a
  button or a wheel, while a macro did. Spells now cast by their name, with the rank you chose.
- `/ec keys` shows the modifiers and triggers the game sees held with each key.
- **LT + RB and RT + LB** can take an action (issue #5): the game leaves them to its targeting. LT + LB
  and RT + RB stay the game's class actions.
- **Vibrations**: **Aggro lost** (tanks, issue #6): a mob you held goes for someone else, in combat
  (not when it dies or the fight ends; at most every 3 s; off by default). No critical hit vibration
  (issue #7): WoW Forever keeps the combat log to the Blizzard UI, an addon reading it is blocked.
- `/ec fish` lists the game's events for a minute: to find which one tells a fish bites (issue #8).
- **Triggers: press to switch** (Home › Gamepad, off by default, issue #1): no need to hold a trigger
  any more. LT pressed alone keeps the left bar on (A, B, X, Y and the D-pad use it), pressed again
  back to the top bar; same for RT; LT then RT: the bottom bar. Holding a trigger with a button still
  works as before. The paddles, L3 / R3 and the extra buttons follow the bar on. Needs the game's
  compact action bar: the bar switched on shows in place of the top bar. Back to the top bar after
  combat (option, on). Off, nothing changes.
- **Fixes**: at merchants, the chat line counts a grey item whose price wasn't loaded yet (it says
  what the merchant paid); a section whose last rows are greyed (a module off) scrolls to show them;
  the vibration rows' help bar shows the D-pad first, like every other row; an old saved tab name
  reopens on its section; the panel no longer redraws itself after it closed.

## 1.8.1

- **Trigger layers kept apart**: a function on a button in one layer only (a wheel on L3, a spell on
  a paddle...) no longer runs in its other layers too. The game ran a key with LT / RT held that had
  nothing of its own as the key without them; those layers now do nothing, unless the game has its own
  function there.
- **The panel's shortcut alone**: with something of yours on D-pad down (a wheel...), RB + D-pad down
  opened it together with the configuration panel. While RB is held, out of combat, D-pad down is
  left to the game, and comes back on release.

## 1.8.0

- **Extra buttons** (Home › Gamepad): up to 8 more buttons, 4 a side, for both controllers with
  more buttons (Vader Pro...) and touchpads set as buttons (Steam Deck, Steam Controller). Make each
  button send a keyboard key in Steam Input (F17 to F24 for example), turn on the ones you use, one by
  one, then Identify paddles learns their keys. They work like the back paddles: the four trigger
  layers, spells, items, macros, game functions, shown next to the gamepad bar. The Gamepad tab lists
  them under the controller.
- **Free placement** of the extra buttons (Home › Gamepad): anywhere, a few pixels at a time with
  the D-pad or dragged with the mouse, instead of the fixed places.
- **Red when out of range** (Home › Gamepad): the whole spell turns red on the gamepad bar and the
  extra buttons when the target is too far (or too close for a hunter), not only the game's small dot.
- "Place bar" is now **Move buttons**, and the Gamepad tab's Display options are in **Home › Gamepad**,
  with the Gamepad extras switch at the top (it turns on the functions on the free buttons, paddles
  and extra buttons; the options that need it are greyed while it is off).
- **Keyboard suggestions** are never cut with "...": each one is as wide as its word, and the ones
  that don't fit whole are left out (the daisywheel's row is narrow).

## 1.7.0

- **OLED screens** (Home › Look › Centre dot): the gamepad UI's dot in the middle of the screen, always
  lit at the same place, can burn into an OLED screen. Keep the game's white dot, give it a colour
  (amber, cyan, red, green, magenta, blue, grey, black), let it change colour every 5 minutes, or hide
  the reticle completely.
- **Nintendo Switch button glyphs** (Home › Look › Button glyphs), with the game's own Switch icons:
  B at the bottom, A on the right, L / R, ZL / ZR, + and -.

## 1.6.2

- **Consumables wheel**: raw fish and the other trade goods the game lets you eat or drink now
  show with the food and drinks.

## 1.6.1

Fixes found by a second round of end-to-end tests.

- **Wheels**: the mouse clicks the item drawn even when the bags change with the wheel open; a tick
  when the item under a held stick changes page; bandages in your own wheels go on you; your replaced
  buttons come back after a wheel closes.
- **Chat keyboard**: a quest link can no longer become a whisper's recipient; a whisper's draft never
  comes back on a public channel, nor a message typed with the mouse for someone else; the "!" chip
  keeps your channel when reached with the mouse too; a warning when the new textures need a restart.
- **Split keyboard**: the gold flash on the key typed always shows.
- **Configuration panel**: holding a direction into a list no longer changes its first setting;
  Escape cancels the paddles' wizard; a captured button held long no longer acts on its release;
  the size steps from a custom scale no longer go the wrong way; the help bar offers A only where it
  acts.
- **Better items**: no arrow on an item scoring lower than yours.
- **Supplies**: the bar no longer moves after an update or when its direction changes; the reagent
  bag's items can be added.
- **Quest items and merchants**: leaving a merchant is always noted; turned back on, quest items read
  the quest log again; the repair waits for items still being sold.
- Shorter labels ("Daisywheel look" translated, German Shift).

## 1.6.0

- **A new look for the chat keyboard** (Claude Design), in the style of the wheels and the game's
  radial menu: a dark window with a bronze edge, dark rows, copper pills for the chosen word, channel
  and mode.
- **Daisywheel**: drawn on the 8-section wheel; the petal picked with the left stick lights up in
  copper and the others dim, a gold pastille marks the character aimed with the right stick, which
  the centre shows in large. New option (Keyboard › Input › Daisywheel look): **groups circled** (a
  ring around each group of 4 characters) or **characters only**.
- **Split keyboard**: new keys, columns aligned across all rows (Shift and 123 one key wide, Backspace
  two, Space across both halves), the left target in copper and the right one in amber, a short
  flash on the key typed with LT / RT, a divider between the halves, new cursors.
- **Quests chip**: moving along the channel row to the "!" no longer leaves you on the last channel
  passed; the channel you were on comes back, and the quest link goes there.

## 1.5.0

- **Wheels that fit what they hold** (Claude Design): the consumables wheel and your own wheels are cut
  in as many sections as the page holds, from 1 to 8: two items, two halves; five items, five
  sections. Same look as the game's radial menu: the aimed section lights up, what can't be used now
  is veiled, each name sits beside its icon in the game's font, the banner right under the wheel.
  Your own wheels show their filled slots only, in their order. Works in combat as before.

## 1.4.2

Fixes found by end-to-end tests of the whole addon.

- **Chat keyboard**: a command typed while on a whisper (/g, /dance...) is run, never whispered to the
  person; Enter on an empty chat box no longer wipes the message typed with the pad; Battle.net
  whispers are sent; text typed on a physical keyboard and sent with A is not taken again; B always
  empties the message; LT then RT typed quickly no longer loses a letter; /ec in the chat opens the
  keyboard with the IM chat style; /r works without the game's deprecated functions; a draft only
  comes back in a whisper to the same person; the combat message follows the keyboard's settings.
- **Wheels**: no more vibration while a wheel is closed; A always uses the item drawn, even when the
  bags change with the wheel open; the wheels work after a /reload in combat; two wheel keys held
  together no longer close the wheel; food and drink greyed in combat in your own wheels too; a
  wheel's name is cut at 40 letters, never inside one; editor fixes (Delete disarmed by the mouse, A
  on a slot opens its list on what it holds).
- **Configuration panel**: closing the panel or entering combat while placing something no longer
  breaks the panel's shortcut; B while placing the supplies or the wheel puts them back, A saves;
  the panel reopens on the last tab after a reload; a held direction never repeats forever; lists
  scroll back when they shrink; a single list has no tab row; the shortcut's buttons, still held
  after it is learned, no longer act on the panel.
- **Gamepad**: two paddles can no longer end up on the same key (they swap); LB / RB given their own
  function back while the panel is open; X and B work while a paddle is awaited; the help bar only
  offers what works; B while moving an extra button puts every button back.
- **Bindings**: replaced buttons no longer take the chat keyboard's or an open wheel's keys.
- **Better items**: arrows in the reagent bag; a one-hand weapon compared with the weapon only when
  you carry a shield; plain armor and empty slots judged by item level; the status says when the
  game gives no stats.
- **At merchants**: the repair waits for the grey items' money; never in combat; bags excluded from
  junk selling are left alone; quest items stay protected with their module off.
- **Supplies**: the bar grows from its first button; an unticked resource no longer vibrates.
- **Quest items**: borders in the reagent bag; turned off, they go at once.
- A damaged saved settings file no longer stops the addon; help texts brought up to date.

## 1.4.1

- **Better items** (Alerts › Inventory, on): a green arrow at the bottom right of a bag item better
  than what you wear in its slot. Items are compared by their stats, weighed for your class: a
  weapon's damage per second first, then strength, agility, stamina, intellect, spirit, attack and
  spell power, armor (a hybrid by the talent tree with the most points: a holy paladin weighs
  intellect and healing, a protection one stamina and armor); the side panel shows your weights. Only
  for what you can use, of your class's armor type (or the type you already wear there). Rings,
  trinkets and one-hand weapons are compared with the weaker of the two, a two-hand weapon with both
  hands.
- **At merchants** (Home › Automation, off until you turn them on): **sell grey items**, one after the
  other, with a line in the chat saying what they brought (quest items never sold); **repair**, once
  the grey items are sold, with a line saying what it cost; **with the guild's money** first, as an
  option, when the guild allows it.

## 1.4.0

- **A new configuration panel** (Claude Design). Five tabs: Home, Gamepad, Wheels, Keyboard and
  Alerts. In each, its sections on the left, their settings in the middle, and on the right what the
  selected one does; short labels, the long explanations in that side panel. The help bar at the
  bottom shows where you are and only the buttons that work there (they can be clicked). LB / RB
  change tabs, B goes back to the sections then closes; the panel reopens on the tab and section you
  left. Forget learned words, Restore the game's buttons and Delete a wheel ask a second A (B, a move
  or 4 seconds cancel). Short messages confirm what was done.
- **Home**: every module with its state (input method, "N yours", "N tracked", "N events"), Y on one
  jumps to its settings; the panel's shortcut; button glyphs, game icons and font.
- **Gamepad**: your controller drawn over an Xbox controller, its 20 buttons where they are, each with
  what it does in the layer shown (alone, LT, RT, LT + RT) and one of five states: the game's function,
  a slot of the game's bar (gold ring), yours (cyan ring), free, unavailable (striped, with the reason).
  The D-pad's slots are square, like the game's gamepad bar. The D-pad goes from button to button, up
  to the layers, down to the actions; A opens the lists on the right (Game, Spells, Items with the
  wheels first, Macros, Bar); X gives the button back, empties the slot or removes yours; Y learns a
  paddle's key again. Under the controller: **Identify paddles** (the steps in the right panel, X skips
  one), **Place bar**, **Display** (extra buttons next to the bar, L3 / R3, their names, RT as a
  modifier) and **Restore (N)**.
- **Wheels**: your wheels as cards, New wheel first, each showing its 8 slots, its name and the button
  it is on. Its editor: the wheel with its slots around it, the lists always on the right; a choice
  fills the slot aimed at and goes on to the next one, with a cyan diamond on what is already in the
  wheel. Rename in a box over the wheel; **Assign a button** takes you to the Gamepad tab, where the
  button you pick gets the wheel. The consumables wheel and the wheels' position have their own
  sections.
- **Keyboard**: opening, input, sticks (the dead zone is a slider), prediction, position.
- **Alerts**: vibrations (each event: A turns it on or off, the D-pad picks its pattern, Y tests it,
  the intensity is a slider), supplies (items added from your bags with the lists), quest items.

## 1.3.0

- **Your own wheels** (Wheels tab, formerly Wheel): up to 8 wheels of your own, 8 slots each, filled
  with the spells, items and macros you choose, in an editor of their own: the wheel drawn with its
  slots around it, the chosen slot's list beside it (Spells / Items / Macros); a choice fills the slot
  and goes on to the next one. Named with the addon's keyboard or a physical one. They look and work
  like the consumables wheel, in combat too, and each one gets a key: Gamepad tab, Items list (any
  free button, a paddle), or the game's Key Bindings. Deleting a wheel takes it off its buttons.
- **Every button remappable from the start.** The game's buttons switch is gone: A, B, X, Y, the D-pad,
  LB / RB, Start and Select take any function right away. In its place, **Restore the game's
  buttons (N)** (A, then A again) gives every replaced button back to the game, and only those: the
  game's slots, free buttons, paddles and wheels keep what you put there.
- **Vibrations**: low health and big hit removed. WoW Forever hides your health from addons in combat,
  so they could never work there.

## 1.2.1

- **The game's own gamepad functions on any free button.** The Gamepad tab's Game list starts with
  them: jump, back, interact and inspect (the game's fixed A / B / X / Y buttons, pressed from the
  other button: their exact behaviour, the smart interact included), the Start menu, interface
  focus, ping, and ally / enemy targeting (held). Put jump on a back paddle, the Start menu on
  LT + L3...
- **Replace the game's own buttons (optional, off by default).** A switch at the top right of the
  Gamepad tab: "Game's buttons: left alone / replaceable". Turned on, A, B, X, Y, the D-pad, LB / RB
  (alone), Start and Select take any function, in any layer: a slot of the gamepad bar still takes a
  spell, an item or a macro in the slot; anything else replaces the button, with its picture over
  the game's, and X gives the button back (with what its slot held). The game's menus keep their
  buttons; LT and RT become modifiers so that each layer has a key of its own. Turned off again,
  every replaced button gets the game's default binding back (the game's slots, free buttons and
  paddles keep theirs). `/ec binds` shows the replaced keys.
  Ping put on a button is held to open the wheel and released to send: the game's own gamepad ping
  waits for its key to be pressed again, and a key changed meanwhile left its listener over the
  screen, every A in a menu becoming a ping.
- **Consumables wheel**: after a reload, the banner under the wheel was empty on its first opening.

## 1.2.0

- **Vibrations** (new tab). The controller vibrates on the events you choose: one switch and one
  intensity, then each event with its own pattern (micro tick, tick, double tick, pulse, long,
  heartbeat, crescendo) or Off, picked with the D-pad; A tests it, X turns it on or off.
  - Combat: death, your spell interrupted (by someone, not by moving), loss of control, aggro,
    entering combat, spell proc, action impossible. Low health and big hit are listed as
    unavailable when WoW Forever hides your health from addons in combat.
  - Social: whisper, group or raid invite, ready check, resurrection or summon, trade or duel.
  - Progress: level up, quest objective or quest complete, rare loot, bags full, gear almost broken.
  - Easy Controller: low supplies, little room in the bags, the wheel's slots, chat keyboard keys.
  - `/ec vibe` shows what the client allows and plays a pattern.
- **Supplies** (new tab). A round button per resource, in the gamepad bar's style: free bag slots
  (special bags apart), the equipped ammunition, the class reagents once carried (soul shards,
  powders, candles, symbols, seeds, poisons...) and any item added from your bags. Each shows its
  count and glows under its low threshold, bigger and redder down to the critical one; thresholds
  are set with the D-pad, each resource can be turned off. The bar is placed freely (dragged with
  the mouse while unlocked, or moved with the D-pad), grows right, left, down or up, in 3 sizes. A
  click opens the bags, through the game's own backpack button.
- **Consumables wheel** (new tab). A key of its own (Gamepad tab, Items list: any free button, or a
  back paddle in any layer; or the game's key bindings) opens a wheel drawn with the game's own
  radial menu art: food, drink, healing and mana potions, healthstone, mana gem, bandages (used on
  yourself), buff food, elixirs and flasks, scrolls from your bags, the best of each kind first,
  8 a page (LB / RB turn the pages, up to 3).
  - Point at an item with the left stick and press A to use it; the stick back in the middle points
    at nothing; B cancels. The right stick stays the game's, for its own spell wheels. The mouse
    works too.
  - While it is open, and after it closes until you let the stick go, the sticks don't move the
    character or the camera: eating isn't cut short.
  - It works in combat (food and drink greyed there); its content is updated out of combat. Items
    above your level are left out. No game setting is changed.
  - `/ec wheel` lists what it holds, and why an item of your bags is not in it.
- The configuration panel's tabs share the room for the new ones, and the panel can be dragged
  anywhere with the mouse.
- New icon, in the game's addon list too.

## 1.1.1

- Mapping window: the gamepad bar slots that hold a flyout (hunter aspects, tracking, pets) or
  anything else than a spell, an item or a macro show its name instead of "empty".
- The actions the game won't take off its gamepad bars (hunter aspects, pet actions while the pet
  has its bar) can no longer be replaced or cleared from the mapping window: it shows the game's own
  message, like its action bar editor.
- With a list open, the side panel no longer writes over the list's tabs.

## 1.1.0

- The addon's folder and package are now **EasyController** (were ControllerKeyboard). Settings saved
  under the old name stay in `WTF/.../SavedVariables/ControllerKeyboard.lua`: copy that file to
  `EasyController.lua` (game closed) to keep them. Remove the old `ControllerKeyboard` folder.
- `/ec` is the command (also `/easycontroller`; `/ck` still works).
- **Back paddles in every trigger layer.** L4 / R4 / L5 / R5 take a spell, an item or a macro in the
  RT and LT + RT layers too, without RT being a modifier: the paddle's key goes to a secure button
  that reads the triggers when it is pressed (the game lets secure code read the gamepad) and runs
  that layer's action. Game functions (key bindings) still need a key of their own: with "RT acts as
  a modifier" on, every layer has one. A game function on a paddle alone takes the key in the
  layers that share it; the mapping window says so.
- **Quest items: a border instead of the glow.** The items a quest asks to collect (meat, cloth...),
  which the game doesn't mark, get the game's own quest item border in orange; the pulsing glow is
  gone, and items the game already marks are left alone. Their tooltip line names the quest.

## 1.0.0

The addon is now **Easy Controller - Forever** (formerly Controller Keyboard): the name players see changes, the
addon's folder and all settings stay the same. `/ec` works as well as `/ck`.

### Configuration panel

- The addon has its own configuration panel, driven with the gamepad or the mouse: **RB + D-pad down**
  (only watched, never bound, so the game's buttons stay as they are; any other pair can be learned
  in the General tab: hold a button, press a second one), `/ck config`, or its key binding. Tabs **General**,
  **Keyboard** and **Gamepad** (LB / RB), D-pad to move and change values, A to choose, B to close.
  The game's options only point to it.
- The addon is a set of modules, and every function can be turned on or off in the General tab:
  keyboard (auto-open, quest links, Shift+click links, drafts, sticky channel), quest items (tooltip
  line, sale warning, merchant selection warning), gamepad mapping (extra buttons on screen), the
  RB + D-pad down shortcut.

### Gamepad mapping

- The Gamepad tab (`/ck map`) shows the whole controller in its four trigger layers (alone, LT, RT,
  LT + RT). Holding LT / RT shows their layer.
- WoW Forever's gamepad UI is never changed: the buttons the game uses are shown with what they do
  and their icon (jump, interact, back, inspect, targeting, Start menu...) and left as they are.
- The gamepad bar's own slots (D-pad and A / B / X / Y in the four layers, but the fixed jump /
  interact / back / inspect) take a spell, an item or a macro from the same window, placed in the
  game's slot like its own action bar editor does (X empties it).
- The free inputs get the missing functions: L3 / R3, trigger combinations nothing is bound to
  (LT + Start...) and the back paddles. Each one can run a game function (run / walk, autorun, game
  menu, map, bags, any key binding of the game, listed by its own categories), a spell, an item, a
  macro, or press a button of the gamepad action bar.
- Back paddles (L4 / R4 / L5 / R5, Steam Deck and others): set each paddle to a keyboard key in Steam
  Input (F13 to F16 for example), then "Identify the back paddles" asks for each paddle in turn (B
  skips one). Controllers whose paddles the game sees directly (PADPADDLE1-4) work as they are.
- The extra buttons that do something (back paddles, L3, R3) are shown around the gamepad action bar,
  in its round slot style, with the action's icon (zoomed like the game's), count, cooldown and
  usability; they show the held trigger layer's action, and press down like the game's buttons.
  Their name (R4...) shows on the outer side (left / right, or up / down following each button's
  place), above, below, left, right, or not at all (option).
  L3 / R3 can be shown too, with what the game does with them (autorun, ping...) or what you put on
  them. Spells are listed and shown with their rank.
- "Place the bar and extra buttons": the game's gamepad bar moves by steps with the D-pad (only its
  place on the screen, out of combat; X puts it back), the extra buttons following it; each extra
  button goes on one of the fixed places around the bar's controls
  (outer columns, two rows above, two below): the D-pad chooses the bar or a button, A picks it up,
  the D-pad moves it (taken places swap), A puts it down, B puts it back; or by clicking; the right side mirrors the left (Y turns it off). Places follow the compact layout.
- Game functions and the game's own L3 / R3 actions use interface icons (ping markers, the gamepad
  jump icon), never spell icons.
- When RT is no modifier in the game's gamepad settings (the RT and LT + RT layers then don't exist
  for the extra buttons), an option makes it one (Alt, or Ctrl), like LT already sends Shift.
- Bindings are set out of combat, only on inputs the game leaves free, and set again when one of the
  game's gamepad windows closes. `/ck keys` lists the keys the game receives and which pad buttons
  act as Shift / Ctrl / Alt.

### Quest items

- Item tooltips show an orange "Quest item: do not sell" line on quest items, including the items a
  quest asks to collect (cloth, ore, meat...), which the game does not mark; in the bags they also get
  a slowly pulsing orange glow (the game's own bag glow).
- Selling one to a merchant shows a warning with a reminder of the Buyback tab. At a merchant, with
  the gamepad bag tooltips turned off, selecting a quest item shows the warning too.

### Quest links and drafts

- The channel row ends with a "Quests" chip: it turns the suggestions row into the list of your
  quests, the right stick click inserts the quest link.
- Links inserted with Shift+click or the game's "Share in chat" go into the keyboard's message.
- When the game closes the chat (a panel opens, combat), the message is kept as a draft and comes back
  with the chat: type "LFM", open the quest log, "Share in chat", and the keyboard holds
  "LFM [quest]". Backspace deletes a link as a whole.

### Fixes

- Sending with Enter on a physical keyboard now always empties the keyboard's copy of the message
  (the game no longer calls the old `ChatEdit_SendText`).

## 0.4.2

- German, Spanish and Italian: dictionaries (12,000 words each), keyboard layouts for the split
  keyboard (QWERTZ with ö ä ü ß, Spanish QWERTY with ñ, Italian QWERTY), and the accents of the 123
  layer follow the language (ä ö ü ß / á é í ó ú ñ ¿ ¡ / à è é ì ò ù). A single language setting
  replaces the French / English switches; the old setting is converted.
- Interface translated into German, Spanish and Italian.
- Language and layout default to the game client's language.
- Fix: words with "à" (città, voilà…) could be cut in two in the suggestions.
- Spanish ¿ and ¡ no longer block the word search.

## 0.4.1

- Right stick click on the channel row confirms the channel and goes back to the suggestions, without
  inserting a suggestion.
- The channel picked in the channel row becomes the chat's own sticky channel, as if `/p` had been
  typed in the game: following messages go there too, including text from a physical keyboard or a
  dictation tool (Handy…), and the keyboard reopens on it. Option to turn it off.

## 0.4.0

### New

- Second input method, "split keyboard": a full AZERTY / QWERTY keyboard with a numbers / accents /
  symbols layer, cut in two halves. The left stick moves a cursor on the left half, the right stick
  on the right half; each stick's tilt is its cursor's absolute position around the center of its
  half (released = center), so the keys near the middle are at the edge of their half and easy to
  hit. LT / RT type the left / right cursor's key, LB deletes, RB space, left stick click 123. Dead
  zone, magnet against flicker, a line from each center, edge keys reachable from 80 % tilt. Large
  keys (54 x 50 px, 600 px wide panel), every key clickable.
- Keyboard size option with 4 presets: small (80 %), normal, large (125 %), extra large (150 %).
- Linear stick response on each axis (no acceleration toward the edges), with a "stick response"
  option: linear, gentle (precise near the center) or fast.
- Options: input method, layout, dead zone, magnet, cursor lines. Commands: `/ck mode wheel|stick`,
  `/ck layout azerty|qwerty`. The options panel scrolls with the mouse wheel.

### Changes

- B empties the message (both methods). With an empty message, B is the game's own and closes the
  chat.
- Code split into a common core (`Message.lua`) and input methods (`Wheel.lua`, `StickKeyboard.lua`).

## 0.3.0

### New

- Chat channel row under the wheel: `/s`, `/y`, `/p`, `/ra`, `/g`, `/1`, `/w`, `/r`. D-pad ↓ / ↑ picks the
  active row (channels or suggestions), D-pad ← → and the right stick move inside it; with the mouse,
  hover a channel (no click, so the chat keeps its focus). Unavailable channels are greyed out and
  skipped.
- `/w` always available: pick the recipient first (suggested names from recent correspondents,
  group, friends and guild, or A to confirm what you typed; names with a space work), then type the
  message. Deleting on an empty message goes back to the name.
- Option to hide the mouse buttons row (Shift, 123, Space, Delete, Send, X); the panel gets shorter.
- Suggestions default to the client's language: French on a French client, English otherwise (both
  12,000-word dictionaries are included; change it in the options).

### Changes

- The message now lives in the keyboard's own bar and A sends it (secure macro, or a direct whisper);
  the game's chat box is never written to. B still closes the chat.
- The keyboard is disabled in combat: trying to open it shows "Not possible in combat". The chat works
  as usual, and the keyboard comes back by itself after combat if the chat is still open.
- The wheel center no longer shows the gesture legend; it only shows the letter aimed with the right
  stick.

### Fixes

- Crashes and "action blocked" cascades in combat: text typed by the addon into the game's chat box
  tainted WoW Forever's gamepad UI when it read it back.
- The keyboard could be blocked from opening ("ControllerKeyboardFrame:Show()").
- LB / RB / LT / RT could stay captured by the addon until the end of combat.

## 0.2.0

- New look matching WoW Forever's gamepad UI: dark 8-petal wheel with bronze and gold rims, Friz
  Quadrata font, the game's own gamepad button icons.
- Dual-stick typing: left stick picks a petal, right stick flicks toward the letter.
- iPhone-style prediction: message starters with nothing typed, next word from your own 2 and 3 word
  sequences plus built-in French phrases.
- Slash command autocomplete: `/reload`, `/p`, `/ra`, `/g`, `/w` first, then your most used commands.
- Options panel in *Escape > Options > AddOns*: lock, auto-open, size, font, button style, language,
  learning, reset position, forget learned words.
- Mouse / Steam Controller: the keyboard stays open and keeps the message when a click closes the chat.
- `/ck lock` to lock / unlock the position.
- A, B, X, Y, Start and Select are left to the game's gamepad chat UI.
- Fixes for WoW Forever's gamepad UI: no more "blocked action" popup or client freeze when sending.

## 0.1.0

- First version: daisywheel keyboard, French word prediction, learning from sent messages.
