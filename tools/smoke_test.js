// Quick checks for game/index.html: 1) the game script parses, 2) characters and both worlds' terrain generate
// without errors under a stubbed THREE.js (no browser needed). Run: node tools/smoke_test.js
const fs=require('fs'),path=require('path'),cp=require('child_process');
const html=fs.readFileSync(path.join(__dirname,'..','game','index.html'),'utf8');
const scripts=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
const tmp=path.join(require('os').tmpdir(),'loot-the-egg-game.js');
fs.writeFileSync(tmp,scripts[scripts.length-1][1]);
cp.execFileSync('node',['--check',tmp],{stdio:'inherit'});console.log('syntax ok');
const out=cp.execFileSync('node',[path.join(__dirname,'stub.js')]).toString().trim();
console.log('generation:',out);if(out!=='ok')process.exit(1);
