import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {readImage} from './lib/image.mjs';
import {placeLegacy} from './legacy.mjs';
import assert from 'node:assert/strict';
import {stripFaceOutline} from './lib/face_outline.mjs';
const rig={landmarks:{centre_x:367,eye_l:[293,293],eye_r:[440,293],brow_y:236}};
function fixture(thickness){
 const image={width:721,height:760,data:Buffer.alloc(721*760*4)};
 for(let y=160;y<=430;y++)for(let x=180;x<=554;x++){
  const r=Math.sqrt(((x-367)/140)**2+((y-275)/100)**2),inner=1-thickness/100;
  if(r<=1&&(r>=inner||y<230))image.data.set([118,76,58,255],(y*721+x)*4);
 }
 // Filled locks and pink ties at both sides are not an isolated outline.
 for(const left of [230,464])for(let y=325;y<=420;y++)for(let x=left;x<left+40;x++)image.data.set(y<340?[230,145,145,255]:[137,92,65,255],(y*721+x)*4);
 // A fractional-alpha rim on the bottom must not leave a ghost after repair.
 for(let x=350;x<=384;x++)image.data.set([118,76,58,70],(376*721+x)*4);
 return image;
}
for(const thickness of [4,6]){
 const input=fixture(thickness),before=Buffer.from(input.data),{image,report}=stripFaceOutline(input,rig);
 assert.deepEqual(input.data,before,'no input mutation');assert.ok(report.removed_pixels>200);
 for(let y=0;y<236;y++)assert.deepEqual(image.data.subarray(y*721*4,(y+1)*721*4),before.subarray(y*721*4,(y+1)*721*4),'above brow unchanged');
 for(const left of [230,464])for(let y=325;y<=420;y++)for(let x=left;x<left+40;x++){const i=(y*721+x)*4;assert.deepEqual(image.data.subarray(i,i+4),before.subarray(i,i+4),'filled lock / tie retained');}
 for(let x=350;x<=384;x++)assert.equal(image.data[(376*721+x)*4+3],0,'fractional bottom rim gone');
 assert.equal(image.data[(373*721+367)*4+3],0,'bottom outline gone');
 console.log(JSON.stringify({thickness,...report}));
}
const thick=fixture(18),thickResult=stripFaceOutline(thick,rig);assert.equal(thickResult.image.data[(373*721+367)*4+3],255,'thick fill not classified as isolated outline');
const open=fixture(4);for(let y=0;y<300;y++)open.data.fill(0,(y*721+365)*4,(y*721+370)*4);
assert.deepEqual(stripFaceOutline(open,rig).image.data,open.data,'open face fails closed');
console.log('PASS 4/6px curved rims, fractional alpha, unchanged locks/ties/bangs, thick fill and open-face refusal');

const root=fileURLToPath(new URL('../../',import.meta.url)),actualRig=JSON.parse(fs.readFileSync(root+'project/data/doll/rig_chibi.json')),regions=readImage(root+actualRig.regions.file);
const input=fixture(4),plain=placeLegacy(input,{slot:'hair'},{scale:1,residual_px:0},actualRig,regions),clean=placeLegacy(input,{slot:'hair',stripFaceOutline:true},{scale:1,residual_px:0},actualRig,regions);
assert.deepEqual(clean.fit,plain.fit,'repair cannot alter fit/search/scale');
assert.deepEqual(clean.anchor,plain.anchor);assert.ok(clean.outline_cleanup.removed_pixels>0);
assert.equal(plain.outline_cleanup,null,'opt-in only');
console.log('PASS legacy placement integration: identical fit and anchor, opt-in cleanup only');
