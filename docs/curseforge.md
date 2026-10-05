# Easy Controller - Forever

**Built to be as light as possible, for handhelds and the Steam Deck: about 0.1 % CPU and 5 MB of memory.**
Every feature you don't need can be turned off to save even more resources.

> **To open the settings: hold RB and press D-pad down** (or type `/ec config` in the chat).

**WoW Forever's gamepad play, made easy. No keyboard needed.**

## What's new in 1.11
- **Clearer Gamepad tab, comfier meals** (1.11.15): A on an unavailable layer says why and frees it on the spot; the camera turns while eating, getting up takes a quarter of a second, and bandages are protected too (new option).
- **Every press shows** (1.11.14): with "Triggers: press to switch", the bar's icons are pressed in on each press and cropped like the game's; quick presses show one by one.
- **Stances, stealth and forms** (1.11.13): a trigger layer of a button the addon handles (a wheel on D-pad up, RT + D-pad up...) now reaches the stance bar's spell.
- **Game functions on a button alone** (1.11.12): a face or D-pad button running a game function alone shows its trigger layers locked, with how to free them.
- **Round where the buttons are round** (1.11.11): the out-of-range red and, with "Triggers: press to switch", the icons and cooldowns follow the shape of the game's buttons.
- **Macros in the game's bar slots** (1.11.10): a macro on a trigger layer (RT + A...) now runs when the addon handles that button, with "Triggers: press to switch" too.
- **Fixes from a contributor** (1.11.9): learned words no longer lost past the limit, next-word suggestions in your language, no more wrong upgrade arrows while items load, important vibrations no longer cut by small ones.
- **Red when out of range** (1.11.8): now drawn over the game's bar without touching its buttons (fixes a Lua error in ActionButton.lua).
- **Characters sharing a first name** (1.11.7): WoW Forever's surnames are now part of the profile, so "Fraicheur Rog" and "Fraicheur Hunt" each keep their own settings. Each one starts from the settings they shared, nothing lost.
- **Macro window** (1.11.7): the controller keyboard no longer opens in the macro window or in fields of several lines (a mail's text); type them on a keyboard as before.
- **/ec profile** (1.11.6): shows whether this character has its own settings, and what each character holds.
- **Macros work again with the addon on** (1.11.5): choosing a channel on the chat keyboard no longer touches the game's chat box, which blocked the /cast of your macros.
- **Stay seated while eating** (1.11.4, Wheels › Consumables, on by default): a stick still pushed from the wheel, or nudged, no longer stands you up and wastes the meal. Push the left stick all the way for half a second to get up.
- **Supplies buttons** (1.11.4): their tooltip says they are Easy Controller's and where to set or hide them.
- **L3 / R3 and LT + RB / RT + LB layers** (1.11.3): while the button alone keeps the game's function (autorun, ping, targeting), the game takes its trigger layers too, so the Gamepad tab now says so. Put a spell, a wheel or the new **Nothing** on the button alone, and its trigger layers work.
- **Profiles are automatic** (1.11.2): each character keeps its own buttons, wheels and supplies, with nothing to set, and nothing done on one character changes another's. The Profiles tab is gone.
- **Start and Select stay the game's** (1.11.2): they can't be changed any more; what was on them is removed and the chat tells you once.
- **Stealth, forms and stances** (1.11.1): the stance bar that takes the place of a gamepad bar in stealth or a form can now be set from the Gamepad tab, and your replaced buttons press its spells while you are in the stance.
- **The keyboard in the game's fields**: it now opens for the Auction House search, the bags' search, mail, notes... What you type goes into the field, A is Enter (the Auction House searches), B closes it. Option in Keyboard › Opening, on by default.
- **Supplies**: no more "item:0" row for characters without ammo.

## What's new in 1.10
- **Hold to show a wheel** (option, Wheels › Opening): hold the wheel's button, aim with the left stick, let go to use what it aims at. Let go with the stick in the middle to close it.
- **Each trigger layer of a button runs its own**: a wheel on D-pad down no longer opens with LT or RT held (the game's bar comes back there), and a wheel on LT + a button now opens.
- **Character and camera back right away** after closing a wheel with the stick still pushed.
- **/ec config** typed in the chat opens the panel at once.
- A broken saved file no longer stops the addon.

## What's new in 1.9
- **Profiles**: each character has its own buttons and paddles, wheels and supplies, automatically. Every character starts from your current setup, so with one character nothing changes.
- **LT + RB and RT + LB** can now be set from the Gamepad tab (they showed "Unavailable" in 1.8.2).

## Also since 1.8 (1.8.1 and 1.8.2)
- **Triggers: press to switch** (option): press LT alone and the left bar stays on, press it again to come back; same for RT, LT then RT for the bottom bar. Holding still works as before. Made for the game's compact action bar.
- **Back paddles on Steam Deck / Steam Controller**: each trigger layer now works, even when Steam Input sends the paddles as plain keys.
- **Trigger layers kept apart**: an action set on one layer of a button no longer runs on its other layers.
- **Spells like Ghost Wolf** now cast from paddles, buttons and wheels (cast by name, with the rank you chose).
- **LT + RB and RT + LB** can take a spell, an item, a macro or a wheel.
- **Aggro lost vibration** for tanks.
- **RB + D-pad down** opens the configuration panel only, not what you put on D-pad down too.

## What's new in 1.8
- **Extra buttons**: up to 8 more buttons, for controllers with more buttons (Vader Pro…) or touchpads set as buttons (Steam Deck, Steam Controller), working like the back paddles.
- **Red when out of range**: the whole spell turns red on the gamepad bar, not just the small dot (too far, or too close for a hunter).
- **Free placement** of the extra buttons next to the gamepad bar.
- **Gamepad options in Home › Gamepad**, under the Gamepad extras switch.
- **Keyboard suggestions** always show whole words.

## Features
- **Gamepad mapping (ABXY)** and **back paddles** (Steam Deck, Xbox Elite, DualSense Edge…)
- **Extra buttons**: up to 8 more, for controllers with more buttons or touchpads (Steam Deck, Steam Controller)
- **Triggers: press to switch** instead of holding them (option)
- **Profiles**: each character its own buttons, wheels and supplies, automatically
- **Chat keyboard** with smartphone-style word prediction, also in the game's fields (Auction House search...)
- **Red when out of range**: the whole spell, not just a dot
- **Quest items** marked in your bags, quest links in the chat
- **Vibrations** on the events you pick
- **Supplies** tracker (arrows, soul shards, reagents, bag space…) that glows when you run low
- **Your own wheels** of spells, items and macros
- **Consumables wheel**, usable in combat
- **Hold to show** a wheel, let go to use (option)
- **Wheels that fit**: as many sections as items
- **Better items**: highlights upgrade items in your bags
- **At merchants**: auto-sell junk and auto-repair
- **OLED burn-in prevention** for the centre dot
- **Xbox / PlayStation (DualSense) / Nintendo Switch** button icons

Everything is driven with the gamepad (RB + D-pad down opens the configuration panel), every function
can be turned off, and the look matches WoW Forever's gamepad UI. The details of each part follow.

## Chat keyboard

The keyboard opens as soon as you open the chat. Pick the input method that suits you, let the
prediction finish your words and sentences, choose the channel, and send with A. Everything stays
clickable with the mouse or the Steam Controller trackpad. It also opens in the game's own fields
(the Auction House search, the bags' search, mail...): what you type goes into the field, A is Enter.

## Two input methods

**Daisywheel**
A wheel of 8 petals with 4 characters each, drawn like the game's radial menu. The left stick picks a
petal (it lights up), the right stick flicks toward the letter. Two gestures per letter, thumbs never
leave the sticks. Groups circled or characters only, as you like.

**Split keyboard**
A full AZERTY, QWERTY, QWERTZ, Spanish or Italian keyboard cut in two halves. The left stick moves a
cursor on the left half, the right stick on the right half: each stick's tilt is its cursor's
position, released = center. LT types the left key, RT the right one. Large keys with aligned columns,
a copper (left) and amber (right) target, a magnet so the highlight never flickers, and a linear stick
response with an optional gentle or fast curve.

Both methods have a numbers / accents / symbols layer whose accents follow the language
(é è à ç… / ä ö ü ß / á é í ó ú ñ ¿ ¡ / à è é ì ò ù), and can be switched at any time in the options.

## Keyboard features

- **Smartphone-style prediction**
  - word completion in English, French, German, Spanish and Italian (12,000 words each, client
    language by default) plus WoW slang: lfg, heal, dungeon…
  - accents ignored while searching: `ca` suggests "ça";
  - next word prediction from your own habits and common phrases;
  - suggestions as soon as the chat opens, before you type anything.
- **Learning**: your words, message starters and word sequences are remembered, locally.
- **Chat channel row**: `/s`, `/y`, `/p`, `/ra`, `/g`, `/1`, `/w`, `/r` in their channel colors,
  switched with the D-pad or by hovering with the mouse. Unavailable channels are greyed out. The
  chosen channel sticks for the whole chat, like typing `/p` in game, so a physical keyboard or a
  dictation tool writes there too.
- **Whispers**: pick the recipient from suggested names (recent correspondents, group, friends,
  guild) or type any name, including names with a space, then write the message.
- **Slash command autocomplete**: `/` suggests `/reload`, `/p`, `/ra`, `/g`, `/w`, then your most
  used commands.
- **Mouse and Steam Controller**: every key is clickable; the message is kept even when the game
  closes the chat on a click.
- **Safe with WoW Forever's gamepad UI**: the addon never types text into the game's chat box and is
  disabled in combat, so it cannot cause blocked actions or freezes.
- **Options panel**: input method, keyboard layout, stick dead zone and response, magnet, 4 window
  sizes, Blizzard fonts, Xbox / PlayStation (DualSense) / Nintendo Switch button icons, suggestion
  language, and more.

## Modules

**Configuration panel**
RB + D-pad down (or `/ec config`) opens the addon's own panel, driven with the gamepad or the mouse:
Home (every module and its state, the panel's shortcut, the look, the gamepad bar and extra buttons,
automation at merchants), Gamepad (your controller drawn button by button), Wheels, Keyboard and
Alerts (vibrations, supplies, quest items, better items). Sections on the left, settings in the
middle, what the selected one does on the right, and a help bar showing only the buttons that work
there.

**Your own wheels**
Up to 8 wheels of your own, shown as cards (their 8 slots, their name, the button they're on). Each
opens an editor: the wheel with its slots around it and the lists beside it (spells, items, macros);
a choice fills the slot and goes on to the next one. Name it with the gamepad keyboard, give it a
button straight from the editor ("Assign a button"). Each wheel shows its filled slots only, in as many
sections, and works like the consumables wheel, in combat too.

**Consumables wheel**
A key of its own (any free button, or a back paddle in any trigger layer) opens a wheel drawn like
the game's own radial menu, cut in as many sections as it holds (two items: two halves; five: five
sections), up to 8 consumables a page (LB / RB for more), from your bags: food, drink, healing and
mana potions, healthstone, mana gem, bandages, buff food, elixirs and flasks, scrolls, the best first.
Point with the left stick and press A to use; B cancels; the mouse works too. Or hold its key, aim and
let go to use (option). While it is open, and a moment after, your character doesn't move, so eating
isn't cut short. It works in combat (food and drink greyed there).

**Supplies**
A round button per resource: free bag slots, your ammunition, your class reagents (soul shards,
powders, candles, symbols, seeds, poisons…) and any item you add from your bags. Under its low
threshold it glows, stronger and redder down to the critical one; thresholds are yours to set.
Place the bar anywhere (mouse or D-pad), lock it; a click opens your bags.

**Vibrations**
The controller vibrates on the game events you choose: combat (death, interrupted, loss of control,
aggro gained or lost…), social (whisper, invite, ready check, resurrection…) and progress (level up, quest
objective, rare loot, bags full…). Each event has its own switch and its own pattern (tick, double
tick, pulse, heartbeat, crescendo…), with one intensity for all. Any controller the game drives
vibrates.

**Gamepad mapping**
The Gamepad tab draws your whole controller over an Xbox controller, in its four trigger layers, each
button with what it does and its state (the game's, a slot of its bar, yours, free, unavailable). The
buttons WoW Forever uses stay exactly as they are; the free ones get the missing functions: L3 / R3,
unused trigger combinations (LT + Start…) and the back paddles can run a game function (run / walk,
autorun, game menu, map, bags, any key binding of the game), one of the game's own gamepad functions
(jump, back, interact, inspect, Start menu, ping, targeting…), a spell, an item, a macro, or press a
button of the gamepad action bar. The game's own buttons (A, B, X, Y, D-pad, LB / RB, Start, Select)
can be replaced too, its menus keeping their buttons; one button gives them all back, and LT + RB / RT + LB
(which the game leaves to its targeting) can take an action too. Each trigger layer keeps its own
function: what you put on L3 alone stays on L3 alone.

**Back paddles (L4 / R4 / L5 / R5)**
Steam Deck and other controllers: set each paddle to a keyboard key in Steam Input (F13 to F16 for
example), then "Identify paddles" asks for each one in turn. Each paddle has the four trigger layers
(alone, LT, RT, LT + RT) for spells, items and macros, even when RT is no modifier or Steam Input
sends the paddle without the trigger's modifier; game functions
too once "RT as a modifier" is on (Home › Gamepad). The extra buttons (back paddles, L3, R3) are shown
around the gamepad action bar, in its own round slot style, with the action's icon, count and
cooldown, and press down like the game's buttons. Place each one where you want among fixed places
around the bar's controls, with the D-pad or the mouse, mirrored left / right, or anywhere with Free
placement.

**Extra buttons**
For both controllers with more buttons (Vader Pro…) and touchpads set as buttons (Steam Deck, Steam
Controller: 4 buttons a touchpad): make each button send a keyboard key in Steam Input (F17 to F24 for
example), turn on the ones you use in Home › Gamepad, and "Identify paddles" learns them. Up to 8
more buttons, working like the back paddles: the four trigger layers, spells, items, macros, game
functions, shown next to the gamepad bar.

**Triggers: press to switch**
An option in Home › Gamepad: press LT alone (no other button while it is down) and the left bar stays
on; press LT again to come back to the top bar. Same for RT (the right bar); LT then RT: the bottom bar.
Holding a trigger and pressing a button still works as before. The back paddles, L3 / R3 and the extra
buttons follow the bar on. Made for the game's compact action bar (one bar shown): the bar switched on
shows in place of the top bar. Optionally back to the top bar after each fight.

**Red when out of range**
Turn it on in Home › Gamepad: when the target is out of range (too far, or too close for a hunter's
shots), the whole spell turns red on the gamepad bar and on the extra buttons, instead of the game's
small red dot only.

**OLED burn-in prevention**
The gamepad UI's dot in the middle of the screen is always lit at the same place, which can burn into
an OLED screen (Steam Deck OLED, handhelds). In Home › Look, give it a colour, let it change colour
every 5 minutes, or hide it.

**Quest items**
The items a quest asks to collect (cloth, ore, meat…), which the game does not mark, get the game's
own quest item border in orange in your bags, and an orange "Quest item (quest name): do not sell"
line in their tooltip. A warning with a Buyback reminder if you sell one anyway.

**Better items**
A green arrow at the bottom right of an item in your bags that would be better than what you wear in
its slot. Items are compared by their stats, weighed for your class: a weapon's damage per second
first, then strength, agility, stamina, intellect, spirit, attack and spell power, armor (hybrids by
their main talent tree: a holy paladin weighs intellect and healing). Only what you can use and your
class's armor type; rings, trinkets and one-hand weapons against the weaker of the two you wear. The
panel shows your weights.

**At merchants**
Turn them on in Home › Automation: grey items sold by themselves (never a quest item), then
everything repaired, with a line in the chat for each; the guild's money first if you want it.

**Quest links and drafts**
A "Quests" chip in the channel row lists your quests and inserts their links. Links from Shift+click
or from the game's own "Share in chat" go into the message. When the game closes the chat (a panel
opens), your message is kept as a draft: type "LFM", share a quest from the quest log, and the
keyboard holds "LFM [quest]".

## Gamepad controls

**Common to both methods**

| Button | Action |
|---|---|
| A | send the message |
| B | clear the message (on an empty message: the game's back, closes the chat) |
| D-pad ↓ / ↑ | channel row / suggestions row |
| D-pad ← → | move in the active row |
| Right stick click | insert the suggestion (on the channel row: confirm the channel) |

X, Y, Start and Select stay with the game's gamepad UI.

**Daisywheel**

| Button | Action |
|---|---|
| Left stick | pick a petal |
| Right stick | type the aimed letter (with the left stick centered: move in the active row, ↑ insert, ↓ delete) |
| LB / RB | delete / space |
| LT | shift (double tap: caps lock) |
| RT or left stick click | numbers, accents, symbols |

**Split keyboard**

| Button | Action |
|---|---|
| Left stick / right stick | move the cursor on the left / right half |
| LT / RT | type the left / right cursor's key |
| LB / RB | delete / space |
| Left stick click | numbers, accents, symbols |

## Languages

Interface in English, French, German, Spanish and Italian. Suggestions and keyboard layout follow
the game client's language by default.

## Installation

Install with the CurseForge app, or extract the zip into
`World of Warcraft/_classic_beta_/Interface/AddOns/`.
**Fully restart the game** after installing or updating (a `/reload` does not load new files).

## Commands

- `/ec`: open the keyboard
- `/ec mode wheel|stick`: daisywheel or split keyboard
- `/ec layout azerty|qwerty|qwertz|es|it`: split keyboard layout
- `/ec lang fr|en|de|es|it|both`: suggestion and accent language
- `/ec lock`: lock / unlock the position (unlocking shows the keyboard to move it)
- `/ec scale 1.2`: any size (the options offer 4 presets)
- `/ec config`: configuration panel (also RB + D-pad down)
- `/ec map`: gamepad mapping (free buttons, back paddles, extra buttons)
- `/ec keys`: list the keys the game receives (to set up back paddles and extra buttons)
- `/ec vibe [pattern]`: test the controller vibration
- `/ec wheel`: what the consumables wheel holds, and why an item is not in it
- `/ec help`: all commands
- Options: RB + D-pad down, `/ec config`, or *Escape > Options > AddOns > Easy Controller - Forever*

## Compatibility

Made for **WoW Forever** and its gamepad UI. The keyboard is disabled in combat (the game blocks too
many actions there) and comes back by itself after combat if the chat is still open.

Source code and issues: [GitHub](https://github.com/moust4ki/EasyControllerWowForever) - Roadmap:
[ROADMAP.md](https://github.com/moust4ki/EasyControllerWowForever/blob/main/ROADMAP.md)

*Dictionaries derived from FrequencyWords by Hermit Dave (CC-BY-SA-4.0). Code under the MIT license.*
