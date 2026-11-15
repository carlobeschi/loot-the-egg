# Loot the Egg: Roblox port kit

This folder is a head start for rebuilding the browser game in **Roblox Studio**. Read the first section before anything else.

## What this is (and isn't)

- The web game (the JavaScript/three.js file) **cannot be uploaded to Roblox**. Roblox only runs games made in Roblox Studio, written in a language called Luau.
- So the Roblox version is a **rebuild**. This kit gives you the rules, numbers and server logic already written in Luau, so you are not starting from zero. The maps, models, enemies and combat still need building in Studio.
- **The JavaScript game stays your working prototype.** Keep designing and tuning there. A small tool (below) copies the numbers into the Roblox files so the two never drift apart.
- I wrote these scripts without Roblox Studio available to run them. They are starter code: they're structured carefully and checked for balanced syntax, but expect to fix small errors on first run. Test them in Studio before you trust them.

## What's in the folder

| File | Where it goes in Studio | What it does |
|---|---|---|
| `Config.lua` | ReplicatedStorage > **ModuleScript** named `Config` | Game rules: pen size, rebirth, weapon damage, egg odds, enemy stats |
| `ConfigData.lua` | A ModuleScript named `ConfigData` **inside** `Config` | The numbers (rarities, pets, income, costs, weapon names). Generated from the JS game |
| `DataService.lua` | ServerScriptService > ModuleScript | Saves and loads each player's progress (DataStore) |
| `PlotService.lua` | ServerScriptService > ModuleScript | Gives each player a plot, builds the pen look, spawns their pets |
| `PetService.lua` | ServerScriptService > ModuleScript | Hatching, equip best, selling, pen upgrades, rebirth, World Gate |
| `DungeonService.lua` | ServerScriptService > ModuleScript | Enemies, boss defeated, egg drop, taking the egg wakes everything, banking it in town |
| `Main.server.lua` | ServerScriptService > **Script** named `Main` | Starts everything, makes the RemoteEvents, runs the coin income loop |
| `ClientHUD.client.lua` | StarterPlayer > StarterPlayerScripts > **LocalScript** | Coins display, Hatch, Equip Best, Rebirth, Settings with "Show my pets" |
| `tools/export_config.js` | Stays on your computer | Re-creates `ConfigData.lua` from the JavaScript game |

The `.server.lua` / `.client.lua` names are for the Rojo tool. In plain Studio just paste each file's contents into the right kind of script.

## Quick start

1. In Roblox Studio, make a new **Baseplate** place.
2. Create the scripts from the table above and paste each file in.
3. In Workspace, build a Folder named **Plots**. Inside it make one Model per plot (Plot1 to Plot8). Each plot Model needs parts with these exact names:
   - `PenArea`: a flat Part over the inside of the pen (pets wander in it)
   - `Spawn`: where the owner appears
   - `Fence`: a Model or Folder of fence Parts (they get recolored on each pen upgrade)
   - `CollectPad` (optional): walk onto it to collect pet earnings
   - `Sign` (optional): a part with a SurfaceGui and a TextLabel named `SignText`
4. Add a Part named **TownZone** in Workspace (invisible, CanCollide off) over the safe town. Reaching it with an egg banks the egg.
5. In ServerStorage make a Folder **Enemies** with four rigs named `Zombie`, `Runner`, `Tank`, `Boss` (Rig Builder in Studio makes simple ones).
6. Turn on **Game Settings > Security > Enable Studio Access to API Services** so saving works in tests.
7. Test with **Test > Clients and Servers** (2 or more players) to check plots are handed out one per player.
8. When happy: **File > Publish to Roblox**, then set the game's name, description, thumbnail and age questionnaire in the Creator Hub.

## How the JavaScript game maps to Roblox

| In the JS game | In Roblox |
|---|---|
| Browser save (localStorage) | DataStore (`DataService`) |
| One pen for you | One plot per player (`PlotService`), 8 or more plots |
| Coins, pets, rebirth in memory | Server only. The client sends requests, the server decides |
| Shops and menus (HTML) | ScreenGui windows. `ClientHUD` shows the pattern |
| Settings > Show pets | Client-side `LocalTransparencyModifier`, saved in the profile |
| Dungeon towers, stairs | Build in Studio (or generate with a script like the JS does) |
| Enemies, boss slam, enrage, summons | `DungeonService.SpawnEnemy` plus your own boss script (below) |
| Weapons (12 tiers per class) | Tools. Damage = `Config.weaponDamage(class, tier)` |
| Worlds 1 and 2 | Two zones in one place, or two places joined by TeleportService |
| Pen colors per upgrade | `PlotService.ApplyPenStyle` recolors the Fence parts |

## Keeping the JavaScript game and the Roblox files in sync

Run this any time you change numbers in the JavaScript game (needs Node.js):

```
cd roblox/tools
node export_config.js ../../three-oaths-3d.html ../ConfigData.lua
```

Then paste the new `ConfigData.lua` into Studio. It carries the rarities, colors, pet names, income, rebirth costs, weapon names and prices, and upgrade costs. The **rules** in `Config.lua` (egg odds formula, enemy stats formula, damage multipliers) are written by hand, so if you change those in the JS game, change them in `Config.lua` too. Rarity numbers start at 1 in Lua (1 = Common, 8 = Divine); weapon tiers and dungeon floors start at 0, like the JavaScript.

## Safety: let the server decide

- Never let the client say "give me 1000 coins". The client only fires RemoteEvents like `Hatch`. The server checks and acts. `Main.server.lua` also rate-limits each action.
- Add a distance check before hatching (the player must be near the nest) and before collecting.
- For a real launch, use a session-locking save library such as ProfileService so two servers can't overwrite each other's saves.

## Roblox rules to plan for

- **Odds disclosure:** if you ever sell random items for Robux (egg luck boosts, paid eggs), Roblox's rules require you to show the odds before purchase. `Config.eggWeights(depth)` gives you the numbers to display.
- Use your own models and sounds or assets you have the rights to. Don't copy other games' content.
- Roblox runs moderation on everything you upload, and you fill in a content questionnaire when you publish. Read the Community Standards and Creator Terms in the Creator Hub first.
- Plan for phones and tablets. A large share of players are on touch screens, so test the UI with Studio's device emulator.

## Not done yet (suggested order)

1. **Combat:** Tools for the sword, staff and bow. On a hit, fire a RemoteEvent and let the server deal damage = base x `Config.weaponDamage` x the enemy's `Armor` attribute. Set `LastHitBy` on the enemy so `DungeonService.OnBossDefeated` knows who gets the egg.
2. **Dungeon towers:** build one tower in Studio with stairs, copy it for the other depths, give each a `Depth` attribute and a locked gate. After a boss falls, open the gate of the dungeon with Depth + 1.
3. **Boss moves:** the JS boss has a ground slam (red warning ring, then damage), summons helpers, and enrages below half health. Rebuild those as a loop on the Boss rig: telegraph, wait about 1 second, then damage players inside the ring.
4. **Real models:** swap the Part-built pets for models in `ServerStorage.PetModels`. Add the pen sign pad (upgrade pen), the shop and the blacksmith as proximity prompts or touch pads that open ScreenGuis.
5. **The rest:** rebirth and World Gate screens in the HUD, egg visuals, sound, and music.

If you want, I can write any of these next, one at a time, starting with whichever you pick.

## Testing it (see also `SetupTestPlace.lua` and `TestCheats.lua`)

1. Paste `SetupTestPlace.lua` into View > Command Bar (in Edit mode) to build the 8 plots, the TownZone and the enemy rigs for you.
2. Add the scripts from the table above, then press **Test > Play** and look at the Output window (View > Output) for red errors.
3. Use **Test > Server & Clients** with 2 clients to check that each player gets their own plot.
4. While playing, use the Client/Server toggle to switch to Server view and paste a snippet from `TestCheats.lua` to give yourself coins and eggs.
