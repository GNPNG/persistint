import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {anchor,placeLegacy,buildLegacy} from './legacy.mjs';
import {readImage,writeImage} from './lib/image.mjs';
import {alphaMetrics} from './intake.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'),rig=JSON.parse(fs.readFileSync(path.join(root,'project/data/doll/rig_chibi.json'),'utf8')),regions=readImage(path.join(root,rig.regions.file));
const wig={width:360,height:400,data:Buffer.alloc(360*400*4)};
for(let y=0;y<400;y++)for(let x=0;x<360;x++)if(x<15||x>344||y<20||y>380)wig.data.set([100,60,40,255],(y*360+x)*4);
const placed=placeLegacy(wig,{slot:'hair'}, {scale:1,residual_px:0},rig,regions);assert.equal(placed.fit.relative_scale,1);assert.equal(placed.fit.scale,1);assert.equal(placed.fit.nudge[0],0);
assert.ok(Math.abs(anchor(wig,'hair',rig).target[1]-rig.landmarks.chin_y)<1);
for(let y=rig.landmarks.chin_y+1;y<rig.frame[1];y++)for(let x=0;x<rig.frame[0];x++)assert.equal(placed.layers.front.data[(y*rig.frame[0]+x)*4+3],0);
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
 console.log('PASS proof CLI persists accepted catalog/layers and refuses changed-item output');
 console.log('PASS sheet-scale wig, exact chin split, separate feet, full frames and legacy residual review flags');
 console.log('RESULT: PASS');
}finally{fs.rmSync(tmp,{recursive:true,force:true});}
