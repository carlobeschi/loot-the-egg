# Loot the Egg: Roblox port kit

This folder is a head start for rebuilding the browser game in **Roblox Studio**. Read the first section before anything else.

## What this is (and isn't)

- The web game (the JavaScript/three.js file) **cannot be uploaded to Roblox**. Roblox only runs games made in Roblox Studio, written in a language called Luau.
- So the Roblox version is a **rebuild**. This kit gives you the rules, numbers and server logic already written in Luau, so you are not starting from zero. The maps, models, enemies and combat still need building in Studio.
- **The JavaScript game stays your working prototype.** Keep designing and tuning there. A small tool (below) copies the numbers into the Roblox files so the two never drift apart.
- I wrote these scripts without Roblox Studio available to run them. They are starter code: they're structured carefully and checked for balanced syntax, but expect to fix small errors on first run. Test them in Studio before you trust them.

## What's in the folder

With Rojo (recommended, see "Using Rojo" below) the files in `src/` sync straight into Studio. Without Rojo, paste each file's contents into a script of the kind shown.

| File | Where it goes in Studio | What it does |
|---|---|---|
| `src/ReplicatedStorage/Config/init.lua` | ReplicatedStorage > **ModuleScript** named `Config` | Game rules: pen size, rebirth, weapon damage, egg odds, enemy stats |
| `src/ReplicatedStorage/Config/ConfigData.lua` | A ModuleScript named `ConfigData` **inside** `Config` | The numbers (rarities, pets, income, costs, weapon names). Generated from the JS game |
| `src/ServerScriptService/DataService.lua` | ServerScriptService > ModuleScript | Saves and loads each player's progress (DataStore) |
| `src/ServerScriptService/PlotService.lua` | ServerScriptService > ModuleScript | Gives each player a plot, builds the pen look, spawns their pets |
| `src/ServerScriptService/PetService.lua` | ServerScriptService > ModuleScript | Hatching, equip best, selling, pen upgrades, rebirth, World Gate |
| `src/ServerScriptService/DungeonService.lua` | ServerScriptService > ModuleScript | Enemies, boss defeated, egg drop, taking the egg wakes everything, banking it in town |
| `src/ServerScriptService/CombatService.lua` | ServerScriptService > ModuleScript | Sword, staff and bow: gives your weapon, works out hits on the server |
| `src/ServerScriptService/EggService.lua` | ServerScriptService > ModuleScript | Eggs as backpack items; placing them in your pen; countdown and hatching |
| `src/ServerScriptService/ShopService.lua` | ServerScriptService > ModuleScript | Builds the town huts (Blacksmith, Trainer, World Gate), pen sign prompts, and does the buying |
| `src/ServerScriptService/TowerService.lua` | ServerScriptService > ModuleScript | Builds the test tower (Dungeon 1) from Parts, fills it with enemies and a boss when you walk in |
| `src/ServerScriptService/Main.server.lua` | ServerScriptService > **Script** named `Main` | Starts everything, makes the RemoteEvents, runs the coin income loop |
| `src/StarterPlayer/StarterPlayerScripts/ClientHUD.client.lua` | StarterPlayer > StarterPlayerScripts > **LocalScript** | Coins display, Equip Best, Rebirth, class picker, Settings with "Show my pets" |
| `src/StarterPlayer/StarterPlayerScripts/ClientEggs.client.lua` | StarterPlayer > StarterPlayerScripts > **LocalScript** | Shows where an egg will go and places it when you click in your pen |
| `src/StarterPlayer/StarterPlayerScripts/ClientShops.client.lua` | StarterPlayer > StarterPlayerScripts > **LocalScript** | The shop, trainer, pen, rebirth and World Gate windows |
| `src/StarterPlayer/StarterPlayerScripts/ClientCombat.client.lua` | StarterPlayer > StarterPlayerScripts > **LocalScript** | Sends your aim to the server when you click with your weapon |
| `studio-tools/SetupTestPlace.lua`, `TestCheats.lua` | Pasted into Studio's Command Bar, never synced | Builds a test map; testing cheats |
| `tools/export_config.js` | Stays on your computer | Re-creates `ConfigData.lua` from the JavaScript game |
| `default.project.json` | Used by Rojo | Tells Rojo which folder goes to which Studio service |

## Using Rojo

Rojo keeps the files in this repo and the Studio place in sync, so Claude Code can edit the files and Studio updates live.

1. Install Rojo (the Rojo docs recommend the Rokit tool manager: `rokit add rojo-rbx/rojo`) and install the Rojo plugin into Studio.
2. In this `roblox/` folder run `rojo serve`.
3. In Studio, open a Baseplate place, open the Rojo plugin and click Connect.
4. Edit files in `src/`; changes appear in Studio. Scripts only flow one way for the files in `src/`: edit them in the repo, not in Studio.

Rojo only manages scripts. The map, plots, rigs and other parts live in the Studio place; run `studio-tools/SetupTestPlace.lua` in the Command Bar to build a test map, and save the place with File > Save to Roblox.

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
node export_config.js ../../game/index.html ../src/ReplicatedStorage/Config/ConfigData.lua
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

Done so far: combat (sword, staff, bow in `CombatService`), one generated test tower with a boss (`TowerService`), boss slam, summons and enrage (`DungeonService`). Still to do:

1. **First Play test** and fixing the errors it shows (nothing here has run in Studio yet).
2. **Boss charge** (the JS `chargeAI`) and the class abilities (Shield Slam, Blink Burst, Arrow Volley).
3. **More towers:** call `TowerService.Build` for depths 2 to 9 and lock each door until `profile.bestDepth >= depth - 1`. Enemies use `MoveTo` for now; switch to PathfindingService if they get stuck on ramps.
5. **Real models, egg visuals, sound and music.**

## Checking the scripts without Studio

`npm test` runs a rough block check. For a real type check, get `luau-lsp` and `globalTypes.d.luau` from
https://github.com/JohnnyMorganz/luau-lsp and run
`LUAU_LSP=path/to/luau-lsp ROBLOX_DEFS=path/to/globalTypes.d.luau bash roblox/tools/luau_check.sh`.
What to try in Studio for each slice is in `docs/TESTING.md`.

## Testing it (see also `studio-tools/SetupTestPlace.lua` and `TestCheats.lua`)

1. Paste `studio-tools/SetupTestPlace.lua` into View > Command Bar (in Edit mode) to build the 8 plots, the TownZone and the enemy rigs for you.
2. Add the scripts from the table above, then press **Test > Play** and look at the Output window (View > Output) for red errors.
3. Use **Test > Server & Clients** with 2 clients to check that each player gets their own plot.
4. While playing, use the Client/Server toggle to switch to Server view and paste a line from `TestCheats.lua` to give yourself coins, eggs, a better weapon or a boss.
5. Walk south from the spawn to the tower marked "Dungeon 1". Stepping through the door fills it with enemies. Click to attack. Beat the boss on the top floor, take the egg (everything wakes up) and run back to the middle of the map to bank it. The egg appears in your backpack (bottom of the screen): equip it, click inside your pen to place it, wait for "Ready!" and press E next to it to hatch it.
