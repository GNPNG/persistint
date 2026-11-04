import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerProof,splitHair,warp} from './register.mjs';
import {readImage,magick} from './lib/image.mjs';
import {fitBody,distanceField,landmarkSeed,gates} from './lib/registration.mjs';
const point={width:7,height:7,data:Buffer.alloc(7*7*4)};point.data[(3*7+3)*4+3]=255;const field=distanceField(point);assert.equal(field.data[0],Math.sqrt(18));assert.equal(field.data[24],0);
const base=readImage(new URL('../../project/assets/canon/body_base.png',import.meta.url).pathname);
for(const [s,x,y] of [[1,7,-4],[1.02,4,-3],[.98,-3,4],[1.06,0,-40]]){
 const data=magick(['-size',`${base.width}x${base.height}`,'-depth','8','rgba:-','-virtual-pixel','transparent','-filter','Lanczos','-define','distort:viewport=850x850+0+0','-distort','AffineProjection',`${s},0,0,${s},${x},${y}`,'-depth','8','rgba:-'],base.data);
 const source={width:850,height:850,data},seed=landmarkSeed(source,base),fit=fitBody(source,base,{seed});
 assert.ok(Math.abs(fit.scale*s-1)<=.003);assert.ok(Math.abs(fit.offset[0]+x/s)<=.5);assert.ok(Math.abs(fit.offset[1]+y/s)<=.5);
 assert.equal(gates(fit).failures.includes('scale-correction'),s===1.06);
 console.log('PASS known body transform',JSON.stringify({input:[s,x,y],fit}));
}
assert.ok(gates({scale:1,offset:[0,0],residual_px:2}).failures.includes('outline-residual'));
assert.ok(gates({scale:1,offset:[0,0],residual_px:0},{rotationDegrees:1.1}).failures.includes('rotation'));


const rig=JSON.parse(fs.readFileSync(new URL('../../project/data/doll/rig_chibi.json',import.meta.url),'utf8'));
const item={...base,data:Buffer.alloc(base.data.length)},proof={...base,data:Buffer.from(base.data)};
for(let y=440;y<550;y++)for(let x=315;x<420;x++){const p=(y*base.width+x)*4;item.data.set([100,110,220,255],p);proof.data.set([100,110,220,255],p);}
const passed=registerProof(proof,item,base,{rig});assert.ok(passed.pass,JSON.stringify(passed.failures));assert.ok(passed.proofItemIoU>=.9);
const changed={...item,data:Buffer.from(item.data)};for(let y=440;y<510;y++)for(let x=315;x<420;x++)changed.data[(y*base.width+x)*4+3]=0;
assert.ok(registerProof(proof,changed,base,{rig}).failures.includes('proof-item-mismatch'));
const split=splitHair(item,480);for(let y=0;y<base.height;y++)for(let x=0;x<base.width;x++){const p=(y*base.width+x)*4;assert.equal(split.front.data[p+3]+split.back.data[p+3],item.data[p+3]);if(y>480)assert.equal(split.front.data[p+3],0);}
console.log('PASS same-frame proof identity, changed-item rejection and exact chin split');
const shiftedProof=warp(proof,{scale:1.02,offset:[4,-3]},850,850),shiftedItem=warp(item,{scale:1.02,offset:[4,-3]},850,850);
const shifted=registerProof(shiftedProof,shiftedItem,base,{rig});assert.ok(shifted.pass,JSON.stringify({failures:shifted.failures,iou:shifted.proofItemIoU}));
console.log('PASS shifted/scaled proof and item composition',shifted.proofItemIoU);
console.log('RESULT: PASS (proof/core checks; legacy wearable placement pending)');
