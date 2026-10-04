<img src="docs/icon.png" alt="Easy Controller - Forever" width="128" align="right">

# Easy Controller - Forever

*Formerly Controller Keyboard.* Download: [CurseForge](https://www.curseforge.com/wow/addons/easy-controller-forever)

**WoW Forever's gamepad play, made easy**, without changing the game's own gamepad UI: a **chat
keyboard** with word prediction, a **gamepad mapping** (the gamepad bar's slots, game functions on
the free buttons and back paddles), and **quest** helpers. RB + D-pad down opens the configuration.

The **gamepad keyboard** types in **WoW Forever**'s chat, with **smartphone-style word prediction**
that learns the way you write. Two input methods: a **daisywheel** and a **split keyboard** (one half per stick).
Everything is also clickable with the mouse, so it works with the Steam Controller trackpad too.

The look follows WoW Forever's gamepad UI: bronze and gold rims, Friz Quadrata font, the game's own
button icons.

Besides the keyboard, a few quality of life modules for gamepad players: a **gamepad mapping**
window that adds the missing game functions (run / walk, game menu...) on the free buttons and the
**back paddles** without changing WoW Forever's own gamepad UI, **quest items** marked "do not sell",
and **quest links** in the chat. Each module can be turned off in the options.

## Languages

The interface is translated into English, French, German, Spanish and Italian, following the game
client's language. Suggestions and keyboard layout also follow it by default: a German client gets
QWERTZ and the German dictionary.

## Installation

1. Download the repository (*Code > Download ZIP*) and extract it, or grab the zip from CurseForge.
2. Rename the folder to **`EasyController`** (exact name) and put it in
   `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. **Fully restart the game** after installing or updating (`/reload` does not load new files).

## Gamepad

The keyboard opens by itself with the chat. It is disabled in combat (the game blocks too many
actions there, "Not possible in combat") and comes back after combat if the chat is still open.

Choose the input method in the options or with `/ec mode wheel|stick`.

### Common to both methods

| Button | Action |
|---|---|
| A | send the message (secure macro `/s`, `/y`, `/p`, `/g`… following the channel, or a direct whisper) |
| B | empty the message; with an empty message, B is the game's own and closes the chat |
| D-pad ↓ / ↑ | go to the channel row / back to the suggestions |
| D-pad ← → | move in the active row: suggestion, or chat channel |
| Right stick click | suggestions row: insert the suggestion; channel row: confirm the channel and go back to the suggestions |

**X** (channels), **Y** (tab settings), **Start** and **Select** stay with the game's gamepad UI.

### Daisywheel

```
            [a b c d]
   [. , ? !]         [e f g h]
 [y z ' -]     (•)     [i j k l]
   [u v w x]         [m n o p]
            [q r s t]
```

Drawn on a solid stone wheel with Forever's bronze rim: the petal picked lights up,
the others dim, a native circular highlight marks the aimed character, and the centre
shows it in large. A brief pressed state follows each typed character. Option
**Daisywheel look**: groups circled (a ring
around each group of 4) or characters only.

- **Left stick**: pick a petal.
- **Right stick**: flick toward the letter to type (left / top / right / bottom of the petal).
- **Left stick centered**: the right stick moves in the active row (← →), ↑ inserts the suggestion,
  ↓ deletes.

| Button | Action |
|---|---|
| LB | delete (hold to repeat) |
| RB | space |
| LT | shift (tap = one capital, double tap = caps lock) |
| RT or left stick click | numbers, accents and symbols |

### Split keyboard

A full keyboard (AZERTY, QWERTY, QWERTZ, Spanish QWERTY with ñ or Italian QWERTY; option or
`/ec layout azerty|qwerty|qwertz|es|it`), with a numbers / accents / symbols layer whose accents follow
the language (é è à ç… / ä ö ü ß / á é í ó ú ñ ¿ ¡ / à è é ì ò ù), cut in two halves: the **left stick** drives a cursor on
the left half (columns 1-5), the **right stick** on the right half (columns 6-10). Each stick's
**tilt is its cursor's position** around the center of its half: released, the cursor is at the
center; push fully to reach an edge or a corner. The keys near the middle of the keyboard are at the
edge of their half, so they are easy to hit. A line links each center to its cursor; a magnet keeps
the highlight from flickering. Keys over the middle (Space) belong to both halves. The columns are
aligned in every row (Shift and 123 one key wide, Backspace two); the left target is copper, the right
one amber, and the key typed flashes.

| Button | Action |
|---|---|
| Left stick / right stick | move the left / right cursor (absolute position) |
| LT / RT | type the left / right cursor's key (one pull = one letter) |
| LB | delete (hold to repeat) |
| RB | space |
| Left stick click | numbers, accents and symbols |

Shift is the keyboard's own Shift key (tap = one capital, double tap = caps lock). The suggestions
and channels are driven with the D-pad.

Options: layout, stick dead zone, stick response (linear, gentle, fast), magnet strength, cursor
lines. Pick a larger window size in the options if the keys feel small.

## Mouse / Steam Controller

Every letter, suggestion and action (Shift, 123, Space, Delete, Send, X) is clickable. The game's
gamepad UI closes the chat on the first click: the keyboard then stays open and keeps the message,
"Send" sends it to the chat channel and "X" closes the keyboard.

## Chat channels

A row under the keyboard shows `/s`, `/y`, `/p`, `/ra`, `/g`, `/1`, `/w`, `/r` in their channel
colors. You have to reach for it, so you never switch by mistake: press **D-pad ↓** to make it the
active row, then **D-pad ← →** (or the right stick in the daisywheel); **D-pad ↑** goes back to the
suggestions. With the mouse, simply **hover** a channel (no click needed). The message is then sent
there with A. Unavailable channels are greyed out and skipped (party / raid / guild you are not in,
`/r` with nobody to reply to). Switching never loses the chat focus.

With **Channel sticks** enabled, the addon keyboard remembers its selected channel for
the next message. It keeps this choice in its own state; the game's chat text and
channel attributes remain owned by the game. A later channel choice made in native
chat takes precedence, and explicit whispers keep their own recipient.

With `/w`, first pick the recipient: type the name (names may contain a space) and insert a
suggestion (recent correspondents, group members, online friends, guild) or press A to confirm what
you typed; then type the message. Deleting on an empty message goes back to the name.

## Quest links and drafts

- The channel row ends with a **Quests** chip: select it to turn the suggestions row into the list of
  your quests, then insert one with the right stick click.
- Links inserted with **Shift+click**, or with the game's own **Share in chat** (gamepad quest log:
  Y > Share in chat), go into the keyboard's message.
- When the game closes the chat (another panel opens, combat), the message is kept as a **draft**
  and comes back with the chat: type "LFM", open the quest log, share the quest, and the keyboard
  holds "LFM [quest]". B empties it as usual; a draft is dropped after 10 minutes.
- Backspace deletes a link as a whole.

## Configuration panel

**RB + D-pad down** opens the addon's own panel (only watched, never bound: the game's own buttons stay as they are;
Home › Shortcut learns any other pair: press A on it, then hold a button and press a second one;
also `/ec config`, a key binding, or *Options > AddOns > Easy Controller - Forever*).

Five tabs, LB / RB to go from one to the next. In each, its sections on the left, their settings in
the middle, and on the right what the selected one does. The help bar at the bottom shows where you
are and the buttons that work there (click them with the mouse too). The D-pad moves and changes
values, A checks or chooses, B goes back to the sections, then closes. The panel reopens where you
left it. Forgetting the learned words, restoring the game's buttons and deleting a wheel ask a
second A.

- **Home**: every module with its state, Y on one jumps to its settings; the panel's shortcut;
  button glyphs (Xbox / PlayStation / Nintendo Switch), the game's button icons, font, the centre dot for
  OLED screens; automation at merchants.
- **Gamepad**: the mapping below.
- **Wheels**: your own wheels, the consumables wheel, where they open.
- **Keyboard**: opening, input method and layout, size, sticks, prediction, position.
- **Alerts**: the vibrations, the supplies buttons, the quest items and the better items below.

## Gamepad mapping

The Gamepad tab (`/ec map`) draws your controller, each button where it is, with what it does in the
layer shown: alone, LT, RT, LT + RT (the row above the controller, or hold the triggers). Each button
is in one of five states: the game's function, a slot of the game's gamepad bar (gold ring), yours
(cyan ring and diamond), free (+), unavailable (striped; the right panel says why). The D-pad goes
from button to button, up to the layers, down to the actions under the controller.

- **The game's own buttons** are shown with what they do and its icon: jump, interact, back, inspect,
  targeting, Start menu... They can be replaced too (below).
- **The gamepad bar's slots** (D-pad and A / B / X / Y in the four layers, but the fixed jump /
  interact / back / inspect) take a spell, an item or a macro: press A on one, pick it, and it goes
  in the game's own slot, like with its action bar editor (X empties it).
- **The free inputs get the missing functions**: L3 / R3, trigger combinations nothing is bound to
  (LT + Start...) and the back paddles. Press A on one and pick in the lists on the right, LB / RB
  to change list:
  - **Game**: first **the game's own gamepad functions**: jump, back, interact and inspect (the
    game's fixed A / B / X / Y buttons, pressed: their own behaviour, the smart interact
    included), the Start menu, interface focus, ping, ally and enemy targeting (held); then run /
    walk, autorun, game menu, map, bags, character, spellbook, quest log, open the keyboard... and
    every key binding of the game, by its own categories;
  - **Spells**, **Items** (your wheels first, then the usable items in your bags), **Macros**;
  - **Bar**: press a button of the gamepad action bar ("LT + RT A"...).
- X gives a button back to the game, empties a slot or removes yours; B closes the lists. Everything
  is clickable with the mouse too.

### Replacing the game's own buttons

- A, B, X, Y, the D-pad, LB / RB (alone), Start, Select and the sticks' buttons the game uses take any
  function from the lists too, in any layer. A slot of the gamepad bar still takes a spell, an item or a
  macro in the slot itself; anything else replaces the button, and what the slot held stays in it,
  under the picture of your function, for when you give the button back (X).
- The game's menus keep their buttons: the replacements are taken away while one of its gamepad
  windows has the focus, and set again when it closes. LB / RB with a trigger stay the game's (its
  class and pet actions read them directly), and so do LT / RT.
- Each layer needs a key of its own, so LT and RT become modifiers (the game's gamepad setting, like
  LT already sending Shift); the other layers of a replaced button keep what the game does there.
- **Restore (N)**, under the controller (A, then A again to confirm),
  gives every replaced button back to the game, as the game sets it. Only those: what you put in the
  game's slots, on the free buttons, on the paddles and in your wheels stays.
- `/ec binds` lists the replaced keys and what each one runs right now.

### Back paddles (L4 / R4 / L5 / R5) and extra buttons

For the Steam Deck and other controllers with back paddles: set each paddle to a keyboard key in
Steam Input (F13 to F16 for example), then **Identify paddles** (under the controller) asks you to
press each one in turn; X skips a paddle your controller doesn't have, B stops. Y on one paddle
learns it again. `/ec keys` lists the keys the game receives, with the modifiers and triggers it sees
held. Controllers whose paddles the game sees directly (PADPADDLE1-4) work as they are.

The paddles have the four layers: alone, LT, RT, LT + RT. When a paddle is pressed, the addon reads
the triggers held from the game's secure code (the gamepad's state, or the modifier a trigger adds)
and runs that layer's **spell, item, macro or wheel**; a layer with nothing does nothing. This works
whether or not the key a paddle sends comes with the triggers' modifiers (Steam Input's keyboard keys
may come without them). A game function (run / walk, map...) is a key binding and needs a key of its
own: the trigger must be a modifier in the game's gamepad settings, so the key changes with it (turn
on **RT as a modifier** in Home › Gamepad), or the layers share it. Spells are cast by their name
(with the rank you chose), like a macro: shapeshift forms such as Ghost Wolf cast too.

L3 / R3 can be shown too (Home › Gamepad), with what the game does with them (autorun, ping...) or what
you put on them. Spells are listed with their rank.

The extra buttons that do something (back paddles, L3, R3) appear around the gamepad action bar, in
its round slot style: the action's icon, count, cooldown and usability, the held trigger layer's
action, and the game's pressed look when you press them. **Move buttons** moves the game's gamepad bar by steps with the D-pad (only its
place on the screen changes, out of combat; X puts it back; the extra buttons follow it), and puts each
extra button
on one of the fixed places around the bar's controls (two columns on the outer side, two rows above and
two below): the D-pad chooses the bar or a button (LB / RB too), A picks it up, then the D-pad moves it
(a button goes from place to place, onto a taken place the two buttons swap), A puts it down and B puts
it back; the mouse clicks a button then a place; the right side mirrors the left (Y turns it
off), X puts a button back. Places follow the compact layout. With **Free placement** on (Home ›
Gamepad), the buttons go anywhere: a few pixels at a time with the D-pad, or dragged with the mouse.

### LT + RB and RT + LB

The game gives these two combinations no function of their own (they fall on the targeting): like the
game's other buttons, they can take a spell, an item, a macro, a wheel or a game function (both
triggers as modifiers). LT + LB and RT + RB stay the game's class actions.

### Triggers: press to switch

Home › Gamepad › **Triggers: press to switch** (off by default): no need to hold a trigger to use its
bar. Press LT alone (no other button while it is down): the left bar stays on, A, B, X, Y and the
D-pad use it; press LT again: back to the top bar. Same for RT (the right bar); LT then RT: the bottom
bar. Holding a trigger and pressing a button still works as before, the bar comes back once you let go.
The back paddles, L3 / R3 and the extra buttons follow the bar on. **It needs the game's compact
action bar** (the game's gamepad options): the game shows one bar, and the bar switched on shows in its
place. Without it, the game keeps showing its usual bars and the top one highlighted. **Top bar again after combat**
(on by default) brings the top bar back when a fight ends; off, a bar stays on until you press its
trigger again. A game window, the panel or the chat keyboard get their buttons back while open.

Limits: the game's class actions (LT + LB, RT + RB) still need the trigger held; a game function put on
a bar button used while holding a trigger counts as a press alone (the bar switches on when you let
go); in combat, a game window opened while a bar is on doesn't get A, B, X, Y back until it closes.

### Extra buttons

Up to 8 more buttons, 4 a side, for both: controllers with more buttons (Vader Pro...) and touchpads
set as buttons (Steam Deck, Steam Controller: 4 buttons a touchpad, 1 up, 2 right, 3 down, 4 left).
In Steam Input, make each button send a keyboard key (F17 to F24 for example). Turn on the ones you
use in Home › Gamepad › Extra buttons (TL1-TL4 on the left, TR1-TR4 on the right), then **Identify
paddles** asks for them after the back paddles. They work like the paddles (the four layers, spells,
items, macros, game functions) and show next to the gamepad bar; the Gamepad tab lists them under the
controller.

### Red when out of range

Home › Gamepad › Red when out of range: the whole spell turns red on the gamepad bar and on the
extra buttons when the target is out of range (too far, or too close for a hunter's shots), instead of
the game's small red dot only.

## Vibrations

The controller vibrates on the game events you choose (Alerts › Vibrations): one switch and one
intensity for all, then each event with its own box and its own pattern (micro tick, tick, double
tick, pulse, long, heartbeat, crescendo): A turns it on or off, the D-pad picks its pattern, Y tests
it.

- **Combat**: death, your spell interrupted (by someone, not by moving), loss of control, aggro, aggro lost (tanks), entering combat, spell proc,
  action impossible.
- **Social**: whisper, group or raid invite, ready check, resurrection or summon, trade or duel.
- **Progress**: level up, quest objective or quest complete, rare loot, bags full, gear almost broken.
- **Easy Controller**: a key typed on the chat keyboard.

Only the two standard motors are used, so any controller the game drives vibrates. No vibration on
your health: WoW Forever hides it from addons in combat. `/ec vibe [pattern]` tells what the client
allows and plays a pattern.

## Supplies

One round button per resource, in the gamepad bar's style (Alerts › Supplies):

- **free bag slots** (quivers, ammo pouches and soul bags apart), the **equipped ammunition**, the
  **class reagents** (soul shards, infernal stones, arcane powder, runes, candles, symbols, seeds,
  ankhs, poisons, powders...) once you carry them, and **any item** added from your bags;
- the count, and under the **low threshold** a glow that grows stronger, faster and redder down to
  the **critical threshold**; each resource can be turned off, its thresholds set with the D-pad;
- the bar is **placed freely**: dragged with the mouse while unlocked, or moved with the D-pad
  ("Move with the D-pad"), growing right, left, down or up, in 3 sizes; a click opens the bags
  (through the game's own backpack button);
- low supplies and little room left can vibrate (Alerts › Vibrations).

## Consumables wheel

A key of its own opens a wheel of consumables from your bags, drawn in the style of the game's own
radial menu and cut in as many sections as the page holds (two items: two halves; five: five
sections), each name beside its icon; up to 8 per page, **LB / RB** turn the pages (up to 3). Food,
drink, healing and mana potions, healthstone, mana gem, bandages (used on yourself), buff food,
elixirs and flasks, scrolls. The best of each kind comes first, then the other variants you carry (an option); each
kind can be left out (Wheels › Consumables).

- Give it a key in the Gamepad tab (Items list: any free button, or a back paddle in any layer) or
  in *Escape > Key Bindings > AddOns*.
- Open: **point at an item with the left stick and press A** to use it (the stick back in the middle
  points at nothing); **B** cancels; LB / RB turn the pages; the wheel's key closes it too. The right
  stick stays the game's (for its own spell wheels). The mouse works too. While it is open it takes
  the sticks, like the game's own wheels: the camera and the character stay still. The aimed item's
  name shows in the game's banner under the wheel.
- No game setting is changed. `/ec wheel` lists what the wheel holds, and why an item is not in it.

### Your own wheels

Up to 8 wheels of your own, made in Wheels › My wheels with the gamepad: a card per wheel (its 8
slots, its name, the button it is on), **New wheel** first. In play, a wheel shows its filled slots
only, in their order, in as many sections. A on a card opens its editor: the wheel,
its name and count in the middle, its 8 slots around it, and the lists on the right (Spells, Items,
Macros; LB / RB change list). The D-pad (or LB / RB) goes from slot to slot; A aims the lists at a
slot, and a choice fills it and goes on to the next one, the lists still open (a cyan diamond marks
what is already in the wheel); X empties a slot, B goes back. **Rename** (Y) types its name in a box
over the wheel, with the addon's keyboard (A confirms, B cancels) or a physical one (Enter / Escape);
**Assign a button** takes you to the Gamepad tab, where the button you pick gets the wheel;
**Delete** asks twice. Each wheel shows and works like the consumables wheel (left stick, A, B; in
combat too) with its name in the banner, and gets a key of its own: Assign a button, the Gamepad
tab's Items list (any free button or paddle), or the game's Key Bindings (under AddOns). What a wheel
holds changes out of combat only.
- It sits in the middle of the screen (unlocked, drag the open wheel with the mouse, or move it with
  the D-pad: Wheels › Position).
- It works **in combat**: the wheel and the keys it takes are secure, run by the game. Food and drink
  are greyed there (the game forbids them in combat). Its content is updated out of combat only (a
  rule of the game).
- Moving from slot to slot can vibrate (Alerts › Vibrations).

## Quest items

Item tooltips show an orange **"Quest item: do not sell"** line on quest items, including the items a
quest asks to collect (cloth, ore, meat...) that the game itself does not mark: for those, the line
names the quest. In the bags they get the border the game puts on its own quest items, in orange
(the game's own quest items keep theirs). Selling one to a
merchant shows a warning with a reminder of the Buyback tab; with the gamepad bag tooltips turned
off, selecting one at a merchant warns too.

## Better items

A green arrow at the bottom right of a bag item that would be better than what you wear in its slot
(Alerts › Inventory). Items are compared by their stats, weighed for your class: a weapon's damage
per second first, then strength, agility, stamina, intellect, spirit, attack and spell power, armor,
each with its weight (a hybrid's by the talent tree with the most points: a holy paladin weighs
intellect and healing, a protection one stamina and armor). The side panel shows your weights. Only
for what you can use (nothing in red in its tooltip: armor type, weapon skill, level, class), of
your class's armor type or of the type you already wear there (no cloth arrow for a warrior; plate
from level 40 for warriors and paladins, mail for hunters and shamans). Rings, trinkets and one-hand
weapons (when you can dual wield) are compared with the weaker of the two you wear, a two-hand weapon
with both hands, and with a two-hand weapon worn a one-hand weapon has to beat it whole. A client
that gives no stats compares the item levels.

## At merchants

Home › Automation (both off until you turn them on):

- **Sell grey items**: the grey (poor quality) items of your bags are sold one after the other, and a
  line in the chat says how much they brought. Quest items are never sold.
- **Repair at merchants**: once the grey items are sold, a merchant who repairs repairs everything,
  and a line in the chat says what it cost (or that the money was short). **With the guild's money**
  makes the guild pay first, when it allows you and has enough.

## Prediction

- **Word completion**: English, French, German, Spanish and Italian dictionaries of 12,000 words
  each, plus WoW slang (lfg, heal, dungeon…). Defaults to the client's language, changeable in the
  options (or French + English). Accents are ignored
  while searching: `ca` suggests "ça", `ete` suggests "été".
- **Next word, iPhone style**: your usual message starters as soon as the chat opens; after each word,
  the most likely next word from your own 2 and 3 word sequences, plus built-in common French phrases.
- **Slash commands**: a message starting with `/` suggests `/reload`, `/p`, `/ra`, `/g`, `/w`, then your
  most used commands and common ones (`/r`, `/roll`, `/dance`, `/ec lock`…).
- **Learning**: every message you send (gamepad or keyboard) feeds your words, message starters, word
  sequences and commands. The text after `/w`, `/g`… is never stored as a command. Everything stays
  local, in `WTF/.../SavedVariables/EasyController.lua`.

## Options

In the configuration panel (RB + D-pad down, `/ec config`):

- every module on or off (Home › Modules; Gamepad extras at the top of Home › Gamepad), each one's
  settings in its own tab;
- input method (daisywheel / split keyboard), daisywheel look (groups circled / characters only),
  keyboard layout (AZERTY, QWERTY, QWERTZ, Spanish, Italian), stick dead zone, stick response
  (linear, gentle, fast), magnet, cursor lines;
- lock position, open automatically, only when the gamepad is active;
- keyboard size: small (80 %), normal, large (125 %), extra large (150 %) — `/ec scale` for any
  other value; invert the sticks vertical axis, show / hide the mouse buttons row;
- font (Blizzard fonts: Friz Quadrata, Morpheus, Skurri, Arial Narrow, or the chat font);
- button style (Xbox / PlayStation / Nintendo Switch) and the game's button icons;
- the gamepad UI's centre dot, for OLED screens: the game's, a colour, a colour changing every 5
  minutes, or hidden;
- suggestion language (French, English, German, Spanish, Italian, or French + English), learning;
- reset position, forget learned words.

## Commands

| Command | Effect |
|---|---|
| `/ec` | open the keyboard |
| `/ec lock` | lock / unlock the position (unlocking shows the keyboard to place it) |
| `/ec mode wheel\|stick` | daisywheel or split keyboard |
| `/ec layout azerty\|qwerty\|qwertz\|es\|it` | split keyboard layout |
| `/ec auto` | open automatically with the chat |
| `/ec pad` | only open automatically when the gamepad is active |
| `/ec learn` | turn learning on / off |
| `/ec lang fr\|en\|de\|es\|it\|both` | suggestion and accent language |
| `/ec scale 0.8` | keyboard size |
| `/ec invert` | invert the sticks vertical axis |
| `/ec reset` | reset the keyboard position |
| `/ec stats` | statistics |
| `/ec forget confirm` | forget learned words |
| `/ec config` | configuration panel (also RB + D-pad down) |
| `/ec map` | gamepad mapping (free buttons, back paddles) |
| `/ec keys` | list the keys and buttons the game receives, with the modifiers and triggers held (back paddles) |
| `/ec fish` | list the game's events for a minute, to find which one comes when a fish bites |
| `/ec vibe [pattern]` | test the controller vibration |
| `/ec wheel` | what the consumables wheel holds, and why an item is not in it |
| `/ec binds` | the game's buttons replaced, and what each key runs now |
| `/ec glyphs` | list the game's gamepad button icons |
| `/ec debug` | print received buttons and sticks |

**"Toggle keyboard"**, **"Easy Controller - Forever configuration"** and **"Gamepad mapping"** key bindings
are also available in *Escape > Key Bindings > AddOns*.

## Technical notes

- The addon never writes to the game's chat box: text set by an addon is tainted, and when the gamepad
  UI reads it back its own code gets blocked in combat, over and over until the client freezes. The
  message lives in the keyboard's bar and is sent through a secure macro button.
- WoW Forever's gamepad UI forbids addons from closing the chat or opening panels
  (`SetPreferredGamepadInteractTarget` error, which can freeze the client). The addon never closes the
  chat itself, creates its frames outside the gamepad UI's watch, and sends with the mouse through a
  secure macro button.
- Gamepad buttons are bound (override bindings) only while typing, and released before combat.
- The gamepad mapping never changes WoW Forever's gamepad UI. An input is "free" only when no game
  binding uses it (checked with ours removed); our bindings are plain override bindings of the
  addon's own frame, set out of combat while none of the game's gamepad windows has the focus, below
  the game's own window bindings, and set again when such a window closes. A paddle on a bar button
  is bound to a click on the game's button, which the game runs like its own D-pad and face buttons.
  The paddles on screen are plain frames that only read the game's buttons, so they update in
  combat.
- Quest items only add a line through the tooltip API and watch the buyback list; links and the
  chat's focus are followed through hooks and the game's own events, never by calling its chat code.
- B is bound only while the message holds text; the binding is removed when B is released, so with an
  empty message B goes back to the game, which closes the chat.
- Code layout: `Message.lua` is the common core (message, prediction, channels, sending),
  `Wheel.lua` and `StickKeyboard.lua` are the input methods, `UI.lua` the common panel, `Input.lua`
  the pad buttons and sticks; `ConfigWindow.lua` the configuration panel (`ConfigKit.lua` its parts,
  `Options.lua` the Home, Wheels, Keyboard and Alerts tabs, `MapWindow.lua` the Gamepad tab,
  `MyWheels.lua` the wheels' cards and editor); `Mapping.lua` / `Paddles.lua`,
  `QuestItems.lua` and `QuestLinks.lua` are the modules.

## Roadmap

What is planned next (automation at merchants, better items in the bags...) is in
[ROADMAP.md](ROADMAP.md).

## Development

Textures (PNG sources in `design/textures/`, converted to TGA for the game; the shapes and the
controller silhouette are drawn by `render_textures.py`):

```bash
python tools/render_textures.py
python tools/convert_textures.py
```

Dictionaries ([FrequencyWords](https://github.com/hermitdave/FrequencyWords) frequency lists,
OpenSubtitles):

```bash
python tools/build_dict.py fr    # or en, de, es, it
```

CurseForge / release package (`dist/EasyController-<version>.zip`, page description in
`docs/curseforge.md`):

```bash
python tools/package.py
```

### Local character and role profiles

In the local build, open `/ec config`, then **Home > Profiles**. General, Tank, Healer and
Damage are separate layouts for each character. Selecting a profile previews it;
**Activate** switches outside combat. The first activation of a new role copies
the current layout. Copying another layout replaces personal bindings and custom wheels
after confirmation; shared utility commands keep their current settings.

Controller hardware, display settings and utility commands (targeting, interaction,
menus and consumable-wheel shortcuts) are shared. Spell, item, macro and custom-wheel
bindings belong to the active character/profile. A personal binding takes precedence
over a shared utility; clearing one restores the game's behavior in that profile.
The first character keeps the existing setup; subsequent characters start with shared
utilities and empty personal layouts. The original import remains available to copy.
Native action-bar contents and the game's own bindings are not profile snapshots.

**Home > Role layout** lets you label an interrupt, defensive, movement or emergency
heal, choose its button/layer and select a known spell. Positions are remembered across
characters; abilities are chosen per profile. Review the preview before applying.
Occupied buttons are protected until **Replace existing** is enabled. Disabled buttons
and unavailable layers must be configured in Gamepad settings first. Choose abilities
and activate profiles explicitly; specialization changes do not switch profiles automatically.

Under **Wheels > Position**, **Keep custom wheel directions** preserves eight directions
including empty slots. This is optional and applies to custom wheels, not the automatic
consumables list. Alerts now give important vibration patterns priority over wheel ticks.

### Running regression checks

Run from the repository root (Python 3 and Lua 5.1):

```bash
python -m unittest discover -s tools -p 'test_*.py'
lua tools/test_toggle.lua
lua tools/test_upgrades.lua
lua tools/test_predict.lua
lua tools/test_consumable_refresh.lua
lua tools/test_vibration.lua
lua tools/test_refresh.lua
lua tools/test_profiles.lua
lua tools/test_profile_options.lua
lua tools/test_config_layout.lua
lua tools/test_text_layout.lua
lua tools/test_skin.lua
lua tools/test_consumable_skin.lua
lua tools/test_mwheel_skin.lua
lua tools/test_supplies.lua
lua tools/test_message.lua
python tools/package.py
```

The Lua checks execute addon code with narrow game-API stubs. They do not replace
in-game testing of secure bindings, controller input, or rendering.

### Releases

Releases are automatic (`.github/workflows/release.yml`): set the new `## Version` in the TOC, add a
`## <version>` section to `CHANGELOG.md`, commit, then push a tag `v<version>`:

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub then checks that the tag matches the TOC, builds the zip, creates the GitHub release and uploads
the file to CurseForge, both with that version's CHANGELOG section as release notes. A tag with a dash
(`v1.1.0-beta1`) is a beta. It needs the `CF_API_KEY` repository secret (a CurseForge API token); the
CurseForge game version is 1.60.1 (WoW Forever) unless the `CF_GAME_VERSION` repository variable says
otherwise. CurseForge has no API for the project page itself: paste `docs/curseforge.md` there when it
changes.

## License

Code under the MIT license (see `LICENSE`). The `Dict_*.lua` word lists (French, English, German,
Spanish, Italian) are derived from FrequencyWords (Hermit Dave) and remain under the
[CC-BY-SA-4.0](https://creativecommons.org/licenses/by-sa/4.0/) license.

## AI disclosure

This addon was built with the help of AI: the code was written with Claude Code (Anthropic) and the
visual design created with Claude Design, directed by the author, who defined the features and tested
the addon in game.
