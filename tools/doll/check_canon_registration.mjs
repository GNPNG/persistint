#!/usr/bin/env node
// provenance: diagnostic-only
// Team-side encrypted-source acceptance. Output root is isolated from production.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {buildLegacy,compose} from './legacy.mjs';
import {readImage,writeImage} from './lib/image.mjs';
import {maskIoU} from './register.mjs';
const [sheet,bodyCrop,out,crownTruth]=process.argv.slice(2);
if(!crownTruth)throw Error('Usage: node tools/doll/check_canon_registration.mjs SHEET BODY_CROP OUTPUT_ROOT INDEPENDENT_CROWN_FRAME.png');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'),output=path.resolve(out);
assert.notEqual(output,root,'Use a separate review output root');
for(const file of ['project/data/doll/rig_chibi.json','project/assets/canon/body_base.png','project/assets/doll/rig/chibi_regions.png']){const dest=path.join(output,file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(root,file),dest);}
const specs={hair_pigtails:'379x419+595+89',hair_crown:'402x511+1095+81',hair_braids:'534x512+1530+99',hair_short:'423x374+2199+90'};
const result=buildLegacy({sheet:path.resolve(sheet),bodyCrop,items:Object.entries(specs).map(([id,crop])=>({id,slot:'hair',crop}))},output);
assert.ok(Math.abs(result.bodyFit.fit.scale-1)<=.01,'canon body sheet scale must be 1 +/- .01');
for(const id of Object.keys(specs))assert.ok(Math.abs(result.catalog[id].fit.relative_scale-1)<=.02,`${id} grew relative to sheet`);
const front=readImage(path.join(output,'project/assets/doll/hair_crown.png')),back=readImage(path.join(output,'project/assets/doll/hair_crown__back.png')),rig=JSON.parse(fs.readFileSync(path.join(output,'project/data/doll/rig_chibi.json'),'utf8'));
for(let y=rig.landmarks.chin_y+1;y<front.height;y++)for(let x=0;x<front.width;x++)assert.equal(front.data[(y*front.width+x)*4+3],0,'front crown below chin');
const whole=compose([back,front],front.width,front.height),truth=readImage(crownTruth);assert.deepEqual([truth.width,truth.height],rig.frame);const iou=maskIoU(whole,truth);
writeImage(path.join(output,'crown-registered.png'),whole);const report={bodyScale:result.bodyFit.fit.scale,wigRelativeScales:Object.fromEntries(Object.keys(specs).map(id=>[id,result.catalog[id].fit.relative_scale])),crownIoU:iou,truth:path.resolve(crownTruth)};
fs.writeFileSync(path.join(output,'canon-registration.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));assert.ok(iou>=.97,'crown differs from independent sheet-scale ground truth');console.log('RESULT: PASS');
