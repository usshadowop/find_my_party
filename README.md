# Find My Party

A **WoW: Forever** addon for party members who lose track of the group in crowds.

- **Colored names over party members' heads.** Teal to start with, or any color and size you like, so your party's names stand out instead of blending in. The addon draws the name right over the game's own (the health bar stays), with a small arrow above it pointing down at them. That arrow has its own size setting.
- **Hide everyone else's name plates (optional).** Off at first. Turn it on and in a busy city only your party's names show.
- **Arrows that point to people.** Tick a party member's name and an on-screen arrow points their way, with how many yards off they are. Tick several people to get several arrows. Move them by unlocking them, or in the game's Edit Mode.
- **Checkboxes on the party frames.** Each party member's frame (portrait, health and mana) gets a little checkbox. Tick it to point an arrow at them, and untick it to stop.
- **A minimap button** (yellow party silhouettes) that opens the settings.

Everything is set from one window: click the minimap button or type `/fmp`.

## Installing

1. Download this repository (**Code → Download ZIP** on GitHub) and unzip it.
2. Copy the **`FindMyParty`** folder (the folder itself, not just what's inside it) into
   `World of Warcraft\_forever_\Interface\AddOns\`
3. **Fully restart the game.** A `/reload` won't pick up the arrow picture the first time.
4. The addon is marked for WoW: Forever's interface version **16001**. If a future patch makes the AddOns list call it *out of date*, tick **Load out of date AddOns**, or change the number on the first line of `FindMyParty.toc` to what `/dump select(4, GetBuildInfo())` prints in game.

## Using it

Click the **minimap button** (yellow party silhouettes) or type **`/fmp`**. It's also in the AddOns menu under the minimap, and under **Options → AddOns → Find My Party**.

**The minimap button**
- **Left-click** opens or closes the settings.
- **Right-click** unlocks the arrows so you can move them, and right-click again to lock them.
- **Drag** it to move it around the edge of the minimap. Untick **Show minimap button** in the settings to hide it.

**Left side: names**
- Click a colored square, or **Pick any color...** for any color you like.
- Drag **Name size** to make names bigger.
- Drag **Size of the arrow above their heads** to make that arrow bigger or smaller.
- The preview box shows what the names will look like.

**Right side: arrows**
- Everyone in your group is listed. Tick the people you want an arrow for. The addon remembers who you ticked, so the arrow comes back when that person joins your group again.
- **From the party frames:** a checkbox sits just right of each party member's frame, with a small arrow beside it. Tick it to point an arrow at them, and untick it to stop. It stays in step with the list in the settings. Untick **Arrow checkboxes on the party frames** to hide them. They show on the standard party frames (with portraits), not on raid-style party frames.
- **Moving the arrows:** tick **Unlock the arrows so I can drag them** (or right-click the minimap button), drag them where you like, then untick it to lock them. While locked, your clicks go straight through them. They can also be moved in the game's **Edit Mode** (Esc → Edit Mode): they get a blue box there like the game's own frames, and lock again when you leave.
- `/fmp unlock` and `/fmp lock` do the same, and `/fmp reset` puts the arrows back in the middle of the screen.

The arrow points relative to the direction **your character** is facing: up means straight ahead. It also shows the distance in yards.

## Things the game doesn't allow

- **Inside dungeons and raids**, the game keeps friendly name plates and party members' locations to itself, so the names and arrows don't work there. They do work in the open world and in cities, which is where people usually get lost.
- The colored names use **friendly player name plates**. The addon turns them on the first time it runs, and there's a checkbox for them in the window. They're also in the game's Options under Nameplates.
- Name plates only appear for people within about 45 yards (Forever's default), so the arrow is what finds people who are further away.
- During combat the game sometimes hides who a name plate belongs to. The addon then leaves that plate alone until it can tell again.
- With another name plate addon the colored names still appear, but hiding other people's plates may not.
- The arrows' position is saved by the addon, not in your Edit Mode layout: the game doesn't let addons add frames to its layouts.

## Tip

You can also put a raid marker (star, skull, etc.) on yourself: right-click your own portrait, then **Target Marker Icon**. It floats over your head, and your party can see it from far away.

## Blizzard's addon rules

The addon follows Blizzard's [UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534):
- It's free, with all its code in plain view.
- It has no ads and asks for no donations.
- It sends no chat or addon messages.
- It uses only the game's official addon API.

It doesn't automate anything: no moving, targeting, casting or clicking for you. It only shows what the game already shows about your own group, which is your party members' positions (the game puts those on your map and minimap too). It respects the game's restrictions in dungeons, raids and combat rather than working around them.

## For developers

- Built against WoW: Forever's API: Blizzard's generated API docs and UI source for the Forever client (interface 16001), plus how existing Forever addons handle name plates. Key Forever rules it follows:
  - Never anchor to a name plate's base frame.
  - The friendly plates CVar is `nameplateShowFriendlyPlayers`.
  - `UnitName`'s second value is a surname, not a realm.
  - Check for secret values before testing them.
- `tools/make_arrow.py` regenerates `FindMyParty/Media/Arrow.tga` (a white arrow that the addon tints), and `tools/make_icon.py` the minimap icon `FindMyParty/Media/MinimapIcon.tga`.
- `tests/harness.lua` runs the addon against a small fake Forever client and checks the name plate logic, arrow math and settings window: `lua5.1 tests/harness.lua FindMyParty`.
