#!/usr/bin/env node
// provenance: diagnostic-only
// Integration coverage: baseline scope, full mode, explicit exception boundaries, history.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
process.chdir(path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..'));
import assert from 'node:assert/strict';
import {spawnSync,execFileSync} from 'node:child_process';
const root=path.resolve('.cache/doll_qa/scope-fixture');
fs.rmSync(root,{recursive:true,force:true});fs.mkdirSync(path.join(root,'project/data/doll'),{recursive:true});
fs.symlinkSync(path.resolve('project/assets'),path.join(root,'project/assets'),'dir');
for(const name of ['rig_chibi.json','items.json'])fs.copyFileSync(`project/data/doll/${name}`,path.join(root,'project/data/doll',name));
const rig=JSON.parse(fs.readFileSync('project/data/doll/rig_chibi.json'));
fs.mkdirSync(path.dirname(path.join(root,rig.regions.file)),{recursive:true});fs.copyFileSync(rig.regions.file,path.join(root,rig.regions.file));
function run(where,full=false,expected=0){const r=spawnSync('godot',['--headless','--path','project','--script','res://tests/test_doll_qa.gd'],{encoding:'utf8',timeout:60000,env:{...process.env,DOLL_QA_ROOT:where,DOLL_QA_FULL:full?'1':'0'}});assert.equal(r.status,expected,r.stdout+r.stderr);assert.doesNotMatch(r.stdout+r.stderr,/SCRIPT ERROR|Parse Error/);return JSON.parse(fs.readFileSync(path.join(where,'.cache/doll_qa/report.json')));}
const initial=run(root);assert.equal(initial.reports.filter(x=>x.id.includes('+')).length,1);
fs.writeFileSync(path.join(root,'project/data/doll/qa_baseline.json'),JSON.stringify(initial.fingerprints));
const unchanged=run(root);assert.equal(unchanged.reports.filter(x=>x.id.includes('+')).length,0);
const full=run(root,true);assert.equal(full.reports.filter(x=>x.id.includes('+')).length,1);
const catalog=JSON.parse(fs.readFileSync(path.join(root,'project/data/doll/items.json')));
catalog.unlisted_hair={...catalog.hair_daughter};delete catalog.hair_daughter;
fs.writeFileSync(path.join(root,'project/data/doll/items.json'),JSON.stringify(catalog));
const unlisted=run(root,false,1);assert.ok(unlisted.failures>0,'needs_review cannot silently whitelist a new item');
if(process.env.DOLL_QA_HISTORY==='1'){
execFileSync(process.execPath,['tools/doll/export_qa_history.mjs'],{stdio:'pipe'});
const historical=run(path.resolve('.cache/doll_qa/historical'),true,1);
for(const [id,term] of [['hair_crown','legacy_scale'],['hair_crown','front_forbidden:torso'],['hair_short','front_forbidden:neck'],['dress_uniform','skin_leak'],['hair_pigtails','fringe']])assert.ok(historical.reports.find(x=>x.id===id).findings.some(x=>x.endsWith(term)),`${id} ${term}`);
assert.ok(historical.reports.find(x=>x.id==='body_base').metrics.fringe_ratio>.14);
}
console.log('RESULT: PASS baseline skips unchanged pairs; full checks all; new review findings gate; optional historical assertions when DOLL_QA_HISTORY=1');
