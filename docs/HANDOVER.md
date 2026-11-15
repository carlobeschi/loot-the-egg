# Handover (2026-11-15)

Written at the end of the chat session that built the game, so work can continue in Claude Code. Repo: https://github.com/carlobeschi/loot-the-egg (branch `main`, licence GPL-3.0).

## 1. What this is

"Loot the Egg": pick a class (Knight, Wizard, Bowman), explore a forest, clear dungeon towers, beat bosses, take the egg (everything wakes up, run home). Eggs hatch into pets in your pen that earn coins. Shops, rebirth, Equip Best, settings, World 2. Full list of what the owner asked for: `docs/DESIGN.md`.

The owner wants to publish it on Roblox, and keep the JavaScript game as the working prototype and source of balance numbers.

## 2. Repo map

| Path | What |
|---|---|
| `game/index.html` | The whole browser game (three.js r128 from a CDN, Fredoka font). Version 55 of the old claude.ai artifact, which is now just an old copy. This repo is the source of truth. |
| `roblox/` | Luau starter kit as a Rojo project. `default.project.json`, scripts in `src/`, Command Bar helpers in `studio-tools/`, `tools/export_config.js`. |
| `scratch/` | Simplified top-down Scratch version `loot-the-egg.sb3`, built by `build_sb3.py` (python3, no packages). Never opened in Scratch. |
| `site/`, `hosting/` | Landing page and Firebase Hosting steps. The owner dropped hosting for now. `tools/build_site.sh` builds `dist/`. |
| `tools/` | `smoke_test.js` and `stub.js` (test harness). |
| `docs/` | `DESIGN.md`, `CHANGELOG.md`, `ROADMAP.md`, this file. |

Commands: `npm test`, `npm run build:site`, `npm run export:roblox`, `npm run build:scratch`.

## 3. Browser game: how it works and what to watch for

- Coordinates: game (x, y) maps to three.js (x, z). `P.z` is height, `P.f` is the floor. Floor height `FH=150`, wall height `WH=FH-3`.
- Towers: 300 wide and 300 deep, ramps alternate east/west (`rxOf`). World 1 map 3200x2080 with 5 towers at a time (a sliding window of depths in `DD`, `initDD`, `withSeed` for stable layouts). World 2 map 4000x2600 with 9 towers (depths 10-18, 5 floors).
- Collision list `O` with types tree, rock, pond, post, wall, pil, x (keep-clear). `block()` and `kick()` resolve collisions; updates are substepped (dt <= 1) in `loop` so lag does not create invisible walls.
- Save: localStorage key `oaths3`.
- Weapons: 12 tiers per class. Rarity: 8 tiers. Rebirth: 12 levels.
- Weapon looks: `mkPlayer` (third person), `mkVM` (first-person viewmodel), `tintVM` and `decorate` (tier effects). `tintVM` indexes weapon children (`children[0]`, `children[1]`), so keep the shaft/blade first and the orb/second part second when changing weapon models.
- Characters use rounded boxes from `rbox()`; the wizard staff pulses via `userData.pl/rg` in the loop.

**Gotcha: duplicate definitions.** The file contains older copies of several functions (`mkTree`, `mkPlayerOld`, `mkPlayerOld2`, `mkEnemy`, `decorateOld`, `faceOld`, ...). JavaScript uses the last definition. A good cleanup task: delete the dead copies, run `npm test`, and look at the game in a browser.

**Testing limits.** `npm test` uses a stubbed THREE (Proxy fake) in `tools/stub.js`. It catches syntax and runtime reference errors in `mkPlayer`, `mkVM` and terrain generation for both worlds, but nothing is rendered. The last visual changes (bigger/darker trees with shadows, rounder characters, smaller weapons, terrain props) were never looked at in a real browser: do that first.

Recent balance change: World 1 bosses nerfed (health about -20%, hit about -25%, slam and charge less often, softer enrage); World 2 unchanged. See `docs/CHANGELOG.md`.

## 4. Roblox port

State: economy, pets, pen plots, saving (DataStore), egg loop, HUD, combat (`CombatService`, `ClientCombat`), Dungeons 1 to 9 with gates (`TowerService`, `ClientTowers`), eggs as backpack items you place and hatch in your pen (`EggService`, `ClientEggs`), shops and screens (`ShopService`, `ClientShops`), and boss slam, charge, summon and enrage are written. NOT written: class abilities, the World 2 map and towers, real models. Carlo and Lorenzo Play-tested the combat, tower and egg slices on 2026-11-15 (no script errors); later slices may not have been tried in Studio yet, see `docs/TESTING.md`. Type-check with `roblox/tools/luau_check.sh` (luau-lsp; Carlo approved downloading it in cloud sessions). `tools/lua_check.js` (part of `npm test`) only checks that blocks and brackets balance. Per-slice test steps: `docs/TESTING.md`. Test cheats go through `ServerStorage.Cheat` (Studio only), because the Command Bar gets its own copy of required modules.

Workflow: `rojo serve` in `roblox/`, connect from the Studio plugin, edit files in `src/` with Claude Code, never in Studio. Rojo manages scripts only. Build the test map with `studio-tools/SetupTestPlace.lua` (Command Bar), cheats in `TestCheats.lua`. Numbers come from the JS game: `npm run export:roblox`.

The owner's setup status when this was written: has the Roblox account and a parent account; about to install Studio, make a Baseplate place, and install Rojo (steps were given). Next step is the first Play test and pasting errors back for fixing.

Suggested order of work: (1) get the existing scripts running without errors; (2) one tower, one boss and combat (a vertical slice); (3) shop and World Gate UI; (4) private publish and testing with early testers; (5) public release.

Publishing rules as read from Roblox docs on 2026-11-15 (they change, re-check): Studio File > Publish, up to 10 early testers, a content ratings questionnaire (answering No to age-restricted content gives Content May Vary, available to age-checked 16+). For under-16 players (Kids and Select) the account needs 2FA, 2 months of Premium or a 1,000 Robux fee, a rating of Mild or Moderate (9+), and evaluation (250 unique plays from engaged, age-checked players within 60 days). Sources: create.roblox.com docs "Publish experiences and places" and "Kids and Select". Developer Exchange (cashing out Robux) rules were NOT verified. Eggs must never be buyable (owner's rule).

## 5. Scratch version

`scratch/loot-the-egg.sb3` is a simplified top-down game generated by `scratch/build_sb3.py`. The owner decided against pursuing Scratch ("back to the game"); a written block-by-block guide exists as a Claude Docs document made in the earlier session. Low priority.

## 6. Environment notes

- Cloud sessions here: pushing to `main` works; pushing tags and deleting branches were refused (HTTP 403 by the session proxy). `v0.1.0` exists locally in the original session but is not on GitHub.
- The browser game needs internet for the three.js CDN. Making it work offline (local copy) is on the roadmap.

## 7. Suggested next steps

1. Open `game/index.html` in a browser and check the recent visual changes (trees, shadows, characters, weapons, terrain). Tune if needed.
2. Remove dead duplicate functions from the game file (see section 3).
3. Roblox: first Play test, fix errors, then the vertical slice (section 4).
4. Polish the Knight sword and Bowman bow like the staff.
5. Minimap marker for the newest unlocked dungeon; more boss variety.
