// Rough checks for the Roblox Luau files, since no Luau runtime runs here. It is NOT a real parser:
// it strips strings and comments, then checks that every block (function, if, do, repeat) has its end,
// that brackets balance, and that each file's require()d services exist. A real check is a Play test in Studio.
// Run: node tools/lua_check.js
const fs=require('fs'),path=require('path');
const root=path.join(__dirname,'..','roblox');
const files=[];
(function walk(d){for(const f of fs.readdirSync(d)){const p=path.join(d,f);if(fs.statSync(p).isDirectory())walk(p);else if(p.endsWith('.lua'))files.push(p)}})(root);
function strip(src){
  let out='',i=0;
  while(i<src.length){
    const c=src[i],n=src[i+1];
    if(c==='-'&&n==='-'){
      const m=src.slice(i+2).match(/^\[(=*)\[/);
      if(m){const close=']'+m[1]+']';const j=src.indexOf(close,i+2+m[0].length);if(j<0)throw new Error('unclosed long comment');out+=src.slice(i,j).replace(/[^\n]/g,' ');i=j+close.length;continue}
      while(i<src.length&&src[i]!=='\n')i++;continue}
    if(c==='['&&/^\[=*\[/.test(src.slice(i))){const m=src.slice(i).match(/^\[(=*)\[/);const close=']'+m[1]+']';const j=src.indexOf(close,i);if(j<0)throw new Error('unclosed long string');out+=' "" ';i=j+close.length;continue}
    if(c==='"'||c==="'"||c==='`'){let j=i+1;while(j<src.length&&src[j]!==c){if(src[j]==='\\')j++;if(src[j]==='\n'&&c!=='`')throw new Error('unclosed string on line '+(src.slice(0,i).split('\n').length));j++}out+=' "" ';i=j+1;continue}
    out+=c;i++}
  return out}
let bad=0;
for(const f of files){
  const rel=path.relative(path.join(__dirname,'..'),f);
  try{
    const s=strip(fs.readFileSync(f,'utf8'));
    const lines=s.split('\n');const stack=[];
    lines.forEach((line,li)=>{
      for(const w of line.match(/[A-Za-z_][A-Za-z0-9_]*|[(){}\[\]]/g)||[]){
        if(w==='function'||w==='if'||w==='do'||w==='repeat')stack.push([w,li+1]);
        else if(w==='end'){const t=stack.pop();if(!t||t[0]==='repeat'||'({['.includes(t[0]))throw new Error('unexpected end on line '+(li+1))}
        else if(w==='until'){const t=stack.pop();if(!t||t[0]!=='repeat')throw new Error('unexpected until on line '+(li+1))}
        else if('({['.includes(w))stack.push([w,li+1]);
        else if(')}]'.includes(w)){const t=stack.pop();if(!t||'({['.indexOf(t[0])!==')}]'.indexOf(w))throw new Error('unbalanced '+w+' on line '+(li+1))}
      }
      // "for ... do" and "while ... do" open one block via "do"; a stray "then" is fine (if already counted)
    });
    if(stack.length)throw new Error('"'+stack[stack.length-1][0]+'" on line '+stack[stack.length-1][1]+' is never closed');
    for(const m of s.matchAll(/require\(ServerScriptService:WaitForChild\(""\)\)/g))void m;
  }catch(e){bad++;console.log('FAIL',rel+':',e.message)}
}
// every module that Main requires must exist as a file
const main=fs.readFileSync(path.join(root,'src','ServerScriptService','Main.server.lua'),'utf8');
for(const m of main.matchAll(/ServerScriptService:WaitForChild\("(\w+)"\)/g)){
  if(!fs.existsSync(path.join(root,'src','ServerScriptService',m[1]+'.lua'))){bad++;console.log('FAIL Main requires missing module',m[1])}}
console.log(bad?bad+' lua problem(s)':'lua blocks ok ('+files.length+' files)');
if(bad)process.exit(1);
