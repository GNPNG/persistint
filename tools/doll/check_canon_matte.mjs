#!/usr/bin/env node
// Explicit acceptance probe; never overwrites the production body.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {readImage,writeImage} from './lib/image.mjs';
import {whiteMatte} from './lib/matte.mjs';
import {alphaMetrics} from './intake.mjs';
const [source,output]=process.argv.slice(2);
if(!source||!output)throw Error('Usage: node tools/doll/check_canon_matte.mjs BODY_CROP OUTPUT.png');
const image=whiteMatte(readImage(source)),metrics=alphaMetrics(image);
writeImage(output,image);fs.writeFileSync(`${output}.json`,JSON.stringify(metrics,null,2)+'\n');
console.log(JSON.stringify(metrics));assert.equal(metrics.borderOpaquePixels,0,'body crop touches the image edge; use margin crop 482x778+57+250');assert.ok(metrics.fringeRatio<=.02,'outline fringe exceeds 2%');assert.ok(metrics.alphaLevels>=64,'fewer than 64 alpha levels');
console.log('RESULT: PASS');
