#!/usr/bin/env node
// provenance: diagnostic-only
// Team-side encrypted-source acceptance. Output root is isolated from production.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {buildLegacy,compose} from './legacy.mjs';
import {readImage,writeImage} from './lib/image.mjs';
const [sheet,bodyCrop,out]=process.argv.slice(2);
if(!out)throw Error('Usage: node tools/doll/check_canon_registration.mjs SHEET BODY_CROP OUTPUT_ROOT');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'),output=path.resolve(out);
assert.notEqual(output,root,'Use a separate review output root');
for(const file of ['project/data/doll/rig_chibi.json','project/assets/canon/body_base.png','project/assets/doll/rig/chibi_regions.png']){const dest=path.join(output,file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(root,file),dest);}
const specs={hair_pigtails:'379x419+595+89',hair_crown:'402x511+1095+81',hair_braids:'534x512+1530+99',hair_short:'423x374+2199+90'};
const result=buildLegacy({sheet:path.resolve(sheet),bodyCrop,items:Object.entries(specs).map(([id,crop])=>({id,slot:'hair',crop,...(id==='hair_pigtails'?{stripFaceOutline:true}:{}),...(id==='hair_braids'?{component:'largest'}:{})}))},output);
assert.ok(Math.abs(result.bodyFit.fit.scale-1)<=.01,'canon body sheet scale must be 1 +/- .01');
for(const id of Object.keys(specs))assert.ok(Math.abs(result.catalog[id].fit.relative_scale-1)<=.02,`${id} grew relative to sheet`);
const front=readImage(path.join(output,'project/assets/doll/hair_crown.png')),back=readImage(path.join(output,'project/assets/doll/hair_crown__back.png')),rig=JSON.parse(fs.readFileSync(path.join(output,'project/data/doll/rig_chibi.json'),'utf8'));
for(let y=rig.landmarks.chin_y+1;y<front.height;y++)for(let x=0;x<front.width;x++)assert.equal(front.data[(y*front.width+x)*4+3],0,'front crown below chin');
const whole=compose([back,front],front.width,front.height);writeImage(path.join(output,'crown-registered.png'),whole);
const body=readImage(path.join(output,rig.body_file)),contact={width:rig.frame[0]*4,height:rig.frame[1],data:Buffer.alloc(rig.frame[0]*4*rig.frame[1]*4)};
let tile=0;
for(const id of Object.keys(specs)){
 const layers=result.catalog[id].layers.map(layer=>({name:layer.layer,image:readImage(path.join(output,'project',layer.file.slice('res://'.length)))}));layers.push({name:'body',image:body});layers.sort((a,b)=>rig.layers.indexOf(a.name)-rig.layers.indexOf(b.name));
 const image=compose(layers.map(x=>x.image),...rig.frame);
 for(let y=0;y<image.height;y++)image.data.copy(contact.data,(y*contact.width+tile*image.width)*4,y*image.width*4,(y+1)*image.width*4);tile++;
}
writeImage(path.join(output,'canon-qa-contact.png'),contact);
const report={outlineCleanup:Object.fromEntries(Object.keys(specs).map(id=>[id,result.catalog[id].outline_cleanup])),hairFitStage:'before optional outline cleanup; task 4 QA measures delivered layers',bodyScale:result.bodyFit.fit.scale,wigRelativeScales:Object.fromEntries(Object.keys(specs).map(id=>[id,result.catalog[id].fit.relative_scale])),hairFits:Object.fromEntries(Object.keys(specs).map(id=>[id,result.catalog[id].fit])),acceptance:'Run task 4 pixel QA and review canon-qa-contact.png; previous crown truth withdrawn by coordinator.'};
fs.writeFileSync(path.join(output,'canon-registration.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));const failed=Object.entries(report.hairFits).filter(([,fit])=>fit.hair_qa.failures.length);console.log(failed.length?'RESULT: FAIL (hair geometry; inspect hairFits and contact sheet)':'RESULT: PASS (geometry; full pixel acceptance is separate)');if(failed.length)process.exitCode=1;
