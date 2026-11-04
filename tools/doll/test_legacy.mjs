import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {anchor,placeLegacy,buildLegacy,clearWhiteFaceOpening,faceOpening} from './legacy.mjs';
import {readImage,writeImage} from './lib/image.mjs';
import {alphaMetrics} from './intake.mjs';
import {whiteMatte} from './lib/matte.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'),rig=JSON.parse(fs.readFileSync(path.join(root,'project/data/doll/rig_chibi.json'),'utf8')),regions=readImage(path.join(root,rig.regions.file));
const wig={width:360,height:400,data:Buffer.alloc(360*400*4)};
for(let y=0;y<400;y++)for(let x=0;x<360;x++)if(x<15||x>344||y<20||y>380)wig.data.set([100,60,40,255],(y*360+x)*4);
const placed=placeLegacy(wig,{slot:'hair'}, {scale:1,residual_px:0},rig,regions);assert.equal(placed.fit.relative_scale,1);assert.equal(placed.fit.scale,1);assert.equal(placed.fit.nudge[0],0);
assert.ok(Math.abs(anchor(wig,'hair',rig).target[1]-rig.landmarks.chin_y)<1);
for(let y=rig.landmarks.chin_y+1;y<rig.frame[1];y++)for(let x=0;x<rig.frame[0];x++)assert.equal(placed.layers.front.data[(y*rig.frame[0]+x)*4+3],0);
// Identical enclosed white geometry: clear hair's face opening, preserve dress content.
const whiteFixture={width:100,height:120,data:Buffer.alloc(100*120*4,255)};
for(let y=10;y<110;y++)for(let x=10;x<90;x++)whiteFixture.data.set([100,60,40,255],(y*100+x)*4);
for(let y=25;y<100;y++)for(let x=20;x<80;x++)whiteFixture.data.set([247,246,245,255],(y*100+x)*4);
for(let y=15;y<18;y++)for(let x=13;x<16;x++)whiteFixture.data.set([255,255,255,255],(y*100+x)*4);
const whiteMatted=whiteMatte(whiteFixture),before=Buffer.from(whiteMatted.data),opened=clearWhiteFaceOpening(whiteMatted,'hair',true);
assert.deepEqual(faceOpening(opened),[20,25,60,75]);assert.equal(opened.data[(60*100+50)*4+3],0);
assert.equal(opened.data[(16*100+14)*4+3],255,'small white highlight retained');
assert.deepEqual(clearWhiteFaceOpening(whiteMatted,'dress',true).data,before,'white dress panel retained');
assert.deepEqual(clearWhiteFaceOpening(whiteMatted,'hair',false).data,before,'non-white-backed hair unchanged');
assert.deepEqual(whiteMatted.data,before,'source matte is not mutated');
const edgeWhite={...whiteMatted,data:Buffer.from(whiteMatted.data)};for(let y=0;y<5;y++)for(let x=0;x<100;x++)edgeWhite.data.set([255,255,255,255],(y*100+x)*4);
assert.equal(clearWhiteFaceOpening(edgeWhite,'hair',true).data[3],255,'crop-edge white component is not an opening');
const whitePlaced=placeLegacy(opened,{slot:'hair'}, {scale:1,residual_px:0},rig,regions);
assert.equal(whitePlaced.fit.scale,1);assert.deepEqual(whitePlaced.anchor.target,[rig.landmarks.centre_x,rig.landmarks.chin_y]);
console.log('PASS enclosed white wig opening clears; dress panel, highlights and edge-connected white stay opaque');
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'doll-legacy-'));
try{
 for(const f of ['project/data/doll/rig_chibi.json',rig.body_file,rig.regions.file]){fs.mkdirSync(path.dirname(path.join(tmp,f)),{recursive:true});fs.copyFileSync(path.join(root,f),path.join(tmp,f));}
 const manifest=JSON.parse(fs.readFileSync(path.join(root,'tools/doll/manifests/daughter.json'),'utf8'));manifest.sheet=path.join(root,manifest.sheet);
 const result=buildLegacy(manifest,tmp);assert.ok(result.bodyFit.pass);assert.ok(result.bodyFit.fit.residual_px>1.5);assert.equal(Object.keys(result.catalog).length,4);
 for(const item of Object.values(result.catalog)){assert.match(item.needs_review,/body differs from the rig/);assert.equal(item.qa.status,'needs_review');assert.ok(Math.abs(item.fit.relative_scale-1)<=.020001);for(const layer of item.layers){const image=readImage(path.join(tmp,'project',layer.file.slice('res://'.length)));assert.deepEqual([image.width,image.height],rig.frame);assert.equal(alphaMetrics(image).borderOpaquePixels,0);}}
 assert.equal(result.catalog.shoes_daughter_l.side,'l');assert.equal(result.catalog.shoes_daughter_r.side,'r');
 assert.ok(result.catalog.shoes_daughter_l.anchor.target[0]<result.catalog.shoes_daughter_r.anchor.target[0]);
 const body=readImage(path.join(tmp,rig.body_file)),proof={...body,data:Buffer.from(body.data)},item={...body,data:Buffer.alloc(body.data.length)};
 for(let y=440;y<550;y++)for(let x=315;x<420;x++){const p=(y*body.width+x)*4;proof.data.set([100,110,220,255],p);item.data.set([100,110,220,255],p);}
 writeImage(path.join(tmp,'proof.png'),proof);writeImage(path.join(tmp,'item.png'),item);
 const request=path.join(tmp,'proof.json');fs.writeFileSync(request,JSON.stringify({id:'top_fixture',slot:'top',proof:'proof.png',item:'item.png'}));
 const run=()=>spawnSync(process.execPath,[path.join(root,'tools/doll/proof.mjs'),request,tmp],{encoding:'utf8'});
 let command=run();assert.equal(command.status,0,command.stderr+command.stdout);assert.ok(fs.existsSync(path.join(tmp,'project/assets/doll/top_fixture.png')));
 for(let y=440;y<520;y++)for(let x=315;x<420;x++)item.data[(y*body.width+x)*4+3]=0;
 writeImage(path.join(tmp,'item.png'),item);fs.writeFileSync(request,JSON.stringify({id:'top_rejected',slot:'top',proof:'proof.png',item:'item.png'}));command=run();assert.equal(command.status,1);assert.ok(!fs.existsSync(path.join(tmp,'project/assets/doll/top_rejected.png')));
 const whiteSheet={width:1000,height:800,data:Buffer.alloc(1000*800*4,255)};
 for(let y=0;y<body.height;y++)for(let x=0;x<body.width;x++){const p=(y*body.width+x)*4,q=(y*1000+x)*4,a=body.data[p+3]/255;for(let c=0;c<3;c++)whiteSheet.data[q+c]=Math.round(body.data[p+c]*a+255*(1-a));}
 for(let y=0;y<120;y++)whiteFixture.data.copy(whiteSheet.data,((200+y)*1000+800)*4,y*100*4,(y+1)*100*4);
 writeImage(path.join(tmp,'white-sheet.png'),whiteSheet);
 const whiteRun=buildLegacy({sheet:'white-sheet.png',bodyCrop:'721x760+0+0',items:[{id:'hair_white_fixture',slot:'hair',crop:'100x120+800+200'},{id:'dress_white_fixture',slot:'dress',crop:'100x120+800+200'}]},tmp);
 assert.ok(whiteRun.catalog.hair_white_fixture.layers.length===2);
 const dressPanel=readImage(path.join(tmp,'project/assets/doll/dress_white_fixture.png'));let whitePixels=0;for(let i=0;i<dressPanel.data.length;i+=4)if(dressPanel.data[i+3]>250&&Math.min(...dressPanel.data.subarray(i,i+3))>=232)whitePixels++;assert.ok(whitePixels>3000,'white dress panel survives full-sheet pipeline');
 console.log('PASS white-sheet buildLegacy integration places wig and retains white dress panel');
 console.log('PASS proof CLI persists accepted catalog/layers and refuses changed-item output');
 console.log('PASS sheet-scale wig, exact chin split, separate feet, full frames and legacy residual review flags');
 console.log('RESULT: PASS');
}finally{fs.rmSync(tmp,{recursive:true,force:true});}
