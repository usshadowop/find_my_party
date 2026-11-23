# Find My Party

A **WoW: Forever** addon for party members who lose track of the group in crowds.

- **Colored names over party members' heads.** Pick any color and size, and your party's names stand out instead of blending in. The addon draws the name right over the game's own (the health bar stays), with a small arrow above it pointing down at them.
- **Hide everyone else's name plates.** In a busy city only your party's names show. You can turn this off.
- **Arrows that point to people.** Tick a party member's name and an on-screen arrow points their way, with how many yards off they are. Tick several people to get several arrows.

Everything is set from one window, opened with `/fmp`.

## Installing

1. Download this repository (**Code → Download ZIP** on GitHub) and unzip it.
2. Copy the **`FindMyParty`** folder (the folder itself, not just what's inside it) into
   `World of Warcraft\_forever_\Interface\AddOns\`
3. **Fully restart the game.** A `/reload` won't pick up the arrow picture the first time.
4. The addon is marked for WoW: Forever's interface version **16001**. If a future patch makes the AddOns list call it *out of date*, tick **Load out of date AddOns**, or change the number on the first line of `FindMyParty.toc` to what `/dump select(4, GetBuildInfo())` prints in game.

## Using it

Type **`/fmp`**. You can also click it in the AddOns menu under the minimap, or go to **Options → AddOns → Find My Party**.

**Left side: names**
- Click a colored square, or **Pick any color...** for any color you like.
- Drag **Name size** to make names bigger.
- The preview box shows what the names will look like.

**Right side: arrows**
- Everyone in your group is listed. Tick the people you want an arrow for. The addon remembers who you ticked, so the arrow comes back when that person joins your group again.
- Drag the arrows to wherever you like on the screen while the window is open. When the window closes they lock in place and your clicks go through them.
- `/fmp reset` puts the arrow back in the middle of the screen.

The arrow points relative to the direction **your character** is facing: up means straight ahead. It also shows the distance in yards.

## Things the game doesn't allow

- **Inside dungeons and raids**, the game keeps friendly name plates and party members' locations to itself, so the names and arrows don't work there. They do work in the open world and in cities, which is where people usually get lost.
- The colored names use **friendly player name plates**. The addon turns them on the first time it runs, and there's a checkbox for them in the window. They're also in the game's Options under Nameplates.
- Name plates only appear for people within about 45 yards (Forever's default), so the arrow is what finds people who are further away.
- During combat the game sometimes hides who a name plate belongs to. The addon then leaves that plate alone until it can tell again.
- With another name plate addon the colored names still appear, but hiding other people's plates may not.

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
- `tools/make_arrow.py` regenerates `FindMyParty/Media/Arrow.tga` (a white arrow that the addon tints).
- `tests/harness.lua` runs the addon against a small fake Forever client and checks the name plate logic, arrow math and settings window: `lua5.1 tests/harness.lua FindMyParty`.
