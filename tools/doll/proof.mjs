#!/usr/bin/env node
// Explicit proof landing entry point. Rejections write a report, never item layers.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {readImage,writeImage} from './lib/image.mjs';
import {matte,registerProof,splitHair} from './register.mjs';
import {bbox} from './legacy.mjs';
const [manifestFile,rootArg='.']=process.argv.slice(2),root=path.resolve(rootArg);
if(!manifestFile)throw Error('Usage: node tools/doll/proof.mjs MANIFEST.json [ROOT]');
const input=JSON.parse(fs.readFileSync(manifestFile,'utf8'));
if(!/^[a-z][a-z0-9_]*$/.test(input.id))throw Error('Unsafe item id');
const rig=JSON.parse(fs.readFileSync(path.join(root,'project/data/doll/rig_chibi.json'),'utf8'));
if(!rig.slots[input.slot])throw Error('Unknown slot');
const proofPath=path.resolve(root,input.proof),itemPath=path.resolve(root,input.item),body=readImage(path.join(root,rig.body_file));
const result=registerProof(matte(readImage(proofPath)),matte(readImage(itemPath)),body,{rig,slot:input.slot,expectedScale:input.expectedScale??1,expectedOffset:input.expectedOffset??[0,0]});
const {layer,...report}=result;fs.writeFileSync(`${manifestFile}.registration.json`,JSON.stringify(report,null,2)+'\n');
if(!result.pass){console.log(`FAIL ${result.failures.join(', ')}`);process.exitCode=1;}else{
 const pieces=input.slot==='hair'?splitHair(layer,rig.landmarks.chin_y,input.frontMask?readImage(path.resolve(root,input.frontMask)):undefined):{[input.slot]:layer},layers=[],directory=path.join(root,'project/assets/doll');fs.mkdirSync(directory,{recursive:true});
 for(const [kind,image] of Object.entries(pieces)){const name=`${input.id}${kind==='back'?'__back':''}.png`;writeImage(path.join(directory,name),image);layers.push({layer:kind==='front'?'hair':kind==='back'?'hair_back':kind,file:`res://assets/doll/${name}`,bbox:bbox(image)});}
 const catalogPath=path.join(root,'project/data/doll/items.json'),catalog=fs.existsSync(catalogPath)?JSON.parse(fs.readFileSync(catalogPath,'utf8')):{},hash=f=>createHash('sha1').update(fs.readFileSync(f)).digest('hex');
 catalog[input.id]={slot:input.slot,rig:rig.id,layers,covers:rig.slots[input.slot].covers,source:{method:'proof',brief:input.brief??null,proof:input.proof,item:input.item,provenance:input.provenance??null,sha1:{proof:hash(proofPath),item:hash(itemPath)}},fit:{...result.itemFit,body_fit:result.fit,correction:{scale_pct:100*(result.fit.scale/(input.expectedScale??1)-1),shift_px:Math.hypot(...result.fit.offset.map((v,i)=>v-(input.expectedOffset??[0,0])[i]))},nudge:[0,0]},qa:{status:'needs_review',registration_pass:true,proof_item_iou:result.proofItemIoU,failures:[]}};
 if(input.slot==='hair')catalog[input.id].split={rule:'chin_y',front_mask:input.frontMask??null};
 fs.writeFileSync(catalogPath,JSON.stringify(catalog,null,2)+'\n');console.log('PASS registration; pixel QA and visual review remain required');
}
