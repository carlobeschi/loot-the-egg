// Writes a Rojo-style sourcemap.json for the Luau checker (luau-lsp), without needing Rojo installed.
// It follows default.project.json and Rojo's file rules (init.lua, .server.lua, .client.lua).
// Run: node roblox/tools/sourcemap.js > sourcemap.json  (paths are relative to roblox/)
const fs=require('fs'),path=require('path');
const root=path.join(__dirname,'..');
const project=JSON.parse(fs.readFileSync(path.join(root,'default.project.json'),'utf8'));
function scriptClass(f){return f.endsWith('.server.lua')?'Script':f.endsWith('.client.lua')?'LocalScript':'ModuleScript'}
function baseName(f){return path.basename(f).replace(/\.(server|client)\.lua$|\.lua$/,'')}
function fromPath(rel,name){
  const abs=path.join(root,rel);
  if(fs.statSync(abs).isFile())return{name,className:scriptClass(rel),filePaths:[rel]};
  const entries=fs.readdirSync(abs).sort();
  const init=entries.find(e=>/^init(\.server|\.client)?\.lua$/.test(e));
  const node=init?{name,className:scriptClass(init),filePaths:[path.join(rel,init)]}:{name,className:'Folder'};
  node.children=entries.filter(e=>e!==init&&(e.endsWith('.lua')||fs.statSync(path.join(abs,e)).isDirectory()))
    .map(e=>fromPath(path.join(rel,e),fs.statSync(path.join(abs,e)).isDirectory()?e:baseName(e)));
  return node}
function fromTree(name,t){
  let node=t.$path?fromPath(t.$path,name):{name,className:t.$className||'Folder',children:[]};
  if(t.$className)node.className=t.$className==='DataModel'?'DataModel':(t.$path&&node.filePaths?node.className:t.$className);
  node.children=node.children||[];
  for(const k of Object.keys(t))if(!k.startsWith('$'))node.children.push(fromTree(k,t[k]));
  return node}
process.stdout.write(JSON.stringify(fromTree(project.name,project.tree),null,1));
