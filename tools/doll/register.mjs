#!/usr/bin/env node
// Registration preflight and proof verification. Never publish a rejected fit.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {readImage,writeImage,magick} from './lib/image.mjs';
import {greenMatte,whiteMatte,borderKey} from './lib/matte.mjs';
import {crop,isolateLargest,fitBody,landmarkSeed,gates} from './lib/registration.mjs';
export function warp(image,{scale,offset:[x,y]},width=721,height=760){return {width,height,data:magick(['-size',`${image.width}x${image.height}`,'-depth','8','rgba:-','-virtual-pixel','transparent','-filter','Lanczos','-define',`distort:viewport=${width}x${height}+0+0`,'-distort','AffineProjection',`${scale},0,0,${scale},${x},${y}`,'-clamp','-depth','8','rgba:-'],image.data)};}
export function matte(image){for(let i=3;i<image.data.length;i+=4)if(image.data[i]<255)return image;return Math.min(...borderKey(image))>230?whiteMatte(image):greenMatte(image);}
export function splitHair(image,chinY,frontMask){const front={...image,data:Buffer.from(image.data)},back={...image,data:Buffer.alloc(image.data.length)};
 if(frontMask&&(frontMask.width!==image.width||frontMask.height!==image.height))throw Error('Front mask must use frame dimensions');
 for(let y=0;y<image.height;y++)for(let x=0;x<image.width;x++){const p=(y*image.width+x)*4;if(y>chinY&&!(frontMask&&frontMask.data[p+3]>127)){image.data.copy(back.data,p,p,p+4);front.data.fill(0,p,p+4);}}return {front,back};
}
export function differenceMask(a,b,threshold=40){if(a.width!==b.width||a.height!==b.height)throw Error('Comparison dimensions differ');const data=Buffer.alloc(a.data.length);for(let i=0;i<data.length;i+=4){let d=0;for(let c=0;c<3;c++)d=Math.max(d,Math.abs(a.data[i+c]*a.data[i+3]/255-b.data[i+c]*b.data[i+3]/255));d=Math.max(d,Math.abs(a.data[i+3]-b.data[i+3]));if(d>threshold)data[i+3]=255;}return {...a,data};}
export function maskIoU(a,b){let intersection=0,union=0;for(let i=3;i<a.data.length;i+=4){const aa=a.data[i]>127,bb=b.data[i]>127;intersection+=aa&&bb;union+=aa||bb;}return union?intersection/union:0;}
export function registerProof(proof,item,body,{slot='top',rig,expectedScale=1,expectedOffset=[0,0]}={}){
 const lm=rig.landmarks,visible=slot==='top'?((x,y)=>y<lm.chin_y-10||y>lm.crotch_y+10):slot==='hat'?((x,y)=>y>lm.neck_y+10):(()=>true);
 const seed=landmarkSeed(proof,body),fit=fitBody(proof,body,{seed,visible});
 const correction={...fit,offset:fit.offset.map((x,i)=>x-expectedOffset[i])};
 const verdict=gates(correction,{expectedScale,maxShift:.02*Math.max(body.width,body.height),rotationDegrees:seed.rotationDegrees});
 const fittedProof=warp(proof,fit,body.width,body.height);
 // Compare against a reference sampled through the same two grids, so Lanczos
 // changes at the body's own edges are not mistaken for a changed garment.
 const inverse={scale:1/fit.scale,offset:fit.offset.map(v=>-v/fit.scale)};
 const sampledBody=warp(warp(body,inverse,proof.width,proof.height),fit,body.width,body.height);
 const delta=differenceMask(fittedProof,sampledBody);
 let itemFit=fit;
 // When B is not in A's coordinate frame, match its silhouette to the delta.
 if(item.width!==proof.width||item.height!==proof.height){itemFit=fitBody(item,delta);}
 const layer=warp(item,itemFit,body.width,body.height),iou=maskIoU(delta,layer);
 if(iou<.9)verdict.failures.push('proof-item-mismatch');verdict.pass=verdict.failures.length===0;
 return {fit,itemFit,proofItemIoU:iou,...verdict,layer};
}
export function bodyPreflight(sheet,bodyCrop,target){const source=isolateLargest(matte(crop(sheet,bodyCrop))),seed=landmarkSeed(source,target);const fits=[fitBody(source,target,{seed}),fitBody(source,target)];
 // Independent bounding-box and landmark initializations guard against a poor seed.
 const fit=fits.reduce((a,b)=>a.residual_px<b.residual_px?a:b),verdict=gates(fit,{expectedScale:fit.scale,rotationDegrees:seed.rotationDegrees});
 return {source,layer:warp(source,fit,target.width,target.height),report:{...verdict,fit,initializations:fits,sourceCrop:bodyCrop}};
}
function parseCrop(text){const m=/^(\d+)x(\d+)\+(\d+)\+(\d+)$/.exec(text);if(!m)throw Error('Crop must be WxH+X+Y');return [+m[3],+m[4],+m[1],+m[2]];}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const [sheetFile,cropText,targetFile,outputDir]=process.argv.slice(2);if(!outputDir)throw Error('Usage: node tools/doll/register.mjs SHEET BODY_CROP TARGET_BODY OUTPUT_DIR');
 const result=bodyPreflight(readImage(sheetFile),parseCrop(cropText),readImage(targetFile));fs.mkdirSync(outputDir,{recursive:true});writeImage(path.join(outputDir,'body-fit.png'),result.layer);fs.writeFileSync(path.join(outputDir,'body-fit.json'),JSON.stringify(result.report,null,2)+'\n');console.log(JSON.stringify(result.report));process.exitCode=result.report.pass?0:1;
}
