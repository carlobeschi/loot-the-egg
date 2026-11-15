# Loot the Egg: notes for Claude Code

3D browser action game (three.js r128, one file) plus a Roblox port (Rojo project) and a Scratch version. Read `docs/HANDOVER.md` first: it has the current state, gotchas and next steps.

- Game: `game/index.html` (single file, no build). `npm test` must pass before every commit (syntax check plus a stubbed-THREE generation test for both worlds). It does not render anything, so look at visual changes in a real browser.
- The game file has several older duplicate function definitions (`mkTree`, `mkPlayer`, `mkEnemy`, `decorate`...). The LAST definition in the file is the live one. Edit that one, or the change has no effect.
- Roblox: `roblox/` is a Rojo project (`default.project.json`, scripts in `src/`). Edit scripts in the repo, never in Studio. Numbers come from the JS game via `npm run export:roblox`. Nothing in `roblox/` has been run in Studio yet.
- Commit to `main` in small commits. Co-author lines as in the existing history.
- The owner is Carlo; a family member, Lorenzo, is also working on the Roblox side. Plain, short explanations work best.
