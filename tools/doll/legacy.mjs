#!/usr/bin/env node
// Legacy-sheet placement. Residuals are review flags, never permission to warp anatomy.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {readImage,writeImage} from './lib/image.mjs';
import {crop,isolateLargest} from './lib/registration.mjs';
import {bodyPreflight,matte,warp,splitHair} from './register.mjs';
export function parseCrop(text){if(Array.isArray(text))return text;const m=/^(\d+)x(\d+)\+(\d+)\+(\d+)$/.exec(text);if(!m)throw Error('Expected WxH+X+Y crop');return [+m[3],+m[4],+m[1],+m[2]];}
export function bbox(image){let x0=image.width,y0=image.height,x1=-1,y1=-1;for(let y=0;y<image.height;y++)for(let x=0;x<image.width;x++)if(image.data[(y*image.width+x)*4+3]>127){x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);}if(x1<0)throw Error('Empty item');return [x0,y0,x1-x0+1,y1-y0+1];}
export function faceOpening(image){const {width:w,height:h,data}=image,seen=new Uint8Array(w*h),holes=[];
 for(let p=0;p<w*h;p++){if(seen[p]||data[p*4+3]>127)continue;const q=[p];seen[p]=1;let edge=false,x0=w,y0=h,x1=0,y1=0;
 for(let k=0;k<q.length;k++){const i=q[k],x=i%w,y=Math.floor(i/w);edge ||= x===0||y===0||x===w-1||y===h-1;x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);for(const [xx,yy] of [[x-1,y],[x+1,y],[x,y-1],[x,y+1]]){const j=yy*w+xx;if(xx>=0&&yy>=0&&xx<w&&yy<h&&!seen[j]&&data[j*4+3]<=127){seen[j]=1;q.push(j);}}}
 if(!edge)holes.push({area:q.length,bbox:[x0,y0,x1-x0+1,y1-y0+1]});}
 const hole=holes.sort((a,b)=>b.area-a.area)[0];if(!hole)throw Error('Hair requires a closed face opening; request a proof or front mask');return hole.bbox;
}
export function anchor(image,slot,rig,side){const b=bbox(image),cx=b[0]+(b[2]-1)/2,lm=rig.landmarks;
 if(slot==='hair'){const h=faceOpening(image);return {source:[h[0]+(h[2]-1)/2,h[1]+h[3]-1],target:[lm.centre_x,lm.chin_y],rule:'face-opening centre x and chin; preserve sheet scale'};}
 if(slot==='shoes'){if(!['l','r'].includes(side))throw Error('Each shoe must specify image-side l or r');return {source:[cx,b[1]+b[3]-1],target:lm[`sole_${side}`],rule:'individual sole centre'};}
 if(slot==='hat')return {source:[cx,b[1]+b[3]-1],target:lm.head_top,rule:'hat lower centre on head top'};
 if(slot==='bottom')return {source:[cx,b[1]],target:[lm.centre_x,lm.waist_y],rule:'waistband centre'};
 if(slot==='top'||slot==='dress'){let y=b[1];for(;y<b[1]+b[3]*.5;y++)if(image.data[(y*image.width+Math.round(cx))*4+3]>127)break;return {source:[cx,b[1]],target:[lm.centre_x,lm.neck_y],rule:'neck opening upper plane, centred horizontally'};}
 throw Error(`Unsupported legacy slot ${slot}; use a proof or explicit Bench nudge`);
}
function refine(image,initial,slot,rig,regions){const labels=rig.regions.labels,rule=rig.slots[slot]??{},covers=(rule.covers??[]).map(n=>labels[n]),forbidden=(rule.never??[]).map(n=>labels[n]);
 const samples=[];for(let y=0;y<regions.height;y+=4)for(let x=0;x<regions.width;x+=4){const id=regions.data[(y*regions.width+x)*4];if(covers.includes(id)||forbidden.includes(id))samples.push([x,y,covers.includes(id)?1:-1]);}
 const score=t=>{let value=0;for(const [x,y,kind] of samples){const xx=Math.round((x-t.offset[0])/t.scale),yy=Math.round((y-t.offset[1])/t.scale),on=xx>=0&&yy>=0&&xx<image.width&&yy<image.height&&image.data[(yy*image.width+xx)*4+3]>127;value+=on?kind:0;}return value-Math.hypot(t.offset[0]-initial.offset[0],t.offset[1]-initial.offset[1])*2-Math.abs(t.scale/initial.scale-1)*1000;};
 let best=initial,value=score(best);for(const factor of slot==='hair'?[1]:[.98,1,1.02])for(const dx of [-4,0,4])for(const dy of [-4,0,4]){const t={scale:initial.scale*factor,offset:[initial.offset[0]+dx,initial.offset[1]+dy]},v=score(t);if(v>value){best=t;value=v;}}return {...best,coverage_score:value};
}
export function placeLegacy(image,item,sheetFit,rig,regions){const a=anchor(image,item.slot,rig,item.side),scale=sheetFit.scale,initial={scale,offset:a.target.map((v,k)=>v-a.source[k]*scale)},fit=refine(image,initial,item.slot,rig,regions),nudge=item.nudge??[0,0];if(item.slot==='shoes')fit.offset[1]=a.target[1]-a.source[1]*fit.scale;
 fit.offset=fit.offset.map((v,k)=>v+nudge[k]);
 const layer=warp(image,fit,...rig.frame),mask=item.frontMask?readImage(item.frontMask):undefined,layers=item.slot==='hair'?splitHair(layer,rig.landmarks.chin_y,mask):{[item.slot]:layer};
 return {fit:{...fit,residual_px:sheetFit.residual_px,sheet_scale:scale,relative_scale:fit.scale/scale,nudge},anchor:a,layers};
}
export function compose(layers,width,height){const data=Buffer.alloc(width*height*4);for(const layer of layers)for(let p=0;p<data.length;p+=4){const a=layer.data[p+3]/255,b=data[p+3]/255,out=a+b*(1-a);for(let c=0;c<3;c++)data[p+c]=out?Math.round((layer.data[p+c]*a+data[p+c]*b*(1-a))/out):0;data[p+3]=Math.round(out*255);}return {width,height,data};}
export function buildLegacy(manifest,root){const rig=JSON.parse(fs.readFileSync(path.join(root,'project/data/doll/rig_chibi.json'),'utf8')),body=readImage(path.join(root,rig.body_file)),regions=readImage(path.join(root,rig.regions.file)),sheet=readImage(path.resolve(root,manifest.sheet)),preflight=bodyPreflight(sheet,parseCrop(manifest.bodyCrop),body),catalogPath=path.join(root,'project/data/doll/items.json'),catalog=fs.existsSync(catalogPath)?JSON.parse(fs.readFileSync(catalogPath,'utf8')):{},rendered=[];
 const sheetMatte=matte(sheet);
 const directory=path.join(root,'project/assets/doll');fs.mkdirSync(directory,{recursive:true});const sha1=createHash('sha1').update(fs.readFileSync(path.resolve(root,manifest.sheet))).digest('hex');
 for(const item of manifest.items){if(!/^[a-z][a-z0-9_]*$/.test(item.id))throw Error('Unsafe item id');const cut=crop(sheetMatte,parseCrop(item.crop)),image=item.component==='largest'?isolateLargest(cut):cut,placed=placeLegacy(image,item,preflight.report.fit,rig,regions),layers=[];
 for(const [kind,pixels] of Object.entries(placed.layers)){const layer=kind==='front'?'hair':kind==='back'?'hair_back':kind,name=`${item.id}${kind==='back'?'__back':''}.png`;writeImage(path.join(directory,name),pixels);layers.push({layer,file:`res://assets/doll/${name}`,bbox:bbox(pixels)});rendered.push({layer,pixels});}
 const needsReview=preflight.report.fit.residual_px>1.5?`body differs from the rig, residual ${preflight.report.fit.residual_px.toFixed(3)} px`:'legacy placement requires Doll Bench review';
 catalog[item.id]={slot:item.slot,rig:rig.id,layers,covers:rig.slots[item.slot]?.covers??[],side:item.side??null,source:{component:item.component??'all',method:'legacy-sheet',sheet:manifest.sheet,crop:item.crop,sha1:{sheet:sha1}},fit:placed.fit,anchor:placed.anchor,needs_review:needsReview,qa:{status:'needs_review',failures:[]}};
 if(item.slot==='hair')catalog[item.id].split={rule:'chin_y',front_mask:item.frontMask??null};}
 fs.mkdirSync(path.dirname(catalogPath),{recursive:true});fs.writeFileSync(catalogPath,JSON.stringify(catalog,null,2)+'\n');rendered.push({layer:'body',pixels:body});rendered.sort((a,b)=>rig.layers.indexOf(a.layer)-rig.layers.indexOf(b.layer));return {catalog,bodyFit:{...preflight.report,pass:true,failures:[],needs_review:preflight.report.fit.residual_px>1.5?'body differs from the rig':null},composite:compose(rendered.map(r=>r.pixels),...rig.frame)};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){const [manifestPath,root='.',review='.cache/legacy-composite.png']=process.argv.slice(2);const result=buildLegacy(JSON.parse(fs.readFileSync(manifestPath,'utf8')),path.resolve(root));fs.mkdirSync(path.dirname(review),{recursive:true});writeImage(review,result.composite);console.log(JSON.stringify(result.bodyFit));}
