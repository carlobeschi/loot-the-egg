// export_config.js
// Copies the balance numbers (rarities, pets, income, rebirth, weapons, upgrade costs...) out of the
// JavaScript game and writes them as a Roblox ModuleScript (ConfigData.lua).
//
// Usage (needs Node.js):   node export_config.js ../../game/index.html ../ConfigData.lua
// Run it again any time you change numbers in the JavaScript game, then paste the new ConfigData.lua
// into Roblox Studio (ReplicatedStorage > Config > ConfigData).
const fs = require('fs');
const htmlPath = process.argv[2] || '../../game/index.html';
const outPath = process.argv[3] || '../ConfigData.lua';

const html = fs.readFileSync(htmlPath, 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
const code = scripts[scripts.length - 1][1];

// --- tiny stand-ins for the browser + three.js so the game script can load in Node ---
const mk = () => new Proxy(function () {}, {
  get: (t, p) => {
    if (('__s_' + String(p)) in t) return t['__s_' + String(p)];
    if (p === Symbol.toPrimitive) return () => 0;
    if (p === 'length') return 0;
    if (p === 'children') return [mk(), mk(), mk()];
    if (p === 'parent') return null;
    if (p === 'classList') return { add() {}, remove() {} };
    if (p === 'style') return {};
    if (p === 'dataset') return {};
    return mk();
  },
  apply: () => mk(), construct: () => mk(),
  set: (t, p, v) => { t['__s_' + String(p)] = v; return true; },
});
const els = {};
global.document = {
  createElement: () => ({ getContext: () => mk(), width: 0, height: 0 }),
  getElementById: (id) => els[id] || (els[id] = Object.assign(mk(), { width: 160, height: 104 })),
  querySelectorAll: () => [], addEventListener() {}, pointerLockElement: null, hidden: false,
};
global.window = global; global.devicePixelRatio = 1; global.addEventListener = () => {};
global.localStorage = { getItem: () => null, setItem() {} };
global.requestAnimationFrame = () => 0; global.performance = { now: () => 0 };
global.THREE = new Proxy({}, { get: () => mk() });
global.THREE.Vector3 = class { set() { return this; } copy() { return this; } lerp() { return this; } };

(0, eval)(code + '\n;globalThis.__cfg={RN,RC,INC,PT,RBR,RBM,WN,WP,WC,PERK,PC,PN,CL,UC,UL,AN};');
const cfg = globalThis.__cfg;

const hex = (n) => '#' + n.toString(16).padStart(6, '0');
const cap = (s) => s[0].toUpperCase() + s.slice(1);
const classes = ['knight', 'wizard', 'bowman'];
const costs = (fn, max) => Array.from({ length: max }, (_, l) => fn(l));

const data = {
  rarities: cfg.RN,
  rarityColors: cfg.RC.map(hex),
  income: cfg.INC, // coins per second for each rarity (before the rebirth multiplier)
  pets: cfg.PT.map((row) => row.map((p) => ({ name: p[0], color: hex(p[1]), accent: hex(p[2]), wings: p[3] }))),
  rebirth: { required: cfg.RBR.map((r) => r + 1), cost: cfg.RBM, multiplierStep: 0.5 }, // rarity is 1-based here
  pen: { colors: cfg.PC.map(hex), names: cfg.PN, baseCapacity: 6, capacityPerLevel: 2 },
  classes: Object.fromEntries(classes.map((c) => [cap(c), { health: cfg.CL[c].hp, speed: cfg.CL[c].sp, cooldownMs: cfg.CL[c].cd, ability: cfg.AN[c] }])),
  weapons: Object.fromEntries(classes.map((c) => [cap(c), { names: cfg.WN[c], prices: cfg.WP, colors: cfg.WC[c].map(hex), perk: cfg.PERK[c] }])),
  upgrades: {
    health: { max: cfg.UL.h, costs: costs(cfg.UC.h, cfg.UL.h) },
    speed: { max: cfg.UL.s, costs: costs(cfg.UC.s, cfg.UL.s) },
    ability: { max: cfg.UL.a, costs: costs(cfg.UC.a, cfg.UL.a) },
  },
};

// --- JavaScript value -> Lua table text ---
function lua(v, ind = '') {
  const pad = ind + '\t';
  if (Array.isArray(v)) {
    if (v.every((x) => typeof x !== 'object')) return '{ ' + v.map((x) => lua(x)).join(', ') + ' }';
    return '{\n' + v.map((x) => pad + lua(x, pad)).join(',\n') + '\n' + ind + '}';
  }
  if (v && typeof v === 'object') {
    return '{\n' + Object.entries(v).map(([k, x]) => pad + (/^[A-Za-z_]\w*$/.test(k) ? k : `["${k}"]`) + ' = ' + lua(x, pad)).join(',\n') + '\n' + ind + '}';
  }
  if (typeof v === 'string') return JSON.stringify(v);
  return String(v);
}

const header = `--[[ ConfigData (ModuleScript, child of Config in ReplicatedStorage)
  GENERATED from the JavaScript game by tools/export_config.js - do not edit by hand.
  Re-run the tool after changing numbers in the JavaScript game.
  NOTE: Lua tables start at 1. Rarity 1 = Common ... rarity 8 = Divine. Weapon tier arrays start at tier 0 in the
  JavaScript game, so tier N is index N+1 here. Colors are hex strings; use Color3.fromHex(...).
]]
`;
fs.writeFileSync(outPath, header + 'return ' + lua(data) + '\n');
console.log('Wrote', outPath);
