# Loot the Egg

*Un gioco divertente con uova, nemici e spade.* A fun game with eggs, enemies and swords.

A 3D action game that runs in the browser. Pick a class (Knight, Wizard or Bowman), explore a forest, clear dungeon towers, beat the bosses, grab their eggs and run home with everything chasing you. Eggs hatch into pets that live in your pen and earn coins.

## Run it

Open `game/index.html` in a browser (it loads three.js r128 from a CDN, so you need internet). No build step.

Controls: WASD or arrows move, mouse looks and aims, click or space attacks, V switches first/third person, Q is the class ability, 1/2/3 picks a class, M mutes the music. At home: E hatches an egg, F equips your best pets, P upgrades the pen, X sells a pet, R rebirths, H/J/K buy health, speed and ability upgrades. Walk into the shop buildings for weapons and upgrades. In-game messages explain the rest.

## What's in the repo

| Folder | What it is |
|---|---|
| `game/` | The game: a single self-contained `index.html` (three.js). This is the source of truth for design and balance. |
| `roblox/` | Luau starter kit for the Roblox port (pets, pen plots, data saving, dungeon loop, HUD). `tools/export_config.js` copies the numbers from the JS game into `ConfigData.lua`. |
| `scratch/` | A simplified top-down Scratch version (`loot-the-egg.sb3`) and the script that builds it. |
| `site/` | Landing page. `tools/build_site.sh` puts it together with the game into `dist/`. |
| `hosting/` | Firebase Hosting config and steps for putting `dist/` online. |
| `tools/` | Build and test scripts. |
| `docs/` | Design decisions, changelog, roadmap. |

## Commands

```
npm test              # syntax check + generation test for both worlds (no browser needed)
npm run build:site    # builds dist/ (landing page + /play/)
npm run export:roblox # regenerates roblox/ConfigData.lua from the game
npm run build:scratch # rebuilds scratch/loot-the-egg.sb3
```

## Status

Playable prototype. World 1 (Whispering Woods) and World 2 (Ember Wastes, unlocked at the World Gate) work. The Roblox kit has economy, pets and saving but not yet combat, towers or bosses. See `docs/ROADMAP.md`.

Browser scripts are tested with a stubbed THREE.js harness, not in a real browser, so look at the game after big visual changes.

## Licence

GNU General Public License v3.0, see `LICENSE`.
