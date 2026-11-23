# Find My Party

A World of Warcraft addon for party members who lose track of the group in crowds.

- **Colored names over party members' heads.** Pick any color and size, so your party's names stand out instead of blending in as the usual blue or green. A small arrow above each name helps too.
- **Hide everyone else's name plates.** In a busy city only your party's names show.
- **Arrows that point to people.** Tick a party member's name and an on-screen arrow points their way, showing how many yards off they are. Tick several people to get several arrows.

Everything is set from one window, opened with `/fmp`.

## Installing

1. Download this repository (**Code → Download ZIP** on GitHub) and unzip it.
2. Copy the **`FindMyParty`** folder (the folder itself, not just its contents) into:
   - Retail: `World of Warcraft\_retail_\Interface\AddOns\`
   - Classic: `World of Warcraft\_classic_era_\Interface\AddOns\` (or `_classic_`, `_anniversary_`)
3. **Fully restart the game.** A `/reload` won't pick up the arrow picture the first time.
4. If the AddOns list says the addon is *out of date*, tick **Load out of date AddOns**. You can also put your game's version number at the top of `FindMyParty.toc`. Type `/dump select(4, GetBuildInfo())` in game to see it.

## Using it

Type **`/fmp`** to open the window. In retail you can also click it in the AddOns menu under the minimap, or go to **Options → AddOns → Find My Party**.

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

- **Inside dungeons and raids**, the game blocks addons from changing friendly name plates and from knowing where party members are. The names and arrows work in the open world and in cities, which is where people usually get lost.
- The colored names use **friendly name plates**. The addon turns them on the first time it runs, and there's a checkbox for them in the window. **Shift+V** is the game's own shortcut for them.
- Name plates only appear for people fairly close by (roughly 20–60 yards, depending on game version), so the arrow is what finds people who are further away.
- With another name plate addon (Plater, ElvUI, etc.) the colored names still appear, but hiding other people's name plates may not work.

## Tip

You can also put a raid marker (star, skull, etc.) on yourself: right-click your own portrait, then **Target Marker Icon**. It floats over your head, and your party can see it from far away.

## For developers

- `tools/make_arrow.py` regenerates `FindMyParty/Media/Arrow.tga` (a white arrow that the addon tints).
- `tests/harness.lua` runs the addon against a small fake WoW API and checks the name plate logic, arrow math and settings window: `lua5.1 tests/harness.lua FindMyParty`.
