#!/usr/bin/env node
// Acceptance gates for the measured canonical rig and its actual green template.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {build,measure,readImage,ROOT} from './rig.mjs';
const hash=p=>createHash('sha1').update(fs.readFileSync(p)).digest('hex');
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'persistint-rig-'));
try {
  const body='project/assets/canon/body_base.png';
  fs.mkdirSync(path.dirname(path.join(tmp,body)),{recursive:true});
  fs.copyFileSync(path.join(ROOT,body),path.join(tmp,body));
  const before=hash(path.join(ROOT,body)),rig=build(tmp),lm=rig.landmarks;
  const near=(actual,expected,tolerance=1)=>assert.ok(Math.abs(actual-expected)<=tolerance,`${actual} vs ${expected} ±${tolerance}`);
  near(lm.head_top[1],61);near(lm.centre_x,367);near(lm.sole_l[1],758);near(lm.sole_r[1],758);
  near(lm.chin_y,398,3);near(lm.neck_y,406,3);
  assert.ok(lm.neck_y<lm.shoulder_y&&lm.shoulder_y<lm.waist_y&&lm.waist_y<lm.hip_y&&lm.hip_y<lm.crotch_y&&lm.crotch_y<lm.knee_y&&lm.knee_y<lm.ankle_y);
  console.log('PASS landmark tolerances and anatomical ordering');
  const source=readImage(path.join(tmp,body)),regions=readImage(path.join(tmp,rig.regions.file));
  assert.deepEqual([regions.width,regions.height],rig.frame);
  const counts=Array(20).fill(0);
  for(let i=0;i<source.width*source.height;i++){
    const p=i*4,label=regions.data[p],on=source.data[p+3]>0;
    assert.equal(regions.data[p+1],label);assert.equal(regions.data[p+2],label);
    assert.equal(regions.data[p+3],on?255:0);
    assert.ok(on?label>=1&&label<=19:label===0,`pixel ${i}: label ${label}`);counts[label]++;
  }
  for(const [name,id] of Object.entries(rig.regions.labels)){assert.ok(counts[id]>0,`${name} empty`);assert.equal(counts[id],rig.regions.counts[name]);}
  for(const eye of [lm.eye_l,lm.eye_r])assert.equal(regions.data[(eye[1]*source.width+eye[0])*4],rig.regions.labels.eye_band);
  console.log('PASS all opaque pixels have exactly one of 19 labels; eyes in eye band');
  // A translated fixture must move measured landmarks, ruling out fixed coordinate output.
  const dx=11,dy=9,w=source.width+22,h=source.height+18,data=Buffer.alloc(w*h*4);
  for(let y=0;y<source.height;y++)source.data.copy(data,((y+dy)*w+dx)*4,y*source.width*4,(y+1)*source.width*4);
  const moved=measure({width:w,height:h,data}).landmarks;
  near(moved.head_top[1],lm.head_top[1]+dy,0);near(moved.centre_x,lm.centre_x+dx,0);
  near(moved.neck_y,lm.neck_y+dy,0);near(moved.chin_y,lm.chin_y+dy,0);
  for(const eye of ['eye_l','eye_r']){near(moved[eye][0],lm[eye][0]+dx,0);near(moved[eye][1],lm[eye][1]+dy,0);}
  console.log('PASS translated source moves silhouette and eye measurements');
  const template=readImage(path.join(tmp,rig.template.file));assert.deepEqual([template.width,template.height],[1024,1536]);assert.equal(hash(path.join(tmp,rig.template.file)),rig.template.sha1);
  let intersection=0,union=0;
  for(let y=0;y<source.height;y++)for(let x=0;x<source.width;x++){
    const tx=Math.round(x*rig.template.frame_scale+rig.template.frame_origin[0]),ty=Math.round(y*rig.template.frame_scale+rig.template.frame_origin[1]);
    let mapped=false;
    if(tx>=0&&ty>=0&&tx<template.width&&ty<template.height){const i=(ty*template.width+tx)*4;const [r,g,b]=template.data.subarray(i,i+3);mapped=Math.hypot(r,255-g,b)>100;}
    const bodyPixel=source.data[(y*source.width+x)*4+3]>127;if(mapped&&bodyPixel)intersection++;if(mapped||bodyPixel)union++;
  }
  const iou=intersection/union;assert.ok(iou>=.99,`template round-trip IoU ${iou}`);
  assert.deepEqual([...template.data.subarray(0,4)],[0,255,0,255]);
  console.log(`PASS actual green-template inverse mapping IoU=${iou.toFixed(6)} >=0.99`);
  const outputs=['project/data/doll/rig_chibi.json',rig.regions.file,rig.template.file,'docs/reviews/1rjz.1/regions_overlay.png'];
  const hashes=outputs.map(p=>hash(path.join(tmp,p)));build(tmp);assert.deepEqual(outputs.map(p=>hash(path.join(tmp,p))),hashes);
  for(let i=0;i<outputs.length;i++)assert.equal(hash(path.join(ROOT,outputs[i])),hashes[i],`checked-in ${outputs[i]} differs from generated output`);
  assert.equal(hash(path.join(ROOT,body)),before);
  console.log('PASS deterministic outputs match checked-in artifacts; canonical body unchanged');
  console.log('RESULT: PASS');
} finally {fs.rmSync(tmp,{recursive:true,force:true});}
