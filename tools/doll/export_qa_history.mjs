#!/usr/bin/env node
// Read-only historical fixture export; never checks old assets into the working tree.
// provenance: diagnostic-only
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {readImage} from './lib/image.mjs';
import {faceOpening} from './legacy.mjs';
const [ref='45269f5',out='.cache/doll_qa/historical']=process.argv.slice(2);
const output=path.resolve(out);if(output===process.cwd())throw Error('Use an isolated output root');
const rig=JSON.parse(fs.readFileSync('project/data/doll/rig_chibi.json','utf8'));
for(const f of ['project/data/doll/rig_chibi.json',rig.regions.file]){fs.mkdirSync(path.dirname(path.join(output,f)),{recursive:true});fs.copyFileSync(f,path.join(output,f));}
const catalog={};for(const id of ['body_base','hair_crown','hair_short','hair_pigtails','dress_uniform']){
 const file=`project/assets/canon/${id}.png`;let content=execFileSync('git',['show',`${ref}:${file}`],{maxBuffer:32*1024*1024});
 if(content.subarray(0,40).toString().startsWith('version https://git-lfs.github.com'))content=execFileSync('git',['lfs','smudge'],{input:content,maxBuffer:32*1024*1024});
 fs.mkdirSync(path.dirname(path.join(output,file)),{recursive:true});fs.writeFileSync(path.join(output,file),content);
 if(id==='body_base')continue;
 const slot=id.split('_')[0],entry={slot,rig:'chibi',layers:[{layer:slot,file:`res://assets/canon/${id}.png`}],source:{method:'legacy-sheet',historical_ref:ref},qa:{status:'unapproved'}};
 if(id==='hair_crown')entry.fit={scale:faceOpening(readImage(path.join(output,file)))[2]/229,sheet_scale:1,evidence:'rendered face-opening width divided by 229px source opening measured by coordinator/spec3.6; estimate from raster'};
 catalog[id]=entry;
}
fs.writeFileSync(path.join(output,'project/data/doll/items.json'),JSON.stringify(catalog,null,2)+'\n');console.log(output);
