#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {readImage,isPng} from './lib/image.mjs';
import {greenMatte,whiteMatte,borderKey} from './lib/matte.mjs';
export function components({width:w,height:h,data},{alpha=127,mergeDistance=0}={}) {
  const n=w*h,seen=new Uint8Array(n),owners=new Int32Array(n),queue=new Int32Array(n),found=[];
  for(let seed=0;seed<n;seed++){
    if(seen[seed]||data[seed*4+3]<=alpha)continue;
    let head=0,tail=1;queue[0]=seed;seen[seed]=1;
    let x0=w,y0=h,x1=0,y1=0;
    while(head<tail){const p=queue[head++],x=p%w,y=Math.floor(p/w);owners[p]=found.length+1;x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);
      for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){if(x+dx<0||x+dx>=w||y+dy<0||y+dy>=h)continue;const q=(y+dy)*w+x+dx;if(!seen[q]&&data[q*4+3]>alpha){seen[q]=1;queue[tail++]=q;}}
    }
    found.push({area:tail,bbox:[x0,y0,x1-x0+1,y1-y0+1],edgeContact:x0===0||y0===0||x1===w-1||y1===h-1});
  }
  // Multi-source distance expansion measures blank-pixel Manhattan separation.
  const pairGaps=new Map(),distances=new Int32Array(n);let head=0,tail=0,minimumPixelGap=null;
  for(let p=0;p<n;p++)if(owners[p])queue[tail++]=p;
  while(head<tail){const p=queue[head++],x=p%w,y=Math.floor(p/w);
    for(const q of [x?p-1:-1,x+1<w?p+1:-1,y?p-w:-1,y+1<h?p+w:-1]){if(q<0)continue;
      if(!owners[q]){owners[q]=owners[p];distances[q]=distances[p]+1;queue[tail++]=q;}
      else if(owners[q]!==owners[p]){const gap=distances[p]+distances[q],key=[owners[p]-1,owners[q]-1].sort((a,b)=>a-b).join(',');pairGaps.set(key,Math.min(pairGaps.get(key)??Infinity,gap));minimumPixelGap=minimumPixelGap===null?gap:Math.min(gap,minimumPixelGap);}
    }
  }
  // Merging is opt-in from the brief; never discard small components.
  const gap=(a,b)=>Math.hypot(Math.max(0,a.bbox[0]-b.bbox[0]-b.bbox[2],b.bbox[0]-a.bbox[0]-a.bbox[2]),Math.max(0,a.bbox[1]-b.bbox[1]-b.bbox[3],b.bbox[1]-a.bbox[1]-a.bbox[3]));
  if(mergeDistance>0){
    const parents=found.map((_,i)=>i),root=i=>parents[i]===i?i:(parents[i]=root(parents[i]));
    for(const [key,distance] of pairGaps)if(distance<=mergeDistance){const [a,b]=key.split(',').map(Number);parents[root(b)]=root(a);}
    const groups=new Map();
    for(let i=0;i<found.length;i++){const id=root(i),b=found[i];if(!groups.has(id)){groups.set(id,{...b,bbox:[...b.bbox]});continue;}
      const a=groups.get(id),x=Math.min(a.bbox[0],b.bbox[0]),y=Math.min(a.bbox[1],b.bbox[1]);
      a.bbox=[x,y,Math.max(a.bbox[0]+a.bbox[2],b.bbox[0]+b.bbox[2])-x,Math.max(a.bbox[1]+a.bbox[3],b.bbox[1]+b.bbox[3])-y];a.area+=b.area;a.edgeContact ||= b.edgeContact;
    }
    found.splice(0,found.length,...groups.values());
  }
  found.sort((a,b)=>a.bbox[0]-b.bbox[0]||a.bbox[1]-b.bbox[1]);
  let minimumGap=null;for(let i=0;i<found.length;i++)for(let j=i+1;j<found.length;j++){const g=gap(found[i],found[j]);minimumGap=minimumGap===null?g:Math.min(minimumGap,g);}
  return {components:found,minimumGap:minimumPixelGap,gapMetric:'Manhattan blank pixels before optional merging',bboxGapLowerBound:minimumGap};
}
export function alphaMetrics({width:w,height:h,data}) {
  let ring=0,light=0,semiInterior=0,green=0;const levels=new Set();
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){const p=(y*w+x)*4,a=data[p+3];levels.add(a);if(a>25&&data[p+1]-Math.max(data[p],data[p+2])>24)green++;if(a<=127)continue;
    const neighbors=[[x-1,y],[x+1,y],[x,y-1],[x,y+1]];
    const interior=neighbors.every(([xx,yy])=>xx>=0&&yy>=0&&xx<w&&yy<h&&data[(yy*w+xx)*4+3]>127);
    if(!interior){ring++;if(.2126*data[p]+.7152*data[p+1]+.0722*data[p+2]>178.5)light++;}
    else if(a<250)semiInterior++;
  }
  return {outlineRingPixels:ring,lightRingPixels:light,fringeRatio:ring?light/ring:0,alphaLevels:levels.size,semiTransparentInterior:semiInterior,greenExcessPixels:green};
}
export function inspect(image,{expectedCount,mergeDistance=0,referenceBody=false}={}) {
  const {width:w,height:h,data}=image,reasons=[],key=borderKey(image);let transparent=false;
  for(let i=3;i<data.length;i+=4)if(data[i]<255){transparent=true;break;}
  let borderTotal=0,borderMatch=0,greenInterior=0,spread=0;
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    const p=(y*w+x)*4,d=Math.hypot(data[p]-key[0],data[p+1]-key[1],data[p+2]-key[2]);
    if(x===0||y===0||x===w-1||y===h-1){borderTotal++;if(transparent?data[p+3]===0:d<=12)borderMatch++;}
    const e=data[p+1]-Math.max(data[p],data[p+2]);
    if(!transparent&&e>100&&x>=4&&y>=4&&x<w-4&&y<h-4){
      // Ignore antialiased outline transitions: test only a uniformly green neighbourhood.
      let uniform=true;
      for(const [dx,dy] of [[-4,0],[4,0],[0,-4],[0,4]]){const q=((y+dy)*w+x+dx)*4;if(Math.hypot(data[q]-data[p],data[q+1]-data[p+1],data[q+2]-data[p+2])>12)uniform=false;}
      if(uniform){spread=Math.max(spread,d);if(d>40)greenInterior++;}
    }
  }
  if(borderMatch/borderTotal<.98)reasons.push('background-border-or-edge-contact');
  if(spread>24)reasons.push('background-not-flat-or-green-content');
  if(greenInterior)reasons.push('green-interior-content');
  let matte=image;
  if(!transparent){try{matte=Math.min(...key)>230?whiteMatte(image):greenMatte(image,{key});}catch(e){reasons.push(e.message);}}
  const metrics=alphaMetrics(matte);
  if(transparent&&metrics.fringeRatio>.02)reasons.push('light-outline-halo');
  if(transparent&&metrics.semiTransparentInterior)reasons.push('semi-transparent-interior');
  if(metrics.greenExcessPixels)reasons.push('opaque-green-excess');
  const segmented=components(matte,{mergeDistance});
  if(segmented.components.some(c=>c.edgeContact))reasons.push('item-edge-contact');
  const itemCount=segmented.components.length-(referenceBody&&segmented.components.length?1:0);
  if(expectedCount!==undefined&&itemCount!==expectedCount)reasons.push('component-count-mismatch-or-touching-items');
  return {pass:reasons.length===0,reasons,nativeSize:[w,h],alphaSource:transparent,metrics,itemCount,referenceBody:referenceBody?segmented.components[0]:null,background:{key,borderShare:borderMatch/borderTotal,spread,greenInterior},...segmented};
}
export function intake(file,provenance,options={}) {
  if(options.expectedCount!==undefined&&(!Number.isInteger(options.expectedCount)||options.expectedCount<1))throw Error('expectedCount must be a positive integer');
  const report={file,sha1:createHash('sha1').update(fs.readFileSync(file)).digest('hex')};
  if(!isPng(file))return {...report,pass:false,reasons:['not-png']};
  let valid=false;try{const p=JSON.parse(fs.readFileSync(provenance,'utf8'));valid=!!p&&typeof p==='object'&&!Array.isArray(p);}catch{}
  Object.assign(report,inspect(readImage(file),options));if(!valid){report.pass=false;report.reasons.push('invalid-provenance-json');}
  return report;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const [file,provenance,count]=process.argv.slice(2);if(!file||!provenance)throw Error('Usage: node tools/doll/intake.mjs IMAGE.png PROVENANCE.json [EXPECTED_COUNT]');
  const report=intake(file,provenance,{expectedCount:count===undefined?undefined:Number(count)});fs.writeFileSync(`${file}.intake.json`,JSON.stringify(report,null,2)+'\n');console.log(`${report.pass?'PASS':'FAIL'} ${file}: ${report.reasons.join(', ')}`);process.exitCode=report.pass?0:1;
}
