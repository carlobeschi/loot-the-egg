const path=require('path');
const extract=()=>{const h=require('fs').readFileSync(path.join(__dirname,'..','game','index.html'),'utf8');const m=[...h.matchAll(/<script>([\s\S]*?)<\/script>/g)];return m[m.length-1][1]};
const fs=require('fs'),vm=require('vm');
const mk=()=>{const f=function(){};return new Proxy(f,{get(t,k){if(k===Symbol.toPrimitive)return()=>1;if(k==='length')return 0;if(k==='then')return undefined;if(k==='count')return 0;if(!(k in t))t[k]=mk();return t[k]},set(t,k,v){t[k]=v;return true},apply(){return mk()},construct(){return mk()}})};
const T=mk();
const doc=mk();
const ctx={THREE:T,document:doc,window:null,console,Math,Date,performance:{now:()=>0},requestAnimationFrame(){},addEventListener(){},localStorage:{getItem(){return null},setItem(){}},devicePixelRatio:1,innerWidth:1000,innerHeight:600,setTimeout(){},setInterval(){},AudioContext:function(){return mk()},Float32Array,Uint8Array,Array,Object,JSON,Number,String,parseInt,parseFloat,isNaN,Infinity,NaN};
ctx.window=ctx;ctx.self=ctx;ctx.navigator={userAgent:'x'};
vm.createContext(ctx);
let code=extract()+'\n;globalThis.__t=()=>{for(const k of ["knight","wizard","bowman"]){mkPlayer(k);mkVM(k)}world=1;gen();world=2;gen();return "ok"}';
try{vm.runInContext(code,ctx);console.log(ctx.__t())}catch(e){console.log('ERR',e.stack.split('\n').slice(0,5).join('\n'))}
