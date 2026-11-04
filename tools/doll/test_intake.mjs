import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {intake,components} from './intake.mjs';
import {writeImage} from './lib/image.mjs';
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'doll-intake-'));
try {
 const image={width:30,height:20,data:Buffer.alloc(30*20*4)};
 const pixel=(x,y)=>image.data.set([100,60,40,255],(y*30+x)*4);
 for(let y=4;y<12;y++)for(let x=4;x<12;x++)pixel(x,y);
 pixel(20,5); // Far speck is retained, regardless of size.
 const seg=components(image);assert.equal(seg.components.length,2);assert.equal(seg.components[1].area,1);assert.equal(seg.minimumGap,8);
 const file=path.join(dir,'sheet.png'),provenance=path.join(dir,'source.json');writeImage(file,image);fs.writeFileSync(provenance,'{"agent":"synthetic-test"}');
 assert.ok(intake(file,provenance,{expectedCount:2}).pass);
 assert.ok(intake(file,provenance,{expectedCount:1}).reasons.includes('component-count-mismatch-or-touching-items'));
 fs.writeFileSync(provenance,'broken');assert.ok(intake(file,provenance).reasons.includes('invalid-provenance-json'));
 assert.throws(()=>intake(file,provenance,{expectedCount:NaN}),/positive integer/);
 assert.equal(components(image,{mergeDistance:9}).components.length,1);
 console.log('PASS intake provenance, expected count, small component retention, measured gap and explicit merging');
 console.log('RESULT: PASS');
}finally{fs.rmSync(dir,{recursive:true,force:true});}
