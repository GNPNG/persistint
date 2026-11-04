import assert from 'node:assert/strict';
import {greenMatte,whiteMatte} from './lib/matte.mjs';
import {resample,readImage} from './lib/image.mjs';
import {inspect} from './intake.mjs';
function blank(w,h,color=[0,255,0,255]){return {width:w,height:h,data:Buffer.from(Array.from({length:w*h},()=>color).flat())};}
function rect(im,x,y,w,h,color){for(let yy=y;yy<y+h;yy++)for(let xx=x;xx<x+w;xx++)im.data.set(color,(yy*im.width+xx)*4);}
const edge=blank(258,3);for(let x=1;x<=256;x++){const a=(x-1)/255;edge.data.set([Math.round(a*100),Math.round(a*60+(1-a)*255),Math.round(a*40),255],(258+x)*4);}
const m=greenMatte(edge);let error=0;for(let x=1;x<=256;x++)error+=Math.abs(m.data[(258+x)*4+3]-(x-1))/255;assert.ok(error/256<=2/255);for(let i=0;i<m.data.length;i+=4)if(m.data[i+3]>25)assert.ok(m.data[i+1]-Math.max(m.data[i],m.data[i+2])<=24);console.log('PASS known-coverage green alpha mean error',error/256);
const garment=blank(60,60);rect(garment,10,10,40,40,[255,255,255,255]);rect(garment,25,25,10,10,[0,255,0,255]);const gm=greenMatte(garment);assert.equal(gm.data[(30*60+30)*4+3],0);assert.equal(gm.data[(15*60+15)*4+3],255);
for(const color of [[255,255,255],[255,239,215],[80,200,195],[135,206,235]]){const im=blank(20,20);rect(im,5,5,10,10,[...color,255]);const out=greenMatte(im);assert.deepEqual([...out.data.subarray((10*20+10)*4,(10*20+10)*4+4)],[...color,255]);}
console.log('PASS enclosed hole clear and palette interiors exact (delta E 0)');
const white=blank(40,40,[255,255,255,255]);rect(white,8,8,24,24,[100,60,40,255]);rect(white,11,11,18,18,[255,255,255,255]);const wm=whiteMatte(white);assert.equal(wm.data[3],0);assert.equal(wm.data[(20*40+20)*4+3],255);assert.equal(wm.data[(11*40+11)*4+3],255);console.log('PASS white exterior removed, enclosed white preserved');
const resize= resample({width:2,height:1,data:Buffer.from([200,40,20,255,0,255,0,0])},8,1);for(let i=0;i<resize.data.length;i+=4)if(resize.data[i+3]>20){assert.ok(Math.abs(resize.data[i]-200)<=2);assert.ok(Math.abs(resize.data[i+1]-40)<=2);}console.log('PASS alpha-weighted resample has no transparent green bleed');
for(const [name,count] of [['char_daughter_layers',5],['char_mother_layers',7],['host_oprah_garments',4]]){const report=inspect(readImage(new URL(`../../prompts/image/characters/assets/${name}.png`,import.meta.url).pathname),{expectedCount:count,referenceBody:name==='host_oprah_garments'});assert.equal(report.itemCount,count,JSON.stringify(report));console.log('PASS delivered component count',name,count,'intake reasons:',report.reasons);}
const touch=blank(50,50);rect(touch,10,10,20,20,[100,60,40,255]);assert.ok(inspect(touch,{expectedCount:2}).reasons.includes('component-count-mismatch-or-touching-items'));
const border=blank(50,50);rect(border,0,10,20,20,[100,60,40,255]);assert.ok(inspect(border).reasons.includes('item-edge-contact'));
const gradient=blank(50,50);for(let y=0;y<50;y++)for(let x=0;x<50;x++)gradient.data[(y*50+x)*4+1]=155+x*2;assert.ok(!inspect(gradient).pass);
const leaf=blank(50,50);rect(leaf,10,10,30,30,[20,170,30,255]);assert.ok(inspect(leaf).reasons.includes('green-interior-content'));
console.log('PASS gradient, touching, edge-contact and green-leaf failures');
console.log('RESULT: PASS');
