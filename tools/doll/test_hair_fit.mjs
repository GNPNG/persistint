import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {readImage} from './lib/image.mjs';
import {fitHair,clearWhiteFaceOpening} from './legacy.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const rig=JSON.parse(fs.readFileSync(path.join(root,'project/data/doll/rig_chibi.json'))),regions=readImage(path.join(root,rig.regions.file)),labels=rig.regions.labels;
const at=(x,y)=>regions.data[(y*regions.width+x)*4];
for(const [x,y] of [rig.landmarks.eye_l,rig.landmarks.eye_r]){
 assert.equal(at(x,y),labels.eye_band);assert.equal(at(x+15,y),labels.eye_band,'immediate surround protected');
}
assert.equal(at(220,293),labels.head,'temple does not count as eye');assert.equal(at(510,293),labels.head);
assert.equal(at(367,345),labels.face,'nose/mouth area stays protected');
assert.notEqual(at(220,345),labels.face,'side lock does not count as visible face');
// Independently specified oversized hair silhouette: target placement y=0 covers cranium;
// a 35px-low seed leaves the scalp exposed. Face window extends well below the chin.
const hair={width:721,height:760,data:Buffer.alloc(721*760*4)};
for(let y=40;y<=540;y++)for(let x=180;x<=554;x++){
 if(x>=235&&x<=499&&y>=220&&y<=520)continue;
 hair.data.set([100,60,40,255],(y*721+x)*4);
}
const fit=fitHair(hair,{scale:1,offset:[0,35]},rig,regions);
assert.equal(fit.scale,1);assert.equal(fit.offset[0],0,'horizontal centre remains fixed');
assert.ok(fit.search_dy<=-15,'search must lift low seed beyond old +/-4 window');
assert.equal(fit.hair_qa.eye_pixels,0);assert.ok(fit.hair_qa.face_share<=.03);assert.ok(fit.hair_qa.cranium_uncovered_share<=.005);
assert.equal(fit.hair_qa.clipped,false);assert.deepEqual(fit.hair_qa.failures,[]);
const impossible={...hair,data:Buffer.from(hair.data)};for(let y=0;y<760;y++)for(let x=0;x<721;x++)if(impossible.data[(y*721+x)*4+3])impossible.data[(y*721+x)*4+3]=0;
for(let y=280;y<=310;y++)for(let x=270;x<=460;x++)impossible.data.set([100,60,40,255],(y*721+x)*4);
const bad=fitHair(impossible,{scale:1,offset:[0,0]},rig,regions);assert.ok(bad.hair_qa.cranium_uncovered_share>.9,'unfittable geometry retains measured failure');assert.ok(bad.hair_qa.failures.includes('cranium_coverage'));
// Selected white gaps include both ears; top highlights and below-chin content survive.
const white={width:120,height:140,data:Buffer.alloc(120*140*4)};
for(let y=5;y<135;y++)for(let x=5;x<115;x++)white.data.set([100,60,40,255],(y*120+x)*4);
const box=(x0,y0,w,h)=>{for(let y=y0;y<y0+h;y++)for(let x=x0;x<x0+w;x++)white.data.set([255,255,255,255],(y*120+x)*4);};
box(35,25,50,80);box(15,70,12,20);box(93,70,12,20);box(15,15,4,4);box(15,115,12,12);
const cleared=clearWhiteFaceOpening(white,'hair',true),alpha=(x,y)=>cleared.data[(y*120+x)*4+3];
assert.equal(alpha(60,50),0);assert.equal(alpha(20,80),0);assert.equal(alpha(99,80),0);
assert.equal(alpha(16,16),255,'small upper highlight retained');assert.equal(alpha(20,120),255,'white below opening chin retained');
assert.deepEqual(clearWhiteFaceOpening(white,'dress',true).data,white.data);
// Reproduce coordinator-described topology without copying private artwork.
function earShape(mode){
 const image={width:120,height:140,data:Buffer.alloc(120*140*4)};
 for(let y=5;y<135;y++)for(let x=5;x<115;x++)image.data.set([100,60,40,255],(y*120+x)*4);
 const box=(x0,y0,w,h,a=255)=>{for(let y=y0;y<y0+h;y++)for(let x=x0;x<x0+w;x++)image.data.set([255,255,255,a],(y*120+x)*4);};
 box(45,25,30,50);box(35,75,50,30); // tapered face: its bbox overlaps separate ear gaps
 box(25,45,15,20);box(80,45,15,20);box(15,15,4,4);box(15,115,12,12);
 if(mode==='outline')box(0,50,26,3); // ear gap touches crop edge via a narrow white channel
 if(mode==='face')box(39,53,8,3); // ear gap touches the face white
 if(mode==='clear'){box(45,25,30,50,0);box(35,75,50,30,0);}
 return image;
}
for(const mode of ['separate','outline','face','clear']){
 const shape=earShape(mode),result=clearWhiteFaceOpening(shape,'hair',true),a=(x,y)=>result.data[(y*120+x)*4+3];
 assert.equal(a(30,55),0,mode+' left gap');assert.equal(a(90,55),0,mode+' right gap');
 assert.equal(a(60,50),0,mode+' face');assert.equal(a(16,16),255,mode+' highlight');assert.equal(a(20,120),255,mode+' below-chin white');
}
console.log('PASS tapered-face bbox overlap, face-connected, outline-connected and pre-cleared-face ear gaps');
console.log('PASS local eye regions, central face, fixed-scale centred upward fit, impossible fit diagnostics, bilateral ear gaps and retained white detail');
console.log(JSON.stringify(fit));console.log('RESULT: PASS');

// Circlet notch encloses backing above the face; nearby decoration survives.
for(const precleared of [false,true]){
 const img={width:120,height:160,data:Buffer.alloc(120*160*4)};
 for(let y=5;y<155;y++)for(let x=5;x<115;x++)img.data.set([90,60,35,255],(y*120+x)*4);
 const fill=(x0,y0,w,h,rgba)=>{for(let y=y0;y<y0+h;y++)for(let x=x0;x<x0+w;x++)img.data.set(rgba,(y*120+x)*4);};
 fill(35,55,50,80,[255,255,255,precleared?0:255]);
 fill(48,42,24,9,[255,255,255,255]);
 fill(56,20,8,8,[255,255,255,255]); // distant crown jewel
 fill(15,43,10,8,[255,255,255,255]); // side ornament
 fill(44,40,32,2,[230,180,40,255]); // gold circlet boundary
 const out=clearWhiteFaceOpening(img,'hair',true),a=(x,y)=>out.data[(y*120+x)*4+3];
 assert.equal(a(60,46),0,'enclosed upper backing');
 assert.equal(a(60,23),255,'crown jewel retained');assert.equal(a(18,46),255,'side ornament retained');
 assert.equal(a(60,40),255,'accessory boundary retained');
 assert.deepEqual(clearWhiteFaceOpening(img,'dress',true).data,img.data);
 assert.deepEqual(clearWhiteFaceOpening(img,'hair',false).data,img.data);
}
console.log('PASS enclosed circlet gap with opaque/precleared face; retained ornament, gold boundary and non-white-backed art');
