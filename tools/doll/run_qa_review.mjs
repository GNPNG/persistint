#!/usr/bin/env node
// provenance: diagnostic-only
// Run task 4 QA against an isolated registration output, without merging either branch.
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync,execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const repository=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const [output,ref='origin/codex/1rjz.4']=process.argv.slice(2);
if(!output)throw Error('Usage: node tools/doll/run_qa_review.mjs REGISTRATION_OUTPUT_ROOT [TASK4_GIT_REF]');
const root=path.resolve(output);if(root===repository)throw Error('Use an isolated registration output');
const read=file=>execFileSync('git',['show',`${ref}:${file}`],{cwd:repository,encoding:'utf8',maxBuffer:8*1024*1024});
const rigPath=path.join(root,'project/data/doll/rig_chibi.json'),rig=JSON.parse(fs.readFileSync(rigPath));
rig.qa=JSON.parse(read('project/data/doll/rig_chibi.json')).qa;if(!rig.qa)throw Error('Selected QA ref has no thresholds');
fs.writeFileSync(rigPath,JSON.stringify(rig,null,2)+'\n');
const harness=path.join(root,'.qa-harness');fs.mkdirSync(harness,{recursive:true});fs.writeFileSync(path.join(harness,'project.godot'),'config_version=5\n');
for(const file of ['project/scripts/systems/doll_composer.gd','project/tests/test_doll_qa.gd']){const dest=path.join(harness,file.slice('project/'.length));fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,read(file));}
const result=spawnSync('godot',['--headless','--path',harness,'--script','res://tests/test_doll_qa.gd'],{encoding:'utf8',timeout:60000,maxBuffer:8*1024*1024,env:{...process.env,DOLL_QA_ROOT:root,DOLL_QA_FULL:'1'}});
const log=(result.stdout??'')+(result.stderr??'');fs.writeFileSync(path.join(root,'pixel-qa.txt'),log);process.stdout.write(log);
if(result.error)throw result.error;
process.exit(result.status===0&&!/SCRIPT ERROR|Parse Error/.test(log)?0:1);
